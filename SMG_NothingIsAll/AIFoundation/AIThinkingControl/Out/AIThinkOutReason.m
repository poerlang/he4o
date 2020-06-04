//
//  AIThinkOutReason.m
//  SMG_NothingIsAll
//
//  Created by jia on 2019/9/3.
//  Copyright © 2019年 XiaoGang. All rights reserved.
//

#import "AIThinkOutReason.h"
#import "AIAlgNodeBase.h"
#import "AICMVNodeBase.h"
#import "AINetIndex.h"
#import "AIKVPointer.h"
#import "ThinkingUtils.h"
#import "TOFoModel.h"
#import "TOAlgScheme.h"
#import "Output.h"
#import "AIShortMatchModel.h"
#import "TOUtils.h"
#import "AINetUtils.h"
#import "AIThinkOutAction.h"
#import "TOAlgModel.h"
#import "TOValueModel.h"
#import "DemandModel.h"

@interface AIThinkOutReason() <TOAlgSchemeDelegate,TOActionDelegate>

@property (strong, nonatomic) TOAlgScheme *algScheme;
@property (strong, nonatomic) AIThinkOutAction *toAction;

@end

@implementation AIThinkOutReason

-(id) init{
    self = [super init];
    if (self) {
        [self initData];
    }
    return self;
}
-(void) initData{
    self.algScheme = [[TOAlgScheme alloc] init];
    self.algScheme.delegate = self;
    self.toAction = [[AIThinkOutAction alloc] init];
    self.toAction.delegate = self;
}


//MARK:===============================================================
//MARK:                     < method >
//MARK:===============================================================

//MARK:===============================================================
//MARK:                     < 决策行为化 >
//MARK: 1. 以algScheme开始,优先使用简单的方式,后向fo,mv;
//MARK: 2. 因为TOP已经做了很多工作,此处与TOP协作 (与从左至右的理性向性是相符的);
//MARK:===============================================================

/**
 *  MARK:--------------------FromTOP主入口--------------------
 *  @version
 *      20200416 - actions行为输出前,先清空; (如不清空,下轮外循环TIR->TOP.dataOut()时,导致不重新决策,直接输出上轮actions,行为再被TIR预测,又一轮,形成外层死循环 (参考n19p5-B组BUG2);
 */
-(void) commitFromTOP_Convert2Actions:(TOFoModel*)foModel{
    if (foModel) {
        //1. 为空,进行行为化_尝试输出"可行性之首"并找到实际操作 (子可行性判定) (algScheme)
        if (!ARRISOK(foModel.actions)) {
            [self dataOut_AlgScheme:foModel];
        }
        
        //2. actionScheme (行为方案输出,并清空actions)
        if (ARRISOK(foModel.actions)) {
            NSArray *outArr = [foModel.actions copy];
            [foModel.actions removeAllObjects];
            [self dataOut_ActionScheme:outArr];
        }
    }
}

/**
 *  MARK:--------------------R+行为化--------------------
 *  @desc R+行为化,两级判断,参考:19164;
 *          1. isOut则输出;
 *          2. notOut则等待;
 */
-(void) commitReasonPlus:(TOFoModel*)outModel{
    //1. 取出当前帧任务,如果无效,则直接跳下帧;
    AIFoNodeBase *fo = [SMGUtils searchNode:outModel.content_p];
    AIKVPointer *cAlg_p = ARR_INDEX(fo.content_ps, outModel.actionIndex);
    if (!cAlg_p) {
        WLog(@"行为化概念无效");
        outModel.actionIndex ++;
        return;
    }
    
    //2. cHav行为化;
    TOAlgModel *algOutModel = [TOAlgModel newWithAlg_p:cAlg_p group:outModel];
    [self.toAction convert2Out_P:algOutModel];
    if (algOutModel.status == TOModelStatus_Finish) {
        outModel.actionIndex ++;
    }
}

/**
 *  MARK:--------------------R-行为化--------------------
 *  @desc R-行为化,三级判断,参考19165;
 *          1. is(SP)判断 (转移sp行为化);
 *          2. isOut判断 (输出);
 *          3. notOut判断 (等待);
 *  @存储 负只是正的帧推进器,比如买菜为了做饭 (参考19171);
 */
