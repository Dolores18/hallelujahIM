# 缓冲区显示框使用指南

## 🎯 功能概述

为英语延迟模式新增了**缓冲区显示框**功能，实时显示当前缓冲区的所有文本，让用户清楚地看到正在输入的整句内容。

## ✨ 功能特点

### 1. **智能显示模式**
- **翻译模式**：原有功能，显示词汇翻译
- **缓冲区模式**：新功能，显示当前输入的完整文本

### 2. **视觉设计**
- **图标标识**：📝 图标表示缓冲区模式
- **颜色区分**：蓝色文本表示延迟模式
- **动态尺寸**：根据文本长度自动调整窗口大小
- **合理位置**：显示在光标上方，不遮挡输入区域

### 3. **实时更新**
- 字母输入时实时更新
- 空格键继续缓冲时更新
- 候选词选择后更新
- 标点符号输入时更新

## 🎮 使用方法

### 进入缓冲区显示模式
1. 按 **左Shift键** 切换到英语延迟模式
2. 缓冲区显示框自动出现
3. 开始输入，内容实时显示在显示框中

### 显示框内容示例
```
📝 hello world
📝 this is a test.
📝 (输入中...)  // 当缓冲区为空时
```

### 退出显示模式
- 按 **左Shift键** 切换回智能模式
- 按 **回车键** 提交文本后自动隐藏
- **ESC键** 取消输入时隐藏

## 🔧 技术实现

### 核心组件

#### 1. AnnotationWinController 扩展
```objective-c
typedef enum {
    AnnotationModeTranslation,  // 翻译模式
    AnnotationModeBuffer       // 缓冲区模式
} AnnotationMode;

// 新增方法
- (void)showBufferDisplay:(NSString *)bufferText atPoint:(NSPoint)origin;
- (void)updateBufferDisplay:(NSString *)bufferText;
- (void)hideBufferDisplay;
- (void)setBufferText:(NSString *)bufferText;
```

#### 2. InputController 集成
```objective-c
// 显示控制方法
- (void)showBufferDisplayIfNeeded;
- (void)updateBufferDisplayContent;
- (void)hideBufferDisplayIfNeeded;
- (NSPoint)calculateBufferDisplayPosition;
```

### 关键集成点

#### 1. 模式切换时
```objective-c
// 进入延迟模式
if (_currentMode == InputModeEnglishDelay) {
    [self showBufferDisplayIfNeeded];
}

// 退出延迟模式
if (_currentMode == InputModeIntelligent) {
    [self hideBufferDisplayIfNeeded];
}
```

#### 2. 内容更新时
```objective-c
// 所有修改缓冲区的操作后
if (_currentMode == InputModeEnglishDelay) {
    [self updateBufferDisplayContent];
}
```

## 📱 用户体验设计

### 视觉反馈
- **📝 图标**：清楚标识这是缓冲区内容
- **蓝色文字**：与翻译模式的黑色文字区分
- **动态大小**：最小120px，最大400px，根据内容调整

### 位置计算
- 显示在光标上方25px处
- 自动避免超出屏幕边界
- 不遮挡候选词列表

### 交互逻辑
- 只在延迟模式下显示
- 实时跟随内容变化
- 提交或取消时自动隐藏

## 🐛 调试功能

### 日志标识
所有相关日志都包含 `[HallelujahIM] AnnotationWinController:` 或 `Buffer` 关键词：

```bash
# 查看缓冲区显示相关日志
log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND (eventMessage CONTAINS "Buffer" OR eventMessage CONTAINS "AnnotationWinController")'
```

### 关键日志示例
```
[HallelujahIM] AnnotationWinController: showBufferDisplay='hello' at point(100.0, 200.0)
[HallelujahIM] AnnotationWinController: updateBufferDisplay='hello world'
[HallelujahIM] AnnotationWinController: hideBufferDisplay
[HallelujahIM] showBufferDisplayIfNeeded: 显示缓冲区='hello world'
[HallelujahIM] updateBufferDisplayContent: 更新缓冲区='hello world test'
```

## 🔧 故障排除

### 常见问题

#### 1. 显示框不出现
- **检查模式**：确保已切换到英语延迟模式
- **查看日志**：搜索 `showBufferDisplayIfNeeded` 日志
- **确认激活**：检查 AnnotationWinController 是否正确初始化

#### 2. 显示框不更新
- **检查模式状态**：确保仍在延迟模式
- **查看日志**：搜索 `updateBufferDisplayContent` 日志
- **内容检查**：确认缓冲区内容确实发生了变化

#### 3. 显示框不隐藏
- **手动切换**：按左Shift键切换模式
- **重置状态**：按ESC键重置输入法
- **查看日志**：搜索 `hideBufferDisplayIfNeeded` 日志

### 调试步骤

1. **确认基础功能**
   ```bash
   # 查看模式切换日志
   log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "切换"'
   ```

2. **验证显示控制**
   ```bash
   # 查看显示控制日志
   log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "showBufferDisplay"'
   ```

3. **检查内容更新**
   ```bash
   # 查看内容更新日志
   log stream --predicate 'eventMessage CONTAINS "HallelujahIM" AND eventMessage CONTAINS "updateBufferDisplay"'
   ```

## 🎨 自定义选项

### 外观调整
在 `AnnotationWinController.m` 的 `configureForBufferDisplay` 方法中可以调整：
- 文本颜色：`self.view.textColor`
- 背景颜色：`self.view.backgroundColor`
- 窗口大小：`newFrame` 的尺寸参数

### 位置调整
在 `InputController.m` 的 `calculateBufferDisplayPosition` 方法中可以调整：
- 相对位置：修改 `displayPoint.y += 25`
- 边界检查：调整边距参数

## 📈 性能优化

### 高效更新
- 只在延迟模式下执行显示逻辑
- 使用模式检查避免不必要的操作
- 动态调整窗口大小，避免频繁重绘

### 内存管理
- 复用现有的 AnnotationWindow 组件
- 避免创建额外的 UI 组件
- 适时隐藏窗口释放资源

## 🚀 未来扩展

### 可能的增强功能
1. **样式自定义**：允许用户自定义颜色和字体
2. **位置记忆**：记住用户偏好的显示位置
3. **渐变动效**：添加显示/隐藏的平滑过渡
4. **内容格式化**：高亮显示当前正在编辑的单词
5. **多行支持**：支持长文本的多行显示

### 集成建议
- 与用户偏好设置集成
- 添加开关控制是否显示缓冲区
- 提供显示位置的选择选项

通过这个缓冲区显示功能，英语延迟模式的用户体验得到了显著提升，用户可以清楚地看到正在输入的完整内容，使得整句编辑变得更加直观和高效。
