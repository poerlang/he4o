//
//  TCSolution.h
//  SMG_NothingIsAll
//
//  Created by jia on 2021/11/28.
//  Copyright © 2021年 XiaoGang. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  MARK:--------------------解决方案--------------------
 *  @注意:
 *      1. 取解决方案-不得脱离场景;
 *      2. 行为化过程-不得脱离场景;
 */
@interface TCSolution : NSObject

+(void) solution:(TOModelBase*)endBranch endScore:(double)endScore;
+(void) rSolution:(ReasonDemandModel*)demand;
+(void) pSolution:(DemandModel*)demandModel;
+(void) hSolution:(HDemandModel*)hDemand;

@end
