//
//  AvcEncoder.m
//  HardAvcoder
//
//  Created by apple on 2018/11/24.
//  Copyright © 2018年 apple. All rights reserved.
//

#import "AvcEncoder.h"
#import <VideoToolbox/VideoToolbox.h>

@interface AvcEncoder()
{
    VTCompressionSessionRef compressionSessionRef;
    
    int dps;
    
    dispatch_queue_t encoderQueue;
    
}

@property (nonatomic,assign)BOOL isContainSPS;
@end

@implementation AvcEncoder

+(instancetype)getInstance{
    static AvcEncoder* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AvcEncoder alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        dps = 0;
        _isContainSPS = NO;
        encoderQueue = dispatch_queue_create("com.HardAvcoder.encoder", NULL);
    }
    return self;
}

/**
 创建编码器，并且设置参数，准备编码

 @param width 获取到视频的宽度
 @param height 获取到视频的高度
 @param fps 帧率
 @param bps 码率
 */
-(void)prepareEncoder:(int)width height:(int)height fps:(int)fps bps:(int)bps{
    
    // 创建编码器会话
    VTCompressionSessionCreate(NULL, width, height, kCMVideoCodecType_H264, NULL, NULL, NULL, outputCallBack, (__bridge void *)self, &compressionSessionRef);
    
    
    
    // 设置为实时视频流
    VTSessionSetProperty(compressionSessionRef, kVTCompressionPropertyKey_RealTime, kCFBooleanTrue);
    
    // 设置期望帧率
    CFNumberRef fpsCFNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &fps);
    VTSessionSetProperty(compressionSessionRef, kVTCompressionPropertyKey_ExpectedFrameRate, fpsCFNumber);
    
    // 设置平均码率
    CFNumberRef bpsCFNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &bps);
    VTSessionSetProperty(compressionSessionRef, kVTCompressionPropertyKey_AverageBitRate, bpsCFNumber);
    
    // 设置码率上下线,不大于1.5倍
    NSArray* bateLimit = @[@(bps * 1.5 / 8),@(1)];
    VTSessionSetProperty(compressionSessionRef, kVTCompressionPropertyKey_DataRateLimits, (__bridge CFArrayRef)bateLimit);
    
    // 设置I帧间隔，这里的值实际上是两个I帧之间有多少个p帧
    int IframeRate = 30;
    CFNumberRef IFrameRateCFNumber = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &IframeRate);
    VTSessionSetProperty(compressionSessionRef, kVTCompressionPropertyKey_MaxKeyFrameInterval, IFrameRateCFNumber);

    _isContainSPS = NO;
    
   // 准备开始编码
    VTCompressionSessionPrepareToEncodeFrames(compressionSessionRef);
    
}

-(void)releaseEncoder{
    VTCompressionSessionInvalidate(compressionSessionRef);
    compressionSessionRef = NULL;
}

-(void)addCameraData:(CMSampleBufferRef)data{
    
    dispatch_sync(encoderQueue, ^{
        //CVImageBuffer的媒体数据。
        CVImageBufferRef imageBuffer = (CVImageBufferRef)CMSampleBufferGetImageBuffer(data);
        // 此帧的呈现时间戳，将附加到样本缓冲区，传递给会话的每个显示时间戳必须大于上一个。
        dps ++;
        CMTime pts = CMTimeMake(dps, 1000);
        //此帧的呈现持续时间
        CMTime duration = kCMTimeInvalid;
        VTEncodeInfoFlags flags;
        // 调用此函数可将帧呈现给压缩会话。
        OSStatus statusCode = VTCompressionSessionEncodeFrame(compressionSessionRef,
                                                              imageBuffer,
                                                              pts, duration,
                                                              NULL, NULL, &flags);
        
        if (statusCode != noErr) {
            NSLog(@"H264: VTCompressionSessionEncodeFrame failed with %d", (int)statusCode);
            return;
        }
    });
}

void outputCallBack(void *outputCallbackRefCon, void *sourceFrameRefCon, OSStatus status, VTEncodeInfoFlags infoFlags, CMSampleBufferRef sampleBuffer){
    
    AvcEncoder* encoder = (__bridge AvcEncoder*) outputCallbackRefCon;
    
    if (status != noErr) {
        return;
    }
    
    // 判断是否是I帧
    CFArrayRef sampleArr = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    
    const void* attacheValue = CFArrayGetValueAtIndex(sampleArr, 0);
    
    BOOL isNotIFrame = CFDictionaryContainsKey(attacheValue, kCMSampleAttachmentKey_NotSync);
    
    if (!isNotIFrame&&!encoder.isContainSPS) {
        
        encoder.isContainSPS = YES;
        
        // 如果是I帧获取pps和sps信息
        CMFormatDescriptionRef dataFormat = CMSampleBufferGetFormatDescription(sampleBuffer);
        
        // 获取sps
        const uint8_t* sparameterSetPointOut;
        size_t sparameterSetSizeOut,sparameterSetCountOut;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(dataFormat, 0, &sparameterSetPointOut, &sparameterSetSizeOut, &sparameterSetCountOut, 0);
        
        // 获取pps
        const uint8_t* pparameterSetPointOut;
        size_t pparameterSetSizeOut,pparameterSetCountOut;
        CMVideoFormatDescriptionGetH264ParameterSetAtIndex(dataFormat, 1, &pparameterSetPointOut, &pparameterSetSizeOut, &pparameterSetCountOut, 0);
        
        NSData* spsData = [NSData dataWithBytes:sparameterSetPointOut length:sparameterSetSizeOut];
        NSData* ppsData = [NSData dataWithBytes:pparameterSetPointOut length:pparameterSetSizeOut];
        
        if (encoder.delegate && [encoder.delegate respondsToSelector:@selector(AvcEncoder:didReceiveSPS:PPS:)]) {
            [encoder.delegate AvcEncoder:encoder didReceiveSPS:spsData PPS:ppsData];
        }
        
    }
    
    CMBlockBufferRef blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer);
    
    size_t lengthAtOffset,totalLength;
    char* dataPointer;
    
    // 获取编码数据的指针和长度
    OSStatus rtnStatus = CMBlockBufferGetDataPointer(blockBuffer, 0, &lengthAtOffset, &totalLength, &dataPointer);
    if (rtnStatus == noErr) {
        size_t bufferOffset = 0;
        
        static int NALUHeaderLenght = 4;
        
        while (bufferOffset < totalLength - NALUHeaderLenght) {
            
            uint32_t dataLength;
            
            // 获取数据的长度
            memcpy(&dataLength, dataPointer+bufferOffset, NALUHeaderLenght);
            
            // 从网络数据格式转化为系统数据格式
            dataLength = CFSwapInt32BigToHost(dataLength);
            
            // 获取数据封装撑NSData
            NSData* frameData = [NSData dataWithBytes:(dataPointer + bufferOffset + NALUHeaderLenght) length:dataLength];
            
            // 确定帧类型
            AvcEncoderFrameType type;
            if (isNotIFrame) {
                type = AvcEncoderFrameTypePFrame;
            }else{
                type = AvcEncoderFrameTypeIFrame;
            }
            
            if (encoder.delegate && [encoder.delegate respondsToSelector:@selector(AvcEncoder:didReceiveFrame:type:)]) {
                [encoder.delegate AvcEncoder:encoder didReceiveFrame:frameData type:type];
            }
            
            bufferOffset += NALUHeaderLenght + dataLength;
            
        }
        
    }
    
}

@end