-(void) commitReasonSub:(AIFoNodeBase*)matchFo plusFo:(AIFoNodeBase*)plusFo subFo:(AIFoNodeBase*)subFo outModel:(TOFoModel*)outModel {
    //1. 数据准备
    AIKVPointer *firstPlusItem = ARR_INDEX(plusFo.content_ps, 0);
    AIFoNodeBase *fo = [SMGUtils searchNode:outModel.content_p];
    AIKVPointer *checkAlg_p = ARR_INDEX(fo.content_ps, outModel.actionIndex);
    if (!matchFo || !plusFo || !subFo || !checkAlg_p) {
        outModel.status = TOModelStatus_ActNo;
        return;
    }
    
    //2. 正影响首元素,错过判断 (错过,行为化失败);
    NSInteger firstAt_Plus = [TOUtils indexOfAbsItem:firstPlusItem atConContent:fo.content_ps];
    if (outModel.actionIndex > firstAt_Plus) {
        outModel.status = TOModelStatus_ActNo;
        return;
    }
    
    //3. 当firstPlus就是checkAlg_p时 (尝试对checkAlg行为化);
    if (firstAt_Plus == outModel.actionIndex) {
        
        //4. 从SFo中,找出checkAlg的兄弟节点matchAlg;
        AIKVPointer *matchAlg_p = [SMGUtils filterSingleFromArr:matchFo.content_ps checkValid:^BOOL(AIKVPointer *item_p) {
            return [TOUtils mcSameLayer:item_p c:checkAlg_p];
        }];
        
        //5. 根据matchAlg找到对应的S;
        AIKVPointer *sAlg_p = [SMGUtils filterSingleFromArr:subFo.content_ps checkValid:^BOOL(AIKVPointer *item) {
            return [TOUtils mIsC_1:matchAlg_p c:item];
        }];
        
        //6. 行为化 (围绕P做行为);
        AIKVPointer *pAlg_p = firstPlusItem;
        if (sAlg_p) {
            NSInteger sIndex = [TOUtils indexOfAbsItem:sAlg_p atConContent:matchFo.content_ps];
            BOOL sHappened = sIndex < outModel.actionIndex;
            if (sHappened) {
                //a. S存在,且S已发生,则加工SP;
                TOAlgModel *algOutModel = [TOAlgModel newWithAlg_p:checkAlg_p group:outModel];
                [self.toAction convert2Out_SP:sAlg_p pAlg_p:pAlg_p outModel:algOutModel];
                if (algOutModel.status == TOModelStatus_Finish) {
                    outModel.status = TOModelStatus_Finish;
                }
            }else{
                //b. S存在,但S未发生,则等待 (等S发生);
                outModel.status = TOModelStatus_Finish;
            }
        }else{
            //c. S不存在,则仅实现P即可;
            TOAlgModel *algOutModel = [TOAlgModel newWithAlg_p:pAlg_p group:outModel];
            [self.toAction convert2Out_P:algOutModel];
            if (algOutModel.status == TOModelStatus_Finish) {
                outModel.status = TOModelStatus_Finish;
            }
        }
    }
}

/**
 *  MARK:--------------------P+行为化--------------------
 *  @desc P+行为化,两级判断,参考:19166;
 *          1. isOut则输出;
 *          2. notOut则进行cHav行为化;
 *  @version
 *      2020-05-27 : 将isOut=false时等待改成进行cHav行为化;
 */
-(void) commitPerceptPlus:(TOFoModel*)outModel{
    //1. 数据检查
    AIFoNodeBase *fo = [SMGUtils searchNode:outModel.content_p];
    if (!fo) {
        outModel.status = TOModelStatus_ActNo;
        return;
    }
    
    //2. 行为化;
    AIKVPointer *curAlg_p = ARR_INDEX(fo.content_ps, outModel.actionIndex);//从0开始
    
    //3. cHav行为化
    TOAlgModel *algOutModel = [TOAlgModel newWithAlg_p:curAlg_p group:outModel];
    [self.toAction convert2Out_P:algOutModel];
    if (algOutModel.status == TOModelStatus_Finish) {
        outModel.status = TOModelStatus_Finish;
    }
}

