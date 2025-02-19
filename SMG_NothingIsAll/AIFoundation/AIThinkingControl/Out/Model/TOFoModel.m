//
//  TOFoModel.m
//  SMG_NothingIsAll
//
//  Created by jia on 2019/1/30.
//  Copyright © 2019年 XiaoGang. All rights reserved.
//

#import "TOFoModel.h"

@interface TOFoModel()

@property (strong, nonatomic) NSMutableArray *subModels;
@property (strong, nonatomic) NSMutableArray *subDemands;

@end

@implementation TOFoModel

+(TOFoModel*) newWithFo_p:(AIKVPointer*)fo_p base:(TOModelBase<ITryActionFoDelegate>*)base{
    //1. 数据准备;
    AIFoNodeBase *fo = [SMGUtils searchNode:fo_p];
    TOFoModel *result = [[TOFoModel alloc] initWithContent_p:fo_p];
    
    //2. 赋值;
    result.status = TOModelStatus_Runing;
    if (base) [base.actionFoModels addObject:result];
    result.baseOrGroup = base;
    result.actionIndex = -1;//默认为头(-1),r和h任务自行重赋值;
    result.targetSPIndex = fo.count;//默认到尾(foCount),h任务自行重赋值;
    return result;
}

/**
 *  MARK:--------------------每层第一名之和分值--------------------
 *  @desc 跨fo的综合评分,
 *          1. 比如打篮球去?还是k歌去,打篮球考虑到有没有球,球场是否远,自己是否累,天气是否好, k歌也考虑到自己会唱歌不,嗓子是否舒服;
 *          2. 当对二者进行综合评分,选择时,涉及到结构化下的综合评分;
 *          3. 目前用不着,以后可能也用不着;
 *
 */
//-(CGFloat) allNiceScore{
//    //TOModelBase *subModel = [self itemSubModels];
//    //if (subModel) {
//    //    return self.score + [subModel allNiceScore];
//    //}
//    //1. 从当前actionIndex
//    //2. 找itemSubModels下
//    //3. 所有status未中止的
//    //4. 那些时序的评分总和
//    return self.score;
//}

-(NSMutableArray *)subModels {
    if (_subModels == nil) _subModels = [[NSMutableArray alloc] init];
    return _subModels;
}
-(NSMutableArray *)subDemands{
    if (_subDemands == nil) _subDemands = [[NSMutableArray alloc] init];
    return _subDemands;
}

//-(void)setActionIndex:(NSInteger)actionIndex{
//    NSLog(@"toFo.setActionIndex:%ld -> %ld",self.actionIndex,actionIndex);
//    _actionIndex = actionIndex;
//}

/**
 *  MARK:--------------------NSCoding--------------------
 */
- (nullable instancetype)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        self.subModels = [aDecoder decodeObjectForKey:@"subModels"];
        self.actionIndex = [aDecoder decodeIntegerForKey:@"actionIndex"];
        self.targetSPIndex = [aDecoder decodeIntegerForKey:@"targetSPIndex"];
        self.subDemands = [aDecoder decodeObjectForKey:@"subDemands"];
    }
    return self;
}

- (void)encodeWithCoder:(NSCoder *)aCoder {
    [super encodeWithCoder:aCoder];
    [aCoder encodeObject:self.subModels forKey:@"subModels"];
    [aCoder encodeInteger:self.actionIndex forKey:@"actionIndex"];
    [aCoder encodeInteger:self.targetSPIndex forKey:@"targetSPIndex"];
    [aCoder encodeObject:self.subDemands forKey:@"subDemands"];
}

@end
