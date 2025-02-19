//
//  TCSolution.m
//  SMG_NothingIsAll
//
//  Created by jia on 2021/11/28.
//  Copyright © 2021年 XiaoGang. All rights reserved.
//

#import "TCSolution.h"

@implementation TCSolution

/**
 *  MARK:--------------------新螺旋架构solution方法--------------------
 *  @desc 参考24203;
 *  @param endScore : 当传入endBranch为solutionFo时,endScore为:末枝S方案的综合评分;
 *  @version
 *      2021.12.28: 对首条S的支持 (参考25042);
 *      2021.12.28: 支持actYes时最优路径末枝为nil,并中止决策 (参考25042-3);
 *      2022.06.02: 如果endBranch的末枝正在等待actYes,则继续等待,不进行决策 (参考26185-TODO4);
 */
+(void) solution:(TOModelBase*)endBranch endScore:(double)endScore{
    //1. 无末枝时 (可能正在ActYes等待状态),中断决策;
    if (!endBranch) return;
    
    //1. 判断endBranch如果是actYes状态,则不处理,继续静默;
    BOOL endHavActYes = [TOUtils endHavActYes:endBranch];
    if (endHavActYes) return;
    
    //2. 尝试取更多S;
    Act1 runSolutionAct = ^(DemandModel *demand){
        if (ISOK(demand, ReasonDemandModel.class)) {
            //a. R任务继续取解决方案 (参考24203-2);
            [self rSolution:(ReasonDemandModel*)demand];
        }else if (ISOK(demand, PerceptDemandModel.class)) {
            //b. P任务继续取解决方案 (参考24203-2);
            [self pSolution:demand];
        }else if (ISOK(demand, HDemandModel.class)) {
            //c. H任务继续取解决方案 (参考24203-2);
            [self hSolution:(HDemandModel*)demand];
        }
    };
    
    //3. 传入solutionFo时;
    if (ISOK(endBranch, TOFoModel.class)) {
        DemandModel *baseDemand = (DemandModel*)endBranch.baseOrGroup;
        TOFoModel *solutionFo = (TOFoModel*)endBranch;
        
        //4. endBranch >= 0分时,执行TCAction (参考24203-1);
        if (endScore >= 0) [TCAction action:solutionFo];
        
        //5. 无更多S时_直接TCAction行为化 (参考24203-2b);
        else if(baseDemand.status == TOModelStatus_WithOut) [TCAction action:solutionFo];
        
        //6. 末枝S达到3条时,则最优执行TCAction (参考24203-3);
        else if(baseDemand.actionFoModels.count >= cSolutionNarrowLimit) [TCAction action:solutionFo];
        
        //7. endBranch < 0分时,且末枝S小于3条,执行TCSolution取下一方案 (参考24203-2);
        else if (baseDemand.status != TOModelStatus_WithOut && baseDemand.actionFoModels.count < cSolutionNarrowLimit) runSolutionAct(baseDemand);
    }
    
    //8. 传入demand时,且demand还可继续时,尝试执行TCSolution取下一方案 (参考24203);
    if (ISOK(endBranch, DemandModel.class)) {
        if (endBranch.status != TOModelStatus_ActNo && endBranch.status != TOModelStatus_ActYes && endBranch.status != TOModelStatus_WithOut) {
            runSolutionAct((DemandModel*)endBranch);
        }
    }
}

