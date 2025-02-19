//
//  NVHeUtil.m
//  SMG_NothingIsAll
//
//  Created by jia on 2019/7/2.
//  Copyright © 2019年 XiaoGang. All rights reserved.
//

#import "NVHeUtil.h"
#import "AINetIndex.h"
#import "AIKVPointer.h"
#import "AIAlgNodeBase.h"
#import "NSString+Extension.h"
#import "ThinkingUtils.h"
#import "AIScore.h"
#import "TVUtil.h"

@implementation NVHeUtil

+(BOOL) isHeight:(CGFloat)height fromContent_ps:(NSArray*)fromContent_ps {
    for (AIKVPointer *p in ARRTOOK(fromContent_ps)) {
        if ([p.dataSource isEqualToString:@"sizeHeight"]) {
            if ([NUMTOOK([AINetIndex getData:p]) floatValue] == 5) {
                return true;
            }
        }
    }
    return false;
}

+(NSString*) getLightStr4Ps:(NSArray*)node_ps{
    return [self getLightStr4Ps:node_ps simple:true header:true sep:@","];
}
+(NSString*) getLightStr4Ps:(NSArray*)node_ps simple:(BOOL)simple header:(BOOL)header sep:(NSString*)sep{
    //1. 数据检查
    NSMutableString *result = [[NSMutableString alloc] init];
    node_ps = ARRTOOK(node_ps);
    sep = STRTOOK(sep);
    
    //2. 拼接返回
    for (AIKVPointer *item_p in node_ps){
        NSString *str = [NVHeUtil getLightStr:item_p simple:simple header:header];
        [result appendFormat:@"%@%@",str,sep];
    }
    return SUBSTR2INDEX(result, result.length - sep.length);
}

+(NSString*) getLightStr:(AIKVPointer*)node_p {
    return [self getLightStr:node_p simple:true header:false];
}
+(NSString*) getLightStr:(AIKVPointer*)node_p simple:(BOOL)simple header:(BOOL)header{
    NSString *lightStr = @"";
    if (ISOK(node_p, AIKVPointer.class)) {
        if ([self isValue:node_p]) {
            lightStr = [self getLightStr_ValueP:node_p];
        }else if ([self isAlg:node_p]) {
            AIAlgNodeBase *algNode = [SMGUtils searchNode:node_p];
            if (algNode) {
                if (simple) {
                    NSString *firstValueStr = [self getLightStr_ValueP:ARR_INDEX(algNode.content_ps, 0)];
                    lightStr = STRFORMAT(@"%@%@",firstValueStr,(algNode.content_ps.count > 1) ? @"..." : @"");
                }else{
                    lightStr = [self getLightStr4Ps:algNode.content_ps simple:simple header:header sep:@","];
                }
            }
        }else if([self isFo:node_p]){
            AIFoNodeBase *foNode = [SMGUtils searchNode:node_p];
            if (foNode) {
                lightStr = [self getLightStr4Ps:foNode.content_ps simple:simple header:header sep:@","];
            }
        }else if([self isMv:node_p]){
            CGFloat score = [AIScore score4MV:node_p ratio:1.0f];
            lightStr = STRFORMAT(@"%@%@%@",Mvp2DeltaStr(node_p),Class2Str(NSClassFromString(node_p.algsType)),Double2Str_NDZ(score));
        }
    }
    //2. 返回;
    if (header) lightStr = [self decoratorHeader:lightStr node_p:node_p];
    return lightStr;
}

