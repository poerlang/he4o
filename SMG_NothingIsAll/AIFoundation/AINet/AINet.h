//
//  AINet.h
//  SMG_NothingIsAll
//
//  Created by 贾  on 2017/9/17.
//  Copyright © 2017年 XiaoGang. All rights reserved.
//

#import <Foundation/Foundation.h>

/**
 *  MARK:--------------------AINet面板--------------------
 *  @desc 整理各种网络操作的总入口,供系统别处调用;
 *  @关联强度
 *      1. 方向索引: setMvNodeToDirectionReference:difStrong:
 */
@class AIImvAlgsModel,AIPointer,AIKVPointer,AIPort,AIFrontOrderNode,AINetAbsFoNode,AIAbsCMVNode,AIAlgNode,AIAbsAlgNode,AIAlgNodeBase,AICMVNode;
@interface AINet : NSObject

+(AINet*) sharedInstance;

//MARK:===============================================================
//MARK:                     < index >
//MARK:===============================================================

/**
 *  MARK:--------------------算法模型的装箱--------------------
 *  转为指针数组(每个值都是指针)(在dataIn后第一件事就是装箱)
 *  @result notnull
 */
-(NSMutableArray*) algModelConvert2Pointers:(NSDictionary*)modelDic algsType:(NSString*)algsType;
-(AIKVPointer*) getNetDataPointerWithData:(NSNumber*)data algsType:(NSString*)algsType dataSource:(NSString*)dataSource isOut:(BOOL)isOut;//单data装箱


//MARK:===============================================================
//MARK:                     < reference >
//MARK:===============================================================

/**
 *  MARK:--------------------引用序列--------------------
 *  @param indexPointer : value地址
 *  @param target_p : 引用者地址(如:xxNode.pointer)
 *
 *  注:
 *  1. 暂不支持output;
 *  2. 由AINetUtils.insertRefPorts_AllMvNode()取代
 */
//-(void) setNetReference:(AIKVPointer*)value_p target_p:(AIKVPointer*)target_p difValue:(int)difValue;

//获取算法单结果的第二序列联想;
//-(NSArray*) getNetReference:(AIKVPointer*)pointer limit:(NSInteger)limit;


//MARK:===============================================================
//MARK:                     < cmv >
//MARK:===============================================================
-(AIFrontOrderNode*) createCMV:(NSArray*)imvAlgsArr inputTime:(NSTimeInterval)inputTime order:(NSArray*)order;
-(AICMVNode*) createConMv:(NSArray*)imvAlgsArr;
-(AICMVNode*) createConMv:(AIKVPointer*)urgentTo_p delta_p:(AIKVPointer*)delta_p at:(NSString*)at isMem:(BOOL)isMem;


//MARK:===============================================================
//MARK:                     < conFo >
//MARK:===============================================================
-(AIFrontOrderNode*) createConFo:(NSArray*)order isMem:(BOOL)isMem;


//MARK:===============================================================
//MARK:                     < absFo >
//MARK:===============================================================
//-(AINetAbsFoNode*) createAbsFo_General:(NSArray*)conFos content_ps:(NSArray*)content_ps difStrong:(NSInteger)difStrong ds:(NSString*)ds;
-(AINetAbsFoNode*) createAbsFo_NoRepeat:(NSArray*)conFos content_ps:(NSArray*)content_ps difStrong:(NSInteger)difStrong at:(NSString*)at ds:(NSString*)ds type:(AnalogyType)type;

//MARK:===============================================================
//MARK:                     < directionReference >
//MARK:===============================================================
-(NSArray*) getNetNodePointersFromDirectionReference:(NSString*)mvAlgsType direction:(MVDirection)direction isMem:(BOOL)isMem limit:(int)limit;
-(NSArray*) getNetNodePointersFromDirectionReference:(NSString*)mvAlgsType direction:(MVDirection)direction isMem:(BOOL)isMem filter:(NSArray*(^)(NSArray *protoArr))filter;

/**
 *  MARK:--------------------mvNode的方向索引--------------------
 *  @param difStrong    : mv的迫切度越高,越强;
 *  @param cmvNode      : cmvNode有可能还在create阶段,未存硬盘,所以不能传指针进来;
 *  @desc 加强关联强度;
 */
-(void) setMvNodeToDirectionReference:(AICMVNodeBase*)cmvNode difStrong:(NSInteger)difStrong;


//MARK:===============================================================
//MARK:                     < AINetOutputIndex >
//MARK:===============================================================

//小脑索引
-(AIKVPointer*) getOutputIndex:(NSString*)algsType outputObj:(NSNumber*)outputObj;


//MARK:===============================================================
//MARK:                     < absCmv >
//MARK:===============================================================
-(AIAbsCMVNode*) createAbsCMVNode_Outside:(AIKVPointer*)absFo_p aMv_p:(AIKVPointer*)aMv_p bMv_p:(AIKVPointer*)bMv_p;
-(AIAbsCMVNode*) createAbsMv:(AIKVPointer*)absFo_p conMvs:(NSArray*)conMvs at:(NSString*)at ds:(NSString*)ds urgentTo_p:(AIKVPointer*)urgentTo_p delta_p:(AIKVPointer*)delta_p;


//MARK:===============================================================
//MARK:                     < algNode >
//MARK:===============================================================

/**
 *  MARK:--------------------构建抽象概念_防重--------------------
 *  @desc 要做到全局防重,所以废弃具象AIAlgNode,只使用AIAbsAlgNode;
 */
-(AIAbsAlgNode*)createAbsAlg_NoRepeat:(NSArray*)value_ps conAlgs:(NSArray*)conAlgs isMem:(BOOL)isMem at:(NSString*)at type:(AnalogyType)type;
-(AIAbsAlgNode*)createAbsAlg_NoRepeat:(NSArray*)value_ps conAlgs:(NSArray*)conAlgs isMem:(BOOL)isMem at:(NSString*)at ds:(NSString*)ds type:(AnalogyType)type;
-(AIAbsAlgNode*)createAbsAlg_NoRepeat:(NSArray*)value_ps conAlgs:(NSArray*)conAlgs isMem:(BOOL)isMem isOut:(BOOL)isOut at:(NSString*)at type:(AnalogyType)type;
-(AIAbsAlgNode*)createAbsAlg_NoRepeat:(NSArray*)value_ps conAlgs:(NSArray*)conAlgs isMem:(BOOL)isMem isOut:(BOOL)isOut at:(NSString*)at ds:(NSString*)ds type:(AnalogyType)type;

@end
