//
//  FileUtil.h
//  HardAvcoder
//
//  Created by apple on 2018/11/25.
//  Copyright © 2018年 apple. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface FileUtil : NSObject


/**
 初始化文件管理对象

 @param fileName 管理对象的文件名称
 @return 管理对象
 */
- (instancetype)initWithfileName:(NSString*)fileName;


/**
 写入文件，如果存在文件，删除重新创建，如果不存在文件直接创建

 @param data 初始化文件写入内容
 */
-(void)writeFile:(NSData*)data;


/**
 拼接数据到文件末尾

 @param data 要拼接的数据
 @return 是否写入成功
 */
-(BOOL)appendFileToEnd:(NSData*)data;


/**
 获取文件的地址

 @return 文件地址
 */
-(NSString*)getPath;

@end
