//
//  SOSPicker.m
//  SyncOnSet
//
//  Created by Christopher Sullivan on 10/25/13.
//  Modified by Zehui Zhang on 11/12/2018
//
#import "SOSPicker.h"
#import "GMImagePickerController.h"
#import "GMFetchItem.h"
@import MobileCoreServices;

#define CDV_PHOTO_PREFIX @"cdv_photo_"

typedef enum : NSUInteger {
    FILE_URI = 0,
    BASE64_STRING = 1
} SOSPickerOutputType;

@interface SOSPicker () <GMImagePickerControllerDelegate>
@end

@implementation SOSPicker

@synthesize callbackId;

- (void) hasReadPermission:(CDVInvokedUrlCommand *)command {
    CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:[PHPhotoLibrary authorizationStatus] == PHAuthorizationStatusAuthorized];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) requestReadPermission:(CDVInvokedUrlCommand *)command {
    // [PHPhotoLibrary requestAuthorization:]
    // this method works only when it is a first time, see
    // https://developer.apple.com/library/ios/documentation/Photos/Reference/PHPhotoLibrary_Class/

    PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
    if (status == PHAuthorizationStatusAuthorized) {
        NSLog(@"Access has been granted.");
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else if (status == PHAuthorizationStatusDenied) {
        NSString* message = @"Access has been denied. Change your setting > this app > Photo enable";
        NSLog(@"%@", message);
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else if (status == PHAuthorizationStatusNotDetermined) {
        // Access has not been determined. requestAuthorization: is available
        [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {}];
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    } else if (status == PHAuthorizationStatusRestricted) {
        NSString* message = @"Access has been restricted. Change your setting > Privacy > Photo enable";
        NSLog(@"%@", message);
        
        CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:message];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }
}

- (void) getPictures:(CDVInvokedUrlCommand *)command {

    NSDictionary *options = [command.arguments objectAtIndex: 0];

    self.outputType = [[options objectForKey:@"outputType"] integerValue];
    BOOL allow_video = [[options objectForKey:@"allow_video" ] boolValue ];
    NSInteger maximumImagesCount = [[options objectForKey:@"maximumImagesCount"] integerValue];
    NSString * title = [options objectForKey:@"title"];
    NSString * message = [options objectForKey:@"message"];
    BOOL disable_popover = [[options objectForKey:@"disable_popover" ] boolValue];
    if (message == (id)[NSNull null]) {
      message = nil;
    }
    self.width = [[options objectForKey:@"width"] integerValue];
    self.height = [[options objectForKey:@"height"] integerValue];
    self.quality = [[options objectForKey:@"quality"] integerValue];

    self.callbackId = command.callbackId;
    [self launchGMImagePicker:allow_video title:title message:message disable_popover:disable_popover maximumImagesCount:maximumImagesCount];
}

- (void)launchGMImagePicker:(bool)allow_video title:(NSString *)title message:(NSString *)message disable_popover:(BOOL)disable_popover maximumImagesCount:(NSInteger)maximumImagesCount
{
    GMImagePickerController *picker = [[GMImagePickerController alloc] init:allow_video];
    picker.delegate = self;
    picker.maximumImagesCount = maximumImagesCount;
    picker.title = title;
    picker.customNavigationBarPrompt = message;
    picker.colsInPortrait = 4;
    picker.colsInLandscape = 6;
    picker.minimumInteritemSpacing = 2.0;

    if(!disable_popover) {
        picker.modalPresentationStyle = UIModalPresentationPopover;

        UIPopoverPresentationController *popPC = picker.popoverPresentationController;
        popPC.permittedArrowDirections = UIPopoverArrowDirectionAny;
        popPC.sourceView = picker.view;
        //popPC.sourceRect = nil;
    }

    [self.viewController showViewController:picker sender:nil];
}


- (UIImage*)imageByScalingNotCroppingForSize:(UIImage*)anImage toSize:(CGSize)frameSize
{
    UIImage* sourceImage = anImage;
    UIImage* newImage = nil;
    CGSize imageSize = sourceImage.size;
    CGFloat width = imageSize.width;
    CGFloat height = imageSize.height;
    CGFloat targetWidth = frameSize.width;
    CGFloat targetHeight = frameSize.height;
    CGFloat scaleFactor = 0.0;
    CGSize scaledSize = frameSize;

    if (CGSizeEqualToSize(imageSize, frameSize) == NO) {
        CGFloat widthFactor = targetWidth / width;
        CGFloat heightFactor = targetHeight / height;

        // opposite comparison to imageByScalingAndCroppingForSize in order to contain the image within the given bounds
        if (widthFactor == 0.0) {
            scaleFactor = heightFactor;
        } else if (heightFactor == 0.0) {
            scaleFactor = widthFactor;
        } else if (widthFactor > heightFactor) {
            scaleFactor = heightFactor; // scale to fit height
        } else {
            scaleFactor = widthFactor; // scale to fit width
        }
        scaledSize = CGSizeMake(floor(width * scaleFactor), floor(height * scaleFactor));
    }

    UIGraphicsBeginImageContext(scaledSize); // this will resize

    [sourceImage drawInRect:CGRectMake(0, 0, scaledSize.width, scaledSize.height)];

    newImage = UIGraphicsGetImageFromCurrentImageContext();
    if (newImage == nil) {
        NSLog(@"could not scale image");
    }

    // pop the context to get back to the default
    UIGraphicsEndImageContext();
    return newImage;
}


#pragma mark - UIImagePickerControllerDelegate


- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"UIImagePickerController: User finished picking assets");
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    NSLog(@"UIImagePickerController: User pressed cancel button");
}

