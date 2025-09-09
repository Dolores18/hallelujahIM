#import "AnnotationWinController.h"

static AnnotationWinController *sharedController;

@interface AnnotationWinController ()
@property(retain, nonatomic) IBOutlet NSPanel *panel;
@property(retain, nonatomic) IBOutlet NSTextField *view;
@end

@implementation AnnotationWinController
@synthesize view;
@synthesize panel;

+ (AnnotationWinController*)sharedController {
    return sharedController;
}

- (void)awakeFromNib {
    sharedController = self;
    self.width = 160;
    // self.height = 282;
    self.annotationMode = AnnotationModeTranslation; // 默认翻译模式

    [self.panel orderFront:nil];
    (self.panel).level = CGShieldingWindowLevel() + 1;
    // Make sure panel can float over full screen apps
    //  self.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces;
    (self.panel).styleMask = NSWindowStyleMaskBorderless;
    [self performSelector:@selector(hideWindow) withObject:nil afterDelay:0.01];
    // [self showWindow:NSMakePoint(10, self.height + 10)]; //for dev debug
    
    NSLog(@"[HallelujahIM] AnnotationWinController: awakeFromNib 完成初始化");
}

- (void)showWindow:(NSPoint)origin {
    [self.panel setFrameTopLeftPoint:origin];
    self.panel.alphaValue = 1.0;
    self.panel.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces;
    
    if (self.annotationMode == AnnotationModeBuffer) {
        NSLog(@"[HallelujahIM] AnnotationWinController: showWindow in Buffer mode at (%.1f, %.1f)", 
              origin.x, origin.y);
    }
}

- (void)hideWindow {
    self.panel.alphaValue = 0;
    self.panel.collectionBehavior = NSWindowCollectionBehaviorMoveToActiveSpace;
    
    if (self.annotationMode == AnnotationModeBuffer) {
        NSLog(@"[HallelujahIM] AnnotationWinController: hideWindow in Buffer mode");
        // 恢复翻译模式的样式
        self.view.textColor = [NSColor labelColor];
        self.view.backgroundColor = [NSColor textBackgroundColor];
    }
}

- (void)setAnnotation:(NSString *)annotation {
    (self.view).stringValue = annotation;
}

#pragma mark - 缓冲区显示功能

- (void)showBufferDisplay:(NSString *)bufferText atPoint:(NSPoint)origin {
    NSLog(@"[HallelujahIM] AnnotationWinController: showBufferDisplay='%@' at point(%.1f, %.1f)", 
          bufferText, origin.x, origin.y);
    
    self.annotationMode = AnnotationModeBuffer;
    [self setBufferText:bufferText];
    [self configureForBufferDisplay];
    [self showWindow:origin];
}

- (void)updateBufferDisplay:(NSString *)bufferText {
    if (self.annotationMode == AnnotationModeBuffer) {
        NSLog(@"[HallelujahIM] AnnotationWinController: updateBufferDisplay='%@'", bufferText);
        [self setBufferText:bufferText];
        [self resizeForContent:bufferText];
    }
}

- (void)hideBufferDisplay {
    if (self.annotationMode == AnnotationModeBuffer) {
        NSLog(@"[HallelujahIM] AnnotationWinController: hideBufferDisplay");
        [self hideWindow];
        self.annotationMode = AnnotationModeTranslation; // 恢复默认模式
    }
}

- (void)setBufferText:(NSString *)bufferText {
    if (!bufferText) {
        bufferText = @"";
    }
    
    // 为缓冲区文本添加视觉提示
    NSString *displayText = [NSString stringWithFormat:@"📝 %@", bufferText];
    if (bufferText.length == 0) {
        displayText = @"📝 (输入中...)";
    }
    
    (self.view).stringValue = displayText;
    NSLog(@"[HallelujahIM] AnnotationWinController: setBufferText='%@' -> display='%@'", 
          bufferText, displayText);
}

