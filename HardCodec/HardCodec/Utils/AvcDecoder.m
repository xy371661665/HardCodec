//
//  AvcDecoder.m
//  HardAvcoder
//
//  Created by coolkit on 2018/11/26.
//  Copyright © 2018 apple. All rights reserved.
//

#import "AvcDecoder.h"
#import <VideoToolbox/VideoToolbox.h>
#import <CoreImage/CoreImage.h>

const uint8_t startCode[4] = {0,0,0,1};

@interface AvcDecoder()

{
    NSInputStream* fileInputStream;
    CADisplayLink* displayTimer;
    
    int readOffset;
    int inputStreamMaxSize;
    
    NSMutableData* frameData;
    
    dispatch_queue_t deCodecQueue;
    
    
    
    
    
    dispatch_queue_t _displayQueue;
    
    NSData* spsData;
    NSData* ppsData;
    NSData* seiData;
    
    
    
    
    CMFormatDescriptionRef formoatDescRef;
    VTDecompressionSessionRef deCodeSessionRef;
    
    AVSampleBufferDisplayLayer* _displayLayer;
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
        
        // 开启一个屏幕刷新定时器,并且停止
        displayTimer = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateFrame)];
        [displayTimer addToRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [displayTimer setPaused:YES];
    }
    return self;
}

-(void)setDisplayLayer:(AVSampleBufferDisplayLayer*)layer{
    _displayLayer = layer;
    _displayQueue = dispatch_queue_create("com.HarCodec.playVC.sampleLayer", NULL);
    
}


-(void)decoderFile:(NSString *)filePath{
    
    // 开启文件输入流
    fileInputStream = [[NSInputStream alloc] initWithFileAtPath:filePath];
    [fileInputStream open];
    
    deCodecQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
    
    // 初始化数据
    readOffset = 0;
    inputStreamMaxSize = 640 * 480 * 4;
    
    // 开启刷屏定时器，解码
    [displayTimer setPaused:NO];
    
}


/**
 刷屏定时器
 */
-(void)updateFrame{
    // 如果存在输入流
    if (fileInputStream) {
        __weak typeof(self) ws = self;
        dispatch_async(deCodecQueue, ^{
            __strong typeof(ws) sws = ws;
            // 读取数据
            [sws readInputStream];
            
            // 从缓存数据中获取一个Nalu
            NSData* nalu = [sws readNalu];
            
            if (nalu) {
                
                // 大端转小端
                nalu = [sws HostToBig:nalu];
                
                [sws decodeNalu:nalu];
            }
        });
        
        
        
        
    }
}


/**
 从输入流读取数据
 */
-(void)readInputStream{
    if (fileInputStream.hasBytesAvailable) {
        uint8_t* inputData = malloc(inputStreamMaxSize);
        NSInteger readDataLength =  [fileInputStream read:inputData maxLength:inputStreamMaxSize];
        [frameData appendBytes:inputData length:readDataLength];
    }
}


/**
 读取一个Nalu
 */
-(NSData*)readNalu{
    
    int from = -1;
    int to = 0;
    
    while (readOffset < frameData.length) {
        if ([self cmpStartCode:readOffset]) {
            if (from == -1) {
                from = readOffset;
                readOffset += 4;
                continue;
            }else{
                to = readOffset;
                break;
            }
        }else{
            readOffset ++ ;
        }
        
    }
    
    if (to) {
        int length = to - from;
        uint8_t* data = malloc(length);
        [frameData getBytes:data range:NSMakeRange(from, length)];
        return [NSData dataWithBytes:data length:length];
    }
    
    
    
    return nil;
}


/**
 对比是否是startCode

 @param offset 开始位置
 @return 是否是startCode
 */
-(BOOL)cmpStartCode:(int)offset{
    
    if (offset + 4 > frameData.length) {
        return NO;
    }
    
    uint8_t startData[4];
    [frameData getBytes:startData range:NSMakeRange(offset, 4)];
    
    return memcmp(startData, startCode, 4) == 0;
}


/**
 网络端数据转小端

 @param nalu 网络端数据
 @return 小端数据
 */
-(NSData*)HostToBig:(NSData*)nalu{
    
    uint8_t naluP[nalu.length];
    [nalu getBytes:naluP length:nalu.length];
    
    //大小端转换
    uint32_t nalSize = (uint32_t)nalu.length-4;
    uint32_t *pNalSize = (uint32_t *)naluP;
    *pNalSize = CFSwapInt32HostToBig(nalSize);
    
    return [NSData dataWithBytes:pNalSize length:nalu.length];
}

