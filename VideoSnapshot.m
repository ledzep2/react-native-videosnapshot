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
#import "VideoSnapshot.h"
#import "RCTBridgeModule.h"
#import "RCTEventDispatcher.h"


@implementation UIImage (scale)

/**
 * Scales an image to fit within a bounds with a size governed by
 * the passed size. Also keeps the aspect ratio.
 *
 * Switch MIN to MAX for aspect fill instead of fit.
 *
 * @param newSize the size of the bounds the image must fit within.
 * @return a new scaled image.
 */
- (UIImage *)scaleImageToSize:(CGSize)newSize {
    
    CGRect scaledImageRect = CGRectZero;
    
    CGFloat aspectWidth = newSize.width / self.size.width;
    CGFloat aspectHeight = newSize.height / self.size.height;
    CGFloat aspectRatio = MIN ( aspectWidth, aspectHeight );
    
    scaledImageRect.size.width = self.size.width * aspectRatio;
    scaledImageRect.size.height = self.size.height * aspectRatio;
    scaledImageRect.origin.x = (newSize.width - scaledImageRect.size.width) / 2.0f;
    scaledImageRect.origin.y = (newSize.height - scaledImageRect.size.height) / 2.0f;
    
    UIGraphicsBeginImageContextWithOptions( newSize, NO, 0 );
    [self drawInRect:scaledImageRect];
    UIImage* scaledImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return scaledImage;
    
}

@end

@implementation VideoSnapshot

RCT_EXPORT_MODULE();

@synthesize bridge = _bridge;

