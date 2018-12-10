//
//  CameraUtil.m
//  HardAvcoder
//
//  Created by apple on 2018/11/24.
//  Copyright © 2018年 apple. All rights reserved.
//

#import "CameraUtil.h"


@interface CameraUtil()<AVCaptureVideoDataOutputSampleBufferDelegate>
{
    AVCaptureSession* captureSession;
    
    AVCaptureDevice* cameraDevice;
    
    AVCaptureDeviceInput* deviceInput;
    
    AVCaptureVideoDataOutput* videoDataOutput;
    dispatch_queue_t outputQueue;
}
@end

@implementation CameraUtil

+(instancetype)getInstance{
    static CameraUtil* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[CameraUtil alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        captureSession = [[AVCaptureSession alloc] init];
        cameraDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    }
    return self;
}

-(BOOL)prepareCamera{
    NSError* error = nil;
    deviceInput = [[AVCaptureDeviceInput alloc] initWithDevice:cameraDevice error:&error];
    if (error) {
        return NO;
    }
    
    outputQueue = dispatch_queue_create("com.HardAvcoder.CameraUtil.OutPut", NULL);
    
    videoDataOutput = [[AVCaptureVideoDataOutput alloc] init];
    [videoDataOutput setSampleBufferDelegate:self queue:outputQueue];
    
    [captureSession addInput:deviceInput];
    [captureSession addOutput:videoDataOutput];
    
    return YES;
}
-(void)removeCamera{
    [captureSession removeInput:deviceInput];
    deviceInput = nil;
}

-(void)startCamera:(UIView*)view{
    AVCaptureVideoPreviewLayer* showLayer = [AVCaptureVideoPreviewLayer layerWithSession:captureSession];
    [showLayer setFrame:view.frame];
    [view.layer addSublayer:showLayer];
    
    [captureSession startRunning];
}

#pragma mark -- AVCaptureVideoDataOutputSampleBufferDelegate

-(void)captureOutput:(AVCaptureOutput *)output didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(CameraUtil:didReceiveSampleData:)]) {
        [self.delegate CameraUtil:self didReceiveSampleData:sampleBuffer];
    }
}

-(void)captureOutput:(AVCaptureOutput *)output didDropSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection{
    
}

@end
