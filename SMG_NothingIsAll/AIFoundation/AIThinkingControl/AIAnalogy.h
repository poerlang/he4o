//
//  AIAnalogy.h
//  SMG_NothingIsAll
//
//  Created by jia on 2019/3/20.
//  Copyright © 2019年 XiaoGang. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  MARK:--------------------类比器--------------------
 *  @desc
 *      1. 外类比 (复用方法)
 *      2. 内类比 (主入口)
 *      3. 反馈类比 (主入口)
 *      4. 反省类比 (主入口)
 *  @callers
 *      1. InReasonSame: 调用内类比
 *      2. InPerceptSame: 调用正向反馈外类比
 *      3. InPerceptDiff: 调用反向反馈外类比
 *      4. InReasonDiff: 调用InRethink类比
 *      5. Out三种ActYes: 调用OutRethink类比
 *  @version
 *      2021.12.26: 仅留下外类比,其它全废弃删掉 (参考Note24-TC新螺旋架构整理);
 */
@interface AIAnalogy : NSObject

//MARK:===============================================================
//MARK:                     < 外类比时序 >
//MARK:===============================================================
+(AINetAbsFoNode*) analogyOutside:(AIFoNodeBase*)fo assFo:(AIFoNodeBase*)assFo type:(AnalogyType)type createAbsAlgBlock:(void(^)(AIAlgNodeBase *createAlg,NSInteger foIndex,NSInteger assFoIndex))createAbsAlgBlock;

//MARK:===============================================================
//MARK:                     < 概念外类比 >
//MARK:===============================================================
+(AIAlgNodeBase*) analogyAlg:(AIAlgNodeBase*)algA algB:(AIAlgNodeBase*)algB;

@end
