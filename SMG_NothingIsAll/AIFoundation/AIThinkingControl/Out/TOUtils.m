//
//  TOUtils.m
//  SMG_NothingIsAll
//
//  Created by jia on 2020/4/2.
//  Copyright © 2020年 XiaoGang. All rights reserved.
//

#import "TOUtils.h"

@implementation TOUtils

+(BOOL) mIsC:(AIKVPointer*)m c:(AIKVPointer*)c layerDiff:(int)layerDiff{
    if (layerDiff == 0) return [self mIsC_0:m c:c];
    if (layerDiff == 1) return [self mIsC_1:m c:c];
    if (layerDiff == 2) return [self mIsC_2:m c:c];
    return false;
}
+(BOOL) mIsC_0:(AIKVPointer*)m c:(AIKVPointer*)c{
    if (m && c) {
        //1. 判断本级相等;
        BOOL equ0 = [m isEqual:c];
        if (equ0) return true;
    }
    return false;
}
+(BOOL) mIsC_1:(AIKVPointer*)m c:(AIKVPointer*)c{
    if (m && c) {
        //1. 判断本级相等;
        if ([self mIsC_0:m c:c]) return true;
        
        //2. 判断一级抽象;
        NSArray *mAbs = [SMGUtils convertPointersFromPorts:[AINetUtils absPorts_All:[SMGUtils searchNode:m]]];
        BOOL equ1 = [mAbs containsObject:c];
        if (equ1) return true;
    }
    return false;
}
+(BOOL) mIsC_2:(AIKVPointer*)m c:(AIKVPointer*)c{
    if (m && c) {
        //1. 判断0-1级抽象;
        if ([self mIsC_1:m c:c]) return true;
        
        //2. 判断二级抽象;
        NSArray *mAbs = [SMGUtils convertPointersFromPorts:[AINetUtils absPorts_All:[SMGUtils searchNode:m]]];
        NSArray *cCon = [SMGUtils convertPointersFromPorts:[AINetUtils conPorts_All:[SMGUtils searchNode:c]]];
        BOOL equ2 = [SMGUtils filterSame_ps:mAbs parent_ps:cCon].count > 0;
        if (equ2) return true;
    }
    return false;
}

+(BOOL) mIsC_1:(NSArray*)ms cs:(NSArray*)cs{
    ms = ARRTOOK(ms);
    cs = ARRTOOK(cs);
    for (AIKVPointer *c in cs) {
        for (AIKVPointer *m in ms) {
            if ([TOUtils mIsC_1:m c:c]) {
                return true;
            }
        }
    }
    return false;
}

/**
 *  MARK:--------------------判断indexOf (支持本级+一级抽象)--------------------
 *  @bug 2020.06.12 : TOR.R-中firstAt_Plus取值为-1,经查因为mIsC方法取absPorts_Normal,对plus/sub不支持导致,改后好了;
 *  @version
 *      2020.09.10: 支持layerDiff和startIndex;
 *
 */
+(NSInteger) indexOfAbsItem:(AIKVPointer*)absItem atConContent:(NSArray*)conContent{
    return [self indexOfAbsItem:absItem atConContent:conContent layerDiff:1 startIndex:0 endIndex:NSUIntegerMax];
}

//absItem是content中的抽象一员,返回index;
+(NSInteger) indexOfAbsItem:(AIKVPointer*)absItem atConContent:(NSArray*)conContent layerDiff:(int)layerDiff startIndex:(NSInteger)startIndex endIndex:(NSInteger)endIndex{
    conContent = ARRTOOK(conContent);
    endIndex = MIN(endIndex, conContent.count - 1);
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        AIKVPointer *item_p = ARR_INDEX(conContent, i);
        if ([TOUtils mIsC:item_p c:absItem layerDiff:layerDiff]) {
            return i;
        }
    }
    return -1;
}

//conItem是content中的具象一员,返回index;
+(NSInteger) indexOfConItem:(AIKVPointer*)conItem atAbsContent:(NSArray*)content layerDiff:(int)layerDiff startIndex:(NSInteger)startIndex endIndex:(NSInteger)endIndex{
    content = ARRTOOK(content);
    endIndex = MIN(endIndex, content.count - 1);
    for (NSInteger i = startIndex; i <= endIndex; i++) {
        AIKVPointer *item_p = ARR_INDEX(content, i);
        if ([TOUtils mIsC:conItem c:item_p layerDiff:layerDiff]) {
            return i;
        }
    }
    return -1;
}

