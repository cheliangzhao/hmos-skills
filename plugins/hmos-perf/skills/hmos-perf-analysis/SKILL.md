---
name: perf-analysis-skill
description: HarmonyOS / OpenHarmony 端到端性能问题自动分析技能。当用户提到"分析性能问题"、"性能分析"、"卡顿分析"、"丢帧分析"、"启动分析"、"调度分析"、"频点分析"、"分析trace"、"抓trace分析"、"分析perf"、"抓perf分析"等时使用。
author: Huawei Reliability Technology Lab
version: 1.0.0
compatibility:
  python: ">=3.7"
  platform: [windows, linux, macos]
---

# 端到端性能问题分析技能

> **官方分发包获取**:本技能需 `scripts/perf_mcp_server-*.tar.gz`(启动 perf-mcp-server 服务的唯一来源)。本仓库不内置该分发包,若缺失请先执行仓库根目录 `scripts/fetch-official-binaries.sh` 从官方 HarmonyOS DFX 仓库拉取,再继续后续定位流程。

## 概述

本技能实现性能问题的端到端自动分析流程。用户只需描述性能问题（如"列表滑动卡顿"、"应用启动慢"），系统自动完成：

1. **环境就绪**：`perf-mcp-server` 已作为 **local MCP** 注册到宿主 CLI（opencode）的配置文件（`opencode.json`），由宿主常驻管理。**本技能直接调用宿主暴露的 `perf-mcp-server_*` 工具**。
2. **日志就绪**：确认是否已有 trace 和 perf 日志，缺失时调用 `references/` 下的抓取指南帮助用户自动抓取。
3. **根因分析**：将当前 trace 和 perf 作为待分析日志，通过宿主 MCP 工具调用 `perf-mcp-server` 对应的 SKILL（`frame_drop_analysis`、`launch_perf` 等）完成分析并输出根因结论。

三步之间存在依赖关系：步骤 1 是步骤 3 的前提（MCP 服务提供分析能力），步骤 2 是步骤 3 的输入（提供待分析日志）。任一步骤失败需明确报错并终止流程，不可跳过。

## MCP 服务环境

