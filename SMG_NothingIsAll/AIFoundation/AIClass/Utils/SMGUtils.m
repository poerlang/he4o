//
//  SMGUtils.m
//  SMG_NothingIsAll
//
//  Created by 贾  on 2017/4/19.
//  Copyright © 2017年 XiaoGang. All rights reserved.
//

#import "SMGUtils.h"
#import "AIKVPointer.h"
#import "PINCache.h"
#import "XGRedisUtil.h"
#import "AIPort.h"
#import "XGRedis.h"
#import "AIPointer.h"
#import "AIAlgNodeBase.h"
#import "XGWedis.h"
#import "ThinkingUtils.h"
#import "NSFile+Extension.h"

@implementation SMGUtils

//MARK:===============================================================
//MARK:                     < PointerId >
//MARK:===============================================================
+(NSInteger) createPointerId:(NSString*)algsType dataSource:(NSString*)dataSource{
    return [self createPointerId:true algsType:algsType dataSource:dataSource];
}

+(NSInteger) createPointerId:(BOOL)updateLastId algsType:(NSString*)algsType dataSource:(NSString*)dataSource{
    NSInteger lastId = [SMGUtils getLastNetNodePointerId:algsType dataSource:dataSource];
    if (updateLastId) {
        [SMGUtils setNetNodePointerId:1 algsType:algsType dataSource:dataSource];
    }
    return lastId + 1;
}

+(NSInteger) getLastNetNodePointerId:(NSString*)algsType dataSource:(NSString*)dataSource{
    return [[NSUserDefaults standardUserDefaults] integerForKey:STRFORMAT(@"AIPointer_LastNetNodePointerId_KEY_%@_%@",algsType,dataSource)];
}