//conItem是content中的具象或抽象一员,返回index;
+(NSInteger) indexOfConOrAbsItem:(AIKVPointer*)item atContent:(NSArray*)content layerDiff:(int)layerDiff startIndex:(NSInteger)startIndex endIndex:(NSInteger)endIndex{
    NSInteger findIndex = [TOUtils indexOfAbsItem:item atConContent:content layerDiff:layerDiff startIndex:startIndex endIndex:endIndex];
    if (findIndex == -1) {
        findIndex = [TOUtils indexOfConItem:item atAbsContent:content layerDiff:layerDiff startIndex:startIndex endIndex:endIndex];
    }
    return findIndex;
}


//MARK:===============================================================
//MARK:                     < 从TO短时记忆取demand >
//MARK:===============================================================
/**
 *  MARK:--------------------获取subOutModel的demand--------------------
 */
+(DemandModel*) getRootDemandModelWithSubOutModel:(TOModelBase*)subOutModel{
    NSMutableArray *demands = [self getBaseDemands_AllDeep:subOutModel];
    return ARR_INDEX_REVERSE(demands, 0);
}

/**
 *  MARK:--------------------向着某方向取所有demands--------------------
 *  @version
 *      2021.06.01: 因为R子任务时baseOrGroup为空,导致链条中断获取不全的BUG修复 (参考23094);
 *      2021.06.01: 支持getSubDemands_AllDeep (子方向);
 *  @result 含子任务和root任务 notnull;
 *  @rank : base在后,sub在前;
 */
+(NSMutableArray*) getBaseDemands_AllDeep:(TOModelBase*)subModel{
    return [SMGUtils filterArr:[self getBaseOutModels_AllDeep:subModel] checkValid:^BOOL(id item) {
        return ISOK(item, DemandModel.class);
    }];
}
+(NSInteger) getBaseDemandsDeepCount:(TOModelBase*)subModel{
    return [self getBaseDemands_AllDeep:subModel].count;
}

/**
 *  MARK:--------------------获取rDemand的来源同伴--------------------
 *  @version
 *      2022.03.23: 初版 (参考25184-方案2-分析);
 *  @result notnull
 */
//+(NSArray*) getSeemFromIdenRDemands:(ReasonDemandModel*)rDemand{
//    //1. 数据准备;
//    NSString *fromIden = STRTOOK(rDemand.fromIden);
//    NSMutableArray *result = [[NSMutableArray alloc] init];
//
//    //2. 分别从root出发,收集同fromIden的RDemands;
//    for (DemandModel *item in theTC.outModelManager.getAllDemand) {
//        NSArray *subs = [self getSubOutModels_AllDeep:item validStatus:nil cutStopStatus:nil];
//        NSArray *validSubs = [SMGUtils filterArr:subs checkValid:^BOOL(ReasonDemandModel *sub) {
//            return ISOK(sub, ReasonDemandModel.class) && [fromIden isEqualToString:sub.fromIden];
//        }];
//        [result addObjectsFromArray:validSubs];
//    }
//result = [SMGUtils filterArr:result checkValid:^BOOL(ReasonDemandModel *item) {
//    AIFoNodeBase *itemFo = [SMGUtils searchNode:item.mModel.matchFo];
//    AIFoNodeBase *demandFo = [SMGUtils searchNode:demand.mModel.matchFo];
//    return [demandFo.cmvNode_p.identifier isEqualToString:itemFo.cmvNode_p.identifier];
//}];
//    return result;
//}


//MARK:===============================================================
//MARK:                     < 从TO短时记忆取outModel >
//MARK:===============================================================
+(NSArray*) getSubOutModels_AllDeep:(TOModelBase*)outModel validStatus:(NSArray*)validStatus{
    return [self getSubOutModels_AllDeep:outModel validStatus:validStatus cutStopStatus:@[@(TOModelStatus_Finish)]];
}
+(NSArray*) getSubOutModels_AllDeep:(TOModelBase*)outModel validStatus:(NSArray*)validStatus cutStopStatus:(NSArray*)cutStopStatus{
    //1. 数据准备
    validStatus = ARRTOOK(validStatus);
    cutStopStatus = ARRTOOK(cutStopStatus);
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (!outModel) return result;
    
    //2. 收集当前 (当valid为空时,全收集);
    if (!ARRISOK(validStatus) || [validStatus containsObject:@(outModel.status)]) {
        [result addObject:outModel];
    }
    
    //3. Finish负责截停递归;
    if (![cutStopStatus containsObject:@(outModel.status)]) {
        
        //3. 找出子集
        NSMutableArray *subs = [self getSubOutModels:outModel];
        
        //4. 递归收集子集;
        for (TOModelBase *sub in subs) {
            [result addObjectsFromArray:[self getSubOutModels_AllDeep:sub validStatus:validStatus cutStopStatus:cutStopStatus]];
        }
    }
    return result;
}

