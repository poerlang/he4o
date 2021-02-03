//
//  AIVisionAlgs.m
//  SMG_NothingIsAll
//
//  Created by jiaxiaogang on 2018/11/15.
//  Copyright © 2018年 XiaoGang. All rights reserved.
//

#import "AIVisionAlgs.h"
#import "AIVisionAlgsModel.h"
#import "XGRedis.h"
#import "UIView+Extension.h"
#import "NSObject+Extension.h"

@implementation AIVisionAlgs

+(void) commitView:(UIView*)selfView targetView:(UIView*)targetView rect:(CGRect)rect{
    //1. 数据准备;
    if (!selfView || !targetView) {
        return;
    }
    NSMutableArray *dics = [[NSMutableArray alloc] init];
    NSMutableArray *views = [targetView subViews_AllDeepWithRect:rect];
    if (ARRISOK(views)) NSLog(@"\n\n------------------------------- 皮层算法 -------------------------------");
    
    //2. 生成model
    for (HEView *curView in views) {
        if (curView.tag == visibleTag) {
            AIVisionAlgsModel *model = [[AIVisionAlgsModel alloc] init];
            //model.sizeWidth = [self sizeWidth:curView];
            model.sizeHeight = [self sizeHeight:curView];
            //model.colorRed = [self colorRed:curView];
            //model.colorGreen = [self colorGreen:curView];
            //model.colorBlue = [self colorBlue:curView];
            //model.radius = [self radius:curView];
            model.speed = [self speed:curView];
            model.direction = [self direction:selfView target:curView];
            model.distance = [self distance:selfView target:curView];
            model.distanceY = [self distanceY:selfView target:curView];
            model.border = [self border:curView];
            model.posX = [self posX:curView];
            model.posY = [self posY:curView];
            //NSLog(@"视觉目标 [距离:%ld 角度:%f 宽:%f 高:%f 皮:%f 圆角:%f]",(long)model.distance,model.direction,model.sizeWidth,model.sizeHeight,model.border,model.radius);
            NSLog(@"视觉目标 [距离:%ld 角度:%f 高:%f 皮:%f]",(long)model.distance,model.direction,model.sizeHeight,model.border);
            NSMutableDictionary *modelDic = [NSObject getDic:model containParent:true];
            //for (NSString *key in modelDic.allKeys) {
            //    if ([NUMTOOK([modelDic objectForKey:key]) isEqualToNumber:@(0)]) {
            //        [modelDic removeObjectForKey:key];
            //    }
            //}
            [dics addObject:modelDic];
        }
    }
    
    //3. 传给thinkingControl
    [theTC commitInputWithModels:dics algsType:NSStringFromClass(self)];
}

//MARK:===============================================================
//MARK:                     < 视觉算法 >
//MARK:===============================================================

//size
+(CGFloat) sizeWidth:(UIView*)target{
    if (target) return target.width;
    return 0;
}
+(CGFloat) sizeHeight:(UIView*)target{
    if (target) return target.height;
    return 0;
}

//color
+(NSInteger) colorRed:(UIView*)target{
    if (target) return target.backgroundColor.red * 255.0f;
    return 0;
}
+(NSInteger) colorGreen:(UIView*)target{
    if (target){
        return target.backgroundColor.green * 255.0f;
    }
    return 0;
}
+(NSInteger) colorBlue:(UIView*)target{
    if (target) return target.backgroundColor.blue * 255.0f;
    return 0;
}

//radius
+(CGFloat) radius:(UIView*)target{
    if (target) return target.layer.cornerRadius;
    return 0;
}

/**
 *  MARK:--------------------速度--------------------
 *  @desc 目前简单粗暴两桢差值 (随后有需要改用微积分)
 *  @version
 *      2020.07.07: 将主观速度,改为客观速度 (因为主观速度对识别略有影响,虽可克服,但懒得设计训练步骤,正好改成客观速度更符合今后的设计);
 *      2020.08.06: 将lastXY位置记录,加上initTime,因为ios的复用机制,会导致复用已销毁同内存地址的view (参考20151-BUG11);
 */
