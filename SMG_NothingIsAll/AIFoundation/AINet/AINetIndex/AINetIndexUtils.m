//
//  AINetIndexUtils.m
//  SMG_NothingIsAll
//
//  Created by jia on 2019/10/31.
//  Copyright © 2019年 XiaoGang. All rights reserved.
//

#import "AINetIndexUtils.h"
#import "NSString+Extension.h"

@implementation AINetIndexUtils


//MARK:===============================================================
//MARK:                     < 绝对匹配 (概念/时序) 通用方法 >
//MARK:===============================================================

/**
 *  MARK:--------------------alg/fo 绝对匹配通用方法--------------------
 *  @version
 *      2021.04.25: 支持ds同区判断 (参考23054-疑点);
 *      2021.04.27: 修复因ds为空时默认dsSeem为true逻辑错误,导致alg防重失败,永远返回nil的BUG;
 *      2021.09.22: 支持type防重;
 */
+(id) getAbsoluteMatching_General:(NSArray*)content_ps sort_ps:(NSArray*)sort_ps except_ps:(NSArray*)except_ps getRefPortsBlock:(NSArray*(^)(AIKVPointer *item_p))getRefPortsBlock at:(NSString*)at ds:(NSString*)ds type:(AnalogyType)type{
    //1. 数据检查
    if (!getRefPortsBlock) return nil;
    content_ps = ARRTOOK(content_ps);
    NSString *md5 = STRTOOK([NSString md5:[SMGUtils convertPointers2String:sort_ps]]);
    except_ps = ARRTOOK(except_ps);
    
    //2. 依次找content_ps的被引用序列,并判断header匹配;
    for (AIKVPointer *item_p in content_ps) {
        //3. 取refPorts;
        NSArray *refPorts = ARRTOOK(getRefPortsBlock(item_p));
        
        //4. 判定refPort.header是否一致;
        for (AIPort *refPort in refPorts) {
            //5. ds防重 (ds无效时,默认为true);
            BOOL atSeem = STRISOK(at) ? [at isEqualToString:refPort.target_p.algsType] : true;
            BOOL dsSeem = STRISOK(ds) ? [ds isEqualToString:refPort.target_p.dataSource] : true;
            BOOL typeSeem = type == refPort.target_p.type;
            
            //6. ds同区 & 将md5匹配header & 不在except_ps的找到并返回;
            if (atSeem && dsSeem && typeSeem && ![except_ps containsObject:refPort.target_p] && [md5 isEqualToString:refPort.header]) {
                return [SMGUtils searchNode:refPort.target_p];
            }
        }
    }
    return nil;
}

/**
 *  MARK:--------------------从指定范围中获取绝对匹配--------------------
 *  @param validPorts : 指定范围域;
 *  @version
 *      2021.09.23: 指定范围获取绝对匹配,也要判断type类型 (但有时传入的validPorts本来就是已筛选过type的) (参考24019);
 */
+(id) getAbsoluteMatching_ValidPorts:(NSArray*)validPorts sort_ps:(NSArray*)sort_ps except_ps:(NSArray*)except_ps at:(NSString*)at ds:(NSString*)ds type:(AnalogyType)type{
    //1. 数据检查
    NSString *md5 = STRTOOK([NSString md5:[SMGUtils convertPointers2String:sort_ps]]);
    except_ps = ARRTOOK(except_ps);
    
    //2. 从指定的validPorts中依次找header匹配;
    for (AIPort *validPort in validPorts) {
        //5. ds防重 (ds无效时,默认为true);
        BOOL atSeem = STRISOK(at) ? [at isEqualToString:validPort.target_p.algsType] : true;
        BOOL dsSeem = STRISOK(ds) ? [ds isEqualToString:validPort.target_p.dataSource] : true;
        BOOL typeSeem = type == validPort.target_p.type;
        
        //6. ds同区 & 将md5匹配header & 不在except_ps的找到并返回;
        if (atSeem && dsSeem && typeSeem && ![except_ps containsObject:validPort.target_p] && [md5 isEqualToString:validPort.header]) {
            return [SMGUtils searchNode:validPort.target_p];
        }
    }
    return nil;
}

@end
