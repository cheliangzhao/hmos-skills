# 更新日志

## [1.3.0] - 2026-09-01

### 变更
- 同步官方 developtools_dfx_skills(OpenHarmony-SIG)至 v1.3.0。

## [1.2.0] - 2026-08-14

### 变更
- skill版本号升级至 v1.2.0

## [1.0.0] - 2026-07-24

### 新增
- 初始版本发布，新增 `jank-analysis` Skill
- 支持启动分析、丢帧分析、卡顿分析性能场景
- 支持以 HiTrace / trace 为输入进行性能数据分析
- 支持启动阶段拆解（Launch Phases）与启动瓶颈定位
- 支持丢帧区间识别（Jank Intervals）与流水线检测
- 内置渲染管线检测（Render Pipeline Detection）
- 内置芯片型号与 CPU 拓扑识别（Chip Model Identification）
- 内置指标查询引擎（CPU / GPU / 线程运行时 / 频点等）
- 新增参考资料：
  - `references/jank-report-analysis.md`：卡顿报告分析文档
- 输出结构化性能分析报告（含根因分析、优化建议）
