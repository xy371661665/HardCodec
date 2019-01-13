//
//  RecordVC.m
//  HardCodec
//
//  Created by coolkit on 2018/12/10.
//  Copyright © 2018 coolkit. All rights reserved.
//


#import "RecordVC.h"
#import "CameraUtil.h"
#import "AvcEncoder.h"
#import "FileUtil.h"
#import "PlayVC.h"
#import <AVFoundation/AVFoundation.h>

@interface RecordVC ()<CameraUtilDelegate,AvcEncoderDelegate>
{
    BOOL startRecording;
    NSString* filePath;
    
    UIButton* startRecordBtn;
    
    FileUtil* fileManager;
}
@end

@implementation RecordVC

- (void)viewDidLoad {
    [super viewDidLoad];
    startRecording = NO;
    // Do any additional setup after loading the view, typically from a nib.
    
    // 初始化录制文件地址
    fileManager = [[FileUtil alloc] initWithfileName:@"recorder.h264"];
    
    // 播放视频
    [[CameraUtil getInstance] prepareCamera];
    [[CameraUtil getInstance] setDelegate:self];
    [[CameraUtil getInstance] startCamera:self.view];
    
    [self initView];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -- Navigation
-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender{
    
    if ([segue.destinationViewController isKindOfClass:[PlayVC class]]) {
        PlayVC* playVC = (PlayVC*)segue.destinationViewController;
        playVC.filePath = [fileManager getPath];
        
    }
}

#pragma mark -- util
-(void)initView{
    startRecordBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    [startRecordBtn setFrame:CGRectMake(0, 0, 100, 100)];
    [startRecordBtn setBackgroundColor:[UIColor redColor]];
    [startRecordBtn setCenter:self.view.center];
    [startRecordBtn addTarget:self action:@selector(startRecord:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:startRecordBtn];
}



- (void)writeData:(NSData*)data{
    if (data&&data.length>0) {
        [fileManager appendFileToEnd:data];
    }
}

-(void)writeHeade{
    const char bytes[] = "\x00\x00\x00\x01";
    size_t length = (sizeof bytes) - 1;
    NSData *ByteHeader = [NSData dataWithBytes:bytes length:length];
    [self writeData:ByteHeader];
}

#pragma mark -- click
- (void)startRecord:(id)sender {
    if (startRecording) {
        startRecording = NO;
        [self stopEncoder];
        
        // 跳转到播放页面
        [self performSegueWithIdentifier:@"pushToPlayVC" sender:self];
        
    }else{
        
        // 创建录制文件
        [fileManager writeFile:nil];
        
        startRecording = YES;
        // 开启编码器
        [self startEncoder];
        
    }
    
}


/**
 开启编码器
 */
-(void)startEncoder{
    int width = 480;
    int height = 640;
    [[AvcEncoder getInstance] prepareEncoder:width height:height fps:15 bps:width*height];
    [[AvcEncoder getInstance] setDelegate:self];
}

/**
 关闭编码器
 */
-(void)stopEncoder{
    [[AvcEncoder getInstance] releaseEncoder];
}

#pragma mark -- CameraUtilDelegate
-(void)CameraUtil:(CameraUtil *)cameraUtil didReceiveSampleData:(CMSampleBufferRef)data{
    if (startRecording) {
        [[AvcEncoder getInstance] addCameraData:data];
    }
    
}

#pragma mark -- AvcEncoderDelegate
-(void)AvcEncoder:(AvcEncoder *)encoder didReceiveSPS:(NSData *)sps PPS:(NSData *)pps{
    NSLog(@"receive sps:%@",sps);
    NSLog(@"receive pps:%@",pps);
    if (startRecording) {
        [self writeHeade];
        [self writeData:sps];
        [self writeHeade];
        [self writeData:pps];
    }
    
}

-(void)AvcEncoder:(AvcEncoder *)encoder didReceiveFrame:(NSData *)frame type:(AvcEncoderFrameType)type{
    
    if (startRecording) {
        [self writeHeade];
        if (type == AvcEncoderFrameTypeIFrame) {
            NSLog(@"receive i frame :%ld",frame.length);
        }else{
            NSLog(@"receive p frame :%ld",frame.length);
        }
        [self writeData:frame];
    }
}


@end
