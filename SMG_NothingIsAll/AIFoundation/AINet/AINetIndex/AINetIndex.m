//
//  AINetIndex.m
//  SMG_NothingIsAll
//
//  Created by iMac on 2018/4/20.
//  Copyright © 2018年 XiaoGang. All rights reserved.
//

#import "AINetIndex.h"
#import "PINCache.h"
#import "XGRedisUtil.h"

@implementation AINetIndex

//MARK:===============================================================
//MARK:                     < method >
//MARK:===============================================================
+(AIKVPointer*) getDataPointerWithData:(NSNumber*)data algsType:(NSString*)algsType dataSource:(NSString*)dataSource isOut:(BOOL)isOut{
    //1. 数据准备
    if (!ISOK(data, NSNumber.class)) {
        return nil;
    }
    
    //2. 取索引序列 和 稀疏码值字典;
    AINetIndexModel *model = [AINetIndexUtils searchIndexModel:algsType ds:dataSource isOut:isOut];
    NSMutableDictionary *dataDic = [[NSMutableDictionary alloc] initWithDictionary:[AINetIndexUtils searchDataDic:algsType ds:dataSource isOut:isOut]];
    
    //3. 使用二分法查找data
    __block AIKVPointer *resultPointer;
    [XGRedisUtil searchIndexWithCompare:^NSComparisonResult(NSInteger checkIndex) {
        NSNumber *checkPointerIdNumber = ARR_INDEX(model.pointerIds, checkIndex);
        long checkPointerId = [NUMTOOK(checkPointerIdNumber) longValue];
        AIKVPointer *checkValue_p = [SMGUtils createPointerForValue:checkPointerId algsType:algsType dataSource:dataSource isOut:isOut];
        NSString *key = STRFORMAT(@"%ld",(long)checkValue_p.pointerId);
        NSNumber *checkValue = [dataDic objectForKey:key];
        NSComparisonResult compareResult = [NUMTOOK(checkValue) compare:data];
        return compareResult;
    } startIndex:0 endIndex:model.pointerIds.count - 1 success:^(NSInteger index) {
        NSNumber *pointerIdNum = ARR_INDEX(model.pointerIds, index);
        long pointerId = [NUMTOOK(pointerIdNum) longValue];
        AIKVPointer *value_p = [SMGUtils createPointerForValue:pointerId algsType:algsType dataSource:dataSource isOut:isOut];
        resultPointer = value_p;
    } failure:^(NSInteger index) {
        //4. 未找到;创建一个;
        AIKVPointer *value_p = [SMGUtils createPointerForValue:algsType dataSource:dataSource isOut:isOut];
        NSString *key = STRFORMAT(@"%ld",(long)value_p.pointerId);
        [dataDic setObject:data forKey:key];
        resultPointer = value_p;
        
        if (model.pointerIds.count <= index) {
            [model.pointerIds addObject:@(value_p.pointerId)];
        }else{
            [model.pointerIds insertObject:@(value_p.pointerId) atIndex:index];
        }
        
        //5. 存
        [AINetIndexUtils insertIndexModel:model isOut:isOut];
        [AINetIndexUtils insertDataDic:dataDic at:algsType ds:dataSource isOut:isOut];
    }];
    
    return resultPointer;
}

+(NSNumber*) getData:(AIKVPointer*)value_p{
    NSDictionary *dataDic = [AINetIndexUtils searchDataDic:value_p.algsType ds:value_p.dataSource isOut:value_p.isOut];
    return [dataDic objectForKey:STRFORMAT(@"%ld",(long)value_p.pointerId)];
}

/**
 *  MARK:--------------------获取索引序列--------------------
 *  @desc 将索引序列转为稀疏码指针数组返回;
 *  @version
 *      2022.05.20: 支持宽入窄出,仅返回前NarrowLimit条 (参考26073-TODO1);
 *      2022.05.21: V索引不能太窄,改成1000 (参考26075);
 *  @result notnull
 */
