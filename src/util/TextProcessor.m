#import "TextProcessor.h"

extern NSUserDefaults *preference;

@implementation TextProcessor

+ (NSString *)processEnglishText:(NSString *)input {
    NSLog(@"[HallelujahIM] TextProcessor: 开始处理文本='%@'", input ?: @"(空)");
    
    if (!input || input.length == 0) {
        NSLog(@"[HallelujahIM] TextProcessor: 输入为空，直接返回");
        return input;
    }
    
    // 基础的文本处理：去除多余空格，首字母大写等
    NSString *processedText = [self trimWhitespace:input];
    NSLog(@"[HallelujahIM] TextProcessor: 去除首尾空格后='%@'", processedText);
    
    // 去除连续的空格
    processedText = [self cleanupSpaces:processedText];
    NSLog(@"[HallelujahIM] TextProcessor: 清理连续空格后='%@'", processedText);
    
    // 集成更复杂的处理逻辑
    processedText = [self processWithRemoteAPI:processedText];
    
    NSLog(@"[HallelujahIM] TextProcessor: 处理完成，结果='%@'", processedText);
    return processedText;
}

+ (NSString *)cleanupSpaces:(NSString *)input {
    if (!input || input.length == 0) {
        return input;
    }
    
    NSString *result = input;
    NSString *beforeCleanup = result;
    
    // 去除连续的空格
    while ([result containsString:@"  "]) {
        result = [result stringByReplacingOccurrencesOfString:@"  " withString:@" "];
    }
    
    if (![beforeCleanup isEqualToString:result]) {
        NSLog(@"[HallelujahIM] TextProcessor: 清理连续空格 '%@' -> '%@'", beforeCleanup, result);
    }
    
    return result;
}

+ (NSString *)trimWhitespace:(NSString *)input {
    if (!input || input.length == 0) {
        return input;
    }
    
    return [input stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

+ (NSString *)processWithRemoteAPI:(NSString *)input {
    if (!input || input.length == 0) {
        return input;
    }
    
    NSLog(@"[HallelujahIM] TextProcessor: 开始远程API处理='%@'", input);
    
    // 从preference获取API URL
    NSString *apiUrlString = [preference stringForKey:@"textProcessorApiUrl"];
    if (!apiUrlString || apiUrlString.length == 0) {
        apiUrlString = @"http://localhost:3000/edit"; // 默认值
    }
    
    NSLog(@"[HallelujahIM] TextProcessor: 使用API URL='%@'", apiUrlString);
    NSURL *url = [NSURL URLWithString:apiUrlString];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // 创建请求体
    NSDictionary *requestData = @{@"text": input};
    NSError *jsonError;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:requestData 
                                                       options:0 
                                                         error:&jsonError];
    
    if (jsonError) {
        NSLog(@"[HallelujahIM] TextProcessor: JSON序列化失败: %@", jsonError.localizedDescription);
        return input; // 失败时返回原文本
    }
    
    [request setHTTPBody:jsonData];
    
    // 创建信号量实现同步请求
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    __block NSString *result = input; // 默认返回原文本
    
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request 
                                                                 completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSLog(@"[HallelujahIM] TextProcessor: 网络请求失败: %@", error.localizedDescription);
        } else if (data) {
            NSError *parseError;
            NSDictionary *responseDict = [NSJSONSerialization JSONObjectWithData:data 
                                                                         options:0 
                                                                           error:&parseError];
            
            if (parseError) {
                NSLog(@"[HallelujahIM] TextProcessor: 响应解析失败: %@", parseError.localizedDescription);
            } else {
                // 解析响应数据
                NSDictionary *dataDict = responseDict[@"data"];
                NSString *correctedText = dataDict[@"corrected"];
                
                if (correctedText && correctedText.length > 0) {
                    result = correctedText;
                    NSLog(@"[HallelujahIM] TextProcessor: API处理成功 '%@' -> '%@'", input, result);
                } else {
                    NSLog(@"[HallelujahIM] TextProcessor: API返回的corrected字段为空");
                }
            }
        }
        
        dispatch_semaphore_signal(semaphore);
    }];
    
    [task resume];
    
    // 从preference获取超时时间
    NSInteger timeoutSeconds = [preference integerForKey:@"textProcessorTimeout"];
    if (timeoutSeconds <= 0) {
        timeoutSeconds = 10; // 默认10秒
    }
    NSLog(@"[HallelujahIM] TextProcessor: 使用超时时间=%ld秒", (long)timeoutSeconds);
    
    // 等待请求完成
    dispatch_time_t timeout = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeoutSeconds * NSEC_PER_SEC));
    if (dispatch_semaphore_wait(semaphore, timeout) != 0) {
        NSLog(@"[HallelujahIM] TextProcessor: API请求超时");
        [task cancel];
    }
    
    return result;
}

@end
