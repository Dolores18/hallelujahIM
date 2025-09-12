#import <Foundation/Foundation.h>

@interface TextProcessor : NSObject

/**
 * 处理英语文本：去除多余空格，进行基础清理
 * @param input 输入的原始文本
 * @return 处理后的文本
 */
+ (NSString *)processEnglishText:(NSString *)input;

/**
 * 清理文本中的连续空格
 * @param input 输入文本
 * @return 清理后的文本
 */
+ (NSString *)cleanupSpaces:(NSString *)input;

/**
 * 去除文本首尾空格和换行符
 * @param input 输入文本
 * @return 清理后的文本
 */
+ (NSString *)trimWhitespace:(NSString *)input;

/**
 * 通过远程API进行文本处理（拼写检查、语法纠错等）
 * @param input 输入文本
 * @return 处理后的文本
 */
+ (NSString *)processWithRemoteAPI:(NSString *)input;

@end
