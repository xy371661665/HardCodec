//
//  CameraUtil.h
//  HardAvcoder
//
//  Created by apple on 2018/11/24.
//  Copyright © 2018年 apple. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@class CameraUtil;

@protocol CameraUtilDelegate<NSObject>
@optional
-(void)CameraUtil:(CameraUtil*)cameraUtil didReceiveSampleData:(CMSampleBufferRef)data;
@end

@interface CameraUtil : NSObject

+(instancetype)getInstance;

@property (nonatomic,weak)id<CameraUtilDelegate> delegate;

-(BOOL)prepareCamera;

-(void)startCamera:(UIView*)view;

-(void)removeCamera;

@end