/**
 *  MARK:--------------------获取子models--------------------
 *  @version
 *      2021.06.03: 将实现接口判断,改为使用conformsToProtocol,而非判断类名 (因为类名方式有新的类再实现后,易出bug);
 *  @result notnull
 */
+(NSMutableArray*) getSubOutModels:(TOModelBase*)outModel {
    //1. 数据准备
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (!outModel) return result;
    
    //2. 找出子集 (Finish负责截停递归);
    if ([outModel conformsToProtocol:@protocol(ITryActionFoDelegate)]) {
        id<ITryActionFoDelegate> tryActionObj = (id<ITryActionFoDelegate>)outModel;
        [result addObjectsFromArray:tryActionObj.actionFoModels];
    }
    if ([outModel conformsToProtocol:@protocol(ISubModelsDelegate)]) {
        id<ISubModelsDelegate> subModelsObj = (id<ISubModelsDelegate>)outModel;
        [result addObjectsFromArray:subModelsObj.subModels];
    }
    if ([outModel conformsToProtocol:@protocol(ISubDemandDelegate)]) {
        id<ISubDemandDelegate> subDemandsObj = (id<ISubDemandDelegate>)outModel;
        [result addObjectsFromArray:subDemandsObj.subDemands];
    }
    return result;
}

+(NSMutableArray*) getBaseOutModels_AllDeep:(TOModelBase*)subModel{
    //1. 数据准备;
    NSMutableArray *result = [[NSMutableArray alloc] init];
    if (!subModel) return result;
    
    //2. 向base取;
    TOModelBase *checkModel = subModel;
    while (checkModel) {
        [result addObject:checkModel];
        checkModel = checkModel.baseOrGroup;
    }
    return result;
}

//MARK:===============================================================
//MARK:                     < convert >
//MARK:===============================================================

/**
 *  MARK:--------------------将TOModels转为Pointers--------------------
 *  @result notnull
 */
+(NSMutableArray*) convertPointersFromTOModels:(NSArray*)toModels{
    //1. 收集返回 (不收集content_p为空的部分,如:TOValueModel的目标pValue有时为空);
    return [SMGUtils convertArr:toModels convertBlock:^id(TOModelBase *obj) {
        return obj.content_p;
    }];
}

/**
 *  MARK:--------------------是否HNGL节点--------------------
 *  @version
 *      2020.12.16: 增加toAlgModel判断的重载 (因为21115的改动,hngl并不直接由alg判断,而是由fo来判断);
 *  @bug
 *      2020.12.24: isL写成了isN,导致L节点无法判定为HNGL,也导致无法ActYes并触发反省类比;
 */
+(BOOL) isHNGL:(AIKVPointer*)p{
    return [self isH:p] || [self isN:p] || [self isG:p] || [self isL:p];
}
+(BOOL) isHNGLSP:(AIKVPointer*)p{
    return [self isH:p] || [self isN:p] || [self isG:p] || [self isL:p] || [self isS:p] || [self isP:p];
}
+(BOOL) isH:(AIKVPointer*)p{
    return p && p.type == ATHav;
}
+(BOOL) isN:(AIKVPointer*)p{
    return p && p.type == ATNone;
}
+(BOOL) isG:(AIKVPointer*)p{
    return p && p.type == ATGreater;
}
+(BOOL) isL:(AIKVPointer*)p{
    return p && p.type == ATLess;
}
+(BOOL) isS:(AIKVPointer*)p{
    return p && p.type == ATSub;
}
+(BOOL) isP:(AIKVPointer*)p{
    return p && p.type == ATPlus;
}

/**
 *  MARK:--------------------求fo的deltaTime之和--------------------
 */
//从cutIndex取到mvDeltaTime;
+(double) getSumDeltaTime2Mv:(AIFoNodeBase*)fo cutIndex:(NSInteger)cutIndex{
    return [self getSumDeltaTime:fo startIndex:cutIndex endIndex:fo.count];
}

/**
 *  MARK:--------------------获取指定获取的deltaTime之和--------------------
 *  _param startIndex   : 下标(不含);
 *  _param endIndex     : 下标(含);
 *  @templete : 如[0,1,2,3],因不含s和含e,取1到3位时,得出结果应该是2+3=5,即range应该是(2到4),所以range=(s+1,e-s);
 *  @bug
 *      2020.09.10: 原来取range(s,e-s)不对,更正为:range(s+1,e-s);
 */