/**
 解码nalu

 @param nalu nalu数据
 */
-(void)decodeNalu:(NSData*)nalu{
    
    NSLog(@"decode nalu %@",nalu);
    
    // 获取检测数据类型数据
    Byte typeByte;
    [nalu getBytes:&typeByte range:NSMakeRange(4, 1)];
    
    AvcDecoderNALUType type = [self checkNALUType:typeByte];
    
    CVPixelBufferRef pixelBuffer = NULL;
    
    switch (type) {
        case AvcDecoderNALUTypeSPS:
            [self clearFormat];
            spsData = nalu;
            break;
        case AvcDecoderNALUTypePPS:
            ppsData = nalu;
            break;
        case AvcDecoderNALUTypeI:
            [self initH264Decoder];
            
            pixelBuffer = [self decoderFrame:nalu];
            break;
            
        case AvcDecoderNALUTypeSEI:
            seiData = nalu;
            break;
            
        default:
            pixelBuffer = [self decoderFrame:nalu];
            break;
    }
    
    if (pixelBuffer) {
        NSLog(@"decode pix:%@",pixelBuffer);
        __weak typeof(self) ws = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(ws) sws = ws;
            if (sws.delegate&&[sws.delegate respondsToSelector:@selector(onReceiveCVPixelBuffer:)]) {
                [sws.delegate onReceiveCVPixelBuffer:pixelBuffer];
            }
        });
    }
    
}


/**
 清理sps pps 信息 以及生成的format
 */
-(void)clearFormat{
    if (deCodeSessionRef) {
        VTDecompressionSessionInvalidate(deCodeSessionRef);
        deCodeSessionRef = NULL;
    }
    
    if (formoatDescRef) {
        CFRelease(formoatDescRef);
        formoatDescRef = NULL;
    }
    
    spsData = nil;
    ppsData = nil;
    seiData = nil;
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
        Byte spsDataByte[spsData.length-4];
        Byte ppsDataByte[tempPPSData.length-4];
        [spsData getBytes:spsDataByte range:NSMakeRange(4, spsData.length-4)];
        [tempPPSData getBytes:ppsDataByte range:NSMakeRange(4, tempPPSData.length-4)];
        
        const uint8_t *const parameterSetPointers[2] = {spsDataByte,ppsDataByte};
        const size_t parameterSetPointerSize[2] = {(size_t)spsData.length-4,(size_t)tempPPSData.length-4};
        
        OSStatus createStatus  = CMVideoFormatDescriptionCreateFromH264ParameterSets(kCFAllocatorDefault, 2, parameterSetPointers, parameterSetPointerSize, 4, &formoatDescRef);
        if (createStatus != noErr) {
            NSLog(@"create Video format fail : %d",createStatus);
            return NO;
        }
        
        
        
        BOOL isAccept =  VTDecompressionSessionCanAcceptFormatDescription(deCodeSessionRef, formoatDescRef);
        if (!isAccept) {
            
            [self startDecoder];
            
        }
        
        return YES;
    }
    
    return NO;
}

/**
 开启创建解码器
 */
-(void)startDecoder{
    uint32_t nv21Type = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
    
    const void* keys[] = {kCVPixelBufferPixelFormatTypeKey};
    const void* values[] = {CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &nv21Type)};
    
    CFDictionaryRef destinationImageBufferAtt = CFDictionaryCreate(kCFAllocatorDefault, keys, values, 1, NULL, NULL);
    
    VTDecompressionOutputCallbackRecord callbackRecord;
    callbackRecord.decompressionOutputCallback = decodecCallBack;
    callbackRecord.decompressionOutputRefCon = NULL;
    
    
    VTDecompressionSessionCreate(kCFAllocatorDefault, formoatDescRef, NULL, destinationImageBufferAtt, &callbackRecord, &deCodeSessionRef);
    
    CFRelease(destinationImageBufferAtt);
    
}


/**
 解码
 
 @param data 数据
 */