/**
 *  MARK:--------------------P-行为化--------------------
 *  @desc P-行为化,三级判断,参考19167;
 *          1. is(SP)判断 (转移sp行为化);
 *          2. isOut判断 (输出);
 *          3. notOut判断 (等待);
 *  @废弃: 因为左负是不存在的(或者说目前不需要的),可以以左正,转为右正,来实现,累了歇歇的例子;
 */
-(void) commitPerceptSub:(AIFoNodeBase*)matchFo plusFo:(AIFoNodeBase*)plusFo subFo:(AIFoNodeBase*)subFo checkFo:(AIFoNodeBase*)checkFo complete:(void(^)(BOOL actSuccess,NSArray *acts))complete{
    ////1. 数据准备
    //AIKVPointer *firstSubItem = ARR_INDEX(subFo.content_ps, 0);
    //AIKVPointer *firstPlusItem = ARR_INDEX(plusFo.content_ps, 0);
    //AIKVPointer *curAlg_p = ARR_INDEX(checkFo.content_ps, 0);//当前plusFo的具象首元素;
    //if (!matchFo || !plusFo || !subFo || !checkFo || !complete || !curAlg_p) {
    //    complete(false,nil);
    //    return;
    //}
    //
    ////1. 负影响首元素,错过判断 (错过,行为化失败);
    //NSInteger firstAt_Sub = [TOUtils indexOfAbsItem:firstSubItem atConContent:matchFo.content_ps];
    //
    ////2. 正影响首元素,错过判断 (错过,行为化失败);
    //NSInteger firstAt_Plus = [TOUtils indexOfAbsItem:firstPlusItem atConContent:checkFo.content_ps];
    //
    ////3. 三级行为化判断;
    //if (firstAt_Sub == 0 && firstAt_Plus == 0) {
    //    //a. 把S加工成P;
    //}else if(firstAt_Sub == 0){
    //    //b. 把S加工修正;
    //}else if(firstAt_Plus == 0){
    //    //c. 把P加工满足;
    //}else if(curAlg_p.isOut){
    //    //d. isOut输出;
    //    complete(true,@[curAlg_p]);
    //}else{
    //    //e. notOut等待;
    //    complete(true,nil);
    //}
}

/**
 *  MARK:--------------------algScheme--------------------
 *  1. 对条件概念进行判定 (行为化);
 *  2. 理性判定;
 */
-(void) dataOut_AlgScheme:(TOFoModel*)outFoModel{
    //1. 数据准备
    if (!ISOK(outFoModel, TOFoModel.class)) {
        return;
    }
    AIFoNodeBase *foNode = [SMGUtils searchNode:outFoModel.content_p];
    if (!foNode) {
        return;
    }
    
    //2. 进行行为化; (通过有无,变化,等方式,将结构中所有条件概念行为化);
    [self.algScheme setData:[self.delegate aiTOR_GetShortMatchModel]];
    
    [self.algScheme convert2Out_Fo:foNode.content_ps curFo:foNode success:^(NSArray *acts) {
        [outFoModel.actions addObjectsFromArray:acts];
    } failure:^{
        WLog(@"STEPKEYTOR_行为化失败");
    }];
}

//MARK:===============================================================
//MARK:                     < FromTOP_反射反应 >
//MARK:===============================================================
-(void) commitFromTOP_ReflexOut{
    [self dataOut_ActionScheme:nil];
}

-(void) dataOut_ActionScheme:(NSArray*)outArr{
    //1. 尝试输出找到解决问题的实际操作 (取到当前cacheModel中的最佳决策,并进行输出;)
    BOOL tryOutSuccess = false;
    if (ARRISOK(outArr)) {
        for (AIKVPointer *algNode_p in outArr) {
            //>1 检查micro_p是否是"输出";
            //>2 假如order_p足够确切,尝试检查并输出;
            BOOL invoked = [Output output_FromTC:algNode_p];
            if (invoked) {
                tryOutSuccess = true;
            }
        }
    }
    
    //2. 无法解决时,反射一些情绪变化,并增加额外输出;
    if (!tryOutSuccess) {
        //>1 产生"心急mv";(心急产生只是"urgent.energy x 2")
        //>2 输出反射表情;
        //>3 记录log到foOrders;(记录log应该到output中执行)
        
        //1. 如果未找到复现方式,或解决方式,则产生情绪:急
        //2. 通过急,输出output表情哭
        
        //1. 心急情绪释放,平复思维;
        [self.delegate aiThinkOutReason_UpdateEnergy:-1];
        
        //2. 反射输出
        [Output output_FromMood:AIMoodType_Anxious];
    }
}

/**
 *  MARK:--------------------"外层输入" 推进 "中层循环" 决策--------------------
 *  @desc
 *      1. 最新一帧,与上轮循环做匹配 (对单帧匹配到任务Finish的,要推动决策跳转下帧);
 *      2. 未输出行为,等待中的,也要进行下轮匹配,比如等开饭,等来开饭了; (等待的status是ActNo还是Runing?)
 *  @todo
 *      1. 此处在for循环中,所以有可能推进多条,比如我有了一只狗,可以拉雪撬,或者送给爷爷陪爷爷 (涉及多任务间的价值自由竞争),暂仅支持一条,后再支持;
 */
-(BOOL) commitFromOuterPushMiddleLoop:(DemandModel*)demand latestMatchAlg:(AIAlgNodeBase*)latestMatchAlg{
    //1. 数据检查
    if (!latestMatchAlg) {
        return false;
    }
    
    //2. 取出所有等待下轮的outModel (ActYes&Runing);
    NSArray *waitModels = [TOUtils getSubOutModels_AllDeep:demand validStatus:@[@(TOModelStatus_ActYes),@(TOModelStatus_Runing)]];
    
    //3. 判断最近一次input是否与等待中outModel相匹配 (匹配,比如吃,确定自己是否真吃了);
    for (TOModelBase *waitModel in waitModels) {
        if ([TOUtils mIsC_1:latestMatchAlg.pointer c:waitModel.content_p]) {
            
            //4. 匹配,则完成;
            waitModel.status = TOModelStatus_Finish;
            
            //5. 推动单轮循环,继续决策;
            [self singleLoopBackWithSuccessModel:waitModel];
            return true;
        }
    }
    return false;
}

/**
 *  MARK:--------------------新发生outModel完成,推进递归--------------------
 *  @desc
 *      1. 本方法,以递归方式运行 (反馈给上一级,跳到下帧);
 *      2. 最终输出为:
 *          a. 时序下帧概念
 *          b. 概念下帧稀疏码
 *          c. Demand最终完成
 *      3. 输入参数可能为Alg,Value,Demand,参考19203;
 *      4. 参数说明:
 *          a. 由别的方法调用时,参数为:TOAlgModel或TOValueModel;
 *          b. 由递归自行调用时,参数为:TOAlgModel或TOValueModel或DemandModel;
 *  @callers : 由外循环调用,当外循环输入新的matchAlg时,调用此方法推进继续决策;
 */