/**
 *  MARK:--------------------rSolution--------------------
 *  @desc 参考24154-单轮;
 *  @version
 *      2021.11.13: 初版,废弃dsFo,并将reasonSubV5由TOR迁移至此RAction中 (参考24101-第3阶段);
 *      2021.11.15: R任务FRS稳定性竞争,评分越高的场景排越前 (参考24127-2);
 *      2021.11.25: 迭代为功能架构 (参考24154-单轮示图);
 *      2021.12.25: 将FRS稳定性竞争废弃,改为仅取bestSP评分,取最稳定的一条 (参考25032-4);
 *      2021.12.28: 将抽具象路径rs改为从pFos中取同标识mv部分 (参考25051);
 *      2022.01.07: 改为将整个demand.actionFoModels全加入不应期 (因为还在决策中的S会重复);
 *      2022.01.09: 达到limit条时的处理;
 *      2022.01.19: 将时间不急评价封装为FRS_Time() (参考25106);
 *      2022.03.06: 当稳定性综评为0分时,不做为解决方案 (参考25131-思路2);
 *      2022.03.09: 将conPorts取前3条改成15条 (参考25144);
 *      2022.05.01: 废弃从等价demands下取解决方案 (参考25236);
 *      2022.05.04: 树限宽也限深 (参考2523c-分析代码1);
 *      2022.05.18: 改成多个pFos下的解决方案进行竞争 (参考26042-TODO3);
 *      2022.05.20: 过滤掉负价值不做为解决方案 (参考26063);
 *      2022.05.21: 窄出排序方式,以效用分为准 (参考26077-方案);
 *      2022.05.21: 窄出排序方式,退回到以SP稳定性排序 (参考26084);
 *      2022.05.22: 窄出排序方式,改为有效率排序 (参考26095-9);
 *      2022.05.27: 集成新的取S的方法 (参考26128);
 *      2022.05.27: 新解决方案从cutIndex开始行为化,而不是-1 (参考26127-TODO9);
 *      2022.05.29: 前3条优先取快思考,后2条或快思考无效时,再取慢思考 (参考26143-TODO2);
 *  @callers : 用于RDemand.Begin时调用;
 */
+(void) rSolution:(ReasonDemandModel*)demand {
    //0. S数达到limit时设为WithOut;
    OFTitleLog(@"rSolution", @"\n任务源:%@ protoFo:%@ 已有方案数:%ld",demand.algsType,Pit2FStr(demand.protoFo),demand.actionFoModels.count);
    
    //1. 树限宽且限深;
    NSInteger deepCount = [TOUtils getBaseDemandsDeepCount:demand];
    if (deepCount >= cDemandDeepLimit || demand.actionFoModels.count >= cSolutionNarrowLimit) {
        demand.status = TOModelStatus_WithOut;
        NSLog(@"%lld score from 9",theTC.getLoopId);
        [TCScore score];
        NSLog(@">>>>>> rSolution 已达limit条 (S数:%ld 层数:%ld)",demand.actionFoModels.count,deepCount);
        return;
    }
    [theTC updateOperCount];
    Debug();
    
    //2. 不应期 (可以考虑) (源于:反思且子任务失败的 或 fo行为化最终失败的,参考24135);
    NSMutableArray *except_ps = [TOUtils convertPointersFromTOModels:demand.actionFoModels];
    [except_ps addObjectsFromArray:[SMGUtils convertArr:demand.pFos convertBlock:^id(AIMatchFoModel *obj) {
        return obj.matchFo;
    }]];
    
    //3. 前3条,优先快思考;
    AISolutionModel *bestResult = nil;
    if (demand.actionFoModels.count <= 3) {
        bestResult = [TCSolutionUtil rSolution_Fast:demand except_ps:except_ps];
    }
    
    //4. 快思考无果或后2条,再做慢思考;
    if (!bestResult) {
        bestResult = [self rSolution_Slow:demand except_ps:except_ps];
    }

    //6. 转流程控制_有解决方案则转begin;
    DebugE();
    if (bestResult) {
        //7. 消耗活跃度;
        if (![theTC energyValid]) return;
        [theTC updateEnergyDelta:-1];
        
        //a) 下一方案成功时,并直接先尝试Action行为化,下轮循环中再反思综合评价等 (参考24203-2a);
        AIFoNodeBase *bestSFo = [SMGUtils searchNode:bestResult.cansetFo];
        TOFoModel *foModel = [TOFoModel newWithFo_p:bestSFo.pointer base:demand];
        foModel.actionIndex = bestResult.cutIndex;
        NSLog(@"> newS 第%ld例: %@",demand.actionFoModels.count,Fo2FStr(bestSFo));
        
        //a) 有效率
        [TCEffect rEffect:foModel];
        [theTV updateFrame];
        [TCAction action:foModel];
    }else{
        //b) 下一方案失败时,标记withOut,并下轮循环 (竞争末枝转Action) (参考24203-2b);
        demand.status = TOModelStatus_WithOut;
        NSLog(@">>>>>> rSolution 无计可施");
        NSLog(@"%lld score from 8",theTC.getLoopId);
        [TCScore score];
    }
}

/**
 *  MARK:--------------------R慢思考--------------------
 *  @desc 思考求解 (参考26127);
 *  @version
 *      2022.06.04: 修复结果与当前场景相差甚远BUG: 分三级排序窄出 (参考26194 & 26195);
 */
+(AISolutionModel*) rSolution_Slow:(ReasonDemandModel *)demand except_ps:(NSArray*)except_ps{
    //0. 数据准备;
    except_ps = ARRTOOK(except_ps);
    AISolutionModel *result = nil;
    
    //1. 取pFos;
    NSArray *pFos = [SMGUtils convertArr:demand.pFos convertBlock:^id(AIMatchFoModel *obj) {
        return obj.matchFo;
    }];
    NSLog(@"第1步 pFos数:%ld",pFos.count);//测时9条
    
    //2. 取absPFos
    NSArray *absFos = [SMGUtils convertArr:pFos convertItemArrBlock:^NSArray *(AIKVPointer *obj) {
        AIFoNodeBase *pFo = [SMGUtils searchNode:obj];
        return Ports2Pits([AINetUtils absPorts_All:pFo]);
    }];
    absFos = [SMGUtils removeRepeat:absFos];
    NSLog(@"第2步 absFos数:%ld",absFos.count);//测时10条
    
    //3. 取同级;
    NSArray *sameLayerFos = [SMGUtils convertArr:absFos convertItemArrBlock:^NSArray *(AIKVPointer *obj) {
        AIFoNodeBase *absFo = [SMGUtils searchNode:obj];
        return Ports2Pits([AINetUtils conPorts_All:absFo]);
    }];
    sameLayerFos = [SMGUtils removeRepeat:sameLayerFos];
    NSLog(@"第3步 sameLayerFos数:%ld",sameLayerFos.count);//测时749条
    
    //4. 收集起来
    NSMutableArray *cansetFos = [[NSMutableArray alloc] init];
    [cansetFos addObjectsFromArray:pFos];
    [cansetFos addObjectsFromArray:absFos];
    [cansetFos addObjectsFromArray:sameLayerFos];
    cansetFos = [SMGUtils removeRepeat:cansetFos];
    NSLog(@"第4步 cansetFos数:%ld",cansetFos.count);//测时758条
    
    //4. 过滤掉长度为1的 (因为前段全含至少要1位,后段修正也至少要1位)
    cansetFos = [SMGUtils filterArr:cansetFos checkValid:^BOOL(AIKVPointer *item) {
        AIFoNodeBase *fo = [SMGUtils searchNode:item];
        return fo.count > 1;
    }];
    NSLog(@"第5步 最小长度2:%ld",cansetFos.count);//测时149条
    
    //4. 过滤掉有负mv指向的 (参考26063 & 26127-TODO8);
    cansetFos = [SMGUtils filterArr:cansetFos checkValid:^BOOL(AIKVPointer *item) {
        AIFoNodeBase *fo = [SMGUtils searchNode:item];
        return ![ThinkingUtils havDemand:fo.cmvNode_p];
    }];
    NSLog(@"第6步 非负价值:%ld",cansetFos.count);//测时96条
    
    //5. 对比cansetFo和protoFo匹配,得出对比结果 (参考26128-第1步);
    NSArray *solutionModels = [SMGUtils convertArr:cansetFos convertBlock:^id(AIKVPointer *obj) {
        return [TOUtils compareRCansetFo:obj protoFo:demand.protoFo];
    }];
    NSLog(@"第7步 对比匹配成功:%ld",solutionModels.count);//测时94条
    
    //7. 排除不应期;
    solutionModels = [SMGUtils filterArr:solutionModels checkValid:^BOOL(AISolutionModel *item) {
        return ![except_ps containsObject:item.cansetFo];
    }];
    NSLog(@"第8步 排除不应期:%ld",solutionModels.count);//测时xx条
    
    //8. 时间不急评价: 不急 = 解决方案所需时间 <= 父任务能给的时间 (参考:24057-方案3,24171-7);
    solutionModels = [SMGUtils filterArr:solutionModels checkValid:^BOOL(AISolutionModel *item) {
        return [AIScore FRS_Time:demand solutionModel:item];
    }];
    NSLog(@"第9步 排除FRSTime来不及的:%ld",solutionModels.count);//测时xx条
    
    //6. 计算衰后stableScore (参考26128-2-1);
    NSArray *outOfFos = [SMGUtils convertArr:solutionModels convertBlock:^id(AISolutionModel *obj) {
        return obj.cansetFo;
    }];
    for (AISolutionModel *model in solutionModels) {
        AIFoNodeBase *cansetFo = [SMGUtils searchNode:model.cansetFo];
        model.stableScore = [TOUtils getColStableScore:cansetFo outOfFos:outOfFos startSPIndex:model.cutIndex + 1 endSPIndex:model.targetIndex];
    }
    
    //7. 根据候选集综合分排序 (参考26128-2-2);
    NSArray *sortModels = [TOUtils solutionSlow_SortNarrow:solutionModels needBack:false];
    
    //8. 取最佳解决方案;
    result = ARR_INDEX(sortModels, 0);
    
    //12. debugLog
    for (AISolutionModel *model in sortModels) {
        CGFloat solutionScore = model.stableScore * model.frontMatchValue;
        AIFoNodeBase *cansetFo = [SMGUtils searchNode:model.cansetFo];
        if (Log4Solution_Slow) NSLog(@"> %@\n\t评分:%.2f = 前匹配:%.2f x 中稳定:%.2f >> %@",Pit2FStr(model.cansetFo),solutionScore,model.frontMatchValue,model.stableScore,CLEANSTR(cansetFo.spDic));
    }
    AIFoNodeBase *resultFo = [SMGUtils searchNode:result.cansetFo];
    NSLog(@"取得慢思考最佳结果:F%ld 评分 = 前匹配:%.2f x 中稳定:%.2f %@",result.cansetFo.pointerId,result.frontMatchValue,result.stableScore,CLEANSTR(resultFo.spDic));
    return result;
}

/**
 *  MARK:-------------------- pSolution --------------------
 *  @desc
 *      1. 简介: mv方向索引找正价值解决方案;
 *      2. 实例: 饿了,现有面粉,做面吃可以解决;
 *      3. 步骤: 用A.refPorts ∩ F.conPorts (参考P+模式模型图);
 *      4. 联想方式: 参考19192示图 (此行为后补注释);
 *  @todo :
 *      1. 集成原有的能量判断与消耗 T;
 *      2. 评价机制1: 比如土豆我超不爱吃,在mvScheme中评价,入不应期,并继续下轮循环;
 *      3. 评价机制2: 比如炒土豆好麻烦,在行为化中反思评价,入不应期,并继续下轮循环;
 *  @version
 *      2020.05.27: 将isOut=false时等待改成进行cHav行为化;
 *      2020.06.10: 索引解决方案:去除fo的不应期,因为不应期应针对mv,而fo的不应期是针对此处取得fo及其具象conPorts.fos的,所以将fo不应期前置了;
 *      2020.07.23: 联想方式迭代至V2_将19192示图的联想方式去掉,仅将方向索引除去不应期的返回,而解决方案到底是否实用,放到行为化中去判断;
 *      2020.09.23: 取消参数matchAlg (最近识别的M),如果今后还要使用短时优先功能,直接从theTC.shortManager取);
 *      2020.09.23: 只要得到解决方案,就返回true中断,因为即使行为化失败,也会交由流程控制继续决策,而非由此处处理;
 *      2020.12.17: 将此方法,归由流程控制控制 (跑下来逻辑与原来没啥不同);
 *      2022.05.04: 树限宽也限深 (参考2523c-分析代码1);
 *  @bug
 *      1. 查点击马上饿,找不到解决方案的BUG,经查,MatchAlg与解决方案无明确关系,但MatchAlg.conPorts中,有与解决方案有直接关系的,改后解决 (参考20073)
 *      2020.07.09: 修改方向索引的解决方案不应期,解决只持续飞行两次就停住的BUG (参考n20p8-BUG1);
 */
+(void) pSolution:(DemandModel*)demandModel{
    //1. 数据准备;
    //TODO: 2021.12.29: 此处方向索引,可以改成和rh任务一样的从pFos&rFos中取具象得来 (因为方向索引应该算脱离场景);
    MVDirection direction = [ThinkingUtils getDemandDirection:demandModel.algsType delta:demandModel.delta];
    if (!Switch4PS || direction == MVDirection_None) return;
    OFTitleLog(@"pSolution", @"\n任务:%@,发生%ld,方向%ld,已有方案数:%ld",demandModel.algsType,(long)demandModel.delta,(long)direction,demandModel.actionFoModels.count);
    
    //1. 树限宽且限深;
    NSInteger deepCount = [TOUtils getBaseDemandsDeepCount:demandModel];
    if (deepCount >= cDemandDeepLimit || demandModel.actionFoModels.count >= cSolutionNarrowLimit) {
        demandModel.status = TOModelStatus_WithOut;
        NSLog(@"%lld score from 7",theTC.getLoopId);
        [TCScore score];
        NSLog(@"------->>>>>> pSolution 已达limit条");
        return;
    }
    [theTC updateOperCount];
    Debug();
    
    //2. =======以下: 调用通用diff模式方法 (以下代码全是由diff模式方法迁移而来);
    //3. 不应期 (考虑改为所有actionFoModels都不应期);
    NSArray *exceptFoModels = [SMGUtils filterArr:demandModel.actionFoModels checkValid:^BOOL(TOModelBase *item) {
        return item.status == TOModelStatus_ActNo || item.status == TOModelStatus_ScoreNo || item.status == TOModelStatus_ActYes;
    }];
    NSArray *except_ps = [TOUtils convertPointersFromTOModels:exceptFoModels];
    if (Log4DirecRef) NSLog(@"------->>>>>> Fo已有方案数:%lu 不应期数:%lu",(long)demandModel.actionFoModels.count,(long)except_ps.count);
    
    //3. =======以下: 调用方向索引,找解决方案代码
    //2. 方向索引,用方向索引找normalFo解决方案 (P例:饿了,该怎么办 S例:累了,肿么肥事);
    NSArray *mvRefs = [theNet getNetNodePointersFromDirectionReference:demandModel.algsType direction:direction isMem:false filter:nil];
    
    //4. debugLog
    if (Log4DirecRef){
        for (NSInteger i = 0; i < 10; i++) {
            AIPort *item = ARR_INDEX(mvRefs, i);
            AICMVNodeBase *itemMV = [SMGUtils searchNode:item.target_p];
            if (item && itemMV && itemMV.foNode_p) NSLog(@"item-> 强度:%ld 方案:%@->%@",(long)item.strong.value,FoP2FStr(itemMV.foNode_p),Mv2FStr(itemMV));
        }
    }
    
    //3. 逐个返回;
    for (AIPort *item in mvRefs) {
        //a. analogyType处理 (仅支持normal的fo);
        AICMVNodeBase *itemMV = [SMGUtils searchNode:item.target_p];
        AnalogyType foType = itemMV.foNode_p.type;
        if (ATPlus != foType && ATSub != foType) {
            if (Log4DirecRef) NSLog(@"方向索引_尝试_索引强度:%ld 方案:%@",item.strong.value,FoP2FStr(itemMV.foNode_p));
            
            //5. 方向索引找到一条normalFo解决方案 (P例:吃可以解决饿; S例:运动导致累);
            if (![except_ps containsObject:itemMV.foNode_p]) {
                //8. 消耗活跃度;
                if (![theTC energyValid]) return;
                [theTC updateEnergyDelta:-1];
                AIFoNodeBase *fo = [SMGUtils searchNode:itemMV.foNode_p];
                
                //a. 构建TOFoModel
                TOFoModel *toFoModel = [TOFoModel newWithFo_p:fo.pointer base:demandModel];
                
                //b. 取自身,实现吃,则可不饿 (提交C给TOR行为化);
                //a) 下一方案成功时,并直接先尝试Action行为化,下轮循环中再反思综合评价等 (参考24203-2a);
                NSLog(@">>>>>> pSolution 新增第%ld例解决方案: %@->%@",demandModel.actionFoModels.count,Fo2FStr(fo),Mvp2Str(fo.cmvNode_p));
                [theTV updateFrame];
                DebugE();
                [TCAction action:toFoModel];//[theTOR singleLoopBackWithBegin:toFoModel];
                
                //8. 只要有一次tryResult成功,中断回调循环;
                return;
            }
        }
    }
    
    //9. 无计可施,下一方案失败时,标记withOut,并下轮循环 (竞争末枝转Action) (参考24203-2b);
    DebugE();
    demandModel.status = TOModelStatus_WithOut;
    NSLog(@">>>>>> pSolution 无计可施");
    NSLog(@"%lld score from 6",theTC.getLoopId);
    [TCScore score];
}