+(void) setNetNodePointerId:(NSInteger)count algsType:(NSString*)algsType dataSource:(NSString*)dataSource{
    NSInteger lastPId = [self getLastNetNodePointerId:algsType dataSource:dataSource];
    [[NSUserDefaults standardUserDefaults] setInteger:lastPId + count forKey:STRFORMAT(@"AIPointer_LastNetNodePointerId_KEY_%@_%@",algsType,dataSource)];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

//MARK:===============================================================
//MARK:                     < AIPointer >
//MARK:===============================================================

//General指针
+(AIKVPointer*) createPointer:(NSString*)folderName algsType:(NSString*)algsType dataSource:(NSString*)dataSource isOut:(BOOL)isOut isMem:(BOOL)isMem type:(AnalogyType)type{
    NSInteger pointerId = [SMGUtils createPointerId:algsType dataSource:dataSource];
    
    //TODOTOMORROW: 查20151-BUG9 (此处新指针有重复,导致问题);
    if ([kPN_CMV_NODE isEqualToString:folderName] || [kPN_ABS_CMV_NODE isEqualToString:folderName]) {
        WLog(@"---------引用强度BUG-mv新指针:%ld",pointerId);
        HeLog(@"---------引用强度BUG-mv新指针:%ld",pointerId);
    }
    AIKVPointer *kvPointer = [AIKVPointer newWithPointerId:pointerId folderName:folderName algsType:algsType dataSource:dataSource isOut:isOut isMem:isMem type:type];
    return kvPointer;
}

//Direction的mv分区pointer;(存引用序列)
+(AIKVPointer*) createPointerForDirection:(NSString*)mvAlgsType direction:(MVDirection)direction{
    NSInteger pointerId = 0;
    AIKVPointer *kvPointer = [AIKVPointer newWithPointerId:pointerId folderName:kPN_DIRECTION((long)direction) algsType:mvAlgsType dataSource:DefaultDataSource isOut:false isMem:false type:ATDefault];
    return kvPointer;
}

//生成小脑CanOut指针;
+(AIKVPointer*) createPointerForCerebelCanOut{
    AIKVPointer *pointer = [AIKVPointer newWithPointerId:0 folderName:kPN_CEREBEL_CANOUT algsType:DefaultAlgsType dataSource:DefaultDataSource isOut:false isMem:false type:ATDefault];
    return pointer;
}

//生成indexValue的指针;
+(AIKVPointer*) createPointerForValue:(NSString*)algsType dataSource:(NSString*)dataSource isOut:(BOOL)isOut{
    NSInteger pointerId = [self createPointerId:algsType dataSource:dataSource];
    return [AIKVPointer newWithPointerId:pointerId folderName:kPN_VALUE algsType:algsType dataSource:dataSource isOut:isOut isMem:false type:ATDefault];
}

+(AIKVPointer*) createPointerForValue:(NSInteger)pointerId algsType:(NSString*)algsType dataSource:(NSString*)dataSource isOut:(BOOL)isOut{
    return [AIKVPointer newWithPointerId:pointerId folderName:kPN_VALUE algsType:algsType dataSource:dataSource isOut:isOut isMem:false type:ATDefault];
}

+(AIKVPointer*) createPointerForIndex{
    NSInteger pointerId = 0;
    return [AIKVPointer newWithPointerId:pointerId folderName:kPN_INDEX algsType:DefaultAlgsType dataSource:DefaultDataSource isOut:false isMem:false type:ATDefault];
}

+(AIKVPointer*) createPointerForData:(NSString*)algsType dataSource:(NSString*)dataSource isOut:(BOOL)isOut{
    NSInteger pointerId = 0;
    return [AIKVPointer newWithPointerId:pointerId folderName:kPN_DATA algsType:algsType dataSource:dataSource isOut:isOut isMem:false type:ATDefault];
}

/**
 *  MARK:--------------------生成alg指针--------------------
 *  @version
 *      2021.09.25: 将algsType由pointerId改为" ";
 *      2021.09.25: 将at由参数传入,因为有些稀疏码没有ds(如FLY_RDS),此时构建glAlg,就只能传来at (参考24021-概念部分-4);
 */
+(AIKVPointer*) createPointerForAlg:(NSString*)folderName at:(NSString*)at dataSource:(NSString*)dataSource isOut:(BOOL)isOut isMem:(BOOL)isMem type:(AnalogyType)type{
    NSInteger pointerId = [SMGUtils createPointerId:DefaultAlgsType dataSource:dataSource];
    return [AIKVPointer newWithPointerId:pointerId folderName:folderName algsType:at dataSource:dataSource isOut:isOut isMem:isMem type:type];
}

/**
 *  MARK:--------------------生成fo指针--------------------
 *  @version
 *      2021.09.25: 将at由参数传入,因为有些稀疏码没有ds(如FLY_RDS),此时构建glFo,就只能传来at (参考24021-时序部分-3);
 */
+(AIKVPointer*) createPointerForFo:(NSString*)folderName at:(NSString*)at ds:(NSString*)ds type:(AnalogyType)type{
    return [self createPointer:folderName algsType:at dataSource:ds isOut:false isMem:false type:type];
}

@end


/**
 *  MARK:--------------------比较--------------------
 */
@implementation SMGUtils (Compare)

//+(BOOL) compareItemA:(id)itemA itemB:(id)itemB{
//    if (itemA == nil && itemB == nil) {
//        return true;
//    }else if(itemA == nil || itemB == nil || ![self compareKindClassWithItemA:itemA itemB:itemB]){
//        return false;
//    }else{
//        if ([itemA isKindOfClass:[NSString class]]) {
//            return [(NSString*)itemA isEqualToString:itemB];        //NSString
//        }else if ([itemA isKindOfClass:[NSNumber class]]) {
//            return [itemA isEqualToNumber:itemB];                   //NSNumber
//        }else if ([itemA isKindOfClass:[NSValue class]]) {
//            return [itemA isEqualToValue:itemB];                    //NSValue
//        }else if ([itemA isKindOfClass:[NSArray class]]) {
//            return [itemA isEqualToArray:itemB];                    //NSArray
//        }else if ([itemA isKindOfClass:[NSDictionary class]]) {
//            return [itemA isEqualToDictionary:itemB];               //NSDictionary
//        }else if ([itemA isKindOfClass:[NSSet class]]) {
//            return [itemA isEqualToSet:itemB];                      //NSSet
//        }else if ([itemA isKindOfClass:[NSData class]]) {
//            return [itemA isEqualToData:itemB];                     //NSData
//        }else if ([itemA isKindOfClass:[NSDate class]]) {
//            return [itemA isEqualToDate:itemB];                     //NSDate
//        }else if ([itemA isKindOfClass:[NSAttributedString class]]) {
//            return [itemA isEqualToAttributedString:itemB];         //NSAttributedString
//        }else if ([itemA isKindOfClass:[NSIndexSet class]]) {
//            return [itemA isEqualToIndexSet:itemB];                 //NSIndexSet
//        }else if ([itemA isKindOfClass:[NSTimeZone class]]) {
//            return [itemA isEqualToTimeZone:itemB];                 //NSTimeZone
//        }else if ([itemA isKindOfClass:[NSHashTable class]]) {
//            return [itemA isEqualToHashTable:itemB];                //NSHashTable
//        }else if ([itemA isKindOfClass:[NSOrderedSet class]]) {
//            return [itemA isEqualToOrderedSet:itemB];               //NSOrderedSet
//        }else if ([itemA isKindOfClass:[NSDateInterval class]]) {
//            return [itemA isEqualToDateInterval:itemB];             //NSDateInterval
//        }else{
//            return [itemA isEqual:itemB];                           //不识别的类型
//        }
//    }
//}
//
//+(BOOL) compareArrayA:(NSArray*)arrA arrayB:(NSArray*)arrB{
//    if (arrA == nil && arrB == nil) {
//        return true;
//    }else if(!ARRISOK(arrA) || !ARRISOK(arrB)){
//        return false;
//    }else{
//        for (NSObject *itemA in arrA) {
//            BOOL find = false;
//            for (NSObject *itemB in arrB) {
//                if ([itemA isEqual:itemB]) {
//                    find = true;
//                    break;
//                }
//            }
//            if (!find) {
//                return false;
//            }
//        }
//        return true;
//    }
//}
//
//+(BOOL) compareItemA:(id)itemA containsItemB:(id)itemB{
//    if (itemB == nil) {
//        return true;
//    }else if(itemA == nil || ![self compareKindClassWithItemA:itemA itemB:itemB]){
//        return false;
//    }else{
//        if ([itemA isKindOfClass:[NSString class]]) {
//            return [(NSString*)itemA containsString:itemB];        //NSString
//        }else if ([itemA isKindOfClass:[NSArray class]]) {
//            BOOL itemAContainsItemB = true;//默认true;查到一个不包含设为false;
//            for (id bItem in itemB) {
//                BOOL aItemContainsBItem = false;//默认fale;查到一个包含设为true;
//                for (id aItem in itemA) {
//                    if ([self compareItemA:aItem containsItemB:bItem]) {
//                        aItemContainsBItem = true;
//                        break;
//                    }
//                }
//                if (!aItemContainsBItem) {
//                    itemAContainsItemB = false;
//                }
//            }
//            //return [itemA containsObject:itemB];
//            return itemAContainsItemB;                    //NSArray
//        }else if ([itemA isKindOfClass:[NSDictionary class]]) {
//            for (NSString *key in [(NSDictionary*)itemB allKeys]) { //NSDictionary
//                if(![SMGUtils compareItemA:[(NSDictionary*)itemA objectForKey:key] containsItemB:[(NSDictionary*)itemB objectForKey:key]]){
//                    return false;
//                }
//            }
//            return true;
//        }else if ([itemA isKindOfClass:[NSSet class]]) {
//            return [itemA containsObject:itemB];                      //NSSet
//        }else if ([itemA isKindOfClass:[NSDate class]]) {
//            return [itemA containsDate:itemB];                     //NSDate
//        }else if ([itemA isKindOfClass:[NSIndexSet class]]) {
//            return [itemA containsIndexes:itemB];                 //NSIndexSet
//        }else if ([itemA isKindOfClass:[NSHashTable class]]) {
//            return [itemA containsObject:itemB];                //NSHashTable
//        }else if ([itemA isKindOfClass:[NSOrderedSet class]]) {
//            return [itemA containsObject:itemB];               //NSOrderedSet
//        }else{
//            return [SMGUtils compareItemA:itemA itemB:itemB];       //不识别的类型
//        }
//    }
//}
//
//
///**
// *  MARK:--------------------对比itemA和itemB是否有继承关系或同类型(NSObject除外)--------------------
// */
//+(BOOL) compareKindClassWithItemA:(id)itemA itemB:(id)itemB{
//    if (itemA == nil && itemB == nil) {
//        return true;
//    }else if(itemA == nil || itemB == nil){
//        return false;
//    }else{
//        if ([itemA isKindOfClass:[NSArray class]]) {
//            return [itemB isKindOfClass:[NSArray class]];
//        }else if([itemA isKindOfClass:[NSString class]]){
//            return [itemB isKindOfClass:[NSString class]];
//        }else if([itemA isKindOfClass:[NSDictionary class]]){
//            return [itemB isKindOfClass:[NSDictionary class]];
//        }else{
//            BOOL isSeem = ([itemA class] == [itemB class]);
//            BOOL isKind = ([itemA isKindOfClass:[itemB class]] || [itemB isKindOfClass:[itemA class]]);
//            return isSeem || isKind;
//        }
//    }
//}


/**
 *  MARK:--------------------比较refsA是否比refsB大--------------------
 */
//+(NSComparisonResult) compareRefsA_p:(NSArray*)refsA_p refsB_p:(NSArray*)refsB_p{
//    //1. 数据检查 & 准备
//    refsA_p = ARRTOOK(refsA_p);
//    refsB_p = ARRTOOK(refsB_p);
//    NSInteger aLength = refsA_p.count;
//    NSInteger bLength = refsB_p.count;
//    
//    //2. 比较大小
//    for (NSInteger i = 0; i < MIN(aLength, bLength); i++) {
//        AIKVPointer *itemA = ARR_INDEX(refsA_p, i);
//        AIKVPointer *itemB = ARR_INDEX(refsB_p, i);
//        NSNumber *aNum = [SMGUtils searchObjectForPointer:itemA fileName:kFNValue];
//        NSNumber *bNum = [SMGUtils searchObjectForPointer:itemB fileName:kFNValue];
//        NSComparisonResult result = [NUMTOOK(aNum) compare:NUMTOOK(bNum)] ;
//        if (result != NSOrderedSame) {
//            return result;
//        }
//    }
//    
//    //3. 前面都一样
//    return aLength > bLength ? NSOrderedAscending : aLength < bLength ? NSOrderedDescending : NSOrderedSame;
//}

+(NSComparisonResult) comparePointerA:(AIPointer*)pA pointerB:(AIPointer*)pB{
    //1. 数据检查
    BOOL aIsOk = ISOK(pA, AIKVPointer.class);
    BOOL bIsOk = ISOK(pB, AIKVPointer.class);
    if (!aIsOk || !bIsOk) {
        return (aIsOk == bIsOk) ? NSOrderedSame : (aIsOk ? NSOrderedDescending : NSOrderedAscending);
    }
    
    //2. PointerId越大越排前面
    if (pA.pointerId > pB.pointerId) {
        return NSOrderedDescending;
    }else if(pA.pointerId < pB.pointerId){
        return NSOrderedAscending;
    }else{
        return [XGRedisUtil compareStrA:pA.identifier strB:pB.identifier];
    }
}

+(NSComparisonResult) comparePortA:(AIPort*)pA portB:(AIPort*)pB{
    //1. 数据检查
    BOOL aIsOk = ISOK(pA, AIPort.class);
    BOOL bIsOk = ISOK(pB, AIPort.class);
    if (!aIsOk || !bIsOk) {
        return (aIsOk == bIsOk) ? NSOrderedSame : (aIsOk ? NSOrderedDescending : NSOrderedAscending);
    }
    
    //2. 默认按StrongValue从大到小排序 (self.strongValue越大越排前面)
    if (pA.strong.value > pB.strong.value) {
        return NSOrderedDescending;
    }else if(pA.strong.value < pB.strong.value){
        return NSOrderedAscending;
    }else{
        return [SMGUtils comparePointerA:pA.target_p pointerB:pB.target_p];
    }
}

/**
 *  MARK:--------------------比较intA是否比intB大--------------------
 */
+(NSComparisonResult) compareIntA:(NSInteger)intA intB:(NSInteger)intB{
    return intA > intB ? NSOrderedAscending : intA < intB ? NSOrderedDescending : NSOrderedSame;
}


/**
 *  MARK:--------------------比较floatA是否比floatB大--------------------
 *  @desc 从大到小排序,前大后小;
 */
+(NSComparisonResult) compareFloatA:(CGFloat)floatA floatB:(CGFloat)floatB{
    return floatA > floatB ? NSOrderedAscending : floatA < floatB ? NSOrderedDescending : NSOrderedSame;
}
+(NSComparisonResult) compareDoubleA:(CGFloat)doubleA doubleB:(CGFloat)doubleB{
    return doubleA > doubleB ? NSOrderedAscending : doubleA < doubleB ? NSOrderedDescending : NSOrderedSame;
}


@end



@implementation SMGUtils (DB)

/**
 *  MARK:--------------------SQL语句之rowId--------------------
 */
+(NSString*) sqlWhere_RowId:(NSInteger)rowid{
    return [NSString stringWithFormat:@"rowid='%ld'",(long)rowid];
}

//+(NSString*) sqlWhere_K:(id)columnName V:(id)value{
//    return [NSString stringWithFormat:@"%@='%@'",columnName,value];
//}
//
//+(NSDictionary*) sqlWhereDic_K:(id)columnName V:(id)value{
//    if (value) {
//        return [[NSDictionary alloc] initWithObjectsAndKeys:value,STRTOOK(columnName), nil];
//    }
//    return nil;
//}

+(id) searchObjectForPointer:(AIPointer*)pointer fileName:(NSString*)fileName{
    return [self searchObjectForPointer:pointer fileName:fileName time:0];
}

+(id) searchObjectForPointer:(AIPointer*)pointer fileName:(NSString*)fileName time:(double)time{
    if (ISOK(pointer, AIPointer.class)) {
        return [self searchObjectForFilePath:pointer.filePath fileName:fileName time:time];
    }
    return nil;
}

+(id) searchObjectForFilePath:(NSString*)filePath fileName:(NSString*)fileName time:(double)time{
    //isMem临时先这么判断,后续再改 (由各方法自行传入);
    BOOL isMem = [kFNMemNode isEqualToString:fileName] || [kFNMemAbsPorts isEqualToString:fileName] || [kFNMemConPorts isEqualToString:fileName] || [kFNMemRefPorts isEqualToString:fileName];
    return [self searchObjectForFilePath:filePath fileName:fileName time:time isMem:isMem];
}

+(id) searchObjectForFilePath:(NSString*)filePath fileName:(NSString*)fileName time:(double)time isMem:(BOOL)isMem{
    //1. 数据检查
    filePath = STRTOOK(filePath);
    
    //2. 优先取redis
    NSString *key = STRFORMAT(@"%@/%@",filePath,fileName);//随后去掉前辍
    id result = [[XGRedis sharedInstance] objectForKey:key];
    NSString *fromType = @"XGRedis";
    
    //3. 再取wedis
    if (result == nil) {
        result = [[XGWedis sharedInstance] objectForKey:key];
        fromType = @"XGWedis";
        
        //4. 最后取disk
        if (result == nil && !isMem) {
            PINDiskCache *cache = [[PINDiskCache alloc] initWithName:@"" rootPath:filePath];
            result = [cache objectForKey:fileName];
            fromType = @"Disk";
        }
        
        //5. 存到redis (wedis/disk)
        if (time > 0 && result) {
            [[XGRedis sharedInstance] setObject:result forKey:key time:time];
        }
    }
    return result;
}

//+(void) insertObject:(NSObject*)obj rootPath:(NSString*)rootPath fileName:(NSString*)fileName{
//    [self insertObject:obj rootPath:rootPath fileName:fileName time:0 saveDB:true];
//}
+(void) insertObject:(NSObject*)obj pointer:(AIPointer*)pointer fileName:(NSString*)fileName time:(double)time{
    if (ISOK(pointer, AIPointer.class)) {
        [self insertObject:obj rootPath:pointer.filePath fileName:fileName time:time saveDB:!pointer.isMem];
    }
}
+(void) insertObject:(NSObject*)obj rootPath:(NSString*)rootPath fileName:(NSString*)fileName time:(double)time saveDB:(BOOL)saveDB{
    //1. 存disk (异步持久化)
    NSString *key = STRFORMAT(@"%@/%@",rootPath,fileName);
    if (saveDB) {
        [[XGWedis sharedInstance] setObject:obj forKey:key];
        [[XGWedis sharedInstance] setSaveBlock:^(NSDictionary *dic) {
            dic = DICTOOK(dic);
            for (NSString *saveKey in dic.allKeys) {
                id saveObj = [dic objectForKey:saveKey];
                NSString *sep = @"/";
                NSString *saveFileName = STRTOOK(ARR_INDEX_REVERSE(STRTOARR(saveKey, sep), 0));
                NSString *saveRootPath = STRTOOK(SUBSTR2INDEX(saveKey, (saveKey.length - saveFileName.length - 1)));
                PINDiskCache *cache = [[PINDiskCache alloc] initWithName:@"" rootPath:saveRootPath];
                [cache setObject:saveObj forKey:saveFileName];
            }
            if (dic.count > 0) {
                NSLog(@">>>>>>>>>WriteDisk,%lu",(unsigned long)dic.count);
            }
        }];
    }
    
    //2. 存redis
    [[XGRedis sharedInstance] setObject:obj forKey:key time:time];//随后去掉(redisKey)前辍
}

+(id) searchNode:(AIPointer*)pointer {
    if (ISOK(pointer, AIPointer.class)) {
        return [self searchObjectForFilePath:pointer.filePath fileName:kFNNode_All(pointer.isMem) time:cRTNode_All(pointer.isMem)];
    }
    return nil;
}

/**
 *  MARK:--------------------搜索节点组--------------------
 *  @result notnull
 */
+(NSArray*) searchNodes:(NSArray*)ps {
    //1. 数据准备
    ps = ARRTOOK(ps);
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    //2. search
    for (AIKVPointer *item_p in ps) {
        AINodeBase *itemNode = [SMGUtils searchNode:item_p];
        if (itemNode) [result addObject:itemNode];
    }
    return result;
}

+(void) insertNode:(AINodeBase*)node{
    if (ISOK(node, AINodeBase.class)) {
        [self insertObject:node pointer:node.pointer fileName:kFNNode_All(node.pointer.isMem) time:cRTNode_All(node.pointer.isMem)];
    }
}

@end



//MARK:===============================================================
//MARK:                     < MathUtils >
//MARK:===============================================================
@implementation MathUtils

+(CGFloat) getNegativeTen2TenWithOriRange:(UIFloatRange)oriRange oriValue:(CGFloat)oriValue{
    return [self getValueWithOriRange:oriRange targetRange:UIFloatRangeMake(-10, 10) oriValue:oriValue];
}
+(CGFloat) getZero2TenWithOriRange:(UIFloatRange)oriRange oriValue:(CGFloat)oriValue{
    return [self getValueWithOriRange:oriRange targetRange:UIFloatRangeMake(0, 10) oriValue:oriValue];
}
+(CGFloat) getValueWithOriRange:(UIFloatRange)oriRange targetRange:(UIFloatRange)targetRange oriValue:(CGFloat)oriValue{
    //1,数据范围检查;
    oriValue = MAX(oriValue, MIN(oriValue, oriRange.maximum));
    //2,checkValue所在的值
    CGFloat percent = 0;
    if (oriRange.minimum != oriValue) {
        percent = (oriValue - oriRange.minimum) / (oriRange.maximum - oriRange.minimum);
    }
    //3,返回变换值
    return (targetRange.maximum - targetRange.minimum) * percent + targetRange.minimum;
}

@end

//MARK:===============================================================
//MARK:                     < SMGUtils (Contains) >
//MARK:===============================================================
@implementation SMGUtils (Contains)

+(BOOL) containsSub_ps:(NSArray*)sub_ps parent_ps:(NSArray*)parent_ps{
    sub_ps = ARRTOOK(sub_ps);
    for (AIPointer *sub_p in sub_ps) {
        if (![self containsSub_p:sub_p parent_ps:parent_ps]) {
            return false;
        }
    }
    return true;
}

+(BOOL) containsSub_p:(AIPointer*)sub_p parent_ps:(NSArray*)parent_ps{
    if (ISOK(sub_p, AIPointer.class) && ARRISOK(parent_ps)) {
        for (AIPointer *parent_p in parent_ps) {
            if ([sub_p isEqual:parent_p]) {
                return true;
            }
        }
    }
    return false;
}

+(BOOL) containsSub_p:(AIPointer*)sub_p parentPorts:(NSArray*)parentPorts{
    NSArray *parent_ps = [SMGUtils convertPointersFromPorts:parentPorts];
    return [SMGUtils containsSub_p:sub_p parent_ps:parent_ps];
}

@end


//MARK:===============================================================
//MARK:                     < SMGUtils (convert) >
//MARK:===============================================================
@implementation SMGUtils (Convert)

+(NSMutableArray*) convertPointersFromPorts:(NSArray*)ports{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (AIPort *port in ARRTOOK(ports)) {
        if (ISOK(port, AIPort.class) && ISOK(port.target_p, AIPointer.class)) {
            [result addObject:port.target_p];
        }
    }
    return result;
}

+(NSMutableArray*) convertPointersFromNodes:(NSArray*)nodes{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    for (AINodeBase *node in ARRTOOK(nodes)) {
        if (ISOK(node, AINodeBase.class)) {
            [result addObject:node.pointer];
        }
    }
    return result;
}

+(NSString*) convertPointers2String:(NSArray*)pointers{
    NSMutableString *mStr = [[NSMutableString alloc] init];
    for (AIPointer *p in ARRTOOK(pointers)) {
        [mStr appendFormat:@"%@_%ld,",p.identifier,(long)p.pointerId];
    }
    return mStr;
}

//2021.02.05: 概念嵌套早已废弃
//+(NSMutableArray*) convertValuePs2MicroValuePs:(NSArray*)value_ps{
//    //1. 数据准备
//    NSMutableArray *mic_ps = [[NSMutableArray alloc] init];
//
//    //2. 逐个收集
//    for (AIKVPointer *value_p in value_ps) {
//
//        //3. 概念嵌套时
//        if ([kPN_ALG_ABS_NODE isEqualToString:value_p.folderName]) {
//            AIAlgNodeBase *algNode = [SMGUtils searchNode:value_p];
//
//            //4. 递归取嵌套的value_ps
//            if (ISOK(algNode, AIAlgNodeBase.class)) {
//                [mic_ps addObjectsFromArray:[self convertValuePs2MicroValuePs:algNode.content_ps]];
//            }
//        }
//
//        //5. 非概念嵌套时,直接收集;
//        [mic_ps addObject:value_p];
//    }
//    return mic_ps;
//}

//任意arr元素类型转换 notnull
+(NSMutableArray*) convertArr:(NSArray*)arr convertBlock:(id(^)(id obj))convertBlock{
    //1. 数据准备;
    arr = ARRTOOK(arr);
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    //2. 转换
    for (id obj in arr) {
        id convertItem = convertBlock(obj);
        if (convertItem) [result addObject:convertItem];
    }
    return result;
}

@end


//MARK:===============================================================
//MARK:                     < SMGUtils (Sort) >
//MARK:===============================================================
@implementation SMGUtils (Sort)

+(NSArray*) sortPointers:(NSArray*)ps{
    ps = ARRTOOK(ps);
    return [ps sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        return [SMGUtils comparePointerA:obj1 pointerB:obj2];
    }];
}

