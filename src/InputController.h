#import <Cocoa/Cocoa.h>
#import <InputMethodKit/InputMethodKit.h>

#import "AnnotationWinController.h"
#import "ConversionEngine.h"
#import "util/TextProcessor.h"

typedef enum {
    InputModeIntelligent,    // 智能模式（当前）
    InputModeEnglishDirect,  // 纯英文模式（当前）
    InputModeEnglishDelay   // 英语延迟模式（新增）
} InputMode;

@interface InputController : IMKInputController {
    NSMutableString *_composedBuffer;
    NSMutableString *_originalBuffer;
    NSInteger _insertionIndex;
    NSInteger _currentCandidateIndex;
    NSMutableArray *_candidates;
    BOOL _defaultEnglishMode;
    InputMode _currentMode;
    id _currentClient;
    NSUInteger _lastModifiers[2];
    NSEventType _lastEventTypes[2];
    AnnotationWinController *_annotationWin;
}

- (NSMutableString *)composedBuffer;
- (void)setComposedBuffer:(NSString *)string;
- (NSMutableString *)originalBuffer;
- (void)originalBufferAppend:(NSString *)string client:(id)sender;
- (void)setOriginalBuffer:(NSString *)string;

// 英语延迟模式相关方法
- (void)updateEnglishCandidates;
- (NSString *)getLastWordFromBuffer:(NSString *)buffer;
- (void)replaceLastWordWith:(NSString *)candidate;

// 缓冲区显示相关方法
- (void)showBufferDisplayIfNeeded;
- (void)updateBufferDisplayContent;
- (void)hideBufferDisplayIfNeeded;
- (NSPoint)calculateBufferDisplayPosition;

// 组合显示相关方法（缓冲区 + 翻译）
- (void)showBufferWithTranslation:(NSAttributedString *)candidateString;
- (void)updateBufferDisplayContentWithTranslation:(NSString *)translation;

@end
