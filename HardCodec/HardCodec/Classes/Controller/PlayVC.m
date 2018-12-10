//
//  PlayVC.m
//  HardAvcoder
//
//  Created by coolkit on 2018/11/26.
//  Copyright © 2018 apple. All rights reserved.
//

#import "PlayVC.h"
#import "AvcDecoder.h"

@interface PlayVC ()



@end

@implementation PlayVC

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    if (self.filePath) {
        [self receiveData:self.filePath];
    }
    
}

#pragma mark -- util
-(void)receiveData:(NSString*)filePath{
    [[AvcDecoder getInstance] decoderFile:filePath];
    
}


#pragma mark - Navigation
/*
// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
    if ([segue.identifier isEqualToString:@"pushToPlayVC"]) {
        [self receiveData:(NSString*)sender];
    }
}
*/

@end