/**
 *  MARK:--------------------从大到小排序--------------------
 */
+(NSArray*) sortBig2Small:(NSArray*)arr compareBlock:(double(^)(id obj))compareBlock{
    return [SMGUtils sortBig2Small:arr compareBlock1:compareBlock compareBlock2:nil];
}
+(NSArray*) sortBig2Small:(NSArray*)arr compareBlock1:(double(^)(id obj))compareBlock1 compareBlock2:(double(^)(id obj))compareBlock2{
    //1. 数据检查;
    arr = ARRTOOK(arr);
    
    //2. 排序返回;
    return [arr sortedArrayUsingComparator:^NSComparisonResult(id  _Nonnull obj1, id  _Nonnull obj2) {
        //3. 一级对比;
        NSComparisonResult result = NSOrderedSame;
        if (compareBlock1) {
            result = [SMGUtils compareDoubleA:compareBlock1(obj1) doubleB:compareBlock1(obj2)];
        }
        
        //4. 二级对比;
        if (result == NSOrderedSame && compareBlock2) {
            result = [SMGUtils compareDoubleA:compareBlock2(obj1) doubleB:compareBlock2(obj2)];
        }
        return result;
    }];
}

@end


//MARK:===============================================================
//MARK:                     < SMGUtils (Remove) >
//MARK:===============================================================
@implementation SMGUtils (Remove)