/**
 *  MARK:--------------------hSolution--------------------
 *  @desc 找hSolution解决方案 (参考25014-H & 25015-6);
 *  _param endBranch : hDemand目标alg所在的fo (即hDemand.baseA.baseF);
 *  @version
 *      2021.11.25: 由旧有action._Hav第3级迁移而来;
 *      2021.12.25: 迭代hSolution (参考25014-H & 25015-6);
 *      2022.01.09: 达到limit条时的处理;
 *      2022.01.09: 首条就是HAlg不能做H解决方案 (参考25057);
 *      2022.05.04: 树限宽也限深 (参考2523c-分析代码1);
 *      2022.05.22: 窄出排序方式改为有效率为准 (参考26095-9);
 *      2022.05.31: 支持快慢思考 (参考26161 & 26162);
 */
+(void) hSolution:(HDemandModel*)hDemand{
    //0. S数达到limit时设为WithOut;
    OFTitleLog(@"hSolution", @"\n目标:%@ 已有S数:%ld",Pit2FStr(hDemand.baseOrGroup.content_p),hDemand.actionFoModels.count);
    
    //1. 树限宽且限深;
    NSInteger deepCount = [TOUtils getBaseDemandsDeepCount:hDemand];
    if (deepCount >= cDemandDeepLimit || hDemand.actionFoModels.count >= cSolutionNarrowLimit) {
        hDemand.status = TOModelStatus_WithOut;
        NSLog(@"%lld score from 5",theTC.getLoopId);
        [TCScore score];
        NSLog(@"------->>>>>> hSolution 已达limit条");
        return;
    }
    [theTC updateOperCount];
    Debug();
    
    //1. 数据准备;
    NSArray *except_ps = [TOUtils convertPointersFromTOModels:hDemand.actionFoModels];
    
    //3. 前3条,优先快思考;
    AISolutionModel *bestResult = nil;
    if (hDemand.actionFoModels.count <= 3) {
        bestResult = [TCSolutionUtil hSolution_Fast:hDemand except_ps:except_ps];
    }
    
    //4. 快思考无果或后2条,再做慢思考;
    if (!bestResult) {
        bestResult = [self hSolution_Slow:hDemand except_ps:except_ps];
    }
    
    //8. 新解决方案_的结果处理;
    DebugE();
    if (bestResult) {
        //8. 消耗活跃度;
        if (![theTC energyValid]) return;
        [theTC updateEnergyDelta:-1];
        
        //a) 下一方案成功时,并直接先尝试Action行为化,下轮循环中再反思综合评价等 (参考24203-2a);
        TOFoModel *foModel = [TOFoModel newWithFo_p:bestResult.cansetFo base:hDemand];
        foModel.actionIndex = bestResult.cutIndex;
        foModel.targetSPIndex = bestResult.targetIndex;
        NSLog(@"> newH 第%ld例: %@ (cutIndex:%ld=>targetIndex:%ld)",hDemand.actionFoModels.count,Pit2FStr(bestResult.cansetFo),bestResult.cutIndex,bestResult.targetIndex);
        
        //a) 有效率;
        [TCEffect hEffect:foModel];
        [theTV updateFrame];
        [TCAction action:foModel];
    }else{
        //b) 下一方案失败时,标记withOut,并下轮循环 (竞争末枝转Action) (参考24203-2b);
        hDemand.status = TOModelStatus_WithOut;
        NSLog(@">>>>>> hSolution 无计可施");
        NSLog(@"%lld score from 4",theTC.getLoopId);
        [TCScore score];
    }
}

