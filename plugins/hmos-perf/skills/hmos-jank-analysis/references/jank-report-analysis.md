# 性能丢帧分析 Skill

## 用途
分析HarmonyOS/OpenHarmony应用的性能丢帧报告，自动推导根因并生成结构化分析报告。

## 核心原则
> ⚠️ **二三级根因必须联合分析**，单独看二级或三级根因会导致误解：
> - 单独看二级根因：只知道"节点刷新"，不知道是哪个组件
> - 单独看三级根因：只知道"WatchlistRow"，不知道属于什么问题
> - 联合分析：**二级根因（问题类型）+ 三级根因（具体位置）= 完整根因**

## 使用方式


### 方式一：手动分析

按照本skill的分析流程，手动读取Excel并生成报告。

---

## 分析脚本使用方法

### 依赖
- Python 3.x
- 无需额外依赖（仅使用标准库）

### 核心函数

#### 1. read_xlsx_with_chinese(file_path)
读取xlsx文件，处理中文编码。

```python
def read_xlsx_with_chinese(file_path):
    """读取xlsx文件，处理中文编码"""
    with zipfile.ZipFile(file_path, 'r') as zip_ref:
        with zip_ref.open('xl/worksheets/sheet1.xml') as f:
            content = f.read()
    
    for enc in ['utf-8', 'gbk', 'gb18030']:
        try:
            text = content.decode(enc)
            break
        except:
            continue
    
    tree = ET.fromstring(text)
    ns = {'ns': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
    rows = tree.findall('.//ns:row', ns)
    
    all_rows = []
    for row in rows:
        cells = {}
        for cell in row.findall('ns:c', ns):
            ref = cell.get('r', '')
            col = re.sub(r'[0-9]', '', ref)
            t = cell.get('t', '')
            
            if t == 'inlineStr':
                is_elem = cell.find('.//ns:t', ns)
                val = is_elem.text if is_elem is not None else ''
            else:
                v = cell.find('ns:v', ns)
                val = v.text if v is not None else ''
            
            cells[col] = val
        all_rows.append(cells)
    
    return all_rows
```

#### 2. analyze_dropframes(data, animation_filter=None, frame_type_filter=None)
分析丢帧数据，返回统计结果。

```python
def analyze_dropframes(data, animation_filter=None, frame_type_filter=None):
    """分析丢帧数据"""
    drop_times = []
    records = []
    
    for row in data:
        time = float(row['L']) if 'L' in row and row['L'] else 0
        secondary = row.get('J', '')  # 二级根因
        third = row.get('K', '')       # 三级根因
        
        # 根因名称映射（显示优化）
cause_mapping = {
    '未知原因Running耗时长': '负载过高',
    '负载过高': '负载过高',
}
        secondary = cause_mapping.get(secondary, secondary)
        
        # 跳过没有二级或三级根因的记录（二级根因为空时不统计）
        if time > 0 and secondary and third:
            drop_times.append(time)
            records.append({
                '丢帧ID': row.get('B', ''),
                '丢帧耗时': time,
                '帧号': row.get('Q', ''),  # vsyncId帧号
                '丢帧类型': row.get('D', ''),  # UI丢帧/RS丢帧
                '动效名称': row.get('AE', ''),  # 动效区间名称
                '一级根因': row.get('I', ''),
                '二级根因': secondary,
                '三级根因': third,
                '线程名': row.get('S', ''),
                '进程号': row.get('T', ''),
                'running': float(row['AJ']) if row.get('AJ') else 0,
                'runnable': float(row['AK']) if row.get('AK') else 0,
                'sleep': float(row['AL']) if row.get('AL') else 0,
                'd_state': float(row['AM']) if row.get('AM') else 0,
                'is_throttle': row.get('BK', ''),
                'vip_throttle_time': row.get('BO', ''),
                'm3_throttle_time': row.get('CA', ''),
                'normal_throttle_time': row.get('CF', ''),
            })
    
    if not drop_times:
        return None
    
    total_time = sum(drop_times)
    avg_time = total_time / len(drop_times)
    max_time = max(drop_times)
    min_time = min(drop_times)
    
    # 二三级根因联合分组统计
    combined_causes = {}
    for r in records:
        secondary = r['二级根因'] or '未知'
        third = r['三级根因'] or '未知'
        key = f"{secondary}|{third}"
        if key not in combined_causes:
            combined_causes[key] = {
                '二级根因': secondary,
                '三级根因': third,
                '完整根因': f"{secondary} - {third}",
                'count': 0,
                'time': 0,
                'max': 0,
                'items': []
            }
        combined_causes[key]['count'] += 1
        combined_causes[key]['time'] += r['丢帧耗时']
        combined_causes[key]['max'] = max(combined_causes[key]['max'], r['丢帧耗时'])
        combined_causes[key]['items'].append({...})
    
    # 按二级根因分组
    causes_by_second = {}
    for r in records:
        key = r['二级根因'] or '未知'
        if key not in causes_by_second:
            causes_by_second[key] = {'count': 0, 'time': 0, 'max': 0}
        causes_by_second[key]['count'] += 1
        causes_by_second[key]['time'] += r['丢帧耗时']
        causes_by_second[key]['max'] = max(causes_by_second[key]['max'], r['丢帧耗时'])
    
    # 丢帧耗时分布
    dist = {'<100ms': 0, '100-200ms': 0, '200-300ms': 0, '>300ms': 0}
    for t in drop_times:
        if t < 100: dist['<100ms'] += 1
        elif t < 200: dist['100-200ms'] += 1
        elif t < 300: dist['200-300ms'] += 1
        else: dist['>300ms'] += 1
    
    return {
        'count': len(records),
        'total_time': total_time,
        'avg_time': avg_time,
        'max_time': max_time,
        'min_time': min_time,
        'animation_filter': animation_filter,
        'frame_type_filter': frame_type_filter,
        'combined_causes': combined_causes,
        'causes_by_second': causes_by_second,
        'distribution': dist,
        'records': sorted(records, key=lambda x: x['丢帧耗时'], reverse=True)[:10]
    }
```