+(double) getSumDeltaTime:(AIFoNodeBase*)fo startIndex:(NSInteger)startIndex endIndex:(NSInteger)endIndex{
    double result = 0;
    if (fo) {
        //1. 累计deltaTimes中值;
        NSArray *valids = ARR_SUB(fo.deltaTimes, startIndex + 1, endIndex - startIndex);
        for (NSNumber *valid in valids) {
            result += [valid doubleValue];
        }
        
        //2. 累计mvDeltaTime值;
        if (endIndex >= fo.count) {
            result += fo.mvDeltaTime;
        }
    }
    return result;
}

+(NSString*) toModel2Key:(TOModelBase*)toModel{
    return STRFORMAT(@"%p_%@",toModel,Pit2FStr(toModel.content_p));
}

/**
 *  MARK:--------------------effectDic的HN求和--------------------
 */
+(NSRange) getSumEffectHN:(NSDictionary*)effectDic{
    int sumH = 0,sumN = 0;
    for (NSArray *value in effectDic.allValues) {
        for (AIEffectStrong *strong in value) {
            sumH += strong.hStrong;
            sumN += strong.nStrong;
        }
    }
    return NSMakeRange(sumH, sumN);
}

/**
 *  MARK:--------------------稳定性评分--------------------
 *  @desc 根据SP计算"稳定性"分 (稳定性指顺,就是能顺利发生的率);
 *  @version
 *      2022.05.23: 初版 (参考26096-BUG1);
 *      2022.06.02: 每一帧的稳定性默认为0.5,而不是1 (参考26191);
 *  @result 1. 负价值时序时返回多坏(0-1);
 *          2. 正价值时序时返回多好(0-1);
 *          3. 无价值时序时返回多顺(0-1);
 */
+(CGFloat) getStableScore:(AIFoNodeBase*)fo startSPIndex:(NSInteger)startSPIndex endSPIndex:(NSInteger)endSPIndex{
    //1. 数据检查 & 稳定性默认为1分 & 正负mv的公式是不同的 (参考25122-公式);
    if (!fo) return 0;
    CGFloat totalSPScore = 1.0f;
    BOOL isBadMv = [ThinkingUtils havDemand:fo.cmvNode_p];
    
    //2. 从start到end各计算spScore;
    for (NSInteger i = startSPIndex; i <= endSPIndex; i++) {
        AISPStrong *spStrong = [fo.spDic objectForKey:@(i)];
        
        //3. 当sp经历都为0条时 (正mv时,表示多好评分 | 负mv时,表示多坏评分) 默认评分都为0.5;
        CGFloat itemSPScore = 0.5f;
        
        //4. SP有效且其中之一不为0时,计算稳定性评分;
        if (spStrong && spStrong.pStrong + spStrong.sStrong > 0) {
            
            //4. 取"多好"程度;
            CGFloat pRate = spStrong.pStrong / (float)(spStrong.sStrong + spStrong.pStrong);
            
            //5.1 在感性的负mv时,itemSPScore = 1 - pRate (参考25122-负公式);
            if (i == fo.count && isBadMv) {
                itemSPScore = 1 - pRate;
            }else{
                
                //5.2 在理性评分中,pStrong表示顺利程度,与mv正负成正比;
                //5.3 在感性正mv时,pRate与它的稳定性评分一致;
                itemSPScore = pRate;
            }
        }
        
        //6. 将itemSPScore计入综合评分 (参考25114 & 25122-公式);
        totalSPScore *= itemSPScore;
    }
    
    //9. 返回SP评分 (多坏或多好);
    return totalSPScore;
}

/**
 *  MARK:--------------------SP好坏评分--------------------
 *  @desc 根据综合稳定性计算"多好"评分 (参考25114 & 25122-负公式);
 *  @version
 *      2022.02.20: 改为综合评分,替代掉RSResultModelBase;
 *      2022.02.22: 修复明明S有值,P为0,但综评为1分的问题 (||写成了&&导致的);
 *      2022.02.24: 支持负mv时序的稳定性评分公式 (参考25122-负公式);
 *      2022.02.24: 修复因代码逻辑错误,导致负mv在全顺状态下,评为1分的BUG (修复: 明确itemSPScore的定义,整理代码后ok);
 *      2022.05.02: 修复因Int值类型,导致返回result只可能是0或1的问题;
 *      2022.05.14: 当SP全为0时,默认返回0.5 (参考26026-BUG2);
 *  @result 返回spScore稳定性综合评分: 越接近1分越好,越接近0分越差;
 */
