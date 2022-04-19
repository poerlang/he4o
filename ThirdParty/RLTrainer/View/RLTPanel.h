//
//  RLTPanel.h
//  SMG_NothingIsAll
//
//  Created by jia on 2022/4/15.
//  Copyright © 2022年 XiaoGang. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol RLTPanelDelegate <NSObject>

-(void) RLTPanel_Stop;

@end

/**
 *  MARK:--------------------强化训练控制台--------------------
 */
@interface RLTPanel : UIView

@property (weak, nonatomic) id<RLTPanelDelegate> delegate;
@property (assign, nonatomic) BOOL playing;
-(void) open;
-(void) close;

@end
