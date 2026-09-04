# 性能抓Trace和Perf日志

## 概述

本技能帮助你自动抓取性能trace日志，用于分析应用性能问题。trace日志会记录系统运行的详细信息，帮助定位卡顿、延迟等性能问题。

## 前置准备

### 1. 环境要求

- 设备已连接电脑（USB调试已开启）
- 已安装HDC工具（hdc.exe）
- 设备与电脑网络连通

### 2. 验证连接

```bash
# 检查设备连接状态
hdc list targets
```

看到设备ID表示连接正常。
如果hdc工具未安装，则进行如下操作：
1、提示用户打开deveco studio，选择设置，在openharmony sdk选项卡中找到安装路径，提示用户输入此安装路径；
2、在安装路径查找hdc，并将其加入到环境变量中
3、重新检查设备连接状态

---

## 方法一：短时采集（推荐新手）

适用于：测试操作时长明确且较短（如点击一个按钮、滑动一下列表）

### 使用步骤

**Step 1：** 执行以下命令开始采集

```bash
hdc shell hitrace -t 30 --raw --file_size 204800 -b 102400 ace ark app ohos ability graphic sched freq nweb workq pagecache binder irq disk memreclaim samgr sync zcamera zmedia commonlibrary net zaudio idle ufs distributeddatamgr dsoftbus i2c mdfs misc mmc msdp multimodalinput notification regulators sensors window zimage ffrt
```

**Step 2：** 立即进行测试操作（需在30秒内完成）

**Step 3：** 等待命令执行完毕

采集结束后，命令行会显示文件保存路径，例如：

```
/data/log/hitrace/trace_xxx.sys
```

### 参数说明

| 参数 | 值 | 含义 |
|------|-----|------|
| `-t 30` | 30 | 采集30秒，根据测试需要调整 |
| `--raw` | - | 采集为二进制格式（推荐，性能更好） |
| `--file_size` | 204800 | 单文件最大200MB，范围50-500MB |
| `-b` | 102400 | 缓冲区100MB，范围512KB-1GB |

### 采集类型对比

| 类型 | 命令特点 | 优点 | 缺点 |
|------|----------|------|------|
| 二进制（--raw） | 有`--raw`参数 | 1秒落盘一次，完整保存；文件小、开销小 | 不能自定义文件名 |
| 文本trace | 无`--raw`参数 | 可用`-o`指定文件名 | 可能丢数据，一次性落盘 |

> **推荐**：始终使用`--raw`参数采集二进制trace

---

## 方法二：长时采集

适用于：测试时长不确定、或需要覆盖整个测试过程

### 使用步骤

**Step 1：** 开始录制

```bash
hdc shell hitrace --trace_begin --record --file_size 204800 -b 102400 ace ark app ohos ability graphic sched freq nweb workq pagecache binder irq disk memreclaim samgr sync zcamera zmedia commonlibrary net zaudio idle ufs distributeddatamgr dsoftbus i2c mdfs misc mmc msdp multimodalinput notification regulators sensors window zimage ffrt
```

**Step 2：** 执行测试操作（可任意时长）

**Step 3：** 结束录制

```bash
hdc shell hitrace --trace_finish --record
```

命令执行后会显示所有采集文件的路径。

### 注意事项

| 版本 | 文件保存规则 |
|------|--------------|
| root版本 | 不会自动清理 |
| user版本 | 最多保留16个，自动清理旧文件 |

---

## 导出文件到电脑

### 短时采集的文件导出

```bash
# 从设备拉取文件
hdc file recv /data/log/hitrace/trace_xxx.sys ./
```

### 长时采集的文件导出

```bash
# 导出整个目录
hdc file recv /data/log/hitrace ./
```

导出的文件可用SmartPerf工具打开分析。

---

## 常见问题处理

### ❌ 错误码1103

**现象**：命令执行报错，errorCode为1103

**原因**：有未关闭的采集任务

**解决方法**：

```bash
hdc shell hitrace --stop_bgsrv
```

然后重新开始采集。

### ❌ 错误码1

**现象**：命令执行报错，errorCode为1

**原因**：hiview进程异常

**排查步骤**：

```bash
# 1. 查看hiview进程状态
hdc shell ps -ef | grep hiview

# 2. 查看故障日志
hdc shell cat /data/log/faultlog/faultlogger/*.log
hdc shell cat /data/log/faultlog/temp/*.log
```

### ⚠️ 强制中断的风险

**禁止使用**：Ctrl+C 或关闭命令行窗口打断采集

**原因**：会破坏trace环境，导致后续采集失败

**正确做法**：等待命令执行完毕，或使用`hitrace --stop_bgsrv`正常停止

---

## 快速参考

### 最小化采集命令

如果只需要基础trace信息，可使用简化命令：

```bash
# 短时采集
hdc shell hitrace -t 30 --raw ace ark app graphic sched

# 开始长时录制
hdc shell hitrace --trace_begin --record ace ark app graphic sched

# 结束长时录制
hdc shell hitrace --trace_finish --record
```

### 常用tag说明

| Tag | 含义 |
|-----|------|
| ace | ArkUI引擎 |
| ark | Ark运行时 |
| app | 应用框架 |
| graphic | 图形渲染 |
| sched | 调度信息 |
| freq | 频率信息 |
| binder | 进程通信 |

---

## Agent执行方式

Agent可以直接执行以下命令抓取trace：

```powershell
# 设置参数
$TRACE_SAVE_PATH = "$PSScriptRoot\trace_logs"
$DURATION = 30

# 1. 创建目录
New-Item -ItemType Directory -Force -Path $TRACE_SAVE_PATH | Out-Null

# 2. 检查设备连接
Write-Host "[1/4] Checking device connection..."
$deviceCheck = hdc list targets 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Device not found. Please check USB and HDC."
    exit 1
}
Write-Host "[OK] Device connected."

# 3. 清理设备缓存
Write-Host "`n[2/4] Cleaning device trace cache..."
hdc shell "rm -rf /data/log/hitrace/*.sys 2>/dev/null; ls /data/log/hitrace/" | Out-Null

# 4. 执行抓取
Write-Host "[3/4] Starting capture for $DURATION seconds...`n"
hdc shell hitrace -t $DURATION --raw --file_size 204800 -b 102400 ace ark app ohos ability graphic sched freq nweb workq pagecache binder irq disk memreclaim samgr sync zcamera zmedia commonlibrary net zaudio idle ufs distributeddatamgr dsoftbus i2c mdfs misc mmc msdp multimodalinput notification regulators sensors window zimage ffrt

# 5. 导出文件
Write-Host "`n[4/4] Exporting trace files..."
hdc file recv /data/log/hitrace/ "$TRACE_SAVE_PATH\"

# 显示结果
Write-Host "`n[Done] Files saved to: $TRACE_SAVE_PATH"
Get-ChildItem "$TRACE_SAVE_PATH\*.sys","$TRACE_SAVE_PATH\*.raw" -ErrorAction SilentlyContinue | Select-Object Name
```

## 自动化脚本

### 一键抓取脚本（备用）

脚本路径：`jank-analysis\references\一键抓取trace.bat`

功能与上方Agent执行方式相同，供手动使用。

### 使用方法

1. **Agent执行**：直接运行上方PowerShell脚本
2. **手动执行**：双击运行`一键抓取trace.bat`
3. 等待30秒采集完成
4. 文件自动保存到`trace_logs`文件夹
5. 用SmartPerf打开`.sys`文件分析
