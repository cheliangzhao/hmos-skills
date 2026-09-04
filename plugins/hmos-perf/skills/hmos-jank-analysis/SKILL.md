---
name: trace-analyzer
description: >
  分析 HarmonyOS trace 文件，检测卡顿帧、根因分析、CPU 状态统计，生成 CSV/JSON/HTML 报告。
  当用户提到"分析 trace"、"analyze trace"、"卡顿分析"、"jank 分析"、"帧率分析"、
  "完成时延"、"completion latency"、"trace-analyzer"时使用。
metadata:
   author: Huawei Reliability Technology Lab
   version: 1.3.0
---

# 性能卡顿问题分析工具

> **官方工具获取**:本技能依赖 `scripts/analysis.*` 与 `scripts/trace_streamer/*`。这些二进制由官方 HarmonyOS DFX Skills 仓库以 Git LFS 分发,本仓库刻意不内置以保持轻量。运行前若对应 `scripts/` 下缺失工具,请先执行仓库根目录 `scripts/fetch-official-binaries.sh` 拉取。

## 自动加载 References

本 SKILL 会自动加载以下 reference 文件：

| Reference 文件           | 用途                  | 路径                                |
|------------------------|---------------------|-----------------------------------|
| catch-trace.md   | 抓取故障现场trace信息  | references/catch-trace.md    |
| jank-report-analysis.md         | 分析丢帧Excel报告，输出结构化报告 | references/jank-report-analysis.md  |

**自动加载逻辑**：在执行步骤中，需要使用 reference 文件时，动态读取对应文件内容。

## 主要功能

对抓取的 `.htrace`、`.sys`、`.ftrace`、`.db` trace 文件进行性能分析，如果缺失必要文件则提示用户抓取对应日志，
识别卡顿帧、定位根因（RS 高负载、供给不足、同步等待、UI 高负载），生成多格式报告。

## 角色定位
HarmonyOS 高级开发工程师 / HarmonyOS 架构师 / 系统 DFX 工程师 / 整机性能专家。  
精通 OpenHarmony 代码，擅长线程管理、Binder 机制、整机状态管理、内存管理、模块解耦等。

## 分析目标
从 日志和trace中分析出影响性能的**Top根因**，构建完整证据链，并给出修复建议。

## 约束
- 必须基于日志中**实际存在**的信息，严禁编造或随意拼接日志片段。
- 每条关键结论必须有原始日志内容作为佐证。
- 按以下 Step 顺序逐步分析。
- **必须先执行框架识别 (`--option 84`)，根据识别结果选择对应的分析选项**：
  - ArkUI框架 → `--option 3`（或 `--option 5` 兜底）
  - Flutter框架 → `--option 42`
  - Web框架 → `--option 34`
  - PMU框架 → `--option 47`
  - **禁止在未确认框架类型前随意执行分析选项**


## 使用方式

| 命令                                   | 说明                        |
|--------------------------------------|---------------------------|
| `/analysis --path <trace文件父目录>`      | 分析 trace 文件父目录（支持多个trace） |
| `/analysis --trace_file <trace文件>`             | 分析 trace 文件（单个trace）      |
| `/analysis --option <num>`           | 执行丢帧拆解选项                  |
| `/analysis --cpu_load_cfg <cpu_load_cfg文件>` | 传入cpu配置文件                 |

## 执行步骤

### 步骤一：环境检查

按以下顺序查找 `analysis` 可执行文件：


**可执行文件路径（根据系统自动选择）：**

| 系统   | 可执行文件路径                          |
|------|----------------------------------|
| Windows | `./scripts/analysis.exe`         |
| macOS   | `./scripts/analysis_mac`   |
| Linux   | `./scripts/analysis_linux` |

### 步骤二：准备trace
如果缺失可以分析的trace或者perf，提示用户抓取trace和perf日志文件。

> **自动加载 Reference**：通过 `references/性能抓trace和perf日志SKILL.md` 帮用户自动抓trace和perf。

将抓取到的文件作为需要分析的trace日志

### 步骤三：解析用户意图

根据用户请求确定运行参数：

| 用户需求              | 对应参数                                     |
|-------------------|------------------------------------------|
| 指定trace文件目录路径     | `--path "D:\trace_path\"`                |
| 指定按照性能雷达打点分析选项    | `--option 3`                             |
| 指定按照上屏信号fence分析选项 | `--option 5`                             |
| 指定按照启动完成时延分析选项    | `--option 16`                            |
| 指定按照应用启动响应时延分析选项  | `--option 17`                            |
| 指定按照web丢帧分析选项 | `--option 34`                            |
| 指定按照Flutter丢帧分析选项 | `--option 42`                            |
| 指定按照PMU帧拆解分析选项    | `--option 47`                            |
| 指定按照Flutter丢帧分析选项 | `--option 42`                            |
| 分析框架选项            | `--option 84`                            |
| 传入cpu配置文件         | `--cpu_load_cfg "D:\cpu_log_config.txt"` |
| 指定保存路径            | `--save_path "D:\report"`                |

如果用户提及动效类型，则在references下的【性能雷达】单框架动效维测场景全集.xlsx中找到动效类型对应打点

### 步骤四：执行分析

**基础卡顿分析（默认模式）：**

先通过框架检测确认框架类型， 输出结果在excel中，
如果用户没有提及对应线程，则优先看三方应用的框架类型，排除自研应用进程（自研应用为大桌面ohos.sceneboard，render_service线程），
框架类型为G列，应用进程名称在B列。
默认分析ArkUI框架，如果结果中三方框架应用绘制有flutter，则分析flutter框架 有web则分析web框架。
如果确定框架没有检测出结果，则直接给出无结果。

```bash
# 分析框架类型
analysis.exe --path "D:\developtools_dfx_skills-master\examples\2110018587\trace\" --option 84

# 自动检测主线程 分析雷达打点丢帧
analysis.exe --path "D:\developtools_dfx_skills-master\examples\2110018587\trace\" --option 3

# 自动检测主线程 分析Fence丢帧
analysis.exe --path "D:\developtools_dfx_skills-master\examples\2110018587\trace\" --option 5


# 指定cpu配置文件
analysis.exe --path "D:\developtools_dfx_skills-master\examples\2110018587\trace\" --option 3 --cpu_load_cfg "D:\developtools_dfx_skills-master\cpu_load_cfg"

# 指定保存路径
analysis.exe --path "D:\developtools_dfx_skills-master\examples\2110018587\trace\" --option 3 --save_path "D:\developtools_dfx_skills-master\report"

```
默认指定保存路径为SKILL.md同级的report文件夹下新建一个trace同名的文件夹 存放分析结果，
必须指定保存路径，避免与其他结果混淆。

**框架与分析选项对应关系（必须根据框架识别结果选择对应选项）：**
| 框架类型 | 分析选项 | 说明 |
|---------|---------|------|
| ArkUI | `--option 3` | 性能雷达打点丢帧，若结果为空则用 `--option 5` 兜底 |
| Flutter | `--option 42` | Flutter丢帧分析 |
| Web | `--option 34` | Web丢帧时延拆解 |
| PMU | `--option 47` | PMU帧拆解 |

后续基于这个excel来输出后续的报告，excel文件位置在脚本执行最后一行会打印。
优先看三方应用的框架类型，排除自研应用进程（自研应用为大桌面ohos.sceneboard，render_service线程）
如果用户提及对应线程，筛选输出对应线程的问题
如果没有分析结果，则报告trace无发现明显异常，重新抓trace现场
分析性能excel报告使用references下的jank-report-analysis.md

### 步骤五：分析hilog日志

如果分析日志路径下有对应的hilog日志，则通过trace的抓取时间找到hilog附近的日志，找到trace现场的应用场景信息。
严格按照使用references中的hilog日志分析SKILL.md
trace名称上的时间为开始时间
例如：Screen_trace_20260424180056@431227-16218.sys
20260424180056为trace的开始时间 16218为trace的耗时，单位为ms

> **自动加载 Reference**：会动态读取 `references/hilog日志分析SKILL.md` 中的hilog分析规则。


### 步骤六：展示结果

分析完成后，向用户汇报分析结果：
trace开始时间，结束时间，耗时
分析结果用references下的jank-report-analysis.md的输出结果，结果尽可能详细，将根因分析步骤展示清楚。
如果有hilog结果则把场景信息放在分析结果中，放在分析结果的开头。

> **自动加载 Reference**：生成报告时会读取 `references/jank-report-analysis.md` 中的报告模板和输出格式。


## 错误处理

| 错误情况 | 处理方式 |
|----------|----------|
| 输入文件不存在 | 提示用户确认文件路径 |
| .htrace/.ftrace 文件 | trace-analyzer 内置转换，直接传入即可；若转换失败建议先用 `/htrace-converter` 转换 |
| 分析失败（非零退出码） | 显示完整错误输出，建议加 `-v` 重试查看详情 |
| 未检测到目标线程 | 建议用户通过 `-m` 明确指定主线程名 |
| 未检测到触摸事件（完成时延模式） | 提示使用 `--completion-latency-tags` 指定 tag 点 |