+(NSArray*) getIndex_ps:(NSString*)at ds:(NSString*)ds isOut:(BOOL)isOut{
    //1. 取出索引序列;
    AINetIndexModel *indexModel = [AINetIndexUtils searchIndexModel:at ds:ds isOut:isOut];
    
    //2. 转为稀疏码指针数组返回;
    NSArray *nears = [SMGUtils convertArr:indexModel.pointerIds convertBlock:^id(NSNumber *obj) {
        return [SMGUtils createPointerForValue:[NUMTOOK(obj) longValue] algsType:at dataSource:ds isOut:isOut];
    }];
    
    //3. 窄出,仅返回前NarrowLimit条;
    return ARR_SUB(nears, 0, cIndexNarrowLimit);
}

/**
 *  MARK:--------------------获取某标识索引序列的值域--------------------
 *  @desc 获取索引序列的值域 (参考25082-公式1);
 *  @result 值域不为负
 */
+(double) getIndexSpan:(NSString*)at ds:(NSString*)ds isOut:(BOOL)isOut {
    //1. 取索引序列 & 稀疏码值字典;
    AINetIndexModel *model = [AINetIndexUtils searchIndexModel:at ds:ds isOut:isOut];
    NSDictionary *dataDic = [AINetIndexUtils searchDataDic:at ds:ds isOut:isOut];
    
    //2. 取出最大最小pointerId;
    long minPId = [NUMTOOK(ARR_INDEX(model.pointerIds, 0)) longValue];
    long maxPId = [NUMTOOK(ARR_INDEX_REVERSE(model.pointerIds, 0)) longValue];
    
    //3. 取出最大最小的稀疏码值;
    NSNumber *minData = [dataDic objectForKey:STRFORMAT(@"%ld",minPId)];
    NSNumber *maxData = [dataDic objectForKey:STRFORMAT(@"%ld",maxPId)];
    if (!NUMISOK(minData) || !NUMISOK(maxData)) return 0;
    
    //4. 计算值域;
    double span = maxData.doubleValue - minData.doubleValue;
    return span;
}

//MARK:===============================================================
//MARK:                     < output >
//MARK:===============================================================

//暂时不实现小脑网络;
//-(void) setIndexReference:(AIKVPointer*)indexPointer target_p:(AIKVPointer*)target_p difValue:(int)difValue{
//    //    [self.outReference setNodePointerToOutputReference:nil algsType:nil dataSource:nil difStrong:0];
//    //    [outReference setReference:indexPointer target_p:target_p difValue:difValue];
//}
//-(NSArray*) getIndexReference:(AIKVPointer*)indexPointer limit:(NSInteger)limit{
//    //    self.outReference getNodePointersFromOutputReference:algsType dataSource:dataSource limit:333333
//    //    return [self.outReference getReference:indexPointer limit:limit];
//    return nil;
//}

@end


//MARK:===============================================================
//MARK:                     < 内存DataSortModel (一组index) >
//MARK:===============================================================
@implementation AINetIndexModel : NSObject

//MARK:===============================================================
//MARK:                     < method >
//MARK:===============================================================
-(NSMutableArray *)pointerIds{
    if (_pointerIds == nil) {
        _pointerIds = [NSMutableArray new];
    }
    return _pointerIds;
}

/**
 *  MARK:--------------------NSCoding--------------------
 */
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super init];
    if (self) {
        self.pointerIds = [aDecoder decodeObjectForKey:@"pointerIds"];
        self.algsType = [aDecoder decodeObjectForKey:@"algsType"];
        self.dataSource = [aDecoder decodeObjectForKey:@"dataSource"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [aCoder encodeObject:self.pointerIds forKey:@"pointerIds"];
    [aCoder encodeObject:self.algsType forKey:@"algsType"];
    [aCoder encodeObject:self.dataSource forKey:@"dataSource"];
}

@end
