# 延迟模式 + 翻译功能组合显示指南

## 🎯 功能概述

成功实现了在英语延迟模式下**同窗口显示缓冲区内容和候选词翻译**的功能！现在用户可以在一个窗口中同时看到：
- 📝 当前输入的完整缓冲区内容
- 🔤 选中候选词的中文翻译

## ✨ 显示效果

### 📱 组合显示模式（延迟模式 + 翻译开启 + 选中候选词）
```
┌─────────────────────────────┐
│ 📝 hello wor                │  ← 缓冲区内容
│ ─────────────────────────── │  ← 分隔线
│ 🔤 world - 世界；世间       │  ← 选中候选词翻译
└─────────────────────────────┘
```

### 📱 纯缓冲区模式（延迟模式 + 翻译关闭 或 未选中候选词）
```
┌─────────────────────────────┐
│ 📝 hello world              │  ← 仅显示缓冲区内容
└─────────────────────────────┘
```

### 📱 传统翻译模式（智能模式 + 翻译开启）
```
┌─────────────────────────────┐
│ world - 世界；世间          │  ← 仅显示翻译内容
└─────────────────────────────┘
```

## 🎮 使用方法

### 步骤1：启用翻译功能
确保在偏好设置中启用了翻译功能：
```
偏好设置 → showTranslation = true
```

### 步骤2：进入延迟模式
按 **左Shift键** 切换到英语延迟模式

### 步骤3：开始输入
```
输入: "hello wor"
显示: 📝 hello wor
```

### 步骤4：选择候选词
使用 **箭头键** 或 **数字键** 选中候选词：
```
候选词列表: [world, work, word, worth]
选中 "world" → 立即显示组合内容:

┌─────────────────────────────┐
│ 📝 hello wor                │
│ ─────────────────────────── │
│ 🔤 world - 世界；世间       │
└─────────────────────────────┘
```

### 步骤5：确认选择
按 **数字键1** 确认选择候选词：
```
缓冲区更新: "hello world"
显示恢复: 📝 hello world
```

## 🔧 技术实现

### 核心组件

#### 1. AnnotationWinController 新增方法
```objective-c
// 组合显示方法
- (void)showBufferDisplayWithTranslation:(NSString *)bufferText 
                             translation:(NSString *)translation 
                                 atPoint:(NSPoint)origin;

- (void)updateBufferDisplayWithTranslation:(NSString *)bufferText 
                               translation:(NSString *)translation;

- (void)setBufferTextWithTranslation:(NSString *)bufferText 
                         translation:(NSString *)translation;
```

#### 2. InputController 新增方法
```objective-c
// 组合显示控制
- (void)showBufferWithTranslation:(NSAttributedString *)candidateString;
- (void)updateBufferDisplayContentWithTranslation:(NSString *)translation;
```

### 智能显示逻辑

#### 1. candidateSelectionChanged 优化
```objective-c
- (void)candidateSelectionChanged:(NSAttributedString *)candidateString {
    BOOL showTranslation = [preference boolForKey:@"showTranslation"];
    if (showTranslation) {
        if (_currentMode == InputModeEnglishDelay) {
            // 延迟模式：组合显示
            [self showBufferWithTranslation:candidateString];
        } else {
            // 其他模式：正常显示翻译
            [self showAnnotation:candidateString];
        }
    } else {
        if (_currentMode == InputModeEnglishDelay) {
            // 延迟模式但翻译关闭：仅显示缓冲区
            [self updateBufferDisplayContent];
        }
    }
}
```

#### 2. 动态窗口大小
```objective-c
- (void)resizeForContent:(NSString *)content {
    // 检查是否是组合显示模式
    BOOL isCombinedDisplay = [content containsString:@"─────────"];
    
    // 组合显示时窗口更高
    CGFloat windowHeight = isCombinedDisplay ? 80 : 50;
    
    // 动态调整宽度和高度
}
```

## 🔍 调试功能

