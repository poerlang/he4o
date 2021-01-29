//
//  NSLog+Extension.h
//  SMG_NothingIsAll
//
//  Created by jia on 2020/9/21.
//  Copyright © 2020年 XiaoGang. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSLog_Extension : NSObject

+(NSString*) convertTOStatus2Desc:(TOModelStatus)status;
+(NSString*) convertATType2Desc:(AnalogyType)atType;
+(NSString*) convertTIStatus2Desc:(TIModelStatus)status;
+(NSString*) convertClass2Desc:(Class)clazz;

@end