#### 3. generate_report(analysis, output_dir)
生成Markdown格式分析报告。

---

## Excel列字段说明

| 列索引 | 字段名 | 说明 |
|--------|--------|------|
| B | 丢帧ID | 唯一标识 |
| Q | 帧号 | vsyncId，用于trace定位 |
| D | 丢帧类型 | UI丢帧/RS丢帧 |
| I | 一级根因 | 问题大类 |
| J | 二级根因 | **问题类型（需联合三级）** |
| K | 三级根因 | **具体位置/组件（需联合二级）** |
| L | 丢帧耗时(ms) | 关键指标 |
| S | 线程名 | 用于定位问题线程 |
| T | 进程号 | 进程标识 |
| AE | 动效tag | 动效区间名称（如APP_LIST_FLING） |
| AJ | running | CPU执行时间(ms) |
| AK | runnable | 就绪等待时间(ms) |
| AL | sleep | 休眠等待时间(ms) |
| AM | d_state | D状态时间(ms) |
| BK | is_throttle | 是否发生限频 |
| BO | vip_throttle_time | VIP核心限频影响时间(ms) |
| CA | m3_throttle_time | M3核心限频影响时间(ms) |
| CF | normal_throttle_time | 普通限频影响时间(ms) |

---

## 根因分类标准

### 二级根因（J列）- 问题类型
| 二级根因 | 说明 | 可能的优化方向 |
|----------|------|---------------|
| 脏节点刷新耗时长 | UI组件树更新，重新渲染节点 | LazyForEach、减少状态更新 |
| 负载过高 | JS回调或Native代码在主线程执行过长 | Worker、分片处理、trace分析 |
| 组件复用耗时长 | ArkUI框架复用组件的开销 | 优化组件结构 |
| 组件构建耗时长 | 首次创建大量组件 | 虚拟列表、按需加载 |
| 布局耗时 | Layout计算 | 减少嵌套、固定尺寸 |
| GC耗时长 | 垃圾回收暂停 | 对象池、减少分配 |
| I/O等待耗时长 | 读写阻塞 | 异步I/O |

### 三级根因（K列）- 具体位置
| 类型 | 格式示例 | 含义 |
|------|----------|------|
| 组件刷新 | `[name:WatchlistRow,id:]节点刷新耗时长` | WatchlistRow组件刷新 |
| JS回调 | `非UI函数H:Cancelable Event callback:handleId:1604耗时长` | handleId为1604的JS回调 |
| Trace执行 | `TraceRunning耗时[主UI]` | 主线程Trace执行 |
| 组件复用 | `[[WatchlistRow]复用耗时长` | WatchlistRow复用 |
| GC类型 | `Reason12:H:PartialGC:H:PartialGC` | 增量GC |