-(void)decoderData:(NSData*)data{
    
    int bufferOffset = 0;
    
    Byte dataByte[data.length];
    [data getBytes:dataByte range:NSMakeRange(0, data.length)];
    
    int headLength = 4;
    int from = -1,to = 0;
    // 如果剩余的长度比一个startCode大的话继续循环,检查出sps pps和sei的数据，并且返回第一个i帧的位置
//    while (data.length - *bufferOffset > headLength) {
//
//        // 获取startCode验证
//        if (dataByte[*bufferOffset] == 0x00&&
//            dataByte[*bufferOffset+1] == 0x00&&
//            dataByte[*bufferOffset+2] == 0x00&&
//            dataByte[*bufferOffset+3] == 0x01) {
//
//            if (from == -1) {
//                from = *bufferOffset;
//                *bufferOffset = from + 4;
//                continue;
//            }else{
//                to = *bufferOffset;
//            }
//
//            if (to != 0) {
//
//                int length = to-from;
//
//                // 获取数据
//                NSData* pkgData = [data subdataWithRange:NSMakeRange(from, length)];
//
//
//
//                // 获取检测数据类型数据
//                Byte typeByte;
//                [data getBytes:&typeByte range:NSMakeRange(from + 4, 1)];
//
//
//
//                // 检测数据类型
//                AvcDecoderNALUType type = [self checkNALUType:typeByte];
//
//                [self checkNALU:pkgData type:type];
//
//                to = 0;
//                from = *bufferOffset;
//            }
//
//
//
//        }
//
//        (*bufferOffset)++;
    
        
        
//    }
}




void decodecCallBack(void * CM_NULLABLE decompressionOutputRefCon,void * CM_NULLABLE sourceFrameRefCon,OSStatus status,VTDecodeInfoFlags infoFlags,CM_NULLABLE CVImageBufferRef imageBuffer,CMTime presentationTimeStamp,CMTime presentationDuration ){
    CVPixelBufferRef *outputPixelBuffer = (CVPixelBufferRef *)sourceFrameRefCon;
    *outputPixelBuffer = CVPixelBufferRetain(imageBuffer);
    
//    CIImage* ciImage = [CIImage imageWithCVImageBuffer:imageBuffer];
////    CIContext* context = [CIContext contextWithOptions:nil];
////    CGImageRef cgImageRef = [context createCGImage:ciImage fromRect:CGRectMake(0, 0, 375, 675)];
//    UIImage* image = [UIImage imageWithCIImage:ciImage];
    NSLog(@"devompress result:%@",imageBuffer);
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
//                [self decoderFrame:nalu type:type];
            }
            break;
        default:
            break;
    }
    
    NSLog(@"frame data:%@",nalu);
}



-(CVPixelBufferRef)decoderFrame:(NSData*)nalu{
    if (formoatDescRef) {
        
        void* naluData = malloc(nalu.length);
        [nalu getBytes:naluData range:NSMakeRange(0, nalu.length)];
        CMBlockBufferRef blockBuffer;
        OSStatus createBlockStatus = CMBlockBufferCreateWithMemoryBlock(kCFAllocatorDefault, naluData, nalu.length, kCFAllocatorNull, NULL, 0, nalu.length, 0, &blockBuffer);
        if (createBlockStatus != noErr) {
            return nil;
        }
        const size_t sampleSizeArray[] = { nalu.length };
        CMSampleBufferRef sampleBuffer = NULL;
        OSStatus createSampleStatus = CMSampleBufferCreateReady(kCFAllocatorDefault, blockBuffer, formoatDescRef, 1, 0, NULL, 1, sampleSizeArray, &sampleBuffer);
        if (createSampleStatus != noErr || !sampleBuffer) {
            return nil;
        }
        
        VTDecodeFrameFlags decodeFlags = 0;
        VTDecodeInfoFlags infoFlagsOut = 0;
        CVPixelBufferRef pixelBufferRef = NULL;
        
        OSStatus status = VTDecompressionSessionDecodeFrame(deCodeSessionRef, sampleBuffer, decodeFlags, &pixelBufferRef, &infoFlagsOut);
        if(status == kVTInvalidSessionErr) {
            NSLog(@"IOS8VT: Invalid session, reset decoder session");
        } else if(status == kVTVideoDecoderBadDataErr) {
            NSLog(@"IOS8VT: decode failed status=%d(Bad data)", (int)status);
        } else if(status != noErr) {
            NSLog(@"IOS8VT: decode failed status=%d", (int)status);
        }else{
            NSLog(@"result status:%d",status);
        }
        
        CFRelease(sampleBuffer);
        CFRelease(blockBuffer);
        
        return pixelBufferRef;
    }else{
        return nil;
    }
}





@end