+(NSMutableArray*) removeSub_ps:(NSArray*)sub_ps parent_ps:(NSArray*)parent_ps{
    sub_ps = ARRTOOK(sub_ps);
    NSMutableArray *result = [[NSMutableArray alloc] initWithArray:parent_ps];
    for (AIPointer *sub_p in sub_ps) {
        result = [self removeSub_p:sub_p parent_ps:result];
    }
    return result;
}

+(NSMutableArray*) removeSub_p:(AIPointer*)sub_p parent_ps:(NSArray*)parent_ps{
    NSMutableArray *result_ps = [[NSMutableArray alloc] initWithArray:parent_ps];
    if (ISOK(sub_p, AIPointer.class)) {
        [result_ps removeObject:sub_p];
    }
    return result_ps;
}

/**
 *  MARK:--------------------移除--------------------
 *  @param checkValid: 将要移除的item返回true,保留的返回false;
 */
+(NSMutableArray*) removeArr:(NSArray *)arr checkValid:(BOOL(^)(id item))checkValid {
    NSMutableArray *result = [[NSMutableArray alloc] initWithArray:arr];
    NSArray *removeItems = [SMGUtils filterArr:arr checkValid:checkValid limit:NSIntegerMax];
    [result removeObjectsInArray:removeItems];
    return result;
}

