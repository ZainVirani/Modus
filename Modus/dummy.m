//
//  dummy.m
//  Modus
//
//  Created by Zain on 2016-07-28.
//  Copyright © 2016 Modus Applications. All rights reserved.
//

#import <Foundation/Foundation.h>
/*
 #import "notify.h"
 
 -(void)registerAppforDetectLockState {
 
 int notify_token;
 notify_register_dispatch("com.apple.springboard.lockstate", &notify_token,dispatch_get_main_queue(), ^(int token) {
 
 uint64_t state = UINT64_MAX;
 notify_get_state(token, &state);
 
 if(state == 0) {
 NSLog(@"unlock device");
 } else {
 NSLog(@"lock device");
 }
 
 NSLog(@"com.apple.springboard.lockstate = %llu", state);
 UILocalNotification *notification = [[UILocalNotification alloc]init];
 notification.repeatInterval = NSCalendarUnitDay;
 [notification setAlertBody:@"Hello world!! I come becoz you lock/unlock your device :)"];
 notification.alertAction = @"View";
 notification.alertAction = @"Yes";
 [notification setFireDate:[NSDate dateWithTimeIntervalSinceNow:1]];
 notification.soundName = UILocalNotificationDefaultSoundName;
 [notification setTimeZone:[NSTimeZone  defaultTimeZone]];
 
 [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
 
 });
 }
*/