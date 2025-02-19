//
//  RLTPanel.m
//  SMG_NothingIsAll
//
//  Created by jia on 2022/4/15.
//  Copyright © 2022年 XiaoGang. All rights reserved.
//

#import "RLTPanel.h"
#import "MASConstraint.h"
#import "View+MASAdditions.h"
#import "TOMVisionItemModel.h"
#import "PINDiskCache.h"
#import "TVideoWindow.h"
#import "TVUtil.h"
#import "XGDebugTV.h"
#import "XGLabCell.h"

@interface RLTPanel () <UITableViewDelegate,UITableViewDataSource>

@property (strong, nonatomic) IBOutlet UIView *containerView;
@property (weak, nonatomic) IBOutlet UITableView *tv;
@property (weak, nonatomic) IBOutlet XGDebugTV *debugTV;
@property (weak, nonatomic) IBOutlet UILabel *mvScoreLab;
@property (weak, nonatomic) IBOutlet UILabel *spScoreLab;
@property (weak, nonatomic) IBOutlet UILabel *sStrongLab;
@property (weak, nonatomic) IBOutlet UILabel *pStrongLab;
@property (weak, nonatomic) IBOutlet UILabel *solutionLab;
@property (weak, nonatomic) IBOutlet UILabel *progressLab;
@property (weak, nonatomic) IBOutlet UILabel *timeLab;
@property (weak, nonatomic) IBOutlet UIButton *playBtn;
@property (weak, nonatomic) IBOutlet UIButton *stopBtn;
@property (strong, nonatomic) NSArray *tvDatas;
@property (assign, nonatomic) NSInteger tvIndex;

@end

@implementation RLTPanel

-(id) init {
    self = [super init];
    if(self != nil){
        [self initView];
        [self initData];
        [self initDisplay];
    }
    return self;
}

-(void) initView{
    //self
    [self setAlpha:0.5f];
    CGFloat width = 350;//ScreenWidth * 0.667f;
    [self setFrame:CGRectMake(ScreenWidth - width - 20, 64, width, ScreenHeight - 128)];
    
    //containerView
    [[NSBundle mainBundle] loadNibNamed:NSStringFromClass(self.class) owner:self options:nil];
    [self addSubview:self.containerView];
    [self.containerView mas_makeConstraints:^(MASConstraintMaker *make) {
        make.leading.mas_equalTo(self);
        make.trailing.mas_equalTo(self);
        make.top.mas_equalTo(self);
        make.bottom.mas_equalTo(self);
    }];
    [self.containerView.layer setCornerRadius:8.0f];
    [self.containerView.layer setBorderWidth:1.0f];
    [self.containerView.layer setBorderColor:UIColorWithRGBHex(0x000000).CGColor];
    
    //tv
    self.tv.delegate = self;
    self.tv.dataSource = self;
    [self.tv.layer setBorderWidth:1.0f];
    [self.tv.layer setBorderColor:UIColorWithRGBHex(0x0000FF).CGColor];
    [self.tv registerClass:[UITableViewCell class] forCellReuseIdentifier:@"spaceCell"];
    [self.tv registerClass:[XGLabCell class] forCellReuseIdentifier:@"queueCell"];
    
    //debugTV
    [self.debugTV.layer setBorderWidth:1.0f];
    [self.debugTV.layer setBorderColor:UIColorWithRGBHex(0x0000FF).CGColor];
}

-(void) initData{
    self.playing = false;
}

-(void) initDisplay{
    [self close];
}