+(NSMutableArray*) removeRepeat:(NSArray*)protoArr{
    //1. 数据准备
    NSMutableArray *result = [[NSMutableArray alloc] init];
    protoArr = ARRTOOK(protoArr);
    
    //2. 防重收集
    for (id proto in protoArr) {
        if (![result containsObject:proto]) {
            [result addObject:proto];
        }
    }
    return result;
}

+(AIKVPointer*) filterSameIdentifier_p:(AIKVPointer*)a_p b_ps:(NSArray*)b_ps{
    if (!a_p) return nil;
    return ARR_INDEX([self filterSameIdentifier_Dic:@[a_p] b_ps:b_ps].allValues, 0);
}
+(NSMutableDictionary*) filterSameIdentifier_Dic:(NSArray*)a_ps b_ps:(NSArray*)b_ps{
    return [SMGUtils filterPointers:a_ps b_ps:b_ps checkItemValid:^BOOL(AIKVPointer *a_p, AIKVPointer *b_p) {
        return a_p ? [a_p.identifier isEqualToString:b_p.identifier] : false;
    }];
}
//+(NSArray*) filterSameIdentifier_Arr:(NSArray*)from_ps valid_ps:(NSArray*)valid_ps{
//    NSMutableArray *result = [[NSMutableArray alloc] init];
//    [SMGUtils foreach:from_ps b_ps:valid_ps tryOut:^(AIKVPointer *a_p, AIKVPointer *b_p) {
//        if ([a_p.identifier isEqualToString:b_p.identifier]) {
//            [result addObject:a_p];
//        }
//    }];
//    return result;
//}
+(AIKVPointer*) filterSameIdentifier_DiffId_p:(AIKVPointer*)a_p b_ps:(NSArray*)b_ps{
    if (! a_p) return nil;
    return ARR_INDEX([SMGUtils filterSameIdentifier_DiffId_ps:@[a_p] b_ps:b_ps].allValues, 0);
}
+(NSMutableDictionary*) filterSameIdentifier_DiffId_ps:(NSArray*)a_ps b_ps:(NSArray*)b_ps{
    return [SMGUtils filterPointers:a_ps b_ps:b_ps checkItemValid:^BOOL(AIKVPointer *a_p, AIKVPointer *b_p) {
        if (a_p && b_p) {
            return [a_p.identifier isEqualToString:b_p.identifier] && a_p.pointerId != b_p.pointerId;
        }
        return false;
    }];
}