### 二三级联合示例
| 二级根因 | 三级根因 | 完整根因 |
|----------|----------|----------|
| 脏节点刷新耗时长 | [name:WatchlistRow,id:]节点刷新耗时长 | 脏节点刷新耗时长 - [name:WatchlistRow,id:]节点刷新耗时长 |
| 负载过高 | 非UI函数H:Cancelable Event callback:handleId:1604耗时长 | 负载过高 - 非UI函数H:Cancelable Event callback:handleId:1604耗时长 |

---

## CPU状态说明

| 状态 | 含义 | 说明 |
|------|------|------|
| Running | CPU执行中 | 线程正在CPU上执行指令 |
| Runnable | 就绪等待 | 线程已准备好运行，等待CPU调度 |
| Sleep | 休眠等待 | 线程主动休眠，等待事件唤醒 |
| D状态 | 不可中断等待 | 线程处于不可中断的等待状态（如I/O） |

**分析思路：**
- **Running占比高**：CPU确实在执行工作，可能是计算量大、循环多、GC等
- **Runnable占比高**：CPU资源不足，线程在排队等待调度
- **Sleep占比高**：线程在等待，可能是I/O阻塞、同步等待等
- **D状态占比高**：线程在等待I/O或其他不可中断操作

---

## 限频分析

| 限频类型 | 说明 | 影响 |
|----------|------|------|
| VIP核心限频 | 大核/性能核降频 | CPU性能下降，执行变慢 |
| M3核心限频 | 中核降频 | 功耗与性能的平衡 |
| 普通限频 | 其他情况限频 | 发热或电量策略 |

---

## 关键阈值

| 耗时范围 | 用户感知 | 建议 |
|----------|----------|------|
| <16.67ms | 流畅（60fps） | 达标 |
| 16.67-33ms | 轻微卡顿 | 可接受 |
| 33-100ms | 明显卡顿 | 需要优化 |
| 100-300ms | 严重卡顿 | 必须优化 |
| >300ms | 应用"假死" | 紧急优化 |

---

## 报告输出模板

```
# 性能丢帧分析报告

## 一、概览
- 丢帧总数、总耗时、平均耗时、最大耗时

## 二、根因分析

### 2.1 二级根因汇总（高层视图）
| 二级根因 | 次数 | 耗时 | 占比 |

### 2.2 二三级联合根因详情（主要依据）
| 二级根因 | 三级根因 | 次数 | 耗时 | 占比 |

### 2.3 详细说明
#### 根因1：二级 - 三级
- 占比、次数、平均耗时、最大耗时
- CPU状态分析
- 限频分析
- 具体丢帧记录

## 三、推导步骤
1. 看丢帧耗时分布
2. 看二级根因汇总
3. 看二三级联合根因（关键！）
4. 定位代码

## 四、优化建议
（按根因分类）

## 五、数据支撑
- 丢帧耗时分布
- 根因耗时占比图
- TOP10丢帧记录

## 六、下一步行动
```

---

## 常见根因解读

### 1. 脏节点刷新耗时长
**现象**：UI组件树更新时大量节点需要重新渲染
**典型三级**：`[name:WatchlistRow,id:]节点刷新耗时长`
**优化**：
- 使用 `LazyForEach` 懒加载
- 减少状态更新范围
- 使用 `@Reusable` 复用组件

### 2. 负载过高（Running耗时长）
**现象**：JS回调或Native代码在主线程执行时间过长
**典型三级**：`非UI函数H:Cancelable Event callback:handleId:1604耗时长`
**优化**：
- 提取 `handleId` 值，使用SmartPerf定位具体JS函数
- 使用Worker线程处理计算
- 使用分片执行避免阻塞

### 3. 组件复用耗时长
**现象**：ArkUI框架复用组件时的开销
**典型三级**：`[[WatchlistRow]复用耗时长`
**优化**：
- 简化组件结构
- 减少复用时的重新创建

### 4. GC耗时长
**现象**：垃圾回收导致主线程暂停
**典型三级**：`Reason12:H:PartialGC:H:PartialGC`
**优化**：
- 对象池复用
- 减少临时对象创建
- 避免内存抖动

---

## 注意事项

1. **文件编码**：可能是GBK/GB18030，需要特殊处理
2. **列索引**：可能因报告版本不同而变化，但通常固定
3. **根因必填**：只分析同时有二级根因和三级根因的记录，空值跳过
   - 如果**二级根因为空**，该记录不参与统计（即使三级根因存在）
   - 如果**三级根因为空**，该记录不参与统计（即使二级根因存在）
   - 必须在二级和三级根因都存在时才统计
4. **根因理解**：必须结合二级+三级才能准确判断问题
5. **handleId**：JS回调的handleId是定位具体函数的关键
