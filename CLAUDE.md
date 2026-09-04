# CLAUDE.md

本仓库是 **HarmonyOS(hmos-*)技能**的独立插件市场,同时服务 Claude Code 与 Codex 两个生态。所有插件均为双格式(`.claude-plugin/` + `.codex-plugin/`),技能内容一致,改动需两端市场同步。

## 技能来源

本仓库技能内容来自华为官方 HarmonyOS 技能分发的两个互补来源,**多数来自 `devecocli skills`**:

- **主要来源 — `devecocli skills`**(官方分发版,`devecocli skills list` / `add <name> <--project>`):hmos-arkts 的 knowledge-retriever / syntax-checker、hmos-arkui、hmos-multidevice、hmos-kits(push-kit)、hmos-testing,以及 hmos-perf 的 apifault / appfreeze / cppcrash / fdleak / jscrash / jsleak / memleak / native-memleak。技能名自带 `hmos-` 前缀。
- **补充来源 — HarmonyOS DFX Skills(GitCode)** https://gitcode.com/openharmony-sig/developtools_dfx_skills (fault-analysis / code-fix / static-check 底层仓库):对应 hmos-perf 的 jank-analysis、perf-analysis,与 hmos-arkts 的 error-fixes / grammar-standards / runtime-fix;官方 skill 名无 `hmos-` 前缀(如 `nativeleak-analysis`),本地统一加 `hmos-`。
- 更新技能内容时以对应官方源为准(devecocli 或 GitCode);两者内容以各自最新分发对齐。
- 本仓库是 `FadingLight9291117/claude-codex-plugins` 中 hmos-* 插件的独立副本,由该仓库拆出;Android(android-*) 仍留在原仓库。

## 官方更新同步流程(必做)

官方仓库更新后:

1. `git clone --depth 1 https://gitcode.com/openharmony-sig/developtools_dfx_skills.git /tmp/dfx_skills_check`
2. 对照官方目录与 `plugins/hmos*/skills/`,找出更新/新增/删除的技能
3. 将技能改动同步到本仓库 `plugins/hmos*/skills/`,保持完全一致
4. 在受影响插件的两端 `plugin.json`(`.claude-plugin/` 与 `.codex-plugin/`)递增 `version`,否则重装可能不刷新
5. 提交推送;如需本地验证/使用,安装或升级:`claude plugin marketplace add cheliangzhao/hmos-skills` + `claude plugin install <name>` / `codex plugin ...`
6. 官方文件若为 Git LFS 指针(100 字节文本),需在有 git-lfs 的环境 clone 才能拿到真实内容

## 目录结构与格式

- `.claude-plugin/marketplace.json` — Claude 市场清单(owner: cheliangzhao)
- `.agents/plugins/marketplace.json` — Codex 市场清单(插件 name/source 须与 Claude 清单一致;两 schema 不同)
- `plugins/hmos-arkts/` — 双格式,ArkTS 语言技能 5 个
- `plugins/hmos-arkui/` — 双格式,ArkUI 界面技能 3 个
- `plugins/hmos-multidevice/` — 双格式,多设备适配技能 7 个
- `plugins/hmos-kits/` — 双格式,Kit 集成技能 1 个(push-kit)
- `plugins/hmos-perf/` — 双格式,性能/故障分析技能 10 个(含 perf-analysis)
- `plugins/hmos-testing/` — 双格式,测试技能 2 个(instrument-test / local-test)

## 精简与官方二进制获取(重要)

本仓库刻意**不内置**大体积运行时二进制,以保持仓库轻量、避免单文件超 GitHub 100MB 限制:

- 已精简掉的工具:hmos-perf 各技能的 `analysis.exe`/`analysis_linux`/`analysis_mac`、`trace_streamer_*`、cppcrash 早期内置的 `llvm-objdump`/`llvm-addr2line`/`reliability_analyze`/`extract_hilog` 工具链、perf-analysis 的 `perf_mcp_server-*.tar.gz`;以及 hmos-arkts `linter-cli` 的 `node_modules`(以 `.gitignore` 排除,按需 `npm install`)。
- **按需拉取**:这些工具的权威来源是官方 HarmonyOS DFX Skills 仓库(GitCode,Git LFS 分发)。运行依赖二进制的技能前,若缺失,执行仓库根 `scripts/fetch-official-binaries.sh`(对官方仓库做浅克隆 + git-lfs pull,放入各技能 `scripts/`)。相关技能 SKILL.md 顶部已注明。
- **覆盖范围**:官方 GitCode 仓库只含 jank(`analysis_*`+`trace_streamer`)、nativeleak(`trace_streamer`,jsleak 亦复用)、perf(`perf_mcp_server-*.tar.gz`)二进制;cppcrash 官方为纯 Python(本仓库也是纯 Python 流程),其 llvm 工具链官方仓库不收录、无法用 fetch 拉取,确需符号化/反汇编时走官方 devecocli 完整分发。
- `rawheap_translator*`(各 <1MB)与 json 数据、reference 文档等照常入库。
- 若日后某处出现 100 字节 LFS 指针存根(本应是大文件却只有 100 字节文本),说明克隆环境缺 git-lfs 或指针损坏,需重新从官方 clone 恢复。

## 本仓库无构建 / 测试 / lint

本仓库是纯技能内容 + 插件清单仓库,没有代码构建、单测或 lint 体系;改动技能内容后以市场安装/升级是否成功为准做校验。
