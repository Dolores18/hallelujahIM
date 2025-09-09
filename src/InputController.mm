#import <AppKit/NSSpellChecker.h>
#import <CoreServices/CoreServices.h>

#import "InputApplicationDelegate.h"
#import "InputController.h"
#import "NSScreen+PointConversion.h"

extern IMKCandidates *sharedCandidates;
extern NSUserDefaults *preference;
extern ConversionEngine *engine;

typedef NSInteger KeyCode;
static const KeyCode KEY_RETURN = 36, KEY_SPACE = 49, KEY_DELETE = 51, KEY_ESC = 53, KEY_ARROW_DOWN = 125, KEY_ARROW_UP = 126, KEY_RIGHT_SHIFT = 60, KEY_LEFT_SHIFT = 56;

@interface InputController()

- (void)showIMEPreferences:(id)sender;
- (void)clickAbout:(NSMenuItem *)sender;

@end

@implementation InputController

- (NSUInteger)recognizedEvents:(id)sender {
    return NSEventMaskKeyDown | NSEventMaskFlagsChanged;
}

- (BOOL)handleEvent:(NSEvent *)event client:(id)sender {
    NSUInteger modifiers = event.modifierFlags;
    bool handled = NO;
    switch (event.type) {
    case NSEventTypeFlagsChanged:
        // NSLog(@"hallelujah event modifierFlags %lu, event keyCode: %@", (unsigned long)[event modifierFlags], [event keyCode]);

        if (_lastEventTypes[1] == NSEventTypeFlagsChanged && _lastModifiers[1] == modifiers) {
            return YES;
        }

        if (modifiers == 0 && _lastEventTypes[1] == NSEventTypeFlagsChanged && _lastModifiers[1] == NSEventModifierFlagShift &&
            event.keyCode == KEY_RIGHT_SHIFT && !(_lastModifiers[0] & NSEventModifierFlagShift)) {

            _defaultEnglishMode = !_defaultEnglishMode;
            if (_defaultEnglishMode) {
                _currentMode = InputModeEnglishDirect;
                NSLog(@"[HallelujahIM] 右Shift切换到纯英文模式 (InputModeEnglishDirect)");
                NSString *bufferedText = [self originalBuffer];
                if (bufferedText && bufferedText.length > 0) {
                    NSLog(@"[HallelujahIM] 切换模式时提交缓冲文本: '%@'", bufferedText);
                    [self cancelComposition];
                    [self commitComposition:sender];
                }
            } else {
                _currentMode = InputModeIntelligent;
                NSLog(@"[HallelujahIM] 右Shift切换到智能模式 (InputModeIntelligent)");
            }
        }
        
        // 左Shift键切换到英语延迟模式
        if (modifiers == 0 && _lastEventTypes[1] == NSEventTypeFlagsChanged && _lastModifiers[1] == NSEventModifierFlagShift &&
            event.keyCode == KEY_LEFT_SHIFT && !(_lastModifiers[0] & NSEventModifierFlagShift)) {

            NSLog(@"[HallelujahIM] 检测到左Shift按键事件");
            
            if (_currentMode == InputModeEnglishDelay) {
                _currentMode = InputModeIntelligent;
                NSLog(@"[HallelujahIM] 左Shift切换: 英语延迟模式 → 智能模式 (InputModeIntelligent)");
            } else {
                _currentMode = InputModeEnglishDelay;
                NSLog(@"[HallelujahIM] 左Shift切换: %@ → 英语延迟模式 (InputModeEnglishDelay)", 
                      (_currentMode == InputModeIntelligent) ? @"智能模式" : @"纯英文模式");
            }
            
            // 切换模式时，如果有缓冲文本且切换到智能模式，则提交
            if (_currentMode == InputModeIntelligent) {
                NSString *bufferedText = [self originalBuffer];
                if (bufferedText && bufferedText.length > 0) {
                    NSLog(@"[HallelujahIM] 切换到智能模式时提交缓冲文本: '%@'", bufferedText);
                    [self cancelComposition];
                    [self commitComposition:sender];
                } else {
                    NSLog(@"[HallelujahIM] 切换到智能模式，无缓冲文本需要提交");
                }
            } else {
                NSLog(@"[HallelujahIM] 进入英语延迟模式，当前缓冲文本: '%@'", [self originalBuffer] ?: @"(空)");
            }
        }
        break;
    case NSEventTypeKeyDown:
        if (_currentMode == InputModeEnglishDirect) {
            break;
        }

        // ignore Command+X hotkeys.
        if (modifiers & NSEventModifierFlagCommand)
            break;

        if (modifiers & NSEventModifierFlagOption) {
            return false;
        }

        if (modifiers & NSEventModifierFlagControl) {
            return false;
        }

        handled = [self onKeyEvent:event client:sender];
        break;
    default:
        break;
    }

    _lastModifiers[0] = _lastModifiers[1];
    _lastEventTypes[0] = _lastEventTypes[1];
    _lastModifiers[1] = modifiers;
    _lastEventTypes[1] = event.type;
    return handled;
}