-(void) singleLoopBackWithSuccessModel:(TOModelBase*)newFinishModel {
    if (ISOK(newFinishModel, TOAlgModel.class)) {
        //1. Alg (如果取到fo,则下帧继续;)
        TOFoModel *toFoModel = (TOFoModel*)newFinishModel.baseOrGroup;
        
        //2. 完成,则直接返回finish (如本来就是最后一帧,则再递归至上一层);
        AIFoNodeBase *fo = [SMGUtils searchNode:toFoModel.content_p];
        if (toFoModel.actionIndex < fo.content_ps.count - 1) {
            //a. Alg转移 (下帧)
            toFoModel.actionIndex ++;
            AIKVPointer *move_p = ARR_INDEX(fo.content_ps, toFoModel.actionIndex);
            TOAlgModel *algOutModel = [TOAlgModel newWithAlg_p:move_p group:toFoModel];
            [self.toAction convert2Out_Hav:algOutModel];
            //b. 失败,递归
            if (algOutModel.status == TOModelStatus_ActNo || algOutModel.status == TOModelStatus_ScoreNo) {
                [self singleLoopBackWithFailureModel:algOutModel];
            }
        }else{
            //c. 成功,递归
            toFoModel.status = TOModelStatus_Finish;
            [self singleLoopBackWithSuccessModel:toFoModel.baseOrGroup];
        }
    }else if(ISOK(newFinishModel, TOValueModel.class)){
        //3. Value (如果取到alg,则应将当前已完成的value标记到algOutModel.alreadyFinishs,并提给TOAction._P/_SP继续完成去);
        TOAlgModel *toAlgModel = (TOAlgModel*)newFinishModel.baseOrGroup;
        
        //4. Value转移 (未行为化过的sp进行转移);
        BOOL jump = false;
        for (NSData *key in toAlgModel.cGLDic.allKeys) {
            AIKVPointer *sValue_p = DATA2OBJ(key);
            AIKVPointer *pValue_p = [toAlgModel.cGLDic objectForKey:key];
            
            //a. 转移 (找出未行为化过的)
            NSArray *alreadayAct_ps = [TOUtils convertPointersFromTOModels:toAlgModel.subModels];
            if (![alreadayAct_ps containsObject:pValue_p]) {
                TOValueModel *toValueModel = [TOValueModel newWithSValue:sValue_p pValue:pValue_p group:toAlgModel];
                jump = true;
                [self.toAction convert2Out_GL:toAlgModel.pAlg outModel:toValueModel];
                
                //b. 失败,递归;
                if (toValueModel.status == TOModelStatus_ActNo || toValueModel.status == TOModelStatus_ScoreNo) {
                    [self singleLoopBackWithFailureModel:toValueModel];
                }
                break;
            }
        }
        
        //c. 成功,递归;
        if (!jump) {
            toAlgModel.status = TOModelStatus_Finish;
            [self singleLoopBackWithSuccessModel:toAlgModel.baseOrGroup];
        }
    }else if(ISOK(newFinishModel, DemandModel.class)){
        //5. 全部完成;
        NSLog(@"SUCCESS > 决策任务完成");
    }else{
        ELog(@"如打出此错误,则查下为何groupModel不是TOFoModel类型,因为一般行为化的都是概念,而概念的父级就是TOFoModel");
    }
}

/**
 *  MARK:--------------------新发生模型失败,推进递归--------------------
 *  @callers : 由行为化推动 (行为化失败时,直接推动此方法,向右上,找下一解决方案);
 *  @desc
 *      1. 参数说明:
 *          a. 由别的方法调用时,参数为:TOAlgModel或TOValueModel;
 *          b. 由递归自行调用时,参数为:TOAlgModel或TOValueModel或DemandModel;
 *      2. 参数的上级,必然是actYes或runing,对其进行再决策 (不是actYes或runing也不会有子model的failure了);
 *      3. 转移:
 *          a. avd为Alg时,转移方法为:TOAction._Hav;
 *          b. avd为Value时,转移方法为:TOAction._GL;
 *          c. avd为Demand时,转移方法为:TOP.P+;
 */