-(void) refreshDisplay{
    //1. 取数据
    self.tvDatas = ARRTOOK([self.delegate rltPanel_getQueues]);
    self.tvIndex = [self.delegate rltPanel_getQueueIndex];
    
    //2. tv
    [self.tv reloadData];
    if (self.tvIndex < self.tvDatas.count) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.tv scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:self.tvIndex inSection:1] atScrollPosition:UITableViewScrollPositionMiddle animated:true];
        });
    }
    
    //3. progressLab
    self.progressLab.text = STRFORMAT(@"%ld / %ld",self.tvIndex,self.tvDatas.count);
    
    //4. 使用时间;
    double useTimed = [self.delegate rltPanel_getUseTimed];
    double totalTime = self.tvIndex == 0 ? 0 : useTimed * self.tvDatas.count / self.tvIndex;
    int useT = (int)useTimed, totT = (int)totalTime;
    NSString *timeStr = STRFORMAT(@"%d:%d / %d:%d", useT / 60, useT % 60, totT / 60, totT % 60);
    [self.timeLab setText:timeStr];
    
    //5. 综评分;
    NSString *scoreStr = [self mvScoreStr];
    [self.mvScoreLab setText:scoreStr];
    
    //6. 稳定性 & 平均SP强度;
    __block typeof(self) weakSelf = self;
    [self spStr:^(CGFloat rateSPScore, CGFloat rateSStrong, CGFloat ratePStrong) {
        [weakSelf.spScoreLab setText:STRFORMAT(@"%.1f",rateSPScore)];
        [weakSelf.sStrongLab setText:STRFORMAT(@"%.1f",rateSStrong)];
        [weakSelf.pStrongLab setText:STRFORMAT(@"%.1f",ratePStrong)];
    }];
    
    //7. 有解率;
    CGFloat rateSolution = [self solutionStr];
    [self.solutionLab setText:STRFORMAT(@"%.0f％",rateSolution * 100)];
    
    //8. 性能分析;
    [self.debugTV updateModels];
}

//MARK:===============================================================
//MARK:                     < getset >
//MARK:===============================================================
-(void)setPlaying:(BOOL)playing{
    _playing = playing;
    [self.playBtn setTitle: self.playing ? @"暂停" : @"播放" forState:UIControlStateNormal];
}

//MARK:===============================================================
//MARK:                     < publicMethod >
//MARK:===============================================================
-(void) reloadData{
    [self refreshDisplay];
}
-(void) open{
    [self setHidden:false];
}
-(void) close{
    [self setHidden:true];
}

//MARK:===============================================================
//MARK:                     < privateMethod >
//MARK:===============================================================
-(NSString*) cellStr:(NSString*)queue {
    if ([kGrowPageSEL isEqualToString:queue]) {
        return @"页 - 进入成长页";
    }else if ([kFlySEL isEqualToString:queue]) {
        return @"飞 - 随机";
    }else if ([kWoodLeftSEL isEqualToString:queue]) {
        return @"棒 - 扔木棒";
    }else if ([kWoodRdmSEL isEqualToString:queue]) {
        return @"棒 - 随机扔木棒";
    }else if ([kMainPageSEL isEqualToString:queue]) {
        return @"页 - 回主页";
    }else if ([kClearTCSEL isEqualToString:queue]) {
        return @"页 - 重启";
    }else if ([kBirthPosRdmSEL isEqualToString:queue]) {
        return @"参 - 出生地随机";
    }else if ([kBirthPosRdmCentSEL isEqualToString:queue]) {
        return @"参 - 出生地随机偏路中";
    }
    return @"";
}

-(CGFloat) queueCellHeight{
    CGFloat maskHeight = 10.0f;//大概计算10左右高;
    int size = (int)(self.tv.height / maskHeight);
    size = size / 2 * 2 + 1;
    return self.tv.height / size;
}

-(CGFloat) spaceCellHeight{
    CGFloat cellH = [self queueCellHeight];
    return (self.tv.height - cellH) * 0.5f;
}

-(NSString*) mvScoreStr {
    //1. 数据准备;
    NSArray *roots = theTC.outModelManager.getAllDemand;
    NSMutableString *mStr = [[NSMutableString alloc] init];
    
    //2. 分别对每个根任务,进行评分;
    for (DemandModel *root in roots) {
        
        //3. 取最佳解决方案;
        NSMutableDictionary *scoreDic = [[NSMutableDictionary alloc] init];
        TOFoModel *bestFo = [TCScore score_Multi:root.actionFoModels scoreDic:scoreDic];
        
        //4. 综合评分 = 最佳解决方案评分 + 任务评分;
        double rootScore = [AIScore score4Demand:root];
        double bestFoScore = [NUMTOOK([scoreDic objectForKey:TOModel2Key(bestFo)]) doubleValue];
        
        //5. 收集结果;
        [mStr appendFormat:@"%.1f ",rootScore + bestFoScore];
    }
    return mStr;
}

