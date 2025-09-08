# 英语延迟模式扩展计划

## 项目概述

基于现有的 HallelujahIM 多语言智能输入法，新增**英语延迟模式**，实现整句英语输入的智能纠错、翻译和优化功能。

## 功能目标

### 核心功能
- **整句延迟上屏**：英语字符不直接输出，存入缓冲区
- **整句纠错**：基于上下文进行拼写检查和语法纠错
- **翻译功能**：整句翻译或关键词翻译
- **智能建议**：用词建议、语法优化等

### 用户体验
- **无缝切换**：左 Shift 键切换到英语延迟模式
- **实时显示**：缓冲区内容实时显示，支持候选词提示
- **智能处理**：提交前自动进行文本处理
- **用户选择**：可以选择原始文本或处理后的文本

## 技术方案

### 模式管理
```objective-c
typedef enum {
    InputModeIntelligent,    // 智能模式（当前）
    InputModeEnglishDirect,  // 纯英文模式（当前）
    InputModeEnglishDelay   // 英语延迟模式（新增）
} InputMode;

@property (nonatomic, assign) InputMode currentMode;
```

### 模式切换
- **右 Shift**：智能模式 ↔ 纯英文模式（现有功能）
- **左 Shift**：智能模式 ↔ 英语延迟模式（新增功能）

## 关键修改点

### 1. 空格键处理（必须修改）
```objective-c
if (keyCode == KEY_SPACE) {
    if (hasBufferedText) {
        if (_currentMode == InputModeEnglishDelay) {
            // 英语延迟模式：不提交，继续缓冲
            [self appendToComposedBuffer:@" "];
            [self updateEnglishCandidates];
            [self showCandidates];
        } else {
            // 其他模式：直接提交
            [self commitComposition:sender];
        }
    }
}
```

### 2. 标点符号处理（必须修改）
```objective-c
if ([[NSCharacterSet punctuationCharacterSet] characterIsMember:ch]) {
    if (hasBufferedText) {
        if (_currentMode == InputModeEnglishDelay) {
            // 英语延迟模式：继续缓冲
            [self appendToComposedBuffer:characters];
            [self updateEnglishCandidates];
            [self showCandidates];
        } else {
            // 其他模式：提交缓冲内容+标点
            [self appendToComposedBuffer:characters];
            [self commitCompositionWithoutSpace:sender];
        }
    }
}
```

### 3. 回车键处理（需要修改）
```objective-c
if (keyCode == KEY_RETURN) {
    if (hasBufferedText) {
        if (_currentMode == InputModeEnglishDelay) {
            // 英语延迟模式：提交前进行文本处理
            NSString *processedText = [self processEnglishText:[self originalBuffer]];
            [self setOriginalBuffer:processedText];
            [self commitCompositionWithoutSpace:sender];
        } else {
            // 其他模式：直接提交
            [self commitCompositionWithoutSpace:sender];
        }
    }
}
```

### 4. 候选词系统优化（重要改进）
```objective-c
- (void)updateEnglishCandidates {
    if (_currentMode == InputModeEnglishDelay) {
        // 英语延迟模式：使用最后一个单词进行候选词匹配
        NSString *lastWord = [self getLastWordFromBuffer:[self originalBuffer]];
        NSArray *candidates = [engine getCandidates:lastWord];
        [sharedCandidates updateCandidates:candidates];
    } else {
        // 其他模式：使用完整输入进行候选词匹配
        NSArray *candidates = [engine getCandidates:[self originalBuffer]];
        [sharedCandidates updateCandidates:candidates];
    }
}

- (NSString *)getLastWordFromBuffer:(NSString *)buffer {
    // 获取倒数第一个空格之前的文本
    NSRange lastSpaceRange = [buffer rangeOfString:@" " options:NSBackwardsSearch];
    if (lastSpaceRange.location != NSNotFound) {
        return [buffer substringFromIndex:lastSpaceRange.location + 1];
    }
    return buffer; // 如果没有空格，返回整个缓冲区
}
```

### 5. 候选词选择处理（需要修改）
```objective-c
// 在候选词选择时
if (isCandidatesVisible) {
    int pressedNumber = characters.intValue;
    candidate = _candidates[pressedNumber - 1];
    
    if (_currentMode == InputModeEnglishDelay) {
        // 英语延迟模式：替换最后一个单词，不提交
        [self replaceLastWordWith:candidate];
        [self updateEnglishCandidates];
        [self showCandidates];
    } else {
        // 其他模式：直接提交
        [self setOriginalBuffer:candidate];
        [self commitComposition:sender];
    }
}
```

