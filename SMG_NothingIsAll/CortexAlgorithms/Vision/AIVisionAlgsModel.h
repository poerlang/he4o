//
//  AIVisionAlgsModel.h
//  SMG_NothingIsAll
//
//  Created by jiaxiaogang on 2018/11/19.
//  Copyright © 2018年 XiaoGang. All rights reserved.
//

#import <Foundation/Foundation.h>


/**
 *  MARK:--------------------视觉算法结果模型--------------------
 *  1. 用于输入到ThinkingControl;
 */
@interface AIVisionAlgsModel : NSObject

//size
//@property (assign,nonatomic) CGFloat sizeWidth;
@property (assign,nonatomic) CGFloat sizeHeight;

//color
//@property (assign,nonatomic) NSInteger colorRed;
//@property (assign,nonatomic) NSInteger colorGreen;
//@property (assign,nonatomic) NSInteger colorBlue;

//radius
//@property (assign,nonatomic) CGFloat radius;

//speed
@property (assign,nonatomic) NSInteger speed;

//direction
@property (assign,nonatomic) CGFloat direction;

//distance
@property (assign,nonatomic) NSInteger distance;

//border
@property (assign,nonatomic) CGFloat border;

//20190723: originX和originY由direction和distance替代;
//20200317: 二测训练时,再打开,与distance共存,并更名为posX/Y;
@property (assign,nonatomic) NSInteger posX;
@property (assign,nonatomic) NSInteger posY;

@end