+(CGFloat) getSPScore:(AIFoNodeBase*)fo startSPIndex:(NSInteger)startSPIndex endSPIndex:(NSInteger)endSPIndex{
    //1. 获取稳定性评分;
    CGFloat stableScore = [self getStableScore:fo startSPIndex:startSPIndex endSPIndex:endSPIndex];
    
    //2. 负mv的公式是: 1-stableScore (参考25122-公式&负公式);
    BOOL isBadMv = [ThinkingUtils havDemand:fo.cmvNode_p];
    if (isBadMv) {
        stableScore = 1 - stableScore;
    }
    
    //3. 返回好坏评分;
    return stableScore;
}

/**
 *  MARK:--------------------有效率评分--------------------
 *  @desc 计算有效率性评分 (参考26095-8);
 *  @param demandFo     : R任务时传pFo即可, H任务时传hDemand.base.baseFo;
 *  @param effectIndex  : R任务时传demandFo.count, H任务时传hDemand.base.baseFo.actionIndex;
 *  @param solutionFo   : 用于检查有效率的solutionFo;
 *  @version
 *      2022.05.22: 初版,可返回解决方案的有效率 (参考26095-8);
 */
+(CGFloat) getEffectScore:(AIFoNodeBase*)demandFo effectIndex:(NSInteger)effectIndex solutionFo:(AIKVPointer*)solutionFo{
    AIEffectStrong *strong = [self getEffectStrong:demandFo effectIndex:effectIndex solutionFo:solutionFo];
    return [self getEffectScore:strong];
}
+(CGFloat) getEffectScore:(AIEffectStrong*)strong{
    if (strong) {
        if (strong.hStrong + strong.nStrong > 0) {
            return (float)strong.hStrong / (strong.hStrong + strong.nStrong);
        }else{
            return 0.0f;
        }
    }
    return 0;
}
+(AIEffectStrong*) getEffectStrong:(AIFoNodeBase*)demandFo effectIndex:(NSInteger)effectIndex solutionFo:(AIKVPointer*)solutionFo{
    //1. 取有效率解决方案数组;
    NSArray *strongs = ARRTOOK([demandFo.effectDic objectForKey:@(effectIndex)]);
    
    //2. 取得匹配的strong;
    AIEffectStrong *strong = [SMGUtils filterSingleFromArr:strongs checkValid:^BOOL(AIEffectStrong *item) {
        return [item.solutionFo isEqual:solutionFo];
    }];
    
    //3. 返回有效率;
    return strong;
}
+(NSString*) getEffectDesc:(AIFoNodeBase*)demandFo effectIndex:(NSInteger)effectIndex solutionFo:(AIKVPointer*)solutionFo{
    AIEffectStrong *strong = [self getEffectStrong:demandFo effectIndex:effectIndex solutionFo:solutionFo];
    return STRFORMAT(@"%ld/%ld",strong.hStrong,strong.hStrong + strong.nStrong);
}

//MARK:===============================================================
//MARK:                     < 衰减曲线 >
//MARK:===============================================================

/**
 *  MARK:--------------------获取fo衰减后的值--------------------
 *  @param fo_p         : 计算fo的衰减后的值;
 *  @param outOfFo_ps   : fo的竞争者 (包含fo);
 *  @desc 使用牛顿冷却函数,步骤说明:
 *      1. 根据F指针地址排序,比如(F1,F3,F5,F7,F9)
 *      2. 默认衰减时间为F总数,即5;
 *      3. 当sp强度都为1时,最新的F9为热度为1,最旧的F1热度为minValue;
 *      4. 当sp强度>1时,衰减时长 = 默认时长5 * 根号sp强度;
 *  @version
 *      2022.05.24: 初版,用于解决fo的衰减,避免时序识别时,明明fo很老且SP都是0,却可以排在很前面 (参考26104-方案);
 */
