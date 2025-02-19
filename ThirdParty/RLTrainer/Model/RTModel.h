//
//  RTModel.h
//  SMG_NothingIsAll
//
//  Created by jia on 2022/3/31.
//  Copyright © 2022年 XiaoGang. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RTModelDelegate <NSObject>

-(BOOL) rtModel_Playing;
-(void) rtModel_Invoked;
-(void) rtModel_Finished;

@end

@interface RTModel : NSObject

@property (weak, nonatomic) id<RTModelDelegate> delegate;

//MARK:===============================================================
//MARK:                     < getset >
//MARK:===============================================================
-(NSMutableArray *)queues;
-(NSInteger)queueIndex;

//MARK:===============================================================
//MARK:                     < publicMethod >
//MARK:===============================================================
-(void) regist:(NSString*)name target:(NSObject*)target selector:(SEL)selector;
-(void) queue:(NSArray*)names count:(NSInteger)count;
-(void) invoked:(NSString*)name;
-(void) clear;
-(long long) getTotalUseTimed;

@end