### 6. 数字键处理（可能需要修改）
```objective-c
if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch]) {
    if (!hasBufferedText) {
        if (_currentMode == InputModeEnglishDelay) {
            // 英语延迟模式：可能需要特殊处理
            [self appendToComposedBuffer:characters];
            [self updateEnglishCandidates];
            [self showCandidates];
        } else {
            // 其他模式：直接提交数字
            [self appendToComposedBuffer:characters];
            [self commitCompositionWithoutSpace:sender];
        }
    }
}
```

## 不需要修改的部分

### 1. 显示机制（复用现有系统）
- **缓冲区显示**：使用现有的 `showPreeditString:` 方法
- **候选词显示**：使用现有的候选词系统
- **原因**：现有机制成熟稳定，无需重新开发

### 2. 模式切换提交（保持现有逻辑）
- **右 Shift 切换**：切换到纯英文模式时提交缓冲内容
- **原因**：系统行为，应该提交

## 文本处理逻辑

### 核心处理方法
```objective-c
- (NSString *)processEnglishText:(NSString *)input {
    // 1. 整句拼写检查
    NSString *correctedText = [self spellCheckText:input];
    
    // 2. 语法纠错
    NSString *grammarCorrected = [self grammarCheckText:correctedText];
    
    // 3. 翻译功能（可选）
    NSString *translated = [self translateText:grammarCorrected];
    
    // 4. 智能优化
    NSString *optimized = [self optimizeText:translated];
    
    return optimized;
}
```

### 处理功能模块
1. **拼写检查**：基于现有 Damerau-Levenshtein 算法
2. **语法纠错**：集成语法检查 API
3. **翻译功能**：集成翻译服务
4. **智能优化**：自动大小写、标点符号优化

## 实现阶段

### 阶段 1：基础功能（1-2周）
- [ ] 添加英语延迟模式枚举
- [ ] 实现左 Shift 键切换逻辑
- [ ] 修改空格键和标点符号处理
- [ ] 实现基本的延迟上屏功能

### 阶段 2：文本处理（2-3周）
- [ ] 实现整句拼写检查
- [ ] 集成语法纠错功能
- [ ] 添加基本的文本优化
- [ ] 测试文本处理效果

### 阶段 3：高级功能（3-4周）
- [ ] 集成翻译功能
- [ ] 添加用词建议
- [ ] 实现智能优化
- [ ] 完善用户体验

### 阶段 4：优化完善（1-2周）
- [ ] 性能优化
- [ ] 用户界面优化
- [ ] 错误处理完善
- [ ] 文档和测试

## 技术优势

### 1. 架构优势
- **最小侵入性**：只修改关键的条件判断
- **复用现有代码**：充分利用现有的候选词和显示系统
- **保持一致性**：与现有模式保持统一的用户体验

### 2. 功能优势
- **整句处理**：支持整句纠错和翻译
- **智能建议**：基于上下文的智能建议
- **用户控制**：用户可以选择是否应用处理结果

### 3. 开发优势
- **开发简单**：基于现有架构，易于实现
- **测试容易**：复用现有的测试框架
- **维护简单**：代码结构清晰，职责明确

## 预期效果

### 用户体验
```
用户输入："helo world"
    ↓
缓冲区显示：helo world（实时显示）
    ↓
候选词显示（基于最后一个单词 "world"）：
1. world
2. words
3. word
    ↓
用户按数字键 "1" 选择 "world"
    ↓
缓冲区更新为："helo world"
    ↓
继续显示候选词（基于 "world"）
    ↓
用户按回车
    ↓
自动处理：hello world（纠错后的结果）
    ↓
提交到应用程序
```

### 功能特点
- **无缝切换**：左 Shift 键快速切换模式
- **实时反馈**：输入过程中实时显示和提示
- **智能处理**：自动纠错、翻译、优化
- **用户选择**：可以选择原始文本或处理后的文本

## 总结

这个英语延迟模式扩展计划基于现有的 HallelujahIM 架构，通过最小化的修改实现了强大的整句处理功能。方案充分利用了现有的缓冲区机制、候选词系统和显示系统，既保持了架构的稳定性，又实现了新功能的需求。

**核心优势：**
- 最小化修改，最大化复用
- 功能强大，用户体验优秀
- 开发简单，维护容易
- 扩展性强，未来可继续增强

这个方案为 HallelujahIM 增加了重要的英语整句处理能力，使其成为一个更加强大的多语言智能输入法。
