#import "WebServer.h"
#import "GCDWebServer.h"
#import "GCDWebServerDataResponse.h"
#import "GCDWebServerURLEncodedFormRequest.h"

extern NSUserDefaults *preference;

NSString *TRANSLATION_KEY = @"showTranslation";
NSString *COMMIT_WORD_WITH_SPACE_KEY = @"commitWordWithSpace";
NSString *TEXT_PROCESSOR_API_URL_KEY = @"textProcessorApiUrl";
NSString *TEXT_PROCESSOR_TIMEOUT_KEY = @"textProcessorTimeout";


@interface WebServer ()

@property(nonatomic, strong) GCDWebServer *server;

@end

@implementation WebServer

static int port = 62718;

+ (instancetype)sharedServer {
    static WebServer *server = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        server = [[WebServer alloc] init];
    });
    return server;
}

- (void)start {
    if (self.server) {
        return;
    }

    GCDWebServer *webServer = [[GCDWebServer alloc] init];
    [webServer addGETHandlerForBasePath:@"/"
                          directoryPath:[NSString stringWithFormat:@"%@/%@", [NSBundle mainBundle].resourcePath, @"web"]
                          indexFilename:nil
                               cacheAge:3600
                     allowRangeRequests:YES];

    [webServer addHandlerForMethod:@"GET"
                              path:@"/preference"
                      requestClass:[GCDWebServerRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
                          return [GCDWebServerDataResponse responseWithJSONObject:
                                  @{
                                    TRANSLATION_KEY : @([preference boolForKey:TRANSLATION_KEY]),
                                    COMMIT_WORD_WITH_SPACE_KEY : @([preference boolForKey:COMMIT_WORD_WITH_SPACE_KEY]),
                                    TEXT_PROCESSOR_API_URL_KEY : [preference stringForKey:TEXT_PROCESSOR_API_URL_KEY] ?: @"http://localhost:3000/edit",
                                    TEXT_PROCESSOR_TIMEOUT_KEY : @([preference integerForKey:TEXT_PROCESSOR_TIMEOUT_KEY])
                                   }
                                 ];
                      }];

    [webServer addHandlerForMethod:@"POST"
                              path:@"/preference"
                      requestClass:[GCDWebServerURLEncodedFormRequest class]
                      processBlock:^GCDWebServerResponse *(GCDWebServerRequest *request) {
                          NSDictionary *data = ((GCDWebServerDataRequest *)request).jsonObject;

                          bool showTranslation = [data[TRANSLATION_KEY] boolValue];
                          [preference setBool:showTranslation forKey:TRANSLATION_KEY];

                          bool commitWordWithSpace = [data[COMMIT_WORD_WITH_SPACE_KEY] boolValue];
                          [preference setBool:commitWordWithSpace forKey:COMMIT_WORD_WITH_SPACE_KEY];

                          NSString *apiUrl = data[TEXT_PROCESSOR_API_URL_KEY];
                          if (apiUrl && apiUrl.length > 0) {
                              [preference setObject:apiUrl forKey:TEXT_PROCESSOR_API_URL_KEY];
                          }

                          NSNumber *timeout = data[TEXT_PROCESSOR_TIMEOUT_KEY];
                          if (timeout && [timeout integerValue] > 0) {
                              [preference setInteger:[timeout integerValue] forKey:TEXT_PROCESSOR_TIMEOUT_KEY];
                          }

                          return [GCDWebServerDataResponse responseWithJSONObject:data];
                      }];

    NSMutableDictionary *options = [NSMutableDictionary dictionary];
    options[GCDWebServerOption_Port] = @(port);
    options[GCDWebServerOption_BindToLocalhost] = @YES;

    [webServer startWithOptions:options error:nil];
}

@end