+(NSArray*) filterPointers:(NSArray *)from_ps checkValid:(BOOL(^)(AIKVPointer *item_p))checkValid {
    return [self filterArr:from_ps checkValid:checkValid];
}

+(NSMutableDictionary*) filterPointers:(NSArray *)a_ps b_ps:(NSArray*)b_ps checkItemValid:(BOOL(^)(AIKVPointer *a_p,AIKVPointer *b_p))checkItemValid {
    //1. 数据准备
    NSMutableDictionary *result = [[NSMutableDictionary alloc] init];
    a_ps = ARRTOOK(a_ps);
    b_ps = ARRTOOK(b_ps);
    for (AIKVPointer *a_p in a_ps) {
        for (AIKVPointer *b_p in b_ps) {
            if (checkItemValid && checkItemValid(a_p,b_p)) {
                [result setObject:b_p forKey:OBJ2DATA(a_p)];
            }
        }
    }
    return result;
}

/**
 *  MARK:--------------------交集--------------------
 *  @version
 *      2020.12.13: 使之改为保持parent_ps有序 (以前的旧有方式是dic筛选,会使无序,导致原有序被打乱,比如参考21194的BUG);
 */
+(NSArray*) filterSame_ps:(NSArray*)a_ps parent_ps:(NSArray*)b_ps{
    return [self filterArr:b_ps checkValid:^BOOL(id item) {
        return [a_ps containsObject:item];
    }];
}
+(NSMutableArray*) filterArr:(NSArray *)arr checkValid:(BOOL(^)(id item))checkValid {
    return [SMGUtils filterArr:arr checkValid:checkValid limit:NSIntegerMax];
}
+(NSMutableArray*) filterArr:(NSArray *)arr checkValid:(BOOL(^)(id item))checkValid limit:(NSInteger)limit{
    //1. 数据准备
    arr = ARRTOOK(arr);
    NSMutableArray *result = [[NSMutableArray alloc] init];
    
    //2. 筛选
    for (id item in arr) {
        if (checkValid && checkValid(item)) {
            [result addObject:item];
            if (result.count >= limit) break;
        }
    }
    return result;
}