- (BOOL)onKeyEvent:(NSEvent *)event client:(id)sender {
    _currentClient = sender;
    NSInteger keyCode = event.keyCode;
    NSString *characters = event.characters;

    NSString *bufferedText = [self originalBuffer];
    bool hasBufferedText = bufferedText && bufferedText.length > 0;
    
    // 记录关键按键和当前状态
    if (keyCode == KEY_SPACE || keyCode == KEY_RETURN || keyCode == KEY_DELETE || 
        (characters.length > 0 && ([[NSCharacterSet letterCharacterSet] characterIsMember:[characters characterAtIndex:0]] ||
         [[NSCharacterSet punctuationCharacterSet] characterIsMember:[characters characterAtIndex:0]]))) {
        NSString *modeString = (_currentMode == InputModeIntelligent) ? @"智能模式" : 
                              (_currentMode == InputModeEnglishDirect) ? @"纯英文模式" : @"英语延迟模式";
        NSLog(@"[HallelujahIM] 按键事件: keyCode=%ld, char='%@', 当前模式=%@, 缓冲文本='%@'", 
              (long)keyCode, characters, modeString, bufferedText ?: @"(空)");
    }

    if (keyCode == KEY_DELETE) {
        if (hasBufferedText) {
            return [self deleteBackward:sender];
        }

        return NO;
    }

    if (keyCode == KEY_SPACE) {
        if (hasBufferedText) {
            if (_currentMode == InputModeEnglishDelay) {
                // 英语延迟模式：不提交，继续缓冲
                NSLog(@"[HallelujahIM] 空格键-延迟模式: 继续缓冲，当前文本='%@'", bufferedText);
                [self originalBufferAppend:@" " client:sender];
                [self updateEnglishCandidates];
                [sharedCandidates show:kIMKLocateCandidatesBelowHint];
                NSLog(@"[HallelujahIM] 空格键-延迟模式: 缓冲后文本='%@'", [self originalBuffer]);
                return YES;
            } else {
                // 其他模式：直接提交
                NSLog(@"[HallelujahIM] 空格键-非延迟模式: 提交文本='%@'", bufferedText);
                [self commitComposition:sender];
                return YES;
            }
        } else {
            NSLog(@"[HallelujahIM] 空格键: 无缓冲文本，忽略");
        }
        return NO;
    }

    if (keyCode == KEY_RETURN) {
        if (hasBufferedText) {
            if (_currentMode == InputModeEnglishDelay) {
                // 英语延迟模式：提交前进行文本处理
                NSLog(@"[HallelujahIM] 回车键-延迟模式: 开始处理文本='%@'", bufferedText);
                NSString *processedText = [self processEnglishText:[self originalBuffer]];
                NSLog(@"[HallelujahIM] 回车键-延迟模式: 处理后文本='%@'", processedText);
                [self setOriginalBuffer:processedText];
                [self setComposedBuffer:processedText];
                [self commitCompositionWithoutSpace:sender];
                NSLog(@"[HallelujahIM] 回车键-延迟模式: 文本已提交");
                return YES;
            } else {
                // 其他模式：直接提交
                NSLog(@"[HallelujahIM] 回车键-非延迟模式: 直接提交文本='%@'", bufferedText);
                [self commitCompositionWithoutSpace:sender];
                return YES;
            }
        } else {
            NSLog(@"[HallelujahIM] 回车键: 无缓冲文本，忽略");
        }
        return NO;
    }

    if (keyCode == KEY_ESC) {
        [self cancelComposition];
        [sender insertText:@""];
        [self reset];
        return YES;
    }

    char ch = [characters characterAtIndex:0];
    if ((ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z')) {
        NSLog(@"[HallelujahIM] 字母输入: '%@', 当前缓冲='%@'", characters, bufferedText ?: @"(空)");
        [self originalBufferAppend:characters client:sender];
        NSLog(@"[HallelujahIM] 字母输入后缓冲='%@'", [self originalBuffer]);

        if (_currentMode == InputModeEnglishDelay) {
            NSLog(@"[HallelujahIM] 字母输入-延迟模式: 使用英语候选词更新");
            [self updateEnglishCandidates];
        } else {
            NSLog(@"[HallelujahIM] 字母输入-非延迟模式: 使用标准候选词更新");
            [sharedCandidates updateCandidates];
        }
        [sharedCandidates show:kIMKLocateCandidatesBelowHint];
        return YES;
    }

    if ([self isMojaveAndLaterSystem]) {
        BOOL isCandidatesVisible = [sharedCandidates isVisible];
        if (isCandidatesVisible) {
            if (keyCode == KEY_ARROW_DOWN) {
                [sharedCandidates moveDown:self];
                _currentCandidateIndex++;
                return NO;
            }

            if (keyCode == KEY_ARROW_UP) {
                [sharedCandidates moveUp:self];
                _currentCandidateIndex--;
                return NO;
            }
        }

        if ([[NSCharacterSet decimalDigitCharacterSet] characterIsMember:ch]) {
            if (!hasBufferedText) {
                [self appendToComposedBuffer:characters];
                [self commitCompositionWithoutSpace:sender];
                return YES;
            }

            if (isCandidatesVisible) { // use 1~9 digital numbers as selection keys
                int pressedNumber = characters.intValue;
                NSLog(@"[HallelujahIM] 数字键选择候选词: 按键=%d", pressedNumber);
                
                NSString *candidate;
                int pageSize = 9;
                NSUInteger candidateIndex;
                
                if (_currentCandidateIndex <= pageSize) {
                    candidateIndex = pressedNumber - 1;
                } else {
                    candidateIndex = pageSize * (_currentCandidateIndex / pageSize - 1) + (_currentCandidateIndex % pageSize) + pressedNumber - 1;
                }
                
                // 数组越界保护
                if (candidateIndex >= _candidates.count) {
                    NSLog(@"[HallelujahIM] 错误: 候选词索引越界，index=%lu, count=%lu", 
                          (unsigned long)candidateIndex, (unsigned long)_candidates.count);
                    return YES; // 防止崩溃
                }
                
                candidate = _candidates[candidateIndex];
                NSLog(@"[HallelujahIM] 选中候选词: index=%lu, candidate='%@'", 
                      (unsigned long)candidateIndex, candidate);
                
                if (_currentMode == InputModeEnglishDelay) {
                    // 英语延迟模式：替换最后一个单词，不提交
                    NSLog(@"[HallelujahIM] 数字键-延迟模式: 替换最后单词，当前缓冲='%@'", [self originalBuffer]);
                    [self replaceLastWordWith:candidate];
                    NSLog(@"[HallelujahIM] 数字键-延迟模式: 替换后缓冲='%@'", [self originalBuffer]);
                    [self updateEnglishCandidates];
                    [sharedCandidates show:kIMKLocateCandidatesBelowHint];
                    return YES;
                } else {
                    // 其他模式：直接提交
                    NSLog(@"[HallelujahIM] 数字键-非延迟模式: 直接提交候选词='%@'", candidate);
                    [self cancelComposition];
                    [self setComposedBuffer:candidate];
                    [self setOriginalBuffer:candidate];
                    [self commitComposition:sender];
                    return YES;
                }
            }
        }
    }

    if ([[NSCharacterSet punctuationCharacterSet] characterIsMember:ch] || [[NSCharacterSet symbolCharacterSet] characterIsMember:ch]) {
        if (hasBufferedText) {
            NSLog(@"[HallelujahIM] 标点符号输入: '%@', 当前缓冲='%@'", characters, bufferedText);
            if (_currentMode == InputModeEnglishDelay) {
                // 英语延迟模式：继续缓冲
                NSLog(@"[HallelujahIM] 标点-延迟模式: 继续缓冲");
                [self originalBufferAppend:characters client:sender];
                NSLog(@"[HallelujahIM] 标点-延迟模式: 缓冲后='%@'", [self originalBuffer]);
                [self updateEnglishCandidates];
                [sharedCandidates show:kIMKLocateCandidatesBelowHint];
                return YES;
            } else {
                // 其他模式：提交缓冲内容+标点
                NSLog(@"[HallelujahIM] 标点-非延迟模式: 提交缓冲内容+标点");
                [self appendToComposedBuffer:characters];
                [self commitCompositionWithoutSpace:sender];
                return YES;
            }
        } else {
            NSLog(@"[HallelujahIM] 标点符号: 无缓冲文本，忽略");
        }
    }

    return NO;
}

- (BOOL)isMojaveAndLaterSystem {
    NSOperatingSystemVersion version = [NSProcessInfo processInfo].operatingSystemVersion;
    return (version.majorVersion == 10 && version.minorVersion > 13) || version.majorVersion > 10;
}

- (BOOL)deleteBackward:(id)sender {
    NSMutableString *originalText = [self originalBuffer];

    if (_insertionIndex > 0) {
        --_insertionIndex;

        NSString *convertedString = [originalText substringToIndex:originalText.length - 1];

        [self setComposedBuffer:convertedString];
        [self setOriginalBuffer:convertedString];

        [self showPreeditString:convertedString];

        if (convertedString && convertedString.length > 0) {
            [sharedCandidates updateCandidates];
            [sharedCandidates show:kIMKLocateCandidatesBelowHint];
        } else {
            [self reset];
        }
        return YES;
    }
    return NO;
}

- (void)commitComposition:(id)sender {
    NSString *text = [self composedBuffer];

    if (text == nil || text.length == 0) {
        text = [self originalBuffer];
    }
    BOOL commitWordWithSpace = [preference boolForKey:@"commitWordWithSpace"];

    if (commitWordWithSpace && text.length > 0) {
        char firstChar = [text characterAtIndex:0];
        char lastChar = [text characterAtIndex:text.length - 1];
        if (![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:firstChar] && lastChar != '\'') {
            text = [NSString stringWithFormat:@"%@ ", text];
        }
    }

    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self reset];
}

