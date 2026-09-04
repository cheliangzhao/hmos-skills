---
name: catch-perf-log
description: >
  使用hiperf工具抓取HarmonyOS设备性能数据，生成perf.data火焰图数据文件。
  当用户提到"抓perf"、"抓火焰图"、"hiperf"、"perf采样"、"性能采样"时使用。
metadata:
   author: Huawei Reliability Technology Lab
   version: 0.0.1
---

# Perf 日志抓取工具

## 模块介绍

hiperf是HarmonyOS设备上的性能分析工具，通过内核perf event机制和PMU（性能监视单元）采集性能数据：
- **CPU周期数** (hw-cpu-cycles)
- **指令数** (hw-instructions)
- **缓存命中/未命中**
- **分支预测**
- **函数调用栈**

## 约束

- 设备需为debuggable模式或使用调试证书签名
- 采集的应用需处于启动状态
- 默认采样时长10秒，可通过参数调整
- 输出文件默认保存到 `/data/local/tmp/`

## 使用方式

### 基础采样命令

```bash
# 基础采样（推荐）
hiperf record -p <pid> -d 10 -o /data/local/tmp/perf.data

# 指定回栈模式和采样频率
hiperf record -p <pid> -d 10 -s dwarf -f 1000 -o /data/local/tmp/perf.data

# 采集多事件（CPU周期 + 指令数）
hiperf record -p <pid> -d 10 -e hw-cpu-cycles,hw-instructions -g -o /data/local/tmp/perf.data

# 采集指定线程
hiperf record -t <tid> -d 10 -o /data/local/tmp/perf.data

# 采集应用（通过应用名）
hiperf record --app <package_name> -d 10 -o /data/local/tmp/perf.data

# 整机采集（需要root权限）
hiperf record -a -d 10 -o /data/local/tmp/perf.data
```

### 参数说明

| 参数 | 说明 |
|------|------|
| `-p <pid>` | 采集指定进程ID |
| `-t <tid>` | 采集指定线程ID |
| `--app <name>` | 采集指定应用名（应用需在debuggable模式） |
| `-d <seconds>` | 采集时长（秒），默认10 |
| `-f <freq>` | 采样频率（次/秒），默认4000 |
| `-e <events>` | 采集事件类型，支持 hw-cpu-cycles,hw-instructions 等 |
| `-g` | 采集调用栈 |
| `-s dwarf` | 使用dwarf回栈模式（推荐，比fp更准确） |
| `-s fp` | 使用栈指针回栈模式 |
| `-o <path>` | 输出文件路径 |
| `-a` | 采集整机数据（需root） |
| `--offcpu` | 跟踪线程调度时间（离开CPU时间） |
| `-j any_call` | 分支堆栈采样 |

### 常用事件类型

| 事件 | 说明 | 适用场景 |
|------|------|----------|
| hw-cpu-cycles | CPU周期数 | CPU密集型 |
| hw-instructions | 指令数 | CPU密集型 |
| hw-cache-references | 缓存引用 | 内存密集型 |
| hw-cache-misses | 缓存未命中 | 内存密集型 |
| hw-branch-instructions | 分支指令 | 分支密集型 |
| hw-branch-misses | 分支预测失败 | 分支密集型 |

## 自动抓取流程

### 步骤一：连接设备

使用hdc连接设备：
```bash
hdc shell
```
看到设备ID表示连接正常。
如果hdc工具未安装，则进行如下操作：
1、提示用户打开deveco studio，选择设置，在openharmony sdk选项卡中找到安装路径，提示用户输入此安装路径；
2、在安装路径查找hdc，并将其加入到环境变量中
3、重新检查设备连接状态

### 步骤二：查找目标进程/线程

```bash
# 查看高负载进程
top -m 10

# 查看进程中各线程CPU占用
top -H -p <pid>
```

### 步骤三：执行采样

根据目标选择命令：

**单进程采样（推荐）**：
```bash
hiperf record -p <pid> -d 10 -s dwarf -g -e hw-cpu-cycles,hw-instructions -o /data/local/tmp/perf.data
```

**单线程采样**：
```bash
hiperf record -t <tid> -d 10 -s dwarf -g -e hw-cpu-cycles,hw-instructions -o /data/local/tmp/perf.data
```

**整机采样**：
```bash
hiperf record -a --exclude-hiperf -d 10 -s dwarf -g -e hw-cpu-cycles,hw-instructions -o /data/local/tmp/perf.data
```

### 步骤四：拉取数据文件

```bash
# 从设备拉取到PC
hdc file recv /data/local/tmp/perf.data <本地目录>/

# 如果使用压缩选项
hdc file recv /data/local/tmp/perf.data.gz <本地目录>/
```

### 步骤五：生成火焰图

使用SmartPerf或hiperf_make_report.py解析：
```bash
# 使用SmartPerf打开perf.data文件可视化分析

# 或使用命令行解析
hiperf report -i /data/local/tmp/perf.data -o /data/local/tmp/perf_report.txt
```

## 应用场景

| 场景 | 推荐命令 |
|------|----------|
| 分析CPU高负载函数 | `hiperf record -p <pid> -d 10 -s dwarf -g -e hw-cpu-cycles` |
| 分析指令数热点 | `hiperf record -p <pid> -d 10 -s dwarf -g -e hw-instructions` |
| 分析线程调度 | `hiperf record -p <pid> -d 10 --offcpu` |
| 分析分支预测 | `hiperf record -p <pid> -d 10 -s dwarf -g -e hw-branch-misses` |
| 定位"大平顶"帧 | 配合trace抓取，同时采集perf数据 |

## 注意事项

1. **采样时长**：建议10-30秒，过短数据不足，过长文件过大
2. **采样频率**：默认4000次/秒，高频可提高精度但增加开销
3. **回栈模式**：dwarf模式更准确但有额外开销
4. **权限**：整机采集需要root权限，应用采集需要debuggable模式
5. **数据拉取**：大文件建议使用 `-z` 压缩选项

## 错误处理

| 错误 | 解决方法 |
|------|----------|
| Permission denied | 使用debuggable应用或root权限 |
| App not started | 确保应用已启动，等待20秒自动退出 |
| File too large | 减少采样时长或使用压缩 `-z` |
| No data | 检查进程/线程是否存在，确认采样成功 |