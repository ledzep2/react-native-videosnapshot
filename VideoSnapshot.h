/*
 
 Copyright 2014 Sebible Limited
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 
 */
#import "RCTBridgeModule.h"
#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>


@interface VideoSnapshot : NSObject <RCTBridgeModule>

- (NSString *)applicationDocumentsDirectory;
- (void)snapshotAsync:(NSDictionary*)options;
- (void)snapshot:(NSDictionary*)options withCallback:(RCTResponseSenderBlock)callback;
- (void)fail:(RCTResponseSenderBlock)callback withMessage:(NSString*)message;
- (void)success:(RCTResponseSenderBlock)callback withDictionary:(NSDictionary*)ret;
- (UIImage *)drawTimestamp:(CMTime)timestamp withPrefix:(NSString*)prefix ofSize:(int)textSize toImage:(UIImage *)img;

@end