- (void)commitCompositionWithoutSpace:(id)sender {
    NSString *text = [self composedBuffer];

    if (text == nil || text.length == 0) {
        text = [self originalBuffer];
    }

    [sender insertText:text replacementRange:NSMakeRange(NSNotFound, NSNotFound)];

    [self reset];
}

- (void)reset {
    NSString *bufferBeforeReset = [self originalBuffer];
    NSLog(@"[HallelujahIM] reset: 重置输入法状态，清理前缓冲='%@'", bufferBeforeReset ?: @"(空)");
    
    [self setComposedBuffer:@""];
    [self setOriginalBuffer:@""];
    _insertionIndex = 0;
    _currentCandidateIndex = 1;
    [sharedCandidates clearSelection];
    [sharedCandidates hide];
    _candidates = [[NSMutableArray alloc] init];
    [sharedCandidates setCandidateData:@[]];
    [_annotationWin setAnnotation:@""];
    [_annotationWin hideWindow];
    
    NSLog(@"[HallelujahIM] reset: 重置完成");
}

- (NSMutableString *)composedBuffer {
    if (_composedBuffer == nil) {
        _composedBuffer = [[NSMutableString alloc] init];
    }
    return _composedBuffer;
}

- (void)setComposedBuffer:(NSString *)string {
    NSMutableString *buffer = [self composedBuffer];
    [buffer setString:string];
}