#pragma mark - GMImagePickerControllerDelegate

- (void)assetsPickerController:(GMImagePickerController *)picker didFinishPickingAssets:(NSArray *)fetchArray
{
    [picker.presentingViewController dismissViewControllerAnimated:YES completion:nil];

    NSLog(@"GMImagePicker: User finished picking assets. Number of selected items is: %lu", (unsigned long)fetchArray.count);

    NSMutableArray * result_all = [[NSMutableArray alloc] init];
    int i = 1;
    NSString* filePath;
    NSLog(@"filePath %@", filePath);
    NSString* timeSince;
    NSFileManager* fileMgr = [[NSFileManager alloc] init];
    //Clean or move the temp file after invoked this plugin when not in use, transfering the file into persistent.
    NSString* docsPath = [NSTemporaryDirectory()stringByStandardizingPath];
    NSLog(@"docsPath %@", docsPath);
    CDVPluginResult* result = nil;

    for (GMFetchItem *item in fetchArray) {
        NSLog(@"item %@", item);
        if ( !item.image_fullsize ) { 
            continue;
        }
        
        // no scaling, no downsampling, this is the fastest option
        if (self.width == 0 && self.height == 0 && self.quality == 100 && self.outputType != BASE64_STRING) {
            //2018-11-12，simPRO eForms-Peter-MA-1919-ExifInAttachment
            //In GMGridViewController .fixOrientation will purge exif info, a full original size image may showing rotated
            //Todo-figure out a way to fix orientation for original file as well
            //Since we are not using original file, this issue is less priority
            [result_all addObject:item.image_fullsize];
        }  else {
            //Initialization
            NSMutableData *destData = nil;
            NSError* err = nil;
            do {
                NSDateFormatter *objDateformat = [[NSDateFormatter alloc] init];
                [objDateformat setDateFormat:@"yyyyMMddhhmmss"];
                NSString    *strTime = [objDateformat stringFromDate:[NSDate date]];
                NSLog(@"The strTime is = %@",strTime);


                NSDateComponents *comps = [[NSCalendar currentCalendar] 
                                        components:NSDayCalendarUnit | NSYearCalendarUnit | NSMonthCalendarUnit 
                                        fromDate:[NSDate date]];
                [comps setHour:0];
                [comps setMinute:0];    
                [comps setSecond:[[NSTimeZone systemTimeZone] secondsFromGMT]];
                NSLog(@"BLAH %@", [[[NSCalendar currentCalendar] dateFromComponents:comps] timeIntervalSince1970];



                // NSString    *strUTCTime = [self GetUTCDateTimeFromLocalTime:strTime];//You can pass your date but be carefull about your date format of NSDateFormatter.
                // NSLog(@"The strUTCTime is = %@",strUTCTime);
                // NSDate *objUTCDate  = [objDateformat dateFromString:strUTCTime];
                // long long milliseconds = (long long)([objUTCDate timeIntervalSince1970] * 1000.0);

                // NSString *strTimeStamp = [Nsstring stringwithformat:@"%lld",milliseconds];
                // NSLog(@"The Timestamp is = %@",strTimestamp);

                //timeSince = [NSString stringWithFormat:@”%f”,[[NSDate date] timeIntervalSince1970] * 1000];
                filePath = [NSString stringWithFormat:@"%@/%@%03d.%@", docsPath, CDV_PHOTO_PREFIX, i++, @"jpg"];
            } while ([fileMgr fileExistsAtPath:filePath]);
            //Create image source
            NSURL * imageFileURL = [NSURL fileURLWithPath:item.image_fullsize];
            NSLog(@"imageFileURL %@", imageFileURL);
            CGImageSourceRef imageSource = CGImageSourceCreateWithURL((__bridge CFURLRef)(imageFileURL), NULL);
        
            //Read metadata
            NSMutableDictionary *imageMetadata = [(NSDictionary *) CFBridgingRelease(CGImageSourceCopyPropertiesAtIndex(imageSource, 0, NULL))mutableCopy];
        
            //Create Compressed, resized image
            //TODO - max(hegiht, width)
            CFDictionaryRef options = (__bridge CFDictionaryRef)@{(id)kCGImageSourceCreateThumbnailFromImageAlways: (id)kCFBooleanTrue,
                                                                  (id)kCGImageSourceThumbnailMaxPixelSize: [NSNumber numberWithInteger:MAX(self.width, self.height)], // The maximum width and height in pixels of a thumbnail
                                                                  (id)kCGImageDestinationLossyCompressionQuality: [NSNumber numberWithDouble:self.quality/100.0f]};
            CGImageRef thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options);
        
            //Write Metadata into destination's image
            CFStringRef UTI = kUTTypeJPEG;
            destData = [NSMutableData data];
            CGImageDestinationRef destinationRef = CGImageDestinationCreateWithData((__bridge CFMutableDataRef)destData, UTI, 1, NULL);
            if (!destinationRef) {
                NSString *err = @"Failed to create image destination";
                NSLog(@"%@",err);
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:err];
                break;
            }

            //Copy all metadata in source to destination
            CGImageDestinationAddImage(destinationRef, thumbnail, (__bridge CFDictionaryRef)imageMetadata);
            if (!CGImageDestinationFinalize(destinationRef)) {
                NSString *err = @"Failed to create data from image destination";
                NSLog(@"%@",err);
                result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:err];
                break;
            }
        
            CFRelease(destinationRef);
            CFRelease(imageSource);
            CFRelease(thumbnail);

            //Add imageRef into result
            if(self.outputType == BASE64_STRING){
                [result_all addObject:[destData base64EncodedStringWithOptions:0]];
            }else{
            
                if (![destData writeToFile:filePath options:NSAtomicWrite error:&err]) {
                    result = [CDVPluginResult resultWithStatus:CDVCommandStatus_IO_EXCEPTION messageAsString:[err localizedDescription]];
                    break;
                } else {
                    [result_all addObject:[[NSURL fileURLWithPath:filePath] absoluteString]];
                }
            }
            
        }
    }

    if (result == nil) {
        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:result_all];
    }

    [self.viewController dismissViewControllerAnimated:YES completion:nil];
    [self.commandDelegate sendPluginResult:result callbackId:self.callbackId];

}

//Optional implementation:
-(void)assetsPickerControllerDidCancel:(GMImagePickerController *)picker
{
    NSLog(@"GMImagePicker: User pressed cancel button");
}

@end
