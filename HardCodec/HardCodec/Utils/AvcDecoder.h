//
//  AvcDecoder.h
//  HardAvcoder
//
//  Created by coolkit on 2018/11/26.
//  Copyright © 2018 apple. All rights reserved.
//

#import <Foundation/Foundation.h>

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

@interface AvcDecoder : NSObject

+(instancetype)getInstance;

-(void)decoderFile:(NSString*)filePath;

@end

NS_ASSUME_NONNULL_END