- (NSMutableString *)originalBuffer {
    if (_originalBuffer == nil) {
        _originalBuffer = [[NSMutableString alloc] init];
    }
    return _originalBuffer;
}

- (void)setOriginalBuffer:(NSString *)input {
    NSMutableString *buffer = [self originalBuffer];
    [buffer setString:input];
}

- (void)showPreeditString:(NSString *)input {
    NSDictionary *attrs = [self markForStyle:kTSMHiliteSelectedRawText atRange:NSMakeRange(0, input.length)];
    NSAttributedString *attrString;

    NSString *originalBuff = [NSString stringWithString:[self originalBuffer]];
    if ([input.lowercaseString hasPrefix:originalBuff.lowercaseString]) {
        attrString = [[NSAttributedString alloc]
            initWithString:[NSString stringWithFormat:@"%@%@", originalBuff, [input substringFromIndex:originalBuff.length]]
                attributes:attrs];
    } else {
        attrString = [[NSAttributedString alloc] initWithString:input attributes:attrs];
    }

    [_currentClient setMarkedText:attrString
                   selectionRange:NSMakeRange(input.length, 0)
                 replacementRange:NSMakeRange(NSNotFound, NSNotFound)];
}

- (void)originalBufferAppend:(NSString *)input client:(id)sender {
    NSMutableString *buffer = [self originalBuffer];
    [buffer appendString:input];
    _insertionIndex++;
    [self showPreeditString:buffer];
}