本技能依赖的 `perf-mcp-server` MCP 服务**已注册为宿主 CLI 的 local MCP**，由宿主作为常驻子进程管理。MCP 服务分发包以 `perf_mcp_server-<版本号>.tar.gz` 形式（如 `perf_mcp_server-1.0.0.tar.gz`）存放在本技能目录的 `scripts\` 子目录下，**版本号会随版本升级变化**，宿主配置用它经 `uvx` 以隔离环境启动。定位分发包时须兼容版本号差异（见下文"路径定位"），不得硬编码具体版本号。

**本技能通过宿主暴露的 MCP 工具直接对话** `perf-mcp-server`：工具名带 `perf-mcp-server_` 前缀（如 `perf-mcp-server_convert_hitrace_to_sqlite`、`perf-mcp-server_run_skill`、`perf-mcp-server_query_metrics` 等）。宿主负责以 stdio 模式连接服务、常驻管理、保留 session 状态，并按其配置（当前 30 分钟）处理超时。因此分析能力**依赖宿主的 MCP 配置**——若宿主未暴露 `perf-mcp-server_*` 工具，说明 MCP 未加载，需引导用户加载配置。

### 运行环境检测（python / uv，外部开发者必需）

`perf-mcp-server` 依赖 **Python ≥ 3.7** 与 **uv/uvx** 运行。新环境（尤其外部开发者）首次使用时，须先检测并确保两者可用：

1. **检测 python**：
   ```bash
   python --version    # 或 python3 --version
   ```
   - 无输出 / 报 `不是内部或外部命令`：提示用户安装 Python ≥ 3.7（https://www.python.org/downloads/），安装时勾选 "Add Python to PATH"。
   - 版本过低（< 3.7）：提示升级 Python。
2. **检测 uv / uvx**：
   ```bash
   uv --version
   uvx --version
   ```
   - 未安装：提示安装 uv（`pip install uv` 或按 https://docs.astral.sh/uv/ 官方安装指引）。
   - 已安装但命令不在 PATH：提示将 uv 安装目录加入 PATH，或宿主配置 `command` 用 `uvx.exe` 绝对路径。
3. **验证**：`uvx --version` 正常返回即满足要求。

> 若 python 或 uv 缺失/不可用，**先引导用户安装完毕再继续**，不要跳过；否则 MCP 服务无法启动，后续步骤无法执行。

### 宿主配置注册（一次性）

`perf-mcp-server` 已在宿主 `opencode.json` 的 `mcp` 段注册为 `local`：

```json
"perf-mcp-server": {
  "type": "local",
  "command": [
    "<uvx.exe绝对路径>",
    "--from", "{MCP分发包路径}",
    "perf-mcp-server", "stdio"
  ],
  "environment": { "PYTHONIOENCODING": "utf-8" },
  "enabled": true,
  "timeout": 1800000
}
```

> 该条目通常已存在。若宿主未暴露 `perf-mcp-server_*` 工具，引导用户在宿主执行加载 MCP 配置（opencode 可用 `/mcp` 或重启加载 `opencode.json`），**不要**手动修改 skill 自身。

### MCP 分发包位置

```python
# 分发包版本号可能变化，须通过 glob 扫描 scripts 目录动态定位，禁止硬编码具体版本号：
# {MCP分发包路径} = {技能目录}\scripts\perf_mcp_server-<版本号>.tar.gz（唯一匹配）
MCP_PACKAGE = resolve_mcp_package(SKILL_DIR)  # 见 "路径定位" 一节
```

> 该 tarball 是启动服务的唯一来源，随技能包整体分发，供宿主配置经 uvx 使用。**版本号随升级可能变化**，须用 glob 匹配 `perf_mcp_server-*.tar.gz` 动态定位，不要硬编码 `1.0.0`（`scripts` 下只会有一个分发包）。若缺失，向用户报告（提示确切的 tarball 文件名），不要尝试重新下载。

### 验证 MCP 可用（重要）

`perf-mcp-server` 由宿主常驻管理。判定工具可用的标准：

1. **工具已暴露**：宿主当前可用工具列表中出现 `perf-mcp-server_*` 前缀的工具（如 `perf-mcp-server_list_indicators` / `perf-mcp-server_get_skill_catalog`）。
2. **服务响应正常**：调用任一 `perf-mcp-server_*` 工具能返回有效 JSON，说明服务已启动并完成握手。
3. **boot 日志**：服务启动时 stderr 输出 `perf-mcp-server boot: {n} indicators, {m} skills`（宿主日志可见），表示配置加载完成。

> 若宿主未暴露任何 `perf-mcp-server_*` 工具：引导用户在宿主加载 MCP 配置后重试；不要手动用命令行起另一份服务（会造成重复实例），除非排查。

**使用方法**：所有对 `perf-mcp-server` 的能力调用（`get_skill_catalog`、`convert_hitrace_to_sqlite`、`run_skill`、`query_metrics` 等）统一通过宿主暴露的 `perf-mcp-server_*` 工具完成，直接调用，无需 wrapper。调用规范见下节。

## 角色定位

HarmonyOS 高级开发工程师 / HarmonyOS 架构师 / 系统 DFX 工程师 / 整机性能专家。
精通 OpenHarmony 代码，擅长线程管理、Binder 机制、整机状态管理、内存管理、模块解耦等。

## 触发词

| 用户输入模式 | 匹配功能 |
|-------------|---------|
| "分析性能"、"性能分析"、"抓trace分析"、"抓perf分析" | 触发完整三步流程 |
| "卡顿分析"、"丢帧分析"、"启动慢分析"、"调度分析"、"频点分析" | 触发完整三步流程（问题类型用于步骤3选 skill） |
| "帮我分析这个trace"、"分析 {trace文件路径}" | 跳过步骤2（用户已提供日志），执行步骤1+3 |

> **宽匹配触发原则（重要）**：只要用户提到 `trace` 或 `perf`（性能），且当前存在可以分析的文件（如 `.sys` `.systrace` `.htrace` `.ftrace` `.raw` `.data` `.data.gz` 等），就直接执行分析。**不需要前提条件全部具备、也不需要用户明确具体场景**：
> - 已明确场景（启动/丢帧/卡顿/调度/频点…）→ 直接路由到对应 skill
> - 仅提到 trace/perf、未提场景 → 先扫描/转换拿到文件与时间范围（`convert_hitrace_to_sqlite` / `identify_chip_model`），再选择合适的 skill 执行分析（无法明确时用 `ad_hoc_exploration` 兜底）
> - 只要任一日志类型可分析（trace 或 perf 至少有一个），即可开始分析，不要求 trace 和 perf 都齐备
> - 仅当完全找不到可分析文件时，才询问用户是否抓取或提供路径

## 变量约定

本技能所有路径与外部源均以变量形式表达，便于在不同环境部署。

### 路径变量

| 变量 | 含义 | 获取方式 / 默认值 |
|------|------|------------------|
| `{技能目录}` | 本技能文件所在目录 | 运行时通过脚本自身位置定位，**无需用户配置**（见下方"路径定位"） |
| `{Trace抓取指南}` | hitrace 采集流程文档 | 固定 `{技能目录}\references\catch-trace.md` |
| `{Perf抓取指南}` | hiperf 采样流程文档 | 固定 `{技能目录}\references\catch-perf.md` |
| `{本地日志目录}` | 抓取的 trace/perf 保存目录 | 询问用户；默认当前工作目录下的 `trace_logs\` |
| `{MCP分发包路径}` | perf-mcp-server 分发包绝对路径 | 动态定位，见 `{技能目录}\scripts\perf_mcp_server-*.tar.gz`（版本号随升级变化，glob 匹配） |
| `{perf-mcp工具}` | 宿主暴露的 MCP 工具前缀 | 宿主注册名 `perf-mcp-server` → 工具前缀 `perf-mcp-server_`（如 `perf-mcp-server_run_skill`） |

### 运行时变量

| 变量 | 含义 | 获取方式 |
|------|------|---------|
| `{pid}` / `{tid}` | 目标进程/线程 ID | `hdc shell "top -m 10"` 查看高负载进程 |
| `{sqlite_path}` | 日志转换后的 SQLite 路径 | 步骤3.2 由 convert 工具返回 |
| `{选定skill_id}` | 步骤3选定的分析 skill 标识 | 步骤3.3 根据问题描述自主判断 |

### 路径定位

`{技能目录}` 在运行时通过技能文件自身位置定位，**禁止硬编码绝对路径**。`{MCP分发包路径}` 用于宿主注册，本技能运行时不直接使用 tarball：

```python
import os
import glob
# {技能目录} = 本 SKILL.md 所在目录
SKILL_DIR = os.path.dirname(os.path.abspath(__file__))

