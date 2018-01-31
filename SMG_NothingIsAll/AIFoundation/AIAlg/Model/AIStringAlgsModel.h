//
//  AIStringAlgsModel.h
//  SMG_NothingIsAll
//
//  Created by 贾  on 2017/12/20.
//  Copyright © 2017年 XiaoGang. All rights reserved.
//

#import "AIInputModel.h"

@interface AIStringAlgsModel : AIInputModel

@property (strong,nonatomic) NSString *str;
@property (assign, nonatomic) NSUInteger length;
@property (strong,nonatomic) NSArray *spell;

@end