//用analogyType来筛选ports
+(NSArray*) filterPorts_Normal:(NSArray*)ports{
    NSArray *noTypes = @[@(ATGreater),@(ATLess),@(ATHav),@(ATNone),
                         @(ATPlus),@(ATSub)];
    return [SMGUtils filterPorts:ports havTypes:nil noTypes:noTypes];
}
+(NSArray*) filterPorts:(NSArray*)ports havTypes:(NSArray*)havTypes noTypes:(NSArray*)noTypes{
    //1. 数据检查
    havTypes = ARRTOOK(havTypes);
    noTypes = ARRTOOK(noTypes);
    ports = ARRTOOK(ports);
    
    //3. 筛选类型
    return [SMGUtils filterArr:ports checkValid:^BOOL(AIPort *item) {
        //a. hav筛选 (必须被havDSArr包含);
        if (ARRISOK(havTypes) && ![havTypes containsObject:@(item.target_p.type)]) return false;
        //b. no筛选 (必须不被noDSArr包含);
        if (ARRISOK(noTypes) && [noTypes containsObject:@(item.target_p.type)]) return false;
        //c. 干不死的,有效;
        return true;
    }];
}

+(id) filterSingleFromArr:(NSArray *)arr checkValid:(BOOL(^)(id item))checkValid {
    return ARR_INDEX([SMGUtils filterArr:arr checkValid:checkValid limit:1], 0);
}