+(double) getColValue:(AIKVPointer*)fo_p outOfFos:(NSArray*)outOfFo_ps {
    //0. 数据检查;
    if (!fo_p || ![outOfFo_ps containsObject:fo_p]) {
        return 1.0f;
    }
    
    //1. 对fos排序 & 计算衰减区 (从1到minValue的默认区间: 即每强度系数单位可支撑区间);
    outOfFo_ps = [SMGUtils sortBig2Small:outOfFo_ps compareBlock:^double(AIKVPointer *obj) {
        return obj.pointerId;
    }];
    float defaultColSpace = outOfFo_ps.count;
    
    //2. 计算fo的sp强度系数 (总强度 + 1,然后开根号);
    AIFoNodeBase *fo = [SMGUtils searchNode:fo_p];
    int sumSPStrong = 1;
    for (AISPStrong *item in fo.spDic.allValues) sumSPStrong += (item.sStrong + item.pStrong);
    float strongXiSu = sqrtf(sumSPStrong);
    
    //3. fo的实际衰减区间 (默认区间 x 强度系数);
    float colSpace = defaultColSpace * strongXiSu;
    
    //4. 衰减系数 (在colTime结束后,衰减到最小值);
    float minValue = 0.1f;
    double colXiSu = log(minValue) / colSpace;
    
    //5. 取当前fo的age & 计算牛顿衰减后的值;
    NSInteger foAge = [outOfFo_ps indexOfObject:fo_p];
    double result = exp(colXiSu * foAge);
    return result;
}

/**
 *  MARK:--------------------获取衰减后的稳定性--------------------
 */
+(CGFloat) getColStableScore:(AIFoNodeBase*)fo outOfFos:(NSArray*)outOfFo_ps startSPIndex:(NSInteger)startSPIndex endSPIndex:(NSInteger)endSPIndex {
    double colValue = [TOUtils getColValue:fo.pointer outOfFos:outOfFo_ps];
    CGFloat stableScore = [TOUtils getStableScore:fo startSPIndex:startSPIndex endSPIndex:endSPIndex];
    return colValue * stableScore;
}

/**
 *  MARK:--------------------获取衰减后的SP好坏评分--------------------
 */
+(CGFloat) getColSPScore:(AIFoNodeBase*)fo outOfFos:(NSArray*)outOfFo_ps startSPIndex:(NSInteger)startSPIndex endSPIndex:(NSInteger)endSPIndex{
    CGFloat stableScore = [self getColStableScore:fo outOfFos:outOfFo_ps startSPIndex:startSPIndex endSPIndex:endSPIndex];
    return [ThinkingUtils havDemand:fo.cmvNode_p] ? 1 - stableScore : stableScore;
}

//MARK:===============================================================
//MARK:                     < 思考算法 >
//MARK:===============================================================

/**
 *  MARK:--------------------时序对比--------------------
 *  @desc 初步对比候选集是否适用于protoFo (参考26128-第1步);
 *  @result 返回cansetFo前段匹配度 & 以及已匹配的cutIndex截点;
 *  @version
 *      2022.05.30: 匹配度公式改成: 匹配度总和/proto长度 (参考26128-1-4);
 *      2022.05.30: R和H模式复用封装 (参考26161);
 */
+(AISolutionModel*) compareRCansetFo:(AIKVPointer*)cansetFo_p protoFo:(AIKVPointer*)protoFo_p {
    //1. 数据准备;
    AIFoNodeBase *maskFo = [SMGUtils searchNode:protoFo_p];
    
    //2. 已发生个数 (protoFo所有都是已发生) (参考26128-模型);
    NSInteger maskAleardayCount = maskFo.count;
    
    //3. 匹配判断;
    return [self compareCansetFo:cansetFo_p maskFo:maskFo maskAleardayCount:maskAleardayCount needBackMatch:false];
}

+(AISolutionModel*) compareHCansetFo:(AIKVPointer*)cansetFo_p targetFo:(TOFoModel*)targetFoM {
    //1. 数据准备;
    AIFoNodeBase *maskFo = [SMGUtils searchNode:targetFoM.content_p];
    
    //2. 已发生个数 (targetFo已行为化部分即已发生) (参考26161-模型);
    NSInteger maskAleardayCount = targetFoM.actionIndex;
    
    //3. 匹配判断;
    return [self compareCansetFo:cansetFo_p maskFo:maskFo maskAleardayCount:maskAleardayCount needBackMatch:true];
}

/**
 *  MARK:--------------------对比时序--------------------
 *  _param maskFo               : R时传入protoFo; H时传入targetFo;
 *  @param maskAleardayCount    : mask已发生个数 (R.proto全已发生,H.actionIndex前已发生);
 *  @param needBackMatch        : 是否需要后段匹配 (R不需要,H需要);
 */