# 同目录资源（固定相对关系，随技能包整体分发）
CATCH_TRACE   = os.path.join(SKILL_DIR, "references", "catch-trace.md")  # {Trace抓取指南}
CATCH_PERF    = os.path.join(SKILL_DIR, "references", "catch-perf.md")   # {Perf抓取指南}

# 分发包版本号可能变化，用 glob 动态定位，禁止硬编码具体版本号（如 1.0.0）：
#   {MCP分发包路径} = {技能目录}\scripts\perf_mcp_server-<版本号>.tar.gz
# scripts 下只会有一个分发包，glob 匹配返回唯一结果
def resolve_mcp_package(skill_dir):
    matches = glob.glob(os.path.join(skill_dir, "scripts", "perf_mcp_server-*.tar.gz"))
    if not matches:
        raise FileNotFoundError("未找到 scripts/perf_mcp_server-*.tar.gz 分发包")  # 缺失
    return matches[0]

MCP_PACKAGE   = resolve_mcp_package(SKILL_DIR)  # {MCP分发包路径}

# 所有对 perf-mcp-server 的调用统一通过宿主暴露的 MCP 工具完成：
#   {perf-mcp工具}<工具名>，如 perf-mcp-server_convert_hitrace_to_sqlite
```

## 前置条件

本技能坚持"有可分析文件即执行"的宽匹配原则，以下条件非全部必须，按实际存在判断：

1. **MCP 服务可用（执行分析必需）**：宿主已暴露 `perf-mcp-server_*` 工具（MCP 已加载并响应）。不可用且无法修复时无法执行分析，需要向用户报错。
2. **设备连接（仅步骤2抓取时需要）**：HarmonyOS 设备已通过 USB 连接并开启调试模式，已安装 HDC 工具（`hdc list targets` 能识别设备）。仅在需要现场抓取时才要求。
3. **问题描述**：用户应说明遇到的现象（如"滑动卡顿"、"冷启动慢"），用于步骤3选择分析 skill。若未提供（仅提到 trace/perf），不阻塞，直接用已有文件分析，无法明确时用 `ad_hoc_exploration` 兜底。

**核心原则**：只要存在可分析文件（trace 或 perf 至少其一），且 MCP 服务可用，即可开始分析，不要求上述条件全部具备、也不要求日志类型齐全。

> **运行环境（MCP 服务的前提）**：`perf-mcp-server` 依赖 **Python ≥ 3.7** 与 **uv/uvx**。外部开发者首次使用须按"运行环境检测（python / uv，外部开发者必需）"先确保两者可用，否则 MCP 服务无法启动。

## 执行流程

### 步骤 1：确认 perf-mcp-server MCP 工具可用

**目标**：确认宿主已暴露 `perf-mcp-server_*` MCP 工具并响应正常。

#### 1.1 探测 MCP 工具

检查宿主当前可用工具列表，确认存在 `perf-mcp-server_` 前缀的工具（如 `perf-mcp-server_get_skill_catalog`、`perf-mcp-server_list_indicators`、`perf-mcp-server_convert_hitrace_to_sqlite`、`perf-mcp-server_run_skill` 等）。

- **工具已暴露且可调用**：调用 `perf-mcp-server_get_skill_catalog`（或 `perf-mcp-server_list_indicators`）能返回有效 JSON，服务可用，跳到步骤 2。
- **工具未暴露 / 调用报连接错误**：进入 1.2 排查。

> MCP 服务由宿主常驻管理，本次会话内保留 session 状态、按宿主配置（30 分钟）处理超时，多次工具调用间无需重新拉起。

#### 1.2 排查与修复

服务不可用时，按下列顺序排查并**实际执行验证**：

1. **确认宿主配置已注册**：检查宿主 `opencode.json` 的 `mcp` 段已含 `perf-mcp-server`（`enabled: true`，command 用 `uvx --from {MCP分发包路径} perf-mcp-server stdio`）。若无，引导用户添加（参考"MCP 服务环境"一节），提示用 `/mcp` 或重启加载配置。
2. **校验分发包存在**：确认 `{MCP分发包路径}`（`{技能目录}\scripts\perf_mcp_server-<版本号>.tar.gz`，**版本号用 glob 匹配，勿硬编码**）文件存在。若缺失，向用户报告（附确切文件名），不要尝试重新下载。
3. **命令行验证（排查用）**：先确认 python 与 uv/uvx 已安装（见"运行环境检测"一节），再在命令窗口执行 `{MCP启动命令}`（`uvx --from "{MCP分发包路径}" perf-mcp-server stdio`，观察：
   - **成功标志**：stderr 打印 `perf-mcp-server boot: {n} indicators, {m} skills`，说明配置加载完成、服务可正常启动。此时按 `Ctrl+C` 退出。
   - **失败排查**：按报错对照处理：

     | 报错信息 | 原因 | 解决方式 |
     |---------|------|---------|
     | `python` / `uvx: command not found` / `不是内部或外部命令` | 未安装 python/uv 或不在 PATH | 按"运行环境检测"一节安装 python/uv，或修正 uvx 绝对路径后重载配置 |
     | `error: Failed to download/build` / 依赖下载失败 | 公共 PyPI 不可达或网络受限 | 检查网络；
     | `error: cannot find package ... .tar.gz` | `--from` 路径错误 | 检查 `{MCP分发包路径}` 是否为 tarball 绝对路径 |
     | `ModuleNotFoundError: No module named ...` | 构建/安装依赖异常 | 清理 uv 缓存（`uv cache clean`）后重试 |
     | 宿主报连接超时/无响应 | 服务启动慢或首次构建隔离环境 | 增大宿主配置 `timeout`，或先手动执行一次 `{MCP启动命令}` 预热缓存 |

**自行解决原则**：根据具体报错自行分析排查并修复环境（修正宿主配置、安装 uv、清理缓存等）。本技能**不执行任何源码下载或打包**操作，仅使用技能包内置的 `{MCP分发包路径}`。

#### 1.3 复验服务

环境修正后，重新在宿主加载 MCP 配置，再执行 1.1：`perf-mcp-server_*` 工具可用并返回有效 JSON，则步骤 1 完成，进入步骤 2。

若仍失败，向用户报错并附上排查信息（`{MCP启动命令}`、报错内容），终止流程。

---

### 步骤 2：确认并准备 trace 和 perf 日志

**目标**：确认是否已有 trace 和 perf 日志文件，缺失时调用 `{Trace抓取指南}`、`{Perf抓取指南}` 帮助用户自动抓取。

#### 2.1 识别用户已提供的日志

扫描用户输入，提取已明确给出的日志路径。识别规则：

| 日志类型 | 文件扩展名 | 说明 |
|---------|-----------|------|
| trace | `.sys` `.systrace` `.htrace` `.ftrace` `.raw` | 系统调度/渲染/帧链路数据 |
| perf | `.data` `.data.gz` | hiperf 采样数据（函数调用栈/PMU） |

**检查位置**（按优先级）：
1. 用户消息中显式提到的路径
2. 用户指定的目录（如"分析 `{某目录}` 下的trace"）
3. 当前工作目录及其子目录（递归扫描上述扩展名）

**结果判定**：
- 同时找到 trace 和 perf → 跳到 2.3 汇总，按两类日志综合分析。
- 只找到 trace 或只找到 perf → **直接继续，不阻塞**：有 trace 分析帧链路/调度，有 perf 分析函数热点，用已有的任意日志继续分析（步骤3按实际日志类型选择 skill）。仅当用户有明确抓取需求时才执行 2.2 补齐，否则继续。
- 都未找到 → 询问用户是"现场抓取"还是"提供已有路径"。选择现场抓取则执行 2.2。

> 遵循宽匹配原则：只需要 trace 与 perf 至少其一可分析即可继续，不需要两类都齐备。

#### 2.2 缺失时调用 references 抓取

抓取依赖 HDC 工具与已连接的 HarmonyOS 设备。先验证设备连接：

```bash
hdc list targets
```

- **无设备输出**：提示用户检查 USB 连接与调试模式，终止流程。
- **hdc 未安装**：提示用户打开 DevEco Studio → 设置 → OpenHarmony SDK 选项卡找到安装路径，在安装路径下查找 hdc 并加入环境变量，再重新检查。

**抓取 trace**（加载 `{Trace抓取指南}` 执行）：

推荐短时采集（测试操作时长 ≤30s 明确时）：

```bash
# 1. 清理设备缓存
hdc shell "rm -rf /data/log/hitrace/*.sys 2>/dev/null"