/**
 *  MARK:--------------------H慢思考--------------------
 *  @desc 前段匹配,加工后段,H目标静默;
 *  @version
 *      2022.06.04: 修复结果与当前场景相差甚远BUG: 分三级排序窄出 (参考26194 & 26195);
 */
+(AISolutionModel*) hSolution_Slow:(HDemandModel *)hDemand except_ps:(NSArray*)except_ps{
    //0. 数据准备;
    except_ps = ARRTOOK(except_ps);
    AISolutionModel *result = nil;
    TOFoModel *targetFoModel = (TOFoModel*)hDemand.baseOrGroup.baseOrGroup;
    AIFoNodeBase *targetFo = [SMGUtils searchNode:targetFoModel.content_p];
    
    //1. 取absPFos
    NSArray *absFos = Ports2Pits([AINetUtils absPorts_All:targetFo]);
    absFos = [SMGUtils removeRepeat:absFos];
    NSLog(@"第1步 absFos数:%ld",absFos.count);//测时10条
    
    //2. 取同级;
    NSArray *sameLayerFos = [SMGUtils convertArr:absFos convertItemArrBlock:^NSArray *(AIKVPointer *obj) {
        AIFoNodeBase *absFo = [SMGUtils searchNode:obj];
        return Ports2Pits([AINetUtils conPorts_All:absFo]);
    }];
    sameLayerFos = [SMGUtils removeRepeat:sameLayerFos];
    NSLog(@"第2步 sameLayerFos数:%ld",sameLayerFos.count);//测时749条
    
    //3. 收集起来 (参考26161-0);
    NSMutableArray *cansetFos = [[NSMutableArray alloc] init];
    [cansetFos addObject:targetFo.pointer];
    [cansetFos addObjectsFromArray:absFos];
    [cansetFos addObjectsFromArray:sameLayerFos];
    cansetFos = [SMGUtils removeRepeat:cansetFos];
    NSLog(@"第3步 cansetFos数:%ld",cansetFos.count);//测时758条
    
    //4. 过滤掉长度<2的 (因为前段全含至少要1位,后段修正也至少要0位,H目标至少要1位)
    cansetFos = [SMGUtils filterArr:cansetFos checkValid:^BOOL(AIKVPointer *item) {
        AIFoNodeBase *fo = [SMGUtils searchNode:item];
        return fo.count >= 2;
    }];
    NSLog(@"第4步 最小长度2:%ld",cansetFos.count);//测时149条
    
    //4. 过滤掉有负mv指向的 (参考26063 & 26127-TODO8);
    cansetFos = [SMGUtils filterArr:cansetFos checkValid:^BOOL(AIKVPointer *item) {
        AIFoNodeBase *fo = [SMGUtils searchNode:item];
        return ![ThinkingUtils havDemand:fo.cmvNode_p];
    }];
    NSLog(@"第5步 非负价值:%ld",cansetFos.count);//测时96条
    
    //5. 对比cansetFo和targetFo匹配,得出对比结果 (参考26161-1&2&3);
    NSArray *solutionModels = [SMGUtils convertArr:cansetFos convertBlock:^id(AIKVPointer *obj) {
        return [TOUtils compareHCansetFo:obj targetFo:targetFoModel];
    }];
    NSLog(@"第6步 对比匹配成功:%ld",solutionModels.count);//测时94条
    
    //7. 排除不应期;
    solutionModels = [SMGUtils filterArr:solutionModels checkValid:^BOOL(AISolutionModel *item) {
        return ![except_ps containsObject:item.cansetFo];
    }];
    NSLog(@"第7步 排除不应期:%ld",solutionModels.count);//测时xx条
    
    //8. 对下一帧做时间不急评价: 不急 = 解决方案所需时间 <= 父任务能给的时间 (参考:24057-方案3,24171-7);
    solutionModels = [SMGUtils filterArr:solutionModels checkValid:^BOOL(AISolutionModel *item) {
        return [AIScore FRS_Time:hDemand solutionModel:item];
    }];
    NSLog(@"第8步 排除FRSTime来不及的:%ld",solutionModels.count);//测时xx条
    
    //6. 计算衰后stableScore (参考26161-5);
    NSArray *outOfFos = [SMGUtils convertArr:solutionModels convertBlock:^id(AISolutionModel *obj) {
        return obj.cansetFo;
    }];
    for (AISolutionModel *model in solutionModels) {
        AIFoNodeBase *cansetFo = [SMGUtils searchNode:model.cansetFo];
        model.stableScore = [TOUtils getColStableScore:cansetFo outOfFos:outOfFos startSPIndex:model.cutIndex + 1 endSPIndex:model.targetIndex];
    }
    
    //7. 根据候选集综合分排序 (参考26161-4);
    NSArray *sortModels = [TOUtils solutionSlow_SortNarrow:solutionModels needBack:true];
    
    //8. 取最佳解决方案;
    result = ARR_INDEX(sortModels, 0);
    
    //12. debugLog
    for (AISolutionModel *model in sortModels) {
        CGFloat solutionScore = model.stableScore * model.frontMatchValue * model.backMatchValue;
        AIFoNodeBase *cansetFo = [SMGUtils searchNode:model.cansetFo];
        if (Log4Solution_Slow) NSLog(@"> %@\n\t评分:%.2f = 前匹配:%.2f x 中稳定:%.2f x 后相近:%.2f >> %@",Pit2FStr(model.cansetFo),solutionScore,model.frontMatchValue,model.stableScore,model.backMatchValue,CLEANSTR(cansetFo.spDic));
    }
    AIFoNodeBase *resultFo = [SMGUtils searchNode:result.cansetFo];
    NSLog(@"取得慢思考最佳结果:F%ld 评分 = 前匹配:%.2f x 中稳定:%.2f x后相近:%.2f %@",result.cansetFo.pointerId,result.frontMatchValue,result.stableScore,result.backMatchValue,CLEANSTR(resultFo.spDic));
    return result;
}

@end
