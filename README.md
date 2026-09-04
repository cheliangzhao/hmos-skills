# hmos-skills

**HarmonyOS 开发与故障分析技能**插件市场仓库,同时服务 **Claude Code** 与 **Codex** 两个生态。所有插件均为双格式(`.claude-plugin/` + `.codex-plugin/`),技能内容完全一致。

## 包含的插件

| 插件 | 内容 | 技能数 |
|---|---|---|
| `hmos-arkts` | HarmonyOS ArkTS 语言:编译错误修复、语法规范、运行时修复、知识检索、语法检查 | 5 |
| `hmos-arkui` | HarmonyOS ArkUI 界面:ArkUI 开发、知识检索、MVVM 架构模式 | 3 |
| `hmos-multidevice` | HarmonyOS 多设备适配:折叠屏、屏幕窗口、避让区、硬件访问、交互方式、自然方向、场景入口 | 7 |
| `hmos-kits` | HarmonyOS Kit 集成:Push Kit 推送服务集成 | 1 |
| `hmos-perf` | HarmonyOS 性能/故障分析:卡顿、卡死、性能分析、JS/ArkTS/native 内存泄漏、fd 泄漏、C++/JS 崩溃、API 故障 | 10 |
| `hmos-testing` | HarmonyOS 测试:Instrument Test、Local Test 运行与覆盖率统计 | 2 |

## 技能来源

hmos 系列技能源自华为可靠性技术实验室发布的 **HarmonyOS DFX Skills**:

- GitCode: https://gitcode.com/openharmony-sig/developtools_dfx_skills
- 官方技能名无 `hmos-` 前缀,本仓库统一加了 `hmos-` 前缀;升级技能内容以官方仓库为准。

## 关于运行时工具(已精简)

本仓库不内置大体积分析二进制(`analysis.exe`、`trace_streamer_*`、`perf_mcp_server-*.tar.gz` 等),以保持仓库轻量与合规。运行依赖这些工具的技能(jank / native-memleak / perf-analysis 等)前,若对应 `scripts/` 缺失工具,先执行:

```bash
bash scripts/fetch-official-binaries.sh   # 从官方 HarmonyOS DFX Skills 仓库(Git LFS)按需拉取
```

各相关技能 SKILL.md 顶部亦注明。更多说明见 `CLAUDE.md`「精简与官方二进制获取」。

## 安装

### Claude Code

```bash
claude plugin marketplace add cheliangzhao/hmos-skills
claude plugin install hmos-arkts        # 及 hmos-arkui / hmos-multidevice / hmos-kits / hmos-perf / hmos-testing
```

### Codex

```bash
codex plugin marketplace add cheliangzhao/hmos-skills
codex plugin add hmos-arkts
```

## 目录结构

```
├── .claude-plugin/marketplace.json    # Claude 市场清单
├── .agents/plugins/marketplace.json   # Codex 市场清单(需与 Claude 清单保持同名同源)
└── plugins/
    ├── hmos-arkts/                    # 双格式(.claude-plugin/ + .codex-plugin/)
    ├── hmos-arkui/
    ├── hmos-multidevice/
    ├── hmos-kits/
    ├── hmos-perf/
    └── hmos-testing/
```

## 维护

1. 新增/删除插件需同步修改 `.claude-plugin/marketplace.json` 与 `.agents/plugins/marketplace.json`(两清单 schema 不同,但插件 name/source 必须一致)。
2. 技能内容改动后,在受影响插件的 `plugin.json`(两端)递增 `version`,再提交推送;之后 `claude plugin marketplace upgrade hmos-skills` / `codex plugin marketplace upgrade hmos-skills` 刷新,未生效则重装插件。

> 详细同步流程与大型二进制(Git LFS)注意事项见仓库根目录 `CLAUDE.md`,以该文件为准。