+(NSInteger) speed:(HEView*)target{
    //>> 主观速度代码;
    //CGFloat speed = 0;
    //CGPoint targetPoint = [UIView convertWorldPoint:target];
    //CGPoint selfPoint = [UIView convertWorldPoint:selfView];
    //CGFloat distanceX = (targetPoint.x - selfPoint.x);
    //CGFloat distanceY = (targetPoint.y - selfPoint.y);
    //CGFloat distance = sqrt(powf(distanceX, 2) + powf(distanceY, 2));
    //
    //NSString *key = STRFORMAT(@"lastDistanceOf_%p_%p",selfView,target);
    //NSObject *lastDistanceNum = [[XGRedis sharedInstance] objectForKey:key];
    //if (ISOK(lastDistanceNum, NSNumber.class)) {
    //    CGFloat lastDistance = [((NSNumber*)lastDistanceNum) floatValue];
    //    speed = distance - lastDistance;
    //}
    //[[XGRedis sharedInstance] setObject:[NSNumber numberWithFloat:distance] forKey:key time:cRTDefault];
    //return (NSInteger)speed;

    //1. 当前位置
    CGFloat speed = 0;
    CGPoint targetPoint = [UIView convertWorldPoint:target];
    //2. 上帧位置
    NSString *lastXKey = STRFORMAT(@"lastX_%p_%lld",target,target.initTime);
    NSString *lastYKey = STRFORMAT(@"lastY_%p_%lld",target,target.initTime);
    NSObject *lastXObj = [[XGRedis sharedInstance] objectForKey:lastXKey];
    NSObject *lastYObj = [[XGRedis sharedInstance] objectForKey:lastYKey];
    if (ISOK(lastXObj, NSNumber.class) && ISOK(lastYObj, NSNumber.class)) {
        CGFloat lastX = [((NSNumber*)lastXObj) floatValue];
        CGFloat lastY = [((NSNumber*)lastYObj) floatValue];
        
        //3. 计算位置差
        CGFloat distanceX = (targetPoint.x - lastX);
        CGFloat distanceY = (targetPoint.y - lastY);
        speed = sqrt(powf(distanceX, 2) + powf(distanceY, 2));
    }
    
    //4. 存位置下帧用
    [[XGRedis sharedInstance] setObject:[NSNumber numberWithFloat:targetPoint.x] forKey:lastXKey time:cRTDefault];
    [[XGRedis sharedInstance] setObject:[NSNumber numberWithFloat:targetPoint.y] forKey:lastYKey time:cRTDefault];
    
    //5. 返回结果 (保留整数位)
    return (NSInteger)speed;
}

//direction
+(CGFloat) direction:(UIView*)selfView target:(UIView*)target{
    //1. 取距离
    CGPoint distanceP = [UIView distancePoint:selfView target:target];
    
    //2. 在身上,则距离为(0,0);
    //CGFloat distance = [UIView distance:selfView target:target];
    //if (distance == 0) {
    //    distanceP = CGPointMake(0, 0);
    //}
    
    //2. 将距离转成角度-PI -> PI (从右至左,上面为-0 -> -3.14 / 从右至左,下面为0 -> 3.14)
    CGFloat rads = atan2f(distanceP.y,distanceP.x);
    
    //3. 将(-PI到PI) 转换成 (0到1)
    float protoParam = (rads / M_PI + 1) / 2;
    
    //4. 将(0到1)转成四舍五入整数(0-8);
    int paramInt = (int)roundf(protoParam * 8.0f);
    
    //5. 如果是8,也是0;
    float result = (paramInt % 8) / 8.0f;
    if (Log4CortexAlgs) NSLog(@"视觉目标 方向 >> 角度:%f 原始参数:%f 返回参数:%f",rads / M_PI * 180,protoParam,result);
    return result;
}

//distance
+(NSInteger) distance:(UIView*)selfView target:(UIView*)target{
    CGPoint disPoint = [UIView distancePoint:selfView target:target];
    CGFloat disFloat = sqrt(powf(disPoint.x, 2) + powf(disPoint.y, 2));
    NSInteger distance = (NSInteger)(disFloat / 3.0f);
    if (distance <= 5) distance = 0;//与身体重叠,则距离为0;
    return distance;
}

/**
 *  MARK:--------------------distanceY--------------------
 *  @version
 *      2021.01.23: 改为返回真实距离 (什么距离可以被撞到,由反省类比自行学习);
 *      2021.01.24: 真实距离导致DisY在多向飞行的VRS评价容易为否,所以先停掉 (随时防撞训练时,需要再打开,因为多向飞行向上下飞,应该可以不怕此问题);
 *      2021.01.24: 经分析评价为否是因为很少经历多变的DisY,所以将直投到乌鸦身上的位置更随机些,此处又改为真实距离了 (经训练多向飞行ok);
 */
+(NSInteger) distanceY:(UIView*)selfView target:(UIView*)target{
    return selfView.y - target.y;
    //1. 数据准备;
    //CGFloat selfY = [UIView convertWorldRect:selfView].origin.y;
    //CGFloat selfMaxY = selfY + selfView.height;
    //CGFloat targetY = [UIView convertWorldRect:target].origin.y;
    //CGFloat targetMaxY = targetY + target.height;
    //
    ////2. self在下方时;
    //if (selfY > targetMaxY) {
    //    return selfY - targetMaxY;
    //}else if(targetY > selfMaxY){
    //    //3. self在上方时;
    //    return targetY - selfMaxY;
    //}
    ////4. 有重叠时,直接返回0;
    //return 0;
}

//border
+(CGFloat) border:(UIView*)target{
    if (target) return target.layer.borderWidth;
    return 0;
}

//posX
+(NSInteger) posX:(UIView*)target{
    if (target) return (NSInteger)[UIView convertWorldPoint:target].x;
    return 0;
}

//posY
+(NSInteger) posY:(UIView*)target{
    if (target) return (NSInteger)[UIView convertWorldPoint:target].y;
    return 0;
}

@end
