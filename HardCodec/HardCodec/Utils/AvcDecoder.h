//
//  AvcDecoder.h
//  HardAvcoder
//
//  Created by coolkit on 2018/11/26.
//  Copyright © 2018 apple. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

typedef NS_ENUM(NSUInteger, AvcDecoderNALUType) {
    AvcDecoderNALUTypeSPS,
    AvcDecoderNALUTypePPS,
    AvcDecoderNALUTypeSEI,
    AvcDecoderNALUTypeI,
    AvcDecoderNALUTypeP,
    AvcDecoderNALUTypeB,
    AvcDecoderNALUTypeUnKnown
};

NS_ASSUME_NONNULL_BEGIN

@protocol AvcDecoderDelegate <NSObject>

-(void)onReceiveCVPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

@interface AvcDecoder : NSObject

+(instancetype)getInstance;

@property (nonatomic,weak) id<AvcDecoderDelegate>  delegate;

-(void)setDisplayLayer:(AVSampleBufferDisplayLayer*)layer;

-(void)decoderFile:(NSString*)filePath;

@end

NS_ASSUME_NONNULL_END