### 关键日志标识
所有相关日志包含以下关键词：
- `showBufferWithTranslation`
- `updateBufferDisplayWithTranslation`
- `setBufferTextWithTranslation`
- `candidateSelectionChanged`

### 日志查看命令
```bash
# 查看组合显示相关日志
log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND (eventMessage CONTAINS "BufferWithTranslation" OR eventMessage CONTAINS "candidateSelectionChanged")'

# 查看窗口大小调整日志
log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "resizeForContent"'
```

### 典型日志示例
```
[HallelujahIM] candidateSelectionChanged: 延迟模式组合显示，候选词='world'
[HallelujahIM] showBufferWithTranslation: 显示缓冲区='hello wor', 候选词='world', 翻译='世界；世间'
[HallelujahIM] AnnotationWinController: setBufferTextWithTranslation 组合模式
[HallelujahIM] AnnotationWinController: resizeForContent length=45, width=280.0, height=80.0, combined=YES
```

## 🎨 用户体验设计

### 视觉区分
- **📝 图标**：标识缓冲区内容
- **🔤 图标**：标识翻译内容
- **蓝色文字**：区分延迟模式
- **分隔线**：清晰区分两部分内容

### 智能适应
- **动态高度**：根据是否有翻译内容自动调整窗口高度
- **动态宽度**：根据内容长度自动调整窗口宽度
- **位置优化**：避免遮挡候选词列表和输入区域

## 📊 功能矩阵

| 模式 | 翻译设置 | 选中候选词 | 显示内容 |
|------|---------|-----------|---------|
| 智能模式 | 开启 | 是 | 🔤 翻译内容 |
| 智能模式 | 关闭 | - | 无显示 |
| 延迟模式 | 开启 | 是 | 📝 缓冲区 + 🔤 翻译 |
| 延迟模式 | 开启 | 否 | 📝 缓冲区 |
| 延迟模式 | 关闭 | - | 📝 缓冲区 |

## 🔧 故障排除

### 常见问题

#### 1. 组合显示不出现
**可能原因**：
- 翻译功能未开启
- 未选中候选词
- 不在延迟模式

**解决方法**：
```bash
# 检查模式和翻译设置
log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "candidateSelectionChanged"'
```

#### 2. 窗口大小异常
**可能原因**：
- 内容长度计算异常
- 分隔线检测失败

**解决方法**：
```bash
# 检查窗口大小调整
log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "resizeForContent"'
```

#### 3. 翻译内容不显示
**可能原因**：
- 候选词没有翻译
- getAnnotation 返回空值

**解决方法**：
```bash
# 检查翻译获取过程
log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "翻译"'
```

## 🎯 测试用例

### 测试1：基础组合显示
```
1. 启用翻译功能
2. 进入延迟模式
3. 输入 "hel"
4. 用箭头键选择 "hello"
5. 验证显示：📝 hel + 🔤 hello的翻译
```

### 测试2：候选词切换
```
1. 在测试1基础上
2. 用箭头键切换到 "help"
3. 验证翻译内容更新为 "help" 的翻译
4. 缓冲区内容保持 "hel"
```

### 测试3：翻译功能关闭
```
1. 关闭翻译功能
2. 进入延迟模式
3. 输入并选择候选词
4. 验证只显示缓冲区内容，无翻译
```

### 测试4：模式切换
```
1. 在延迟模式组合显示状态
2. 按左Shift切换到智能模式
3. 验证显示切换为传统翻译模式
```

## 🚀 成果总结

通过这次改进，我们成功实现了：

1. **功能融合**：延迟模式 + 翻译功能完美结合
2. **一窗显示**：同一窗口显示缓冲区和翻译内容
3. **智能适应**：根据内容和设置自动调整显示方式
4. **用户友好**：保持所有现有功能，只增强体验
5. **完全兼容**：不影响任何现有功能和用户习惯

现在用户在延迟模式下可以：
- 实时看到完整的输入内容
- 同时查看候选词的翻译
- 享受无缝的学习体验
- 保持高效的输入流程

这个改进让 HallelujahIM 的延迟模式变得更加强大和用户友好！
