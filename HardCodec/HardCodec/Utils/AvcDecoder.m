//
//  AvcDecoder.m
//  HardAvcoder
//
//  Created by coolkit on 2018/11/26.
//  Copyright © 2018 apple. All rights reserved.
//

#import "AvcDecoder.h"
#import <VideoToolbox/VideoToolbox.h>


@interface AvcDecoder()

{
    
    dispatch_queue_t decoder_queue;
    
    NSData* spsData;
    NSData* ppsData;
    NSData* seiData;
    
    NSMutableData* frameData;
    
    
    CMFormatDescriptionRef formoatDescRef;
}

@end

@implementation AvcDecoder

+(instancetype)getInstance{
    static AvcDecoder* instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AvcDecoder alloc] init];
    });
    return instance;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        frameData = [NSMutableData data];
    }
    return self;
}

-(void)decoderFile:(NSString *)filePath{
    NSData* data = [NSData dataWithContentsOfFile:filePath];
//    NSLog(@"data:<%s>",buffer);
    
    int bufferOffset = 0;
    [self checkFormateNALU:&bufferOffset data:data];
    
    NSLog(@"after check sps :%d",bufferOffset);
    
}

-(void)checkFormateNALU:(int*)bufferOffset data:(NSData*)data{
    Byte dataByte[data.length];
    [data getBytes:dataByte range:NSMakeRange(0, data.length)];
    
    int headLength = 4;
    int from = -1,to = 0;
    // 如果剩余的长度比一个startCode大的话继续循环,检查出sps pps和sei的数据，并且返回第一个i帧的位置
    while (data.length - *bufferOffset > headLength) {
        
        // 获取startCode验证
        if (dataByte[*bufferOffset] == 0x00&&
            dataByte[*bufferOffset+1] == 0x00&&
            dataByte[*bufferOffset+2] == 0x00&&
            dataByte[*bufferOffset+3] == 0x01) {
            
            if (from == -1) {
                from = *bufferOffset;
                *bufferOffset = from + 4;
                continue;
            }else{
                to = *bufferOffset;
            }
            
            if (to != 0) {
                
                int length = to-from;
                
                // 获取数据
                NSData* pkgData = [data subdataWithRange:NSMakeRange(from, length)];
                
                // 获取检测数据类型数据
                Byte typeByte;
                [data getBytes:&typeByte range:NSMakeRange(from + 4, 1)];
                
                // 检测数据类型
                AvcDecoderNALUType type = [self checkNALUType:typeByte];
                
                [self checkNALU:pkgData type:type];
                
                to = 0;
                from = *bufferOffset;
            }
            
            
            
        }
        
        (*bufferOffset)++;
        
        
        
    }
}

-(AvcDecoderNALUType)checkNALUType:(Byte)type{
    Byte naluType = type&0x1F;// nalu类型
    Byte nal_reference = type&0x20; // nalu 的重要程度，为0的可以舍弃
    switch (naluType) {
        case 0x7:
            return AvcDecoderNALUTypeSPS;
        case 0x8:
            return AvcDecoderNALUTypePPS;
        case 0x6:
            return AvcDecoderNALUTypeSEI;
        case 0x5:
            return AvcDecoderNALUTypeI;
        case 0x1:
            if (nal_reference == 0x20) {
                return AvcDecoderNALUTypeP;
            }else{
                return AvcDecoderNALUTypeB;
            }
        
        default:
            return AvcDecoderNALUTypeUnKnown;
    }
}


/**
 检测出sps pps 和 sei 如果全都检测出来了就返回true

 @param nalu 数据块
 @param type 数据类型
 */
-(void)checkNALU:(NSData*)nalu type:(AvcDecoderNALUType)type{
    switch (type) {
        case AvcDecoderNALUTypeSPS:
            spsData = nalu;
            break;
        case AvcDecoderNALUTypePPS:
            ppsData = nalu;
            break;
        case AvcDecoderNALUTypeSEI:
            seiData = nalu;
            break;
        case AvcDecoderNALUTypeP:
        case AvcDecoderNALUTypeI:
            if ([self initH264Decoder]) {
                [self decoderFrame:nalu type:type];
            }
            break;
        default:
            break;
    }
    
    NSLog(@"frame data:%@",nalu);
}



-(void)decoderFrame:(NSData*)nalu type:(AvcDecoderNALUType)type{
    if (formoatDescRef) {
        size_t naluLength = (size_t)nalu.length;
        CMBlockBufferRef blockBuffer;
        OSStatus createBlockStatus = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, (void *)[nalu bytes], naluLength, kCFAllocatorNull, NULL, 0, naluLength, 0, &blockBuffer);
        if (createBlockStatus != noErr) {
            return;
        }
        const size_t sampleSizeArray[] = { naluLength };
        CMSampleBufferRef sampleBuffer = NULL;
        OSStatus createSampleStatus = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, formoatDescRef, 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
        if (createSampleStatus != noErr || !sampleBuffer) {
            return;
        }
        
        
        
    }
}


/**
 初始化h264的解码器格式，通过已收到的sps和pps，如果已存在，直接返回YES

 @return 是否初始化成功
 */
-(BOOL)initH264Decoder{
    
    if (formoatDescRef) {
        return YES;
    }
    
    if (spsData&&ppsData) {
        NSMutableData* tempPPSData = [NSMutableData dataWithData:ppsData];
        if (seiData) {
            [tempPPSData appendData:seiData];
        }
        Byte spsDataByte[spsData.length];
        Byte ppsDataByte[tempPPSData.length];
        
        [spsData getBytes:spsDataByte length:spsData.length];
        [tempPPSData getBytes:ppsDataByte length:tempPPSData.length];
        
        const uint8_t *const parameterSetPointers[2] = {spsDataByte,ppsDataByte};
        const size_t parameterSetPointerSize[2] = {(size_t)spsData.length,(size_t)ppsData.length};
        
        CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetPointerSize, 4, &formoatDescRef);
        return YES;
    }
    
    return NO;
}


@end