-(void) singleLoopBackWithFailureModel:(TOModelBase*)failureModel {
    //TODOTOMORROW:
    //1. 将再决策,所需的参数存到相应的outModel中 (到TOModelBase中保留参数);
    //2. 转移_Hav/_GL时,将不应期(从avd.actionFoModels中找failure的部分)去掉;
    //3. 写完TOP.commitFromTOR_MoveForDemand();
    
    
    //1. 转移或递归Block();
    void(^ MoveOrLoopBackBlock)(TOModelBase *avd)= ^ (TOModelBase *avd){
        //a. 转移
        if (ISOK(avd, TOAlgModel.class)) {
            //a1. avdIsAlg: 再决策,转移至TOAction;
            [self.toAction convert2Out_Hav:(TOAlgModel*)avd];
        }else if(ISOK(avd, TOValueModel.class)){
            //a2. avdIsValue: 再决策,转移至TOAction;
            TOAlgModel *baseAlg = (TOAlgModel*)avd.baseOrGroup;
            [self.toAction convert2Out_GL:baseAlg.pAlg outModel:(TOValueModel*)avd];
        }else if(ISOK(avd, DemandModel.class)){
            //a3. avdIsDemand: 再决策,转移至TOP.P+;
            [self.delegate aiTOR_MoveForDemand:avd];
        }
        //b. 转移后,其下全失败,递归;
        if (avd.status == TOModelStatus_ActNo || avd.status == TOModelStatus_ScoreNo) {
            [self singleLoopBackWithFailureModel:avd];
        }
    };
    
    //2. 主方法部分;
    if (ISOK(failureModel, TOAlgModel.class)) {
        //a. Alg时,其右fo失败
        TOFoModel *toFoModel = (TOFoModel*)failureModel.baseOrGroup;
        toFoModel.status = TOModelStatus_ActNo;
        
        //b. 用fo向上找A/V/D进行fos再决策 (先尝试转移,后不行就递归);
        MoveOrLoopBackBlock(toFoModel.baseOrGroup);
    }else if(ISOK(failureModel, TOValueModel.class)){
        //a. Value时,其右alg和fo失败
        TOAlgModel *toAlgModel = (TOAlgModel*)failureModel.baseOrGroup;
        TOFoModel *toFoModel = (TOFoModel*)toAlgModel.baseOrGroup;
        toAlgModel.status = TOModelStatus_ActNo;
        toFoModel.status = TOModelStatus_ActNo;
        
        //b. 用fo向上找A/V/D进行fos再决策 (先尝试转移,后不行就递归);
        MoveOrLoopBackBlock(toFoModel.baseOrGroup);
    }else if(ISOK(failureModel, DemandModel.class)){
        //a. 再决策未成功 (全失败了) ===> 全部失败;
        NSLog(@"Demand所有方案全部失败");
    }else{
        ELog(@"如打出此错误,则查下为何groupModel不是TOFoModel类型,因为一般行为化的都是概念,而概念的父级就是TOFoModel");
    }
}

//MARK:===============================================================
//MARK:                     < TOAlgSchemeDelegate >
//MARK:===============================================================
-(void)toAlgScheme_updateEnergy:(CGFloat)delta{
    [self.delegate aiThinkOutReason_UpdateEnergy:delta];
}
-(BOOL) toAlgScheme_EnergyValid{
    return [self.delegate aiThinkOutReason_EnergyValid];
}
//反思
-(AIShortMatchModel*) toAlgScheme_LSPRethink:(AIAlgNodeBase*)rtAlg rtFoContent_ps:(NSArray*)rtFoContent_ps{
    return [self.delegate aiTOR_LSPRethink:rtAlg rtFoContent_ps:rtFoContent_ps];
}
-(AIAlgNodeBase*) toAlgScheme_MatchRTAlg:(AIAlgNodeBase*)rtAlg mUniqueV_p:(AIKVPointer*)mUniqueV_p{
    return [self.delegate aiTOR_MatchRTAlg:rtAlg mUniqueV_p:mUniqueV_p];
}

//MARK:===============================================================
//MARK:                     < TOActionDelegate >
//MARK:===============================================================
-(void)toAction_updateEnergy:(CGFloat)delta{
    [self.delegate aiThinkOutReason_UpdateEnergy:delta];
}
-(BOOL)toAction_EnergyValid{
    return [self.delegate aiThinkOutReason_EnergyValid];
}
-(void)toAction_Output:(NSArray *)actions{
    actions = ARRTOOK(actions);
    for (AIKVPointer *algNode_p in actions) {
        BOOL invoked = [Output output_FromTC:algNode_p];
    }
}
-(AIShortMatchModel*) toAction_RethinkInnerFo:(AIFoNodeBase*)fo{
    return [self.delegate aiTOR_RethinkInnerFo:fo];
}

@end
