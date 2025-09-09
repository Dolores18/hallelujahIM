#import <Cocoa/Cocoa.h>

typedef enum {
    AnnotationModeTranslation,  // 翻译模式（原有功能）
    AnnotationModeBuffer       // 缓冲区显示模式（新增功能）
} AnnotationMode;

@interface AnnotationWinController : NSWindowController {
}

@property int width;
@property int height;
@property (nonatomic, assign) AnnotationMode annotationMode;

- (void)showWindow:(NSPoint)origin;

- (void)hideWindow;

- (void)setAnnotation:(NSString *)annotation;

// 新增：缓冲区显示相关方法
- (void)showBufferDisplay:(NSString *)bufferText atPoint:(NSPoint)origin;
- (void)updateBufferDisplay:(NSString *)bufferText;
- (void)hideBufferDisplay;
- (void)setBufferText:(NSString *)bufferText;

// 新增：组合显示方法（缓冲区 + 翻译）
- (void)showBufferDisplayWithTranslation:(NSString *)bufferText 
                             translation:(NSString *)translation 
                                 atPoint:(NSPoint)origin;
- (void)updateBufferDisplayWithTranslation:(NSString *)bufferText 
                               translation:(NSString *)translation;
- (void)setBufferTextWithTranslation:(NSString *)bufferText 
                         translation:(NSString *)translation;

+ (AnnotationWinController*)sharedController;

@end
