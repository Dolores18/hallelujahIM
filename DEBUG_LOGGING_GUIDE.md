# HallelujahIM 英语延迟模式调试日志指南

## 日志概述

为了方便调试和监控英语延迟模式的运行状态，我们在关键流程和可能出错的地方添加了详细的NSLog日志。所有日志都以 `[HallelujahIM]` 前缀开始，便于过滤和识别。

## 查看日志的方法

### 方法1: Console.app（推荐）
1. 打开 Console.app（控制台应用）
2. 在搜索框中输入 `HallelujahIM`
3. 实时查看日志输出

### 方法2: 命令行
```bash
# 实时查看日志
log stream --predicate 'eventMessage CONTAINS "HallelujahIM"'

# 查看最近的日志
log show --last 10m --predicate 'eventMessage CONTAINS "HallelujahIM"'
```

### 方法3: Xcode调试
在Xcode中运行项目时，日志会直接显示在调试控制台中。

## 日志分类

### 1. 模式切换日志 🔄

#### 左Shift键（进入/退出延迟模式）
```
[HallelujahIM] 检测到左Shift按键事件
[HallelujahIM] 左Shift切换: 智能模式 → 英语延迟模式 (InputModeEnglishDelay)
[HallelujahIM] 进入英语延迟模式，当前缓冲文本: 'hello'
```

#### 右Shift键（智能模式/纯英文模式）
```
[HallelujahIM] 右Shift切换到纯英文模式 (InputModeEnglishDirect)
[HallelujahIM] 切换模式时提交缓冲文本: 'hello world'
```

### 2. 按键处理日志 ⌨️

#### 通用按键日志
```
[HallelujahIM] 按键事件: keyCode=49, char=' ', 当前模式=英语延迟模式, 缓冲文本='hello'
```

#### 空格键处理
```
[HallelujahIM] 空格键-延迟模式: 继续缓冲，当前文本='hello'
[HallelujahIM] 空格键-延迟模式: 缓冲后文本='hello '
```

#### 回车键处理
```
[HallelujahIM] 回车键-延迟模式: 开始处理文本='hello world'
[HallelujahIM] 回车键-延迟模式: 处理后文本='hello world'
[HallelujahIM] 回车键-延迟模式: 文本已提交
```

#### 字母输入
```
[HallelujahIM] 字母输入: 'h', 当前缓冲='(空)'
[HallelujahIM] 字母输入后缓冲='h'
[HallelujahIM] 字母输入-延迟模式: 使用英语候选词更新
```

#### 标点符号
```
[HallelujahIM] 标点符号输入: '.', 当前缓冲='hello world'
[HallelujahIM] 标点-延迟模式: 继续缓冲
[HallelujahIM] 标点-延迟模式: 缓冲后='hello world.'
```

### 3. 候选词系统日志 📝

#### 候选词更新
```
[HallelujahIM] updateEnglishCandidates: 当前模式=延迟模式
[HallelujahIM] updateEnglishCandidates: 完整缓冲='hello world', 最后单词='world'
[HallelujahIM] updateEnglishCandidates: 为'world'找到15个候选词
[HallelujahIM] updateEnglishCandidates: 前3个候选词=(world, words, worldwide)
```

#### 候选词选择
```
[HallelujahIM] 数字键选择候选词: 按键=1
[HallelujahIM] 选中候选词: index=0, candidate='world'
[HallelujahIM] 数字键-延迟模式: 替换最后单词，当前缓冲='hello worl'
[HallelujahIM] 数字键-延迟模式: 替换后缓冲='hello world'
```

#### 单词提取和替换
```
[HallelujahIM] getLastWordFromBuffer: 输入buffer='hello world'
[HallelujahIM] getLastWordFromBuffer: 找到空格在位置5, 最后单词='world'

[HallelujahIM] replaceLastWordWith: 候选词='words', 当前buffer='hello world'
[HallelujahIM] replaceLastWordWith: 找到空格，前缀='hello ', 新buffer='hello words'
[HallelujahIM] replaceLastWordWith: 完成替换，最终buffer='hello words'
```

### 4. 文本处理日志 🔄

```
[HallelujahIM] processEnglishText: 开始处理文本='hello  world '
[HallelujahIM] processEnglishText: 去除首尾空格后='hello  world'
[HallelujahIM] processEnglishText: 清理连续空格后='hello world'
[HallelujahIM] processEnglishText: 处理完成，结果='hello world'
```

### 5. 系统状态日志 🔧

#### 输入法激活/停用
```
[HallelujahIM] activateServer: 输入法激活
[HallelujahIM] activateServer: 创建AnnotationWinController
[HallelujahIM] activateServer: 初始化完成，当前模式=智能模式

[HallelujahIM] deactivateServer: 输入法停用
```

#### 重置操作
```
[HallelujahIM] reset: 重置输入法状态，清理前缓冲='hello world'
[HallelujahIM] reset: 重置完成
```

### 6. 错误处理日志 ⚠️

#### 数组越界保护
```
[HallelujahIM] 错误: 候选词索引越界，index=10, count=5
```

#### 空值处理
```
[HallelujahIM] getLastWordFromBuffer: 输入buffer为空
[HallelujahIM] processEnglishText: 输入为空，直接返回
```

## 常见调试场景

### 场景1: 左Shift键不响应
查找日志：
```
[HallelujahIM] 检测到左Shift按键事件
```
如果没有此日志，说明按键检测有问题。

### 场景2: 候选词不正确
查找日志：
```
[HallelujahIM] updateEnglishCandidates: 为'xxx'找到N个候选词
```
检查最后单词提取是否正确。

### 场景3: 文本替换失败
查找日志：
```
[HallelujahIM] replaceLastWordWith: 候选词='xxx', 当前buffer='yyy'
[HallelujahIM] replaceLastWordWith: 完成替换，最终buffer='zzz'
```
检查替换逻辑是否正确执行。

### 场景4: 模式切换异常
查找日志：
```
[HallelujahIM] 左Shift切换: 智能模式 → 英语延迟模式
```
确认模式切换是否成功。

## 日志筛选技巧

### 只看模式切换相关
```bash
log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "切换"'
```

### 只看延迟模式相关
```bash
log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "延迟模式"'
```

### 只看错误日志
```bash
log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "错误"'
```

### 只看候选词相关
```bash
log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "候选词"'
```

## 性能考虑

这些日志主要用于开发和调试阶段。在生产版本中，可以通过以下方式控制日志输出：

1. **条件编译**：使用 `#ifdef DEBUG` 包围日志代码
2. **日志级别**：根据重要性设置不同级别
3. **用户设置**：提供开关让用户控制是否输出调试日志

## 故障排除步骤

1. **确认基础功能**：检查输入法是否正常激活
2. **验证模式切换**：确认左Shift键能正确切换模式
3. **检查候选词生成**：验证最后单词提取和候选词生成
4. **验证文本处理**：确认回车键的文本处理流程
5. **测试边界情况**：空文本、特殊字符等

通过这些详细的日志，开发者可以快速定位问题并进行调试优化。