//获取value_p的light描述;
+(NSString*) getLightStr_ValueP:(AIKVPointer*)value_p{
    if (!value_p) return @"";
    double value = [NUMTOOK([AINetIndex getData:value_p]) doubleValue];
    NSString *valueStr = [self getLightStr_Value:value algsType:value_p.algsType dataSource:value_p.dataSource];
    if ([@"sizeWidth" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"宽%@",valueStr);
    }else if ([@"sizeHeight" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"高%@",valueStr);
    }else if ([@"colorRed" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"红%@",valueStr);
    }else if ([@"colorBlue" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"蓝%@",valueStr);
    }else if ([@"colorGreen" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"绿%@",valueStr);
    }else if ([@"radius" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"形%@",valueStr);
    }else if ([@"direction" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"向%@",valueStr);
    }else if ([@"distance" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"距%@",valueStr);
    }else if ([@"distanceX" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"X距%@",valueStr);
    }else if ([@"distanceY" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"Y距_%@_%@",[TVUtil distanceYDesc:value],valueStr);
    }else if ([@"speed" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"速%@",valueStr);
    }else if ([@"border" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"皮%@",valueStr);
    }else if ([@"posX" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"X%@",valueStr);
    }else if ([@"posY" isEqualToString:value_p.dataSource]) {
        return STRFORMAT(@"Y%@",valueStr);
    }else if([EAT_RDS isEqualToString:value_p.algsType]){
        return STRFORMAT(@"吃%@",valueStr);
    }else if([FLY_RDS isEqualToString:value_p.algsType]){
        return STRFORMAT(@"飞%@",valueStr);
    }
    return valueStr;
}

//获取value的light描述;
+(NSString*) getLightStr_Value:(double)value algsType:(NSString*)algsType dataSource:(NSString*)dataSource{
    if(value == ATHav || value == ATNone || value == ATGreater ||
       value == ATLess || value == ATPlus || value == ATSub){
        return [NSLog_Extension convertATType2Desc:value];
    }else if([FLY_RDS isEqualToString:algsType]){
        return [NVHeUtil fly2Str:value];
    }else if([@"direction" isEqualToString:dataSource]){
        return [NVHeUtil direction2Str:value];
    }
    return Double2Str_NDZ(value);
}


//MARK:===============================================================
//MARK:                     < 节点类型判断 >
//MARK:===============================================================
+(BOOL) isValue:(AIKVPointer*)node_p{
    return [kPN_VALUE isEqualToString:node_p.folderName] || [kPN_DATA isEqualToString:node_p.folderName] || [kPN_INDEX isEqualToString:node_p.folderName];
}

+(BOOL) isAlg:(AIKVPointer*)node_p{
    return [kPN_ALG_NODE isEqualToString:node_p.folderName] || [kPN_ALG_ABS_NODE isEqualToString:node_p.folderName];
}

+(BOOL) isFo:(AIKVPointer*)node_p{
    return [kPN_FRONT_ORDER_NODE isEqualToString:node_p.folderName] || [kPN_FO_ABS_NODE isEqualToString:node_p.folderName];
}

+(BOOL) isMv:(AIKVPointer*)node_p{
    return [kPN_CMV_NODE isEqualToString:node_p.folderName] || [kPN_ABS_CMV_NODE isEqualToString:node_p.folderName];
}

+(BOOL) isAbs:(AIKVPointer*)node_p{
    return [kPN_FO_ABS_NODE isEqualToString:node_p.folderName] || [kPN_ABS_CMV_NODE isEqualToString:node_p.folderName] || [kPN_ALG_ABS_NODE isEqualToString:node_p.folderName];
}

//MARK:===============================================================
//MARK:                     < privateMethod >
//MARK:===============================================================
+(NSString*) decoratorHeader:(NSString*)lightStr node_p:(AIKVPointer*)node_p{
    NSString *pIdStr = node_p ? STRFORMAT(@"%ld",node_p.pointerId) : @"";
    if ([self isAlg:node_p]) {
        return STRFORMAT(@"A%@(%@)",pIdStr,lightStr);
    }else if([self isFo:node_p]){
        return STRFORMAT(@"F%@[%@]",pIdStr,lightStr);
    }else if([self isMv:node_p]){
        return STRFORMAT(@"M%@{%@}",pIdStr,lightStr);
    }
    return lightStr;
}

+(NSString*) direction2Str:(CGFloat)value{
    int caseValue = value * 8;
    switch (caseValue) {
        case 0: return @"←";
        case 1: return @"↖";
        case 2: return @"↑";
        case 3: return @"↗";
        case 4: return @"→";
        case 5: return @"↘";
        case 6: return @"↓";
        case 7: return @"↙";
    }
    return @"";
}

+(NSString*) fly2Str:(CGFloat)value{
    return [self direction2Str:value];
}

@end
