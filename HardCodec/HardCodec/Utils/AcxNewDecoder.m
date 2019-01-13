//
//  AcxNewDecoder.m
//  HardCodec
//
//  Created by coolkit on 2019/1/10.
//  Copyright © 2019 coolkit. All rights reserved.
//

#import "AcxNewDecoder.h"

@interface AcxNewDecoder ()
{
    NSInputStream* inputStream;
}

@end

@implementation AcxNewDecoder

+(instancetype)getInstance{
    static AcxNewDecoder* instance ;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[AcxNewDecoder alloc] init];
    });
    return instance;
}

-(void)decodeFile:(NSString*)filePath{
    inputStream = [[NSInputStream alloc] initWithFileAtPath:filePath];
    [inputStream open];
    
}

@end