+(AISolutionModel*) compareCansetFo:(AIKVPointer*)cansetFo_p maskFo:(AIFoNodeBase*)maskFo maskAleardayCount:(NSInteger)maskAleardayCount needBackMatch:(BOOL)needBackMatch{
    //1. 数据准备;
    AISolutionModel *result = nil;
    AIFoNodeBase *cansetFo = [SMGUtils searchNode:cansetFo_p];
    NSInteger lastMatchAtProtoIndex = -1;   //proto的匹配进度;
    CGFloat sumMatchValue = 0;              //累计匹配度;
    NSInteger cansetCutIndex = -1;          //canset的cutIndex,也已在proto中发生;
    
    //2. 前段: cansetFo从前到后,分别在proto中找匹配;
    for (NSInteger i = 0; i < cansetFo.count; i++) {
        AIKVPointer *cansetA_p = ARR_INDEX(cansetFo.content_ps, i);
        CGFloat itemMatchValue = 0;
        
        //3. 继续从proto后面未找过的部分里,找匹配;
        for (NSInteger j = lastMatchAtProtoIndex + 1; j < maskAleardayCount; j++) {
            AIKVPointer *protoA_p = ARR_INDEX(maskFo.content_ps, j);
            
            //4. 对比两个概念匹配度;
            itemMatchValue = [self compareCansetAlg:cansetA_p protoAlg:protoA_p];
            
            //5. 匹配成功,则更新匹配进度,并break报喜;
            if (itemMatchValue > 0) {
                lastMatchAtProtoIndex = j;
                break;
            }
        }
        
        //6. 匹配成功时: 结算这一位,继续下一位;
        if (itemMatchValue > 0) {
            sumMatchValue += itemMatchValue;
        }else{
            //7. 前中段截点: 匹配不到时,说明前段结束,前段proto全含canset,到cansetCutIndex为截点 (参考26128-1-1);
            cansetCutIndex = i - 1;
            break;
        }
    }
    
    //8. 计算前段匹配度 (参考26128-1-4);
    CGFloat frontMatchValue = sumMatchValue / maskAleardayCount;
    
    //9. 找到了`前中段`截点 => 则初步为有效方案 (参考26128-1-3);
    if (cansetCutIndex != -1 && frontMatchValue > 0) {
        
        //10. 后段: 从canset后段,找maskFo目标 (R不需要后段匹配,H需要);
        if (needBackMatch) {
            //a. 数据准备mask目标帧
            CGFloat backMatchValue = 0;//后段匹配度
            NSInteger cansetTargetIndex = -1;//canset目标下标
            AIKVPointer *actionIndexA_p = ARR_INDEX(maskFo.content_ps, maskAleardayCount);
            
            //b. 分别对canset后段,对比两个概念匹配度;
            for (NSInteger i = cansetCutIndex + 1; i < cansetFo.count; i++) {
                AIKVPointer *cansetA_p = ARR_INDEX(cansetFo.content_ps, i);
                CGFloat checkBackMatchValue = [self compareCansetAlg:cansetA_p protoAlg:actionIndexA_p];
                
                //c. 匹配成功时: 记下匹配度和目标下标;
                if (checkBackMatchValue > 0) {
                    backMatchValue = checkBackMatchValue;
                    cansetTargetIndex = i;
                    break;
                }
            }
            
            //d. 后段成功;
            if (cansetTargetIndex > -1) {
                result = [AISolutionModel newWithCansetFo:cansetFo_p maskFo:maskFo.pointer frontMatchValue:frontMatchValue backMatchValue:backMatchValue cutIndex:cansetCutIndex targetIndex:cansetTargetIndex];
            }
            if (!result) NSLog(@"itemCanset不适用当前场景:%ld",cansetFo_p.pointerId);
        }else{
            //11. 后段: R不判断后段;
            result = [AISolutionModel newWithCansetFo:cansetFo_p maskFo:maskFo.pointer frontMatchValue:frontMatchValue backMatchValue:1 cutIndex:cansetCutIndex targetIndex:cansetFo.count];
        }
    }
    return result;
}

/**
 *  MARK:--------------------对比两个概念匹配度--------------------
 *  @result 返回0到1 (0:完全不一样 & 1:完全一样) (参考26127-TODO5);
 */
+(CGFloat) compareCansetAlg:(AIKVPointer*)cansetAlg_p protoAlg:(AIKVPointer*)protoAlg_p{
    //1. 数据准备;
    AIAlgNodeBase *cansetAlg = [SMGUtils searchNode:cansetAlg_p];
    AIAlgNodeBase *protoAlg = [SMGUtils searchNode:protoAlg_p];
    AIKVPointer *cansetFirstV_p = ARR_INDEX(cansetAlg.content_ps, 0);
    AIKVPointer *protoFirstV_p = ARR_INDEX(protoAlg.content_ps, 0);
    NSString *cansetAT = cansetFirstV_p.algsType;
    NSString *protoAT = protoFirstV_p.algsType;
    
    //2. 先对比二者是否同区;
    if (![cansetAT isEqualToString:protoAT]) {
        return 0;
    }
    
    //3. 找出二者稀疏码同标识的;
    __block CGFloat sumNear = 0;
    for (AIKVPointer *cansetV in cansetAlg.content_ps) {
        for (AIKVPointer *protoV in protoAlg.content_ps) {
            if ([cansetV.dataSource isEqualToString:protoV.dataSource]) {
                
                //4. 对比稀疏码相近度 & 并累计;
                sumNear += [self compareCansetValue:cansetV protoValue:protoV];
            }
        }
    }
    return sumNear / protoAlg.count;
}

