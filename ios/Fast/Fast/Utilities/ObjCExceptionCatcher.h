#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ObjCExceptionCatcher : NSObject

+ (BOOL)catchException:(void (NS_NOESCAPE ^)(void))block error:(NSError * _Nullable * _Nullable)error NS_SWIFT_NAME(perform(_:));

@end

NS_ASSUME_NONNULL_END