/**
 *  MARK:--------------------筛选alg by 指定标识--------------------
 *  @desc 从alg_ps中查找含valueIdentifier标识稀疏码的概念并返回;
 *  @result 逐条返回 + 中断前所有收集全返回;
 */
+(NSArray*) filterAlg_Ps:(NSArray*)alg_ps valueIdentifier:(NSString*)valueIdentifier itemValid:(void(^)(AIAlgNodeBase *alg,AIKVPointer *value_p))itemValid{
    return [SMGUtils filterPointers:alg_ps checkValid:^BOOL(AIKVPointer *item_p) {
        AIAlgNodeBase *alg = [SMGUtils searchNode:item_p];
        if (alg) {
            for (AIKVPointer *itemValue_p in alg.content_ps) {
                if ([valueIdentifier isEqualToString:itemValue_p.identifier]) {
                    if (itemValid) itemValid(alg,itemValue_p);
                    return true;
                }
            }
        }
        return false;
    }];
}

/**
 *  MARK:--------------------筛选指针 by isOut--------------------
 *  @param proto_ps : 从中筛选
 *  @param isOut : false时筛选出非out的pointers
 *  注:未判定是否连续;
 */
+(NSArray*) filterPointers:(NSArray*)proto_ps isOut:(BOOL)isOut{
    return [SMGUtils filterPointers:proto_ps checkValid:^BOOL(AIKVPointer *item_p) {
        return item_p.isOut == isOut;
    }];
}

/**
 *  MARK:--------------------筛选指针 by 指定标识--------------------
 */
+(NSArray*) filterPointers:(NSArray*)from_ps identifier:(NSString*)identifier{
    return [SMGUtils filterPointers:from_ps checkValid:^BOOL(AIKVPointer *item_p) {
        return [identifier isEqualToString:item_p.identifier];
    }];
}

/**
 *  MARK:--------------------筛选端口 by 指定标识--------------------
 */
+(NSArray*) filterAlgPorts:(NSArray*)algPorts valueIdentifier:(NSString*)valueIdentifier{
    return [SMGUtils filterArr:algPorts checkValid:^BOOL(AIPort *item) {
        AIAlgNodeBase *alg = [SMGUtils searchNode:item.target_p];
        return ARRISOK([SMGUtils filterPointers:alg.content_ps identifier:valueIdentifier]);
    }];
}

@end

//MARK:===============================================================
//MARK:                     < SMGUtils (Collect) >
//MARK:===============================================================
@implementation SMGUtils (Collect)

+(NSMutableArray *) collectArrA:(NSArray*)arrA arrB:(NSArray*)arrB{
    NSMutableArray *result = [[NSMutableArray alloc] init];
    [result addObjectsFromArray:arrA];
    [result addObjectsFromArray:arrB];
    return result;
}

+(NSMutableArray *) collectArrA_NoRepeat:(NSArray*)arrA arrB:(NSArray*)arrB{
    NSMutableArray *result = [SMGUtils collectArrA:arrA arrB:arrB];
    result = [SMGUtils removeRepeat:result];
    return result;
}

@end

//MARK:===============================================================
//MARK:                     < SMGUtils (Other) >
//MARK:===============================================================
@implementation SMGUtils (Other)

//+(void) foreach:(NSArray *)a_ps b_ps:(NSArray*)b_ps tryOut:(void(^)(AIKVPointer *a_p,AIKVPointer *b_p))tryOut {
//    a_ps = ARRTOOK(a_ps);
//    b_ps = ARRTOOK(b_ps);
//    for (AIKVPointer *a_p in a_ps) {
//        for (AIKVPointer *b_p in b_ps) {
//            if (tryOut) tryOut(a_p,b_p);
//        }
//    }
//}

@end
