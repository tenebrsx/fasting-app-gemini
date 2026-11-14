#import "ObjCExceptionCatcher.h"

@implementation ObjCExceptionCatcher

+ (BOOL)catchException:(void (NS_NOESCAPE ^)(void))block error:(NSError * _Nullable * _Nullable)error {
    @try {
        block();
        return YES;
    } @catch (NSException *exception) {
        if (error) {
            NSString *message = exception.reason ?: exception.name;
            *error = [NSError errorWithDomain:@"com.tenebrsx.fast.objc"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: message}];
        }
        return NO;
    }
}

@end
