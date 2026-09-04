# 更新日志

## [1.1.1] - 2026-08-10

### 变更
- 更新 `SKILL.md` 文档内容，通过 hdc 读取设备落盘日志前需先向用户征求同意，确认后方可采集

## [1.0.0] - 2026-06-10

### 新增
- 初始版本发布，新增 `hmos-apifault-analysis` Skill
- 支持错误码、错误日志、执行失败等问题的结构化诊断
- 内置四阶段诊断流程：环境发现 → 线索提取与模块识别 → 分诊查询 → 深潜分析
- 新增参考资料：
  - `references/log_patterns.md`：日志解析模式
  - `references/module_mapping.md`：模块映射表（含代码仓/文档仓 URL）
  - `references/knowledge/{module_name}/`：各模块知识库（错误码、API 调用链、常见问题等）
- 新增脚本工具：
  - `references/scripts/media_file_analyzer.py`：媒体文件分析
  - `references/scripts/hilog_collector.py`：hilog 日志采集与解析
- 支持 CodeGenie 内置工具调用（文件读写、正则搜索、文档查询、命令执行等）
- 支持状态机转换序列追踪与日志自动采集落盘
