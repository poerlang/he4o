//
//  AIAlgNodeManager.h
//  SMG_NothingIsAll
//
//  Created by jia on 2018/12/14.
//  Copyright © 2018年 XiaoGang. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AIAbsAlgNode;
@interface AIAlgNodeManager : NSObject

/**
 *  MARK:--------------------构建抽象概念_防重版--------------------
 *  @result notnull
 */
+(AIAbsAlgNode*)createAbsAlg_NoRepeat:(NSArray*)value_ps conAlgs:(NSArray*)conAlgs isMem:(BOOL)isMem at:(NSString*)at ds:(NSString*)ds isOutBlock:(BOOL(^)())isOutBlock type:(AnalogyType)type;

@end