-(void) spStr:(void(^)(CGFloat rateSPScore, CGFloat rateSStrong, CGFloat ratePStrong))complete{
    //0. 数据准备;
    NSMutableArray *spScoreArr = [[NSMutableArray alloc] init];
    NSMutableArray *spStrongArr = [[NSMutableArray alloc] init];
    
    //1. 收集根下所有树枝;
    NSArray *roots = theTC.outModelManager.getAllDemand;
    NSArray *branchs = [TVUtil collectAllSubTOModelByRoots:roots];
    NSArray *solutions = [SMGUtils filterArr:branchs checkValid:^BOOL(TOModelBase *item) {
        return ISOK(item, TOFoModel.class);
    }];
    
    //2. 逐一对任务,的解决方案树枝进行sp计算;
    for (TOFoModel *solution in solutions) {
        
        //3. 计算spIndex;
        AIFoNodeBase *fo = [SMGUtils searchNode:solution.content_p];
        NSInteger spIndex = -1;
        if (ISOK(solution.baseOrGroup, HDemandModel.class)) {
            HDemandModel *hDemand = (HDemandModel*)solution.baseOrGroup;
            AIAlgNodeBase *hAlg = [SMGUtils searchNode:hDemand.baseOrGroup.content_p];
            spIndex = [TOUtils indexOfConOrAbsItem:hAlg.pointer atContent:fo.content_ps layerDiff:1 startIndex:0 endIndex:NSUIntegerMax];
        }else if(ISOK(solution.baseOrGroup, ReasonDemandModel.class)){
            spIndex = fo.count;
        }
        
        //4. 根据spIndex计算稳定性和SP统计;
        if (spIndex > 0) {
            
            //5. 计入sp分;
            CGFloat checkSPScore = [TOUtils getSPScore:fo startSPIndex:0 endSPIndex:spIndex];
            [spScoreArr addObject:@(checkSPScore)];
            
            //6. 计入sp值;
            for (NSInteger i = 0; i <= spIndex; i++) {
                AISPStrong *spStrong = [fo.spDic objectForKey:@(i)];
                if (spStrong) {
                    [spStrongArr addObject:spStrong];
                }
            }
        }
    }
    
    //7. 得出平均结果,并返回;
    CGFloat sumSPScore = 0,sumSStrong = 0,sumPStrong = 0;
    for (NSNumber *item in spScoreArr){
        sumSPScore += item.floatValue;
    }
    for (AISPStrong *item in spStrongArr){
        sumSStrong += item.sStrong;
        sumPStrong += item.pStrong;
    }
    CGFloat rateSPScore = spScoreArr.count == 0 ? 0 : sumSPScore / spScoreArr.count;
    CGFloat rateSStrong = spStrongArr.count == 0 ? 0 : sumSStrong / spStrongArr.count;
    CGFloat ratePStrong = spStrongArr.count == 0 ? 0 : sumPStrong / spStrongArr.count;
    complete(rateSPScore,rateSStrong,ratePStrong);
}

-(CGFloat) solutionStr{
    //1. 收集根下所有树枝;
    NSArray *roots = theTC.outModelManager.getAllDemand;
    NSArray *branchs = [TVUtil collectAllSubTOModelByRoots:roots];
    NSArray *demands = [SMGUtils filterArr:branchs checkValid:^BOOL(TOModelBase *item) {
        return ISOK(item, DemandModel.class);
    }];
    
    //2. 统计有解率;
    NSInteger havSolutionCount = 0;
    for (DemandModel *demand in demands) {
        if (ARRISOK(demand.actionFoModels)) {
            havSolutionCount++;
        }
    }
    return demands.count > 0 ? (float)havSolutionCount / demands.count : 0;
}

//MARK:===============================================================
//MARK:                     < onclick >
//MARK:===============================================================
- (IBAction)playBtnOnClick:(id)sender {
    self.playing = !self.playing;
}

- (IBAction)stopBtnOnClick:(id)sender {
    [self.delegate rltPanel_Stop];
}

- (IBAction)closeBtnOnClick:(id)sender {
    [self close];
}

/**
 *  MARK:--------------------学被撞--------------------
 *  @desc
 *      1. 说明: 学被撞 (出生随机位置,被随机扔出的木棒撞 x 300);
 *      2. 作用: 主要用于训练识别功能 (耗时约50min) (参考26197-1);
 *  @version
 *      2022.06.05: 调整 (参考26197-1&2);
 */
