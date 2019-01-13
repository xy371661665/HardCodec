//
//  PlayVC.m
//  HardAvcoder
//
//  Created by coolkit on 2018/11/26.
//  Copyright © 2018 apple. All rights reserved.
//

#import "PlayVC.h"
#import "AvcDecoder.h"
#import <AVFoundation/AVFoundation.h>

@interface PlayVC ()<AvcDecoderDelegate>

@property (nonatomic,strong) UIImageView*  mainImageView;

@property (nonatomic,strong) AVSampleBufferDisplayLayer*  sampleBufferLayer;

@end

@implementation PlayVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self initView];
    if (self.filePath) {
        [self receiveData:self.filePath];
    }
    
}

-(void)initView{
//    [self.mainImageView.layer addSublayer:self.sampleBufferLayer];
    [self.view addSubview:self.mainImageView];
}

-(UIImageView *)mainImageView{
    if (!_mainImageView) {
        _mainImageView = [[UIImageView alloc] initWithFrame:self.view.frame];
    }
    return _mainImageView;
}

-(AVSampleBufferDisplayLayer *)sampleBufferLayer{
    if (!_sampleBufferLayer) {
        _sampleBufferLayer = [AVSampleBufferDisplayLayer layer];
        [_sampleBufferLayer setBounds:self.view.bounds];
        [_sampleBufferLayer setPosition:self.view.center];
//        [_sampleBufferLayer setBackgroundColor:[UIColor redColor].CGColor];
        [_sampleBufferLayer setVideoGravity:AVLayerVideoGravityResizeAspect];
        [_sampleBufferLayer setOpaque:YES];
        
        
        
    }
    return _sampleBufferLayer;
}

#pragma mark -- util
-(void)receiveData:(NSString*)filePath{
    [[AvcDecoder getInstance] setDisplayLayer:self.sampleBufferLayer];
    [[AvcDecoder getInstance] decoderFile:filePath];
    [[AvcDecoder getInstance] setDelegate:self];
}


#pragma mark - Navigation
/*
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"pushToPlayVC"]) {
        [self receiveData:(NSString*)sender];
    }
}
*/

#pragma mark -- AvcDecoderDelegate
-(void)onReceiveCVPixelBuffer:(CVPixelBufferRef)pixelBuffer{
    
    self.mainImageView.image = [UIImage imageWithCIImage:[CIImage imageWithCVPixelBuffer:pixelBuffer]];
}

@end