- (NSString *)applicationDocumentsDirectory {
    return [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
}

-(UIImage *)drawTimestamp:(CMTime)timestamp withPrefix:(NSString*)prefix ofSize:(int)textSize toImage:(UIImage *)img{
    CGFloat w = img.size.width, h = img.size.height;
    CGFloat size = (CGFloat)(textSize * w) / 1280;
    CGFloat margin = (w < h? w : h) * 0.05;
    NSString* fontName = @"Helvetica";
    
    long timeMs = (long)(1000 * CMTimeGetSeconds(timestamp));
    int second = (timeMs / 1000) % 60;
    int minute = (timeMs / (1000 * 60)) % 60;
    int hour = (timeMs / (1000 * 60 * 60)) % 24;
    NSString* text = [NSString stringWithFormat:@"%@ %02d:%02d:%02d", prefix, hour, minute, second];
    //CGSize sizeText = [text sizeWithFont:[UIFont fontWithName:@"Helvetica" size:size] minFontSize:size actualFontSize:nil forWidth:783 lineBreakMode:NSLineBreakModeTailTruncation];
    UIFont* font = [UIFont fontWithName:fontName size:size];
    UIColor* color = [UIColor whiteColor];
    NSDictionary* attrs = [NSDictionary dictionaryWithObjectsAndKeys: font, NSFontAttributeName, color, NSForegroundColorAttributeName, nil];
    CGSize sizeText = CGSizeMake(0.0f, 0.0f);
    if ([text respondsToSelector:@selector(sizeWithAttributes)]) {
        sizeText = [text sizeWithAttributes:attrs];
    } else {
        sizeText = [text sizeWithFont:font];
    }
    
    CGFloat posX = w - margin - sizeText.width;
    CGFloat posY = h - margin - sizeText.height;
    NSLog(@"Drawing at (%f, %f) of size: %f. Image size: (%f, %f)", posX, posY, size, w, h);
    
    UIGraphicsBeginImageContextWithOptions(img.size, NO, 0.0f);
    [img drawAtPoint:CGPointMake(0.0f, 0.0f)];
    if ([text respondsToSelector:@selector(drawAtPoint:withAttributes:)]) {
        [text drawAtPoint:CGPointMake(posX, posY) withAttributes:attrs];
    } else {
        CGContextRef context = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(context, color.CGColor);
        [text drawAtPoint:CGPointMake(posX, posY) withFont:font];
    }
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    return result;
}

RCT_EXPORT_METHOD(snapshotAsync:(NSDictionary*)options)
{
    dispatch_async(dispatch_get_global_queue(0, 0), ^{
        UIApplication __block *application = [UIApplication sharedApplication];
        UIBackgroundTaskIdentifier __block task = [application beginBackgroundTaskWithExpirationHandler:^{
            if (task != UIBackgroundTaskInvalid) {
                [application endBackgroundTask:task];
                task = UIBackgroundTaskInvalid;
            }
        }];
        [self snapshot:options withCallback:^(NSArray *response) {
            if (self.bridge == nil) {
                NSLog(@"Bridge not set. snapshot event ignored");
            }
            
            [self.bridge.eventDispatcher sendAppEventWithName:@"snapshotAsync" body:response[0]];
            
            if (task != UIBackgroundTaskInvalid) {
                [application endBackgroundTask:task];
                task = UIBackgroundTaskInvalid;
            }
        }];
    });
}

RCT_EXPORT_METHOD(snapshot:(NSDictionary*)options withCallback:(RCTResponseSenderBlock)callback)
{
    NSLog(@"In plugin. Options:%@", options);
    
    if (options == nil) {
        [self fail:callback withMessage:@"No options provided"];
        return;
    }
    
    int count = 1;
    int countPerMinute = 0;
    int textSize = 48;
    bool timestamp = true;
    float quality = 0.9f;
    
    NSNumber* nscount = [options objectForKey:@"count"];
    NSNumber* nscountPerMinute = [options objectForKey:@"countPerMinute"];
    NSNumber* nstextSize = [options objectForKey:@"textSize"];
    NSString* source = [options objectForKey:@"source"];
    NSString* nspathPrefix = [options objectForKey:@"pathPrefix"];
    NSString* nsnamePrefix = [options objectForKey:@"namePrefix"];
    NSNumber* nstimestamp = [options objectForKey:@"timeStamp"];
    NSNumber* nsquality = [options objectForKey:@"quality"];
    NSString* nsprefix = [options objectForKey:@"prefix"];
    
    if (source == nil) {
        [self fail:callback withMessage:@"No source provided"];
        return;
    }
    //source = [self.applicationDocumentsDirectory stringByAppendingPathComponent:@"test.mov"];
    
    if (nscount != nil) {
        count = [nscount intValue];
    }
    
    if (nscountPerMinute != nil) {
        countPerMinute = [nscountPerMinute intValue];
    }
    
    if (nstimestamp != nil) {
        timestamp = [nstimestamp boolValue];
    }
    
    if (nsquality != nil) {
        quality = (float)[nsquality intValue] / 100;
    }
    
    if (nspathPrefix == nil) {
        nspathPrefix = @"";
    }
    
    if (nsnamePrefix == nil) {
        nsnamePrefix = @"";
    }
    
    if (nsprefix == nil) {
        nsprefix = @"";
    }
    
    if (nstextSize != nil) {
        textSize = [nstextSize intValue];
    }
    
    
    
    NSURL* url = [NSURL fileURLWithPath:source];
    if (url == nil) {
        [self fail:callback withMessage:@"Unable to open path"];
        return;
    }
    
    NSString* filename = [url.lastPathComponent stringByReplacingOccurrencesOfString:@"." withString:@"_"];
    NSString* tmppath = [[self applicationDocumentsDirectory] stringByAppendingPathComponent:nspathPrefix];
    
    NSFileManager *fileManager= [NSFileManager defaultManager];
    if(![fileManager fileExistsAtPath:tmppath])
        if(![fileManager createDirectoryAtPath:tmppath withIntermediateDirectories:YES attributes:nil error:NULL])
            NSLog(@"Error: Create folder failed %@", tmppath);
    
    AVURLAsset *asset = [[AVURLAsset alloc] initWithURL:url options:nil];
    AVAssetImageGenerator *generate = [[AVAssetImageGenerator alloc] initWithAsset:asset];
    generate.appliesPreferredTrackTransform = true;
    NSError *err = NULL;
    NSMutableArray* paths = [[NSMutableArray alloc] init];
    if (asset.duration.value == 0) {
        [self fail:callback withMessage:@"Unable to load video (duration == 0)"];
        return;
    }
    
    Float64 duration = CMTimeGetSeconds(asset.duration);
    if (countPerMinute > 0) {
        count = countPerMinute * duration / 60;
    }
    if (count < 1) {
        count = 1;
    }
    Float64 delta = duration / (count + 1);
    if (delta < 1.f) {
        delta = 1.f;
    }
    
    NSMutableArray* times = [[NSMutableArray alloc] init];
    for (int i = 1; delta * i < duration && i <= count; i++) {
        [times addObject:[NSValue valueWithCMTime:CMTimeMakeWithSeconds(delta * i, asset.duration.timescale)]];
    }
    
    [generate generateCGImagesAsynchronouslyForTimes:times completionHandler:^(CMTime requestedTime, CGImageRef image, CMTime actualTime, AVAssetImageGeneratorResult result, NSError *error) {
        NSLog(@"err==%@, imageRef==%@", err, image);
        if (err != nil) {
            return;
        }
        
        int sec = (int)CMTimeGetSeconds(actualTime);
        NSString* path = [tmppath stringByAppendingPathComponent: [NSString stringWithFormat:@"%@%@-%d.jpg", nsnamePrefix, filename, sec]];
        UIImage *uiImage = [UIImage imageWithCGImage:image];
        uiImage = [uiImage scaleImageToSize:CGSizeMake(180, 320)];
        if (timestamp) {
            uiImage = [self drawTimestamp:actualTime withPrefix:nsprefix ofSize:textSize toImage:uiImage];
        }
        
        NSData *jpgData = UIImageJPEGRepresentation(uiImage, quality);
        [jpgData writeToFile:path atomically:NO];
        
        @synchronized (paths){
            [paths addObject:path];
            if (paths.count == times.count) {
                NSDictionary* ret = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:true], @"result", paths, @"snapshots", nil];
                
                [self success:callback withDictionary:ret];
            }
        }
        //CFRelease(image);
    }];
}

- (void)success:(RCTResponseSenderBlock)callback withDictionary:(NSDictionary*)ret
{
    NSLog(@"Plugin success. Result: %@", ret);
    callback(@[ret]);
}

- (void)fail:(RCTResponseSenderBlock)callback withMessage:(NSString*)message
{
    NSLog(@"Plugin failed. Error: %@", message);
    NSDictionary* ret = [NSDictionary dictionaryWithObjectsAndKeys:
                         [NSNumber numberWithBool:false], @"result", message, @"error", nil];
    callback(@[ret]);
}

@end