- (void)appendToComposedBuffer:(NSString *)input {
    NSMutableString *buffer = [self composedBuffer];
    [buffer appendString:input];
}

- (NSArray *)candidates:(id)sender {
    NSString *originalInput = [self originalBuffer];
    NSArray *candidateList = [engine getCandidates:originalInput];
    _candidates = [NSMutableArray arrayWithArray:candidateList];
    return candidateList;
}

- (void)candidateSelectionChanged:(NSAttributedString *)candidateString {
    [self _updateComposedBuffer:candidateString];

    [self showPreeditString:candidateString.string];

    _insertionIndex = candidateString.length;

    BOOL showTranslation = [preference boolForKey:@"showTranslation"];
    if (showTranslation) {
        [self showAnnotation:candidateString];
    }
}

- (void)candidateSelected:(NSAttributedString *)candidateString {
    [self _updateComposedBuffer:candidateString];

    [self commitComposition:_currentClient];
}

- (void)_updateComposedBuffer:(NSAttributedString *)candidateString {
    [self setComposedBuffer:candidateString.string];
}

- (void)activateServer:(id)sender {
    NSLog(@"[HallelujahIM] activateServer: 输入法激活");
    [sender overrideKeyboardWithKeyboardNamed:@"com.apple.keylayout.US"];

    if (_annotationWin == nil) {
        _annotationWin = [AnnotationWinController sharedController];
        NSLog(@"[HallelujahIM] activateServer: 创建AnnotationWinController");
    }

    _currentCandidateIndex = 1;
    _candidates = [[NSMutableArray alloc] init];
    _currentMode = InputModeIntelligent; // 初始化为智能模式
    NSLog(@"[HallelujahIM] activateServer: 初始化完成，当前模式=智能模式");
}

- (void)deactivateServer:(id)sender {
    NSLog(@"[HallelujahIM] deactivateServer: 输入法停用");
    [self reset];
}

- (NSMenu *)menu{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    return [NSApp.delegate performSelector:NSSelectorFromString(@"menu")];
#pragma clang diagnostic pop
}

- (void)showIMEPreferences:(id)sender {
    [self openUrl:@"http://localhost:62718/index.html"];
}

- (void)clickAbout:(NSMenuItem *)sender {
    [self openUrl:@"https://github.com/dongyuwei/hallelujahIM"];
}

- (void)openUrl:(NSString *)url {
    NSWorkspace *ws = [NSWorkspace sharedWorkspace];
    
    NSWorkspaceOpenConfiguration *configuration = [NSWorkspaceOpenConfiguration new];
    configuration.promptsUserIfNeeded = YES;
    configuration.createsNewApplicationInstance = NO;
    
    [ws openURL:[NSURL URLWithString:url] configuration:configuration completionHandler:^(NSRunningApplication * _Nullable app, NSError * _Nullable error) {
        if (error) {
          NSLog(@"Failed to run the app: %@", error.localizedDescription);
        }
    }];
}

- (void)showAnnotation:(NSAttributedString *)candidateString {
    NSString *annotation = [engine getAnnotation:candidateString.string];
    if (annotation && annotation.length > 0) {
        [_annotationWin setAnnotation:annotation];
        [_annotationWin showWindow:[self calculatePositionOfTranslationWindow]];
    } else {
        [_annotationWin hideWindow];
    }
}