# 2. 采集 30 秒（用户需在 30s 内完成测试操作）
hdc shell hitrace -t 30 --raw --file_size 204800 -b 102400 ace ark app ohos ability graphic sched freq nweb workq pagecache binder irq disk memreclaim samgr sync zcamera zmedia commonlibrary net zaudio idle ufs distributeddatamgr dsoftbus i2c mdfs misc mmc msdp multimodalinput notification regulators sensors window zimage ffrt

# 3. 导出到本地（保存到 {本地日志目录}）
hdc file recv /data/log/hitrace/ {本地日志目录}\
```

长时采集（测试时长不确定时）：用 `--trace_begin --record` 开始 → 执行测试 → `--trace_finish --record` 结束。详见 `{Trace抓取指南}`。

**抓取 perf**（加载 `{Perf抓取指南}` 执行）：

```bash
# 1. 查找目标进程 {pid}（高负载进程）
hdc shell "top -m 10"

# 2. 单进程采样 10 秒（推荐 dwarf 回栈 + 调用栈 + CPU周期/指令数）
hdc shell hiperf record -p {pid} -d 10 -s dwarf -g -e hw-cpu-cycles,hw-instructions -o /data/local/tmp/perf.data

# 3. 拉取到本地（保存到 {本地日志目录}）
hdc file recv /data/local/tmp/perf.data {本地日志目录}\
```

**抓取注意事项**：
- trace 和 perf 建议同时采集（trace 看调度/帧链路，perf 看函数热点），可先抓 perf 再抓 trace，或并行。
- trace 报错码 1103（有未关闭采集任务）：先执行 `hdc shell hitrace --stop_bgsrv` 再重试。
- 禁止用 Ctrl+C 打断采集，会破坏 trace 环境。
- 采集时告知用户"请在接下来 {时长} 秒内复现问题操作"。

#### 2.3 汇总日志清单

收集本次分析要用的日志文件，记录绝对路径：

```python
logs = {
    "traces": ["{trace文件路径1}", ...],   # trace 文件绝对路径列表
    "perfs":  ["{perf文件路径1}", ...],    # perf 文件绝对路径列表
}
```

若两类日志都为空，向用户报错"未获取到任何待分析日志"，终止流程。

---

### 步骤 3：调用对应 SKILL 分析

**目标**：将步骤 2 准备的 trace 和 perf 作为待分析日志，调用 `perf-mcp-server` 对应 SKILL 完成根因分析。

#### 3.1 学习 perf-mcp-skill-guide（必须先执行，已内嵌本指南）

调用 MCP 前必须先掌握 perf-mcp-server 的正确使用方式。本指南已内嵌于本技能（见下节"perf-mcp-skill-guide 内嵌指南"），无需再单独加载外部技能。

**核心约束**：
- **所有能力调用统一通过宿主暴露的 `perf-mcp-server_*` 工具完成，直接调用**，不再经 wrapper、不再用命令行拉起服务。工具名带 `perf-mcp-server_` 前缀（如 `perf-mcp-server_convert_hitrace_to_sqlite`、`perf-mcp-server_run_skill`）。
- **禁止直接写 SQL 查 trace.db**，必须通过 `perf-mcp-server_query_metrics` 或 `perf-mcp-server_run_skill` 访问数据。直接查库会绕过框架的参数注入和数据转换逻辑，导致错误结果。
- **用 `run_skill` 框架执行分析**：框架自动处理 `default_indicator_params` 注入（tid / chip_model 等）、`iterate` 展开（thread_queries 逐项查询）、断点控制（auto_continue / resume）。**宿主常驻服务保留 session 状态**，`run_skill` 多次调用可带 `resume=<session_id>` 在同一 session 内续跑直到 `is_complete=True`。
- **标准路径**：`perf-mcp-server_get_skill_catalog` → `perf-mcp-server_get_skill` → `perf-mcp-server_run_skill`（`auto_continue=True`）→ 若 `waiting_for_agent=True`，读取 `llm_context` 推理后以 `resume=<session_id> + input_params.reasoning=<推理>` 再次调用 → 直到 `is_complete=True`。

---

### perf-mcp-skill-guide 内嵌指南

#### 触发条件（宽匹配）

只要用户提到 `trace` 或 `perf`（性能），且当前存在可以分析的文件（`.systrace` / `.htrace` / `.ftrace` / `.sys` / `.db` / `.data` 等），就直接执行分析。**不需要先确认用户具体要求、也不要求所有前置条件都具备**——具备可分析文件即可开始。

- 若用户已明确场景（启动 / 丢帧 / 调度 / 频点…）→ 直接路由到对应 skill
- 若仅提到 trace / perf，未提具体场景 → 先 `convert_hitrace_to_sqlite` 或 `identify_chip_model` 拿到文件和时间范围，再执行分析
- 找不到可分析文件时，才询问用户提供 trace 路径

#### 分析任务的标准路径

```
perf-mcp-server_get_skill_catalog  → 查看可用技能（返回 skills 列表）
    ↓