- (IBAction)loadHitBtnOnClick:(id)sender {
    [theRT queue1:kBirthPosRdmSEL];
    [theRT queueN:@[kGrowPageSEL,kWoodRdmSEL,kMainPageSEL,kClearTCSEL] count:200];
    [theRT queueN:@[kGrowPageSEL,kWoodLeftSEL,kMainPageSEL,kClearTCSEL] count:100];
}

/**
 *  MARK:--------------------学飞躲--------------------
 *  @desc
 *      1. 说明: 学飞躲 (出生随机偏中位置,左棒,随机飞x2,左棒 x 100);
 *      2. 作用: 从中习得防撞能力,躲避危险;
 */
//步骤参考26029-加长版强化加训 (参考26031-2);
- (IBAction)loadFlyBtnOnClick:(id)sender {
    //0. 无日志模式;
    //[self.delegate rltPanel_setNoLogMode:true];
    
    //0. 出生在随机偏中位置 (以方便训练被撞和躲开经验);
    [theRT queue1:kBirthPosRdmCentSEL];
    
    //0. 加长版训练100轮
    for (int j = 0; j < 100; j++) {
        
        //1. 进入训练页
        NSMutableArray *names = [[NSMutableArray alloc] init];
        [names addObject:kGrowPageSEL];
        
        //2. 随机飞或扔木棒,五步;
        for (int i = 0; i < 5; i++) {
            NSArray *randomNames = @[kFlySEL,kWoodLeftSEL];
            int randomIndex = arc4random() % 2;
            NSString *randomName = ARR_INDEX(randomNames, randomIndex);
            [names addObject:randomName];
        }
        
        //3. 退到主页,模拟重启;
        [names addObjectsFromArray:@[kMainPageSEL,kClearTCSEL]];
        
        //4. 训练names;
        [theRT queueN:names count:1];
    }
}

//MARK:===============================================================
//MARK:                     < 训练项 >
//MARK:===============================================================
//步骤参考26011-基础版强化训练;
-(void) trainer1{
    [theRT queue1:kGrowPageSEL];
    [theRT queueN:@[kFlySEL,kWoodLeftSEL] count:5];
}
//步骤参考xxxxx
-(void) trainer2{
    [theRT queueN:@[kGrowPageSEL,kFlySEL,kFlySEL,kWoodLeftSEL,kMainPageSEL,kClearTCSEL] count:20];
}

/**
 *  MARK:-------------------- 训练躲避 --------------------
 *  @version
 *      xxxx.xx.xx: 初版 (参考26081-2);
 *      2022.05.26: 少飞一步,变成[棒,飞,飞,棒],因为瞬时记忆只有4条;
 */
-(void) trainer5{
    //0. 出生在随机偏中位置 (以方便训练被撞和躲开经验);
    [theRT queue1:kBirthPosRdmCentSEL];
    
    //1. 加长版训练100轮
    [theRT queueN:@[kGrowPageSEL,kWoodLeftSEL,kFlySEL,kFlySEL,kWoodLeftSEL,kMainPageSEL,kClearTCSEL] count:100];
}

//MARK:===============================================================
//MARK:       < UITableViewDataSource &  UITableViewDelegate>
//MARK:===============================================================
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 3;
}
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if (section == 1) {
        return self.tvDatas.count;
    }
    return 1;
}
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    //1. 返回spaceCell
    if (indexPath.section != 1) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"spaceCell"];
        [cell setFrame:CGRectMake(0, 0, self.tv.width, [self spaceCellHeight])];
        return cell;
    }else {
        //2. 正常返回queueCell_数据准备;
        NSString *queue = STRTOOK(ARR_INDEX(self.tvDatas, indexPath.row));
        NSString *cellStr = STRFORMAT(@"%ld. %@",indexPath.row+1, [self cellStr:queue]);
        BOOL trained = indexPath.row < self.tvIndex;
        UIColor *color = trained ? UIColor.greenColor : UIColor.orangeColor;
        
        //3. 创建cell;
        XGLabCell *cell = [tableView dequeueReusableCellWithIdentifier:@"queueCell"];
        [cell setText:cellStr color:color font:8];
        return cell;
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    if (indexPath.section == 1) {
        return [self queueCellHeight];
    }else{
        return [self spaceCellHeight];
    }
}

@end