- (NSPoint)calculatePositionOfTranslationWindow {
    // Mac Cocoa ui default coordinate system: left-bottom, origin: (x:0, y:0) ↑→
    // see https://developer.apple.com/library/archive/documentation/General/Conceptual/Devpedia-CocoaApp/CoordinateSystem.html
    // see https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CocoaDrawingGuide/Transforms/Transforms.html
    // Notice: there is a System bug: candidateFrame.origin always be (0,0), so we can't depending on the origin point.
    NSRect candidateFrame = [sharedCandidates candidateFrame];

    // line-box of current input text: (width:1, height:17)
    NSRect lineRect;
    [_currentClient attributesForCharacterIndex:0 lineHeightRectangle:&lineRect];
    NSPoint cursorPoint = NSMakePoint(NSMinX(lineRect), NSMinY(lineRect));
    NSPoint positionPoint = NSMakePoint(NSMinX(lineRect), NSMinY(lineRect));
    positionPoint.x = positionPoint.x + candidateFrame.size.width;
    NSScreen *currentScreen = [NSScreen currentScreenForMouseLocation];
    NSPoint currentPoint = [currentScreen convertPointToScreenCoordinates:cursorPoint];
    NSRect rect = currentScreen.frame;
    int screenWidth = (int)rect.size.width;
    int marginToCandidateFrame = 20;
    int annotationWindowWidth = _annotationWin.width + marginToCandidateFrame;
    int lineHeight = lineRect.size.height; // 17px

    if (screenWidth - currentPoint.x >= candidateFrame.size.width) {
        // safe distance to display candidateFrame at current cursor's left-side.
        if (screenWidth - currentPoint.x < candidateFrame.size.width + annotationWindowWidth) {
            positionPoint.x = positionPoint.x - candidateFrame.size.width - annotationWindowWidth;
        }
    } else {
        // assume candidateFrame will display at current cursor's right-side.
        positionPoint.x = screenWidth - candidateFrame.size.width - annotationWindowWidth;
    }
    if (currentPoint.y >= candidateFrame.size.height) {
        positionPoint.y = positionPoint.y - 8; // Both 8 and 3 are magic numbers to adjust the position
    } else {
        positionPoint.y = positionPoint.y + candidateFrame.size.height + lineHeight + 3;
    }

    return positionPoint;
}

#pragma mark - 英语延迟模式相关方法

- (void)updateEnglishCandidates {
    NSLog(@"[HallelujahIM] updateEnglishCandidates: 当前模式=%@", 
          _currentMode == InputModeEnglishDelay ? @"延迟模式" : @"其他模式");
    
    if (_currentMode == InputModeEnglishDelay) {
        // 英语延迟模式：使用最后一个单词进行候选词匹配
        NSString *buffer = [self originalBuffer];
        NSString *lastWord = [self getLastWordFromBuffer:buffer];
        NSLog(@"[HallelujahIM] updateEnglishCandidates: 完整缓冲='%@', 最后单词='%@'", 
              buffer ?: @"(空)", lastWord ?: @"(空)");
        
        if (lastWord && lastWord.length > 0) {
            NSArray *candidateList = [engine getCandidates:lastWord];
            NSLog(@"[HallelujahIM] updateEnglishCandidates: 为'%@'找到%lu个候选词", 
                  lastWord, (unsigned long)candidateList.count);
            if (candidateList.count > 0) {
                NSLog(@"[HallelujahIM] updateEnglishCandidates: 前3个候选词=%@", 
                      [candidateList subarrayWithRange:NSMakeRange(0, MIN(3, candidateList.count))]);
            }
            _candidates = [NSMutableArray arrayWithArray:candidateList];
            [sharedCandidates setCandidateData:candidateList];
        } else {
            NSLog(@"[HallelujahIM] updateEnglishCandidates: 最后单词为空，清空候选词");
            _candidates = [[NSMutableArray alloc] init];
            [sharedCandidates setCandidateData:@[]];
        }
    } else {
        // 其他模式：使用完整输入进行候选词匹配
        NSLog(@"[HallelujahIM] updateEnglishCandidates: 使用标准候选词更新");
        [sharedCandidates updateCandidates];
    }
}