- (void)configureForBufferDisplay {
    // 配置缓冲区显示的样式
    self.view.textColor = [NSColor systemBlueColor]; // 蓝色文本表示缓冲区模式
    self.view.backgroundColor = [NSColor controlBackgroundColor];
    
    // 设置不同的窗口大小用于缓冲区显示
    NSRect currentFrame = self.panel.frame;
    NSRect newFrame = NSMakeRect(currentFrame.origin.x, currentFrame.origin.y, 
                                self.width + 40, 50); // 更宽一些，高度较小
    [self.panel setFrame:newFrame display:YES];
    
    NSLog(@"[HallelujahIM] AnnotationWinController: configureForBufferDisplay 完成");
}

- (void)resizeForContent:(NSString *)content {
    if (!content || content.length == 0) return;
    
    // 检查是否包含分隔线（组合显示模式）
    BOOL isCombinedDisplay = [content containsString:@"─────────"];
    
    // 根据内容长度动态调整窗口大小
    CGFloat estimatedWidth = content.length * 8 + 80; // 大概估算
    CGFloat maxWidth = 400; // 最大宽度
    CGFloat minWidth = 120; // 最小宽度
    
    CGFloat finalWidth = MIN(MAX(estimatedWidth, minWidth), maxWidth);
    
    // 组合显示时需要更高的窗口
    CGFloat windowHeight = isCombinedDisplay ? 80 : 50;
    
    NSRect currentFrame = self.panel.frame;
    NSRect newFrame = NSMakeRect(currentFrame.origin.x, currentFrame.origin.y, 
                                finalWidth, windowHeight);
    [self.panel setFrame:newFrame display:YES animate:NO];
    
    NSLog(@"[HallelujahIM] AnnotationWinController: resizeForContent length=%lu, width=%.1f, height=%.1f, combined=%@", 
          (unsigned long)content.length, finalWidth, windowHeight, isCombinedDisplay ? @"YES" : @"NO");
}

#pragma mark - 组合显示功能（缓冲区 + 翻译）

- (void)showBufferDisplayWithTranslation:(NSString *)bufferText 
                             translation:(NSString *)translation 
                                 atPoint:(NSPoint)origin {
    NSLog(@"[HallelujahIM] AnnotationWinController: showBufferDisplayWithTranslation buffer='%@', translation='%@' at (%.1f, %.1f)", 
          bufferText, translation, origin.x, origin.y);
    
    self.annotationMode = AnnotationModeBuffer;
    [self setBufferTextWithTranslation:bufferText translation:translation];
    [self configureForBufferDisplay];
    [self showWindow:origin];
}

- (void)updateBufferDisplayWithTranslation:(NSString *)bufferText 
                               translation:(NSString *)translation {
    if (self.annotationMode == AnnotationModeBuffer) {
        NSLog(@"[HallelujahIM] AnnotationWinController: updateBufferDisplayWithTranslation buffer='%@', translation='%@'", 
              bufferText, translation);
        [self setBufferTextWithTranslation:bufferText translation:translation];
    }
}

- (void)setBufferTextWithTranslation:(NSString *)bufferText translation:(NSString *)translation {
    if (!bufferText) {
        bufferText = @"";
    }
    
    NSString *displayText;
    
    if (translation && translation.length > 0) {
        // 组合显示：缓冲区 + 翻译
        displayText = [NSString stringWithFormat:@"📝 %@\n─────────────\n🔤 %@", 
                      bufferText.length > 0 ? bufferText : @"(输入中...)", translation];
        NSLog(@"[HallelujahIM] AnnotationWinController: setBufferTextWithTranslation 组合模式");
    } else {
        // 仅缓冲区
        displayText = [NSString stringWithFormat:@"📝 %@", 
                      bufferText.length > 0 ? bufferText : @"(输入中...)"];
        NSLog(@"[HallelujahIM] AnnotationWinController: setBufferTextWithTranslation 纯缓冲区模式");
    }
    
    (self.view).stringValue = displayText;
    [self resizeForContent:displayText];
    
    NSLog(@"[HallelujahIM] AnnotationWinController: setBufferTextWithTranslation 完成，显示文本='%@'", displayText);
}

@end