perf-mcp-server_get_skill          → 读取目标 Skill 的完整定义（steps / input_params / overrides）
    ↓
perf-mcp-server_run_skill          → 执行 run_skill 框架（auto_continue=True 自动执行到 LLM action）
    ↓
Agent 推理                         → 若 waiting_for_agent=True，读取 llm_context 推理后带
                                    resume=<session_id> + reasoning 续跑，直到 is_complete=True
```

> 所有调用均为宿主 MCP 工具的**直接调用**，多次 `run_skill` 调用基于 `resume=<session_id>` 在同一常驻 session 内续跑，不跨进程丢失状态。

#### 切勿直接分析 SQLite 文件

不要自己写 SQL 去查 trace.db，必须通过 `perf-mcp-server_query_metrics` 或 `perf-mcp-server_run_skill` 访问数据。

#### 为什么用 `run_skill` 而不是自己调

`run_skill` 框架自动处理 `default_indicator_params` 注入（tid / chip_model 等）、`iterate` 展开（thread_queries 逐项查询）、断点控制（auto_continue / resume）。自己照着 YAML 一步步调容易遗漏，导致数据错误。通过 `perf-mcp-server_run_skill` 直接调用该框架。

#### 何时用 `run_skill` vs 直接工具

| 场景 | 用什么 | 宿主 MCP 工具 |
|------|--------|-------------|
| 启动 / 丢帧 / 调度 / 频点 / 即席探索 | `run_skill` | `perf-mcp-server_run_skill`（`skill_id` + `trace_path_or_dir` + `input_params`） |
| 单指标查询（cpu_freq / cpu_load / frame_summary） | `query_metrics` | `perf-mcp-server_query_metrics` |
| 确认芯片型号 / 时间范围 | `identify_chip_model` / `convert_hitrace_to_sqlite` | `perf-mcp-server_identify_chip_model` / `perf-mcp-server_convert_hitrace_to_sqlite` |

#### `overrides` 参数

`run_skill` 的 `overrides` 可补充或覆盖 step-level 默认参数（如 indicator_params），优先级高于框架自动注入。直接通过 `perf-mcp-server_run_skill` 在参数里传 `overrides` 字段即可。

#### `input_params` 参数

`run_skill` 的 `input_params` 传入 skill 的输入参数，填充到 YAML `input.xxx` 表达式解析。可用参数由各 skill 的 `input_params` 定义，可通过 `perf-mcp-server_get_skill_catalog` 查看。直接通过 `perf-mcp-server_run_skill` 在参数里传 `input_params` 字段。

**`input_params` 与 `overrides` 的区别**：

| 参数 | 用途 | 数据流 |
|------|------|--------|
| `input_params` | 传入 skill 输入参数 | `input.xxx` 表达式 |
| `overrides` | 覆盖 step-level 参数 | step args / indicator_params |

#### 3.2 转换日志为 SQLite

trace 和 perf 是原始二进制，需先转换为 SQLite 才能查询。转换通过宿主 MCP 工具 `perf-mcp-server_convert_hitrace_to_sqlite` / `perf-mcp-server_convert_hiperf_data` 完成。

**trace 转换**（对每个 trace 文件）：调用 `perf-mcp-server_convert_hitrace_to_sqlite`，参数 `{"trace_path": "{trace文件绝对路径}"}`。
返回：`sqlite_path`、`trace_meta.{start_ms, end_ms, duration_ms}`

**perf 转换**（对每个 perf 文件）：调用 `perf-mcp-server_convert_hiperf_data`，参数 `{"data_path": "{perf.data绝对路径}"}`。
返回：`sqlite_path`、`trace_meta`、`brbe_stats`、`spe_stats`

> 转换后的 `{sqlite_path}` 是后续 `run_skill` 的 `trace_path_or_dir` 入参。

#### 3.3 选择分析 SKILL

先通过 `perf-mcp-server_get_skill_catalog` 获取所有可用技能，再根据用户问题描述自主判断使用哪个 skill（不依赖硬编码触发词正则）：

```json
{"format": "compact"}
```
（返回 skill 列表；格式 `compact` 仅返回 skill_id，`json` 返回含 `input_params` 的完整信息）

| 问题描述特征 | 推荐 `{选定skill_id}` | 说明 |
|------------|--------------|------|
| "启动"、"冷启动"、"首屏"、"launch" | `launch_perf` | 启动阶段拆解 + 瓶颈定位 |
| "卡顿"、"丢帧"、"jank"、"滑动不流畅" | `frame_drop_analysis` | 丢帧区间识别 + 线程下钻 |
| "调度"、"线程阻塞"、"CPU亲和" | `sched_analysis` | 调度延迟与运行时分析 |
| "频点"、"频率"、"大核频率" | `freq_distribution` | 频点分布分析 |
| "IO"、"磁盘"、"读写慢" | `io_analysis` | IO 延迟与块大小 |
| "负载对比"、"多设备对比" | `load_compare` | 负载对比分析 |
| "游戏卡顿"、"游戏丢帧"、"游戏性能" | `game_performance` | 游戏体验分析 |
| "渲染框架"、"渲染管线"、"框架类型" | `detect_rendering_pipeline_skill` | 渲染管线检测 |
| "perf热点"、"函数耗时"、"火焰图" | `hiperf_sampling_analysis` | hiperf 采样分析（需 perf 日志） |
| 无法明确判断 | `ad_hoc_exploration` | 通用即席分析（fallback） |

**有 perf 日志时**：除主 skill 外，建议补充调用 `hiperf_sampling_analysis` 定位函数级热点，与 trace 侧分析互补（trace 看链路/调度，perf 看函数热点）。

#### 3.4 执行 run_skill 分析

对每个 trace/perf 的 `{sqlite_path}`，调用 `perf-mcp-server_run_skill` 执行 skill 分析。**核心约束：必须轮询到 `is_complete=True` 才能提取结论，禁止提前退出。**

`perf-mcp-server_run_skill` 由宿主常驻服务执行，**session 状态在同一 session 内保留**；多次调用通过 `resume=<session_id>` 续跑，不跨进程丢失。请求参数：

| 参数 | 说明 |
|------|------|
| `skill_id` | 选定的 skill 标识（如 `launch_perf` / `frame_drop_analysis`） |
| `trace_path_or_dir` | `{sqlite_path}`（转换后的 trace.db 路径） |
| `input_params` | skill 输入参数（见下方"input_params 提取规则"）；续跑时可含 `reasoning` |
| `auto_continue` | 建议 `true`（自动执行到 LLM action 处暂停） |
| `resume` | 续跑时传上次返回的 `session_id` |
| `overrides` | 可选，覆盖 step-level 参数 |

**调用语义**：
- 返回 `is_complete=true` → 分析完成，读取 `state` / `current_result` 提取结论。
- 返回 `waiting_for_agent=true` → 框架在 LLM action 处暂停，返回含 `llm_context` 与 `session_id`。此时读取上下文、进行推理（`analyze_from_context`），再以 **`resume=<session_id>` + `input_params.reasoning=<推理结果>`** 再次调用 `perf-mcp-server_run_skill` 续跑。
- 续跑后若仍 `waiting_for_agent=true` → 重复"读 `llm_context` → 推理 → `resume` + `reasoning` 续跑"，直至 `is_complete=true`。

**input_params 提取规则**：
- `package_name`：优先用用户说的中文名（如"微信"→"微信"，"抖音"→"抖音"），不要自行翻译为 Android 包名，框架内部自动解析映射。
- `launch_duration`：用户提到启动时长时传入毫秒（如"启动1秒"→1000）。
- 无匹配参数时传 `{}`。
- 续跑的 `reasoning` 放在 `input_params.reasoning`。

**多日志分析**：遍历所有 trace 和 perf，每个独立分析，单个失败不阻断其他。记录每个日志的：文件名、`{选定skill_id}`、根因结论、关键备注（帧号/线程/阶段等）。

#### 3.5 汇总根因结论

所有日志分析完成后，归纳 Top 3 根因及优化建议：

1. **去重归并**：多个日志可能指向同一根因，合并为一条。
2. **排序取 Top 3**：按影响程度（严重度 × 涉及日志数）排序。
3. **标注涉及日志**：每条根因后标注涉及哪些日志序号。
4. **生成优化建议**：为每条根因给出可操作的优化建议。

**输出格式**：
```
1. {根因摘要}(涉及日志{序号}): {优化建议}
2. {根因摘要}(涉及日志{序号}): {优化建议}
3. {根因摘要}(涉及日志{序号}): {优化建议}
```

**结果摘要模板**：
```
【性能分析完成】