- (NSString *)getLastWordFromBuffer:(NSString *)buffer {
    if (!buffer || buffer.length == 0) {
        NSLog(@"[HallelujahIM] getLastWordFromBuffer: 输入buffer为空");
        return @"";
    }
    
    NSLog(@"[HallelujahIM] getLastWordFromBuffer: 输入buffer='%@'", buffer);
    
    // 获取最后一个空格之后的文本
    NSRange lastSpaceRange = [buffer rangeOfString:@" " options:NSBackwardsSearch];
    NSString *lastWord;
    if (lastSpaceRange.location != NSNotFound) {
        lastWord = [buffer substringFromIndex:lastSpaceRange.location + 1];
        NSLog(@"[HallelujahIM] getLastWordFromBuffer: 找到空格在位置%lu, 最后单词='%@'", 
              (unsigned long)lastSpaceRange.location, lastWord);
    } else {
        lastWord = buffer; // 如果没有空格，返回整个缓冲区
        NSLog(@"[HallelujahIM] getLastWordFromBuffer: 未找到空格, 返回整个buffer='%@'", lastWord);
    }
    return lastWord;
}

- (void)replaceLastWordWith:(NSString *)candidate {
    NSString *buffer = [self originalBuffer];
    NSLog(@"[HallelujahIM] replaceLastWordWith: 候选词='%@', 当前buffer='%@'", 
          candidate, buffer ?: @"(空)");
    
    if (!buffer || buffer.length == 0) {
        NSLog(@"[HallelujahIM] replaceLastWordWith: buffer为空，直接设置候选词");
        [self setOriginalBuffer:candidate];
        [self setComposedBuffer:candidate];
        [self showPreeditString:candidate];
        return;
    }
    
    // 找到最后一个空格的位置
    NSRange lastSpaceRange = [buffer rangeOfString:@" " options:NSBackwardsSearch];
    NSString *newBuffer;
    if (lastSpaceRange.location != NSNotFound) {
        // 有空格，替换最后一个单词
        NSString *prefix = [buffer substringToIndex:lastSpaceRange.location + 1];
        newBuffer = [prefix stringByAppendingString:candidate];
        NSLog(@"[HallelujahIM] replaceLastWordWith: 找到空格，前缀='%@', 新buffer='%@'", 
              prefix, newBuffer);
    } else {
        // 没有空格，替换整个缓冲区
        newBuffer = candidate;
        NSLog(@"[HallelujahIM] replaceLastWordWith: 未找到空格，替换整个buffer='%@'", newBuffer);
    }
    
    [self setOriginalBuffer:newBuffer];
    [self setComposedBuffer:newBuffer];
    
    // 更新显示
    [self showPreeditString:newBuffer];
    NSLog(@"[HallelujahIM] replaceLastWordWith: 完成替换，最终buffer='%@'", [self originalBuffer]);
}

- (NSString *)processEnglishText:(NSString *)input {
    NSLog(@"[HallelujahIM] processEnglishText: 开始处理文本='%@'", input ?: @"(空)");
    
    if (!input || input.length == 0) {
        NSLog(@"[HallelujahIM] processEnglishText: 输入为空，直接返回");
        return input;
    }
    
    // 基础的文本处理：去除多余空格，首字母大写等
    NSString *processedText = [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSLog(@"[HallelujahIM] processEnglishText: 去除首尾空格后='%@'", processedText);
    
    // 去除连续的空格
    NSString *beforeSpaceCleanup = processedText;
    while ([processedText containsString:@"  "]) {
        processedText = [processedText stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    if (![beforeSpaceCleanup isEqualToString:processedText]) {
        NSLog(@"[HallelujahIM] processEnglishText: 清理连续空格后='%@'", processedText);
    }
    
    // TODO: 在这里可以集成更复杂的处理逻辑
    // 1. 拼写检查
    // 2. 语法纠错
    // 3. 翻译功能
    // 4. 智能优化
    
    NSLog(@"[HallelujahIM] processEnglishText: 处理完成，结果='%@'", processedText);
    return processedText;
}

@end
