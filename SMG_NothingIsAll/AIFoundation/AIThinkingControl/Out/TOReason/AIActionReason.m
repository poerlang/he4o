//
//  AIActionReason.m
//  SMG_NothingIsAll
//
//  Created by jia on 2021/11/11.
//  Copyright © 2021年 XiaoGang. All rights reserved.
//

#import "AIActionReason.h"
#import "ReasonDemandModel.h"
#import "AIMatchFoModel.h"
#import "AINetUtils.h"
#import "AIPort.h"
#import "TOFoModel.h"
#import "DemandManager.h"
#import "RSResultModelBase.h"
#import "AIThinkOut.h"
#import "AIThinkOutReason.h"
#import "TOAlgModel.h"

@implementation AIActionReason

//MARK:===============================================================
//MARK:                     < 功能架构 >
//MARK:===============================================================


/**
 *  MARK:--------------------solution--------------------
 *  @desc 参考24154-单轮;
 *  @version
 *      2021.11.13: 初版,废弃dsFo,并将reasonSubV5由TOR迁移至此RAction中 (参考24101-第3阶段);
 *      2021.11.25: 迭代为功能架构 (参考24154-单轮示图);
 *  @callers : 用于RDemand.Begin时调用;
 */
-(void) solution:(ReasonDemandModel*)demand{
    //1. 根据demand取抽具象路径rs;
    NSArray *rs = [theTC.outModelManager getRDemandsBySameClass:demand];
    
    //2. 不应期 (可以考虑改为将整个demand.actionFoModels全加入不应期) (源于:反思且子任务失败的 或 fo行为化最终失败的,参考24135);
    NSArray *exceptFoModels = [SMGUtils filterArr:demand.actionFoModels checkValid:^BOOL(TOModelBase *item) {
        return item.status == TOModelStatus_ActNo || item.status == TOModelStatus_ScoreNo;
    }];
    NSMutableArray *except_ps = [TOUtils convertPointersFromTOModels:exceptFoModels];
    [except_ps addObject:demand.mModel.matchFo.pointer];
    
    //3. 从具象出抽象,逐一取conPorts (前3条) (参考24127-步骤1);
    NSMutableArray *sumConPorts = [[NSMutableArray alloc] init];
    for (NSInteger i = 0; i < rs.count; i++) {
        ReasonDemandModel *baseDemand = ARR_INDEX_REVERSE(rs, i);
        NSArray *conPorts = [AINetUtils conPorts_All_Normal:baseDemand.mModel.matchFo];
        conPorts = ARR_SUB(conPorts, 0, 3);
        [sumConPorts addObjectsFromArray:conPorts];
    }
    
    //4. 对conPorts进行FRS稳定性竞争 (参考24127-步骤2);
    NSArray *frsResults = [AIScore FRS_PK:sumConPorts];
    
    //5. frsResults排除不应期;
    frsResults = [SMGUtils removeArr:frsResults checkValid:^BOOL(RSResultModelBase *item) {
        return [except_ps containsObject:item.baseFo.pointer];
    }];
    if (Log4DirecRef) NSLog(@"\n------- baseFo:%@ -------\n已有方案数:%ld 不应期数:%ld 还有方案数:%ld",Fo2FStr(demand.mModel.matchFo),demand.actionFoModels.count,except_ps.count,frsResults.count);
    
    //6. 转流程控制_有解决方案则转begin;
    RSResultModelBase *firstResult = ARR_INDEX(frsResults, 0);
    if (firstResult) {
        TOFoModel *foModel = [TOFoModel newWithFo_p:firstResult.baseFo.pointer base:demand];
        NSLog(@"------->>>>>> R- 新增一例解决方案: %@->%@ FRS_PK评分:%.2f",Fo2FStr(firstResult.baseFo),Mvp2Str(firstResult.baseFo.cmvNode_p),firstResult.score);
        [self outReflect:foModel];
    }else{
        //7. 转流程控制_无则转failure;
        demand.status = TOModelStatus_ActNo;
        [theTC.thinkOut.tOR singleLoopBackWithFailureModel:demand];
        
        //TODOTOMORROW20211125: 向base上一轮递归,
        
        
        
        NSLog(@"------->>>>>> R-无计可施");
    }
}