/**
 *  MARK:--------------------对比稀疏码相近度--------------------
 *  @result 返回0到1 (0:稀疏码完全不同, 1稀疏码完全相同) (参考26127-TODO6);
 */
+(CGFloat) compareCansetValue:(AIKVPointer*)cansetV_p protoValue:(AIKVPointer*)protoV_p{
    //1. 取稀疏码值;
    double cansetData = [NUMTOOK([AINetIndex getData:cansetV_p]) doubleValue];
    double protoData = [NUMTOOK([AINetIndex getData:protoV_p]) doubleValue];
    
    //2. 计算出nearV (参考25082-公式1);
    double delta = fabs(cansetData - protoData);
    double span = [AINetIndex getIndexSpan:protoV_p.algsType ds:protoV_p.dataSource isOut:protoV_p.isOut];
    double nearV = (span == 0) ? 1 : (1 - delta / span);
    return nearV;
}

/**
 *  MARK:--------------------慢思考排序窄出--------------------
 *  @desc 分三步排序窄出 (参考26194 & 26195);
 *  @param needBack : R时现不需要传false(backMatchValue全是1), H时需要传true;
 */
+(NSArray*) solutionSlow_SortNarrow:(NSArray*)solutionModels needBack:(BOOL)needBack{
    //1. 后匹配排序窄出 (取50% & 限制0-40) (参考26195-TODO1);
    if (needBack) {
        int backLimit = MAX(0, MIN(40, solutionModels.count * 0.5f));
        NSArray *backSorts = [SMGUtils sortBig2Small:solutionModels compareBlock:^double(AISolutionModel *obj) {
            return obj.backMatchValue;
        }];
        solutionModels = ARR_SUB(backSorts, 0, backLimit);
    }
    
    //2. 中稳定排序窄出 (取50% & 最小3-20) (参考26195-TODO2);
    int midLimit = MAX(0, MIN(40, solutionModels.count * 0.5f));
    NSArray *midSorts = [SMGUtils sortBig2Small:solutionModels compareBlock:^double(AISolutionModel *obj) {
        return obj.stableScore;
    }];
    solutionModels = ARR_SUB(midSorts, 0, midLimit);
    
    //3. 前匹配排序窄出 (取前3条) (参考26195-TODO3);
    int frontLimit = 3;
    NSArray *frontSorts = [SMGUtils sortBig2Small:solutionModels compareBlock:^double(AISolutionModel *obj) {
        return obj.stableScore;
    }];
    solutionModels = ARR_SUB(frontSorts, 0, frontLimit);
    
    //4. 返回;
    return solutionModels;
}

/**
 *  MARK:--------------------检查某toModel的末枝有没有ActYes状态--------------------
 *  @desc 因为actYes向上传染,不向下,所以末枝有actYes,即当前curModel也不应响应 (参考26184-原则);
 */
+(BOOL) endHavActYes:(TOModelBase*)curModel{
    NSArray *allSubModels = [TOUtils getSubOutModels_AllDeep:curModel validStatus:nil];
    BOOL endHavActYes = [SMGUtils filterSingleFromArr:allSubModels checkValid:^BOOL(TOModelBase *item) {
        return item.status == TOModelStatus_ActYes && [TOUtils getSubOutModels:item].count == 0;
    }];
    return endHavActYes;
}

/**
 *  MARK:--------------------将cansets中同fo的strong合并--------------------
 */
+(NSArray*) mergeCansets:(NSArray*)protoCansets{
    NSMutableDictionary *cansetsDic = [[NSMutableDictionary alloc] init];
    for (AIEffectStrong *item in protoCansets) {
        //a. 取旧;
        id key = @(item.solutionFo.pointerId);
        AIEffectStrong *old = [cansetsDic objectForKey:key];
        if (!old) old = [AIEffectStrong newWithSolutionFo:item.solutionFo];
        
        //b. 更新;
        old.hStrong += item.hStrong;
        old.nStrong += item.nStrong;
        [cansetsDic setObject:old forKey:key];
    }
    return cansetsDic.allValues;
}


@end