环境：perf-mcp-server MCP 服务 ✓ 已就绪
日志：trace {n} 个 / perf {m} 个

📋 根因概要：
1. {根因1}(涉及日志1,2): {优化建议1}
2. {根因2}(涉及日志3): {优化建议2}
3. {根因3}(涉及日志1): {优化建议3}

📁 分析详情：
- {日志1}: {选定skill_id} → {结论摘要}
- {日志2}: {选定skill_id} → {结论摘要}
```

## 错误处理

### 步骤级别错误

| 错误类型 | 出现步骤 | 处理方式 |
|---------|---------|---------|
| 宿主未暴露 `perf-mcp-server_*` 工具 | 步骤1 | 确认 `opencode.json` 的 mcp 段已注册 `perf-mcp-server`，引导用户用 `/mcp` 或重启加载配置，终止流程 |
| `perf-mcp-server_*` 工具调用报连接/超时错误 | 步骤1 | 按 `{MCP启动命令}` 命令行验证服务可启动，检查宿主配置 uvx 路径与 `--from {MCP分发包路径}`，附排查信息，终止流程 |
| 设备未连接 / hdc 未安装 | 步骤2 | 提示用户检查 USB 与调试模式，或配置 hdc 环境变量，终止流程 |
| trace 采集报错（如 1103） | 步骤2 | 执行 `hdc shell hitrace --stop_bgsrv` 后重试 |
| 日志转换失败（convert 报错） | 步骤3 | 记录失败日志，跳过该日志，继续其他日志分析 |
| get_skill_catalog 调用失败 | 步骤3 | 提示 MCP 服务异常，回到步骤1排查，终止流程 |
| `run_skill` 返回 `waiting_for_agent=true` | 步骤3 | 读取 llm_context 推理后带 `resume=<session_id> + input_params.reasoning=<推理>` 续跑（正常流程，非错误） |
| `run_skill` 长时间未 `is_complete` / 报错 | 步骤3 | 记录失败原因，跳过该日志，继续其他日志分析 |

### 流程约束

- **宽匹配执行**：用户提到 trace 或 perf 且存在可分析文件即可执行，不要求前提条件全部具备、不要求 trace 与 perf 齐全。
- **步骤依赖**：步骤1未通过不可进入步骤3（无 MCP 服务无法分析）；步骤2无任何日志不可进入步骤3（无输入）。
- **不可跳过探测**：步骤1.1 必须先实际调用一个 `perf-mcp-server_*` 工具确认可用，不可仅凭配置文件存在就判定可用。
- **禁止直接 SQL**：步骤3 全程通过 `perf-mcp-server_query_metrics` / `perf-mcp-server_run_skill` 访问数据，禁止手写 SQL 查 trace.db。
- **轮询不提前退出**：步骤3.4 `run_skill` 在 `is_complete=true` 前禁止提前退出；`waiting_for_agent` 必须续跑而非放弃。

## 注意事项

1. **变量替换**：执行前先将文中 `{占位符}` 替换为实际值。路径类变量按"变量约定"获取，其中 `{MCP分发包路径}` 通过 glob 匹配 `{技能目录}\scripts\perf_mcp_server-*.tar.gz` 动态定位（**版本号随升级可能变化，禁止硬编码 `1.0.0`**），`{perf-mcp工具}` 前缀为宿主注册名 `perf-mcp-server` 对应的工具前缀 `perf-mcp-server_`。
2. **不执行安装/注册流程**：本技能**不包含** MCP 服务的下载、安装与配置文件修改流程；`perf-mcp-server` 由宿主按 `opencode.json` 的 mcp 段（`uvx --from {MCP分发包路径}` 隔离环境）启动。若宿主未暴露工具，引导用户在宿主加载配置，而非手动另起服务。
3. **启动成功的判定**：服务启动时 stderr 出现 `perf-mcp-server boot: {n} indicators, {m} skills` 才算启动成功；stderr 中的 `pydantic_settings` 警告属正常现象，可忽略。
4. **统一走宿主 MCP 工具**：所有对 perf-mcp-server 的调用统一通过 `perf-mcp-server_*` 工具完成（如 `perf-mcp-server_run_skill`、`perf-mcp-server_query_metrics`、`perf-mcp-server_convert_hitrace_to_sqlite`），**不直接写 SQL**、不经命令行手工起服务。
5. **SQL 查询约束**：禁止直接写 SQL 查询 SQLite 数据库，必须通过 `perf-mcp-server_query_metrics` 或 `perf-mcp-server_run_skill` 执行分析。
6. **session 续跑**：`run_skill` 的 `resume=<session_id>` 在宿主常驻服务同一 session 内有效；分析的 session 状态由宿主保留，多次调用续跑直到 `is_complete=true`。

## 验收标准

- [ ] 用户说"分析性能/卡顿分析/抓trace分析"时技能被正确触发
- [ ] 用户仅提到 trace 或 perf（含提到"perf"但未提具体场景），且存在可分析文件时，技能直接执行分析（不要求前提全部具备、不要求 trace 和 perf 都齐备）
- [ ] 步骤1：能通过宿主 `perf-mcp-server_*` 工具实际探测 MCP 服务可用性（如调用 `perf-mcp-server_get_skill_catalog`）
- [ ] 步骤1：不可用时确认 `{MCP分发包路径}` 存在、宿主 mcp 段已注册 `perf-mcp-server`，按 `{MCP启动命令}` 实际启动验证（看到 `perf-mcp-server boot: ...` 日志即成功），引导用户在宿主加载配置
- [ ] 步骤1：验证通过（`perf-mcp-server_*` 工具返回有效 JSON）后才进入步骤2；不执行任何下载/安装/注册流程
- [ ] 步骤2：能识别 `.sys/.htrace/.data` 等日志文件；缺失时调用 `{Trace抓取指南}`、`{Perf抓取指南}` 抓取
- [ ] 步骤2：抓取前验证设备连接，采集时提示用户复现操作
- [ ] 步骤3：使用内嵌的 perf-mcp-skill-guide 指南，禁止直接 SQL
- [ ] 步骤3：trace 用 `perf-mcp-server_convert_hitrace_to_sqlite`、perf 用 `perf-mcp-server_convert_hiperf_data` 转换
- [ ] 步骤3：根据问题描述自主选择 skill，用 `perf-mcp-server_run_skill` 执行并轮询到 `is_complete=true`
- [ ] 步骤3：`run_skill` 返回 `waiting_for_agent=true` 时读取 llm_context 推理后带 `resume=<session_id> + input_params.reasoning=<推理>` 续跑
- [ ] 步骤3：有 perf 日志时补充 `hiperf_sampling_analysis` 定位函数热点
- [ ] 最终输出含 Top 3 根因 + 优化建议 + 涉及日志序号的结果摘要
- [ ] 用户已提供日志路径时跳过步骤2，直接执行步骤1+3
- [ ] 单个日志分析失败不阻断其他日志，失败原因明确记录
- [ ] 所有本地路径（含 `{MCP分发包路径}`）均以变量/相对 `{技能目录}` 方式表达，无硬编码绝对路径
