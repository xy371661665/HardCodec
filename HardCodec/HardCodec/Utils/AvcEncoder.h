//
//  AvcEncoder.h
//  HardAvcoder
//
//  Created by apple on 2018/11/24.
//  Copyright © 2018年 apple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSUInteger, AvcEncoderFrameType) {
    AvcEncoderFrameTypeIFrame,
    AvcEncoderFrameTypePFrame,
    AvcEncoderFrameTypeBFrame,
};

@class AvcEncoder;
@protocol AvcEncoderDelegate <NSObject>

@optional
/**
 获取SPS和PPS的数据

 @param encoder 编码器
 @param sps sps数据
 @param pps pps数据
 */
-(void)AvcEncoder:(AvcEncoder*)encoder didReceiveSPS:(NSData*)sps PPS:(NSData*)pps;

-(void)AvcEncoder:(AvcEncoder*)encoder didReceiveFrame:(NSData*)frame type:(AvcEncoderFrameType)type;

@end

@interface AvcEncoder : NSObject

+(instancetype)getInstance;

@property (nonatomic,weak)id<AvcEncoderDelegate> delegate;

-(void)prepareEncoder:(int)width height:(int)height fps:(int)fps bps:(int)bps;

-(void)releaseEncoder;

-(void)addCameraData:(CMSampleBufferRef)data;

@end
