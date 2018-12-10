//
//  FileUtil.m
//  HardAvcoder
//
//  Created by apple on 2018/11/25.
//  Copyright © 2018年 apple. All rights reserved.
//

#import "FileUtil.h"
@interface FileUtil()
{
    NSString* filePath;
}
@end

@implementation FileUtil

- (instancetype)initWithfileName:(NSString*)fileName
{
    self = [super init];
    if (self) {
        [self initFilePath:fileName];
    }
    return self;
}

-(NSString*)getPath{
    return filePath;
}

-(void)initFilePath:(NSString*)fileName{
    NSString* rootPath = NSHomeDirectory();
    filePath = [NSString stringWithFormat:@"%@/Documents/%@",rootPath,fileName];
    NSLog(@"setting path:%@",filePath);
}

-(void)writeFile:(NSData*)data{
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        [[NSFileManager defaultManager] removeItemAtPath:filePath error:nil];
    }
    [[NSFileManager defaultManager] createFileAtPath:filePath contents:data attributes:nil];
}

-(BOOL)appendFileToEnd:(NSData *)data{
    if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSFileHandle* handle = [NSFileHandle fileHandleForWritingAtPath:filePath];
        if (handle) {
            [handle seekToEndOfFile];
            
            [handle writeData:data];
            
            [handle closeFile];
            
            return YES;
        }else{
            return NO;
        }
    }else{
        return NO;
    }
}


@end