/**
 *  MARK:--------------------out反思--------------------
 *  @desc 解决方案fo即(加工目标),转_Fo()行为化 (参考24132-行为化1);
 *  @param foModel : notnull
 *  @version
 *      2021.11.17: 需调用者自行对foModel进行FRS稳定性竞争评价,本方法不再进行 (因为fo间的竞争,需由外界,fo内部问题在此方法内解决);
 *      2021.11.25: 迭代为功能架构 (参考24154-单轮示图);
 *  @callers : 可以供_Demand和_Hav等调用;
 */
-(void) outReflect:(TOFoModel*)foModel{
    //1. 数据准备
    AIFoNodeBase *curFo = [SMGUtils searchNode:foModel.content_p];
    OFTitleLog(@"行为化Fo", @"\n时序:%@->%@ 类型:(%@)",Fo2FStr(curFo),Mvp2Str(curFo.cmvNode_p),curFo.pointer.typeStr);
    BOOL isRDemand = ISOK(foModel.baseOrGroup, ReasonDemandModel.class);
    
    //2. 紧急状态判断 (当R模式在3s以内会触发-mv时,属于紧急状态) (参考24057-方案3);
    BOOL rIsTooLate = false;
    if (isRDemand) {
        ReasonDemandModel *rDemand = (ReasonDemandModel*)foModel.baseOrGroup;
        double deltaTime = [TOUtils getSumDeltaTime2Mv:rDemand.mModel.matchFo cutIndex:rDemand.mModel.cutIndex2];
        rIsTooLate = deltaTime < 30;
        NSLog(@"紧急状态 (%d) 预计-mv时间:%f",rIsTooLate,deltaTime);
    }
    
    //3. 对HNGL任务首帧执行前做评价;
    if (foModel.actionIndex == -1 && !rIsTooLate) {
        
        //4. MC反思: 回归tir反思,重新识别理性预测时序,预测价值; (预测到鸡蛋变脏,或者cpu损坏) (理性预测影响评价即理性评价)
        AIShortMatchModel *rtInModel = [theTC to_Rethink:foModel];
        
        //5. 提交子任务;
        __block NSArray *except_ps = nil;
        [DemandManager updateSubDemand:rtInModel baseFo:foModel createSubDemandBlock:^(ReasonDemandModel *subDemand) {
            
            //6. 子任务行为化;
            [self.delegate toAction_SubModelBegin:subDemand];
            //return;//子任务Finish/ActYes时,不return,因为要继续父任务;
        } finishBlock:^(NSArray *_except_ps) {
            except_ps = _except_ps;
        }];
        
        //8. 子任务尝试完成后,进行FPS综合评价 (如果子任务完成后,依然有解决不了的不愿意的价值,则不通过);
        BOOL scoreSuccess = [AIScore FPS:foModel rtInModel:rtInModel except_ps:except_ps];
        NSLog(@"未发生感性评价(反思)-%@",scoreSuccess ? @"通过 (继续父fo行为化)" : @"不通过 (中断父fo行为化)");
        if (!scoreSuccess) {
            foModel.status = TOModelStatus_ScoreNo;
            [self.delegate toAction_SubModelFailure:foModel];
            return;
        }
    }
    
    //4. 跳转下帧,
    if (foModel.actionIndex < curFo.count - 1) {
        //a. Alg转移 (下帧)
        foModel.actionIndex ++;
        AIKVPointer *move_p = ARR_INDEX(curFo.content_ps, foModel.actionIndex);
        TOAlgModel *moveAlg = [TOAlgModel newWithAlg_p:move_p group:foModel];
        NSLog(@"_Fo行为化第 %ld/%ld 个: %@",(long)foModel.actionIndex,(long)curFo.count,Fo2FStr(curFo));
        [self.delegate toAction_SubModelBegin:moveAlg];
    }else{
        //c. 成功,递归 (参考流程控制Finish的注释version-20200916 / 参考22061-7);
        foModel.status = TOModelStatus_ActYes;
        NSLog(@"_Fo行为化: Finish %ld/%ld 到ActYes",(long)foModel.actionIndex,(long)curFo.count);
        [self.delegate toAction_SubModelActYes:foModel];
    }
}

-(void) action{
    //1. isOut时输出
    //2. 否则跳转;
}

-(void) jump{
    //跳转后转到TIR里作为输入;
}

-(void) regroup{
    //交由TIR生成时序完成;
}

-(void) inReflect{
    //交由TIR识别完成;
}

-(void) subDemand{
    //交由DemandManager构建任务完成;
}

@end
