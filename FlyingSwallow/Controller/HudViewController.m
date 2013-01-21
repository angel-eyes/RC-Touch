//
//  HudViewController.m
//  FlyingSwallow
//
//  Created by koupoo on 12-12-21. Email: koupoo@126.com
//  Copyright (c) 2012年 www.angeleyes.it. All rights reserved.
//
//  This program is free software; you can redistribute it and/or
//  modify it under the terms of the GNU General Public License V2
//  as published by the Free Software Foundation.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

#import "HudViewController.h"
#import <mach/mach_time.h>
#import "ac_util.h"
#import "ac_ppm_out.h"
#import "Macros.h"
#import "util.h"
#import "BlockViewStyle1.h"
#import <MediaPlayer/MediaPlayer.h>

#define kThrottleFineTuningStep 0.015


@interface HudViewController (){
    CGPoint joystickRightCurrentPosition, joystickLeftCurrentPosition;
    CGPoint joystickRightInitialPosition, joystickLeftInitialPosition;
    BOOL buttonRightPressed, buttonLeftPressed;
    CGPoint rightCenter, leftCenter;
    
    float joystickAlpha;
    
    BOOL isLeftHanded;
    
    float rightJoyStickOperableRadius;
    float leftJoyStickOperableRadius;
    
    BOOL isTransmitting;
    
    BOOL rudderIsLocked;
    BOOL throttleIsLocked;
    
    CGPoint rudderLockButtonCenter;
    CGPoint throttleUpButtonCenter;
    CGPoint throttleDownButtonCenter;
    CGPoint upIndicatorImageViewCenter;
    CGPoint downIndicatorImageViewCenter;
    
    CGPoint leftHandedRudderLockButtonCenter;
    CGPoint leftHandedThrottleUpButtonCenter;
    CGPoint leftHandedThrottleDownButtonCenter;
    CGPoint leftHandedUpIndicatorImageViewCenter;
    CGPoint leftHandedDownIndicatorImageViewCenter;
    
    NSMutableDictionary *blockViewDict;
}

@property(nonatomic, retain) Channel *aileronChannel;
@property(nonatomic, retain) Channel *elevatorChannel;
@property(nonatomic, retain) Channel *rudderChannel;
@property(nonatomic, retain) Channel *throttleChannel;

@property(nonatomic, retain) Settings *settings;

@property(nonatomic, retain) SettingsMenuViewController *settingMenuVC;

@end


@implementation HudViewController
@synthesize aileronChannel = _aileronChannel;
@synthesize elevatorChannel = _elevatorChannel;
@synthesize rudderChannel = _rudderChannel;
@synthesize throttleChannel = _throttleChannel;

@synthesize settings = _settings;

@synthesize settingMenuVC = _settingMenuVC;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissSettingsMenuView) name:kNotificationDismissSettingsMenuView object:nil];
        
        NSString *documentsDir= [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
        NSString *userSettingsFilePath = [documentsDir stringByAppendingPathComponent:@"Settings.plist"];
        
        _settings = [[[Settings alloc] initWithSettingsFile:userSettingsFilePath] retain];
        UIDevice *device = [UIDevice currentDevice];
        device.batteryMonitoringEnabled = YES;
        [device addObserver:self forKeyPath:@"batteryLevel" options:NSKeyValueObservingOptionNew context:nil];  
        
        [NSTimer scheduledTimerWithTimeInterval:0.3 target:self selector:@selector(checkAudioOuputIsOk) userInfo:nil repeats:YES];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    rudderLockButtonCenter = rudderLockButton.center;
    throttleUpButtonCenter = throttleUpButton.center;
    throttleDownButtonCenter = throttleDownButton.center;
    upIndicatorImageViewCenter = upIndicatorImageView.center;
    downIndicatorImageViewCenter = downIndicatorImageView.center;
    
    float hudFrameWidth = [[UIScreen mainScreen] bounds].size.height;
    
    leftHandedRudderLockButtonCenter = CGPointMake(hudFrameWidth - rudderLockButtonCenter.x, rudderLockButtonCenter.y);
    leftHandedThrottleUpButtonCenter = CGPointMake(hudFrameWidth - throttleUpButtonCenter.x, throttleUpButtonCenter.y);
    leftHandedThrottleDownButtonCenter = CGPointMake(hudFrameWidth - throttleDownButtonCenter.x, throttleDownButtonCenter.y);
    leftHandedUpIndicatorImageViewCenter = CGPointMake(hudFrameWidth - upIndicatorImageViewCenter.x, upIndicatorImageViewCenter.y);
    leftHandedDownIndicatorImageViewCenter = CGPointMake(hudFrameWidth - downIndicatorImageViewCenter.x, downIndicatorImageViewCenter.y);
    
    float operableCoeff = (UIUserInterfaceIdiomPad == UI_USER_INTERFACE_IDIOM()) ? 3.0 : 1.5;
    
    float rightThumbWidth = joystickRightThumbImageView.frame.size.width;
    rightJoyStickOperableRadius = rightThumbWidth / operableCoeff;
    
    float leftThumbWidth = joystickLeftThumbImageView.frame.size.width;
    leftJoyStickOperableRadius = leftThumbWidth / operableCoeff;

    _aileronChannel = [[_settings channelByName:kChannelNameAileron] retain];
    _elevatorChannel = [[_settings channelByName:kChannelNameElevator] retain];
    _rudderChannel = [[_settings channelByName:kChannelNameRudder] retain];
    _throttleChannel = [[_settings channelByName:kChannelNameThrottle] retain];
    
	rightCenter = CGPointMake(joystickRightThumbImageView.frame.origin.x + (joystickRightThumbImageView.frame.size.width / 2), joystickRightThumbImageView.frame.origin.y + (joystickRightThumbImageView.frame.size.height / 2));
	joystickRightInitialPosition = CGPointMake(rightCenter.x - (joystickRightBackgroundImageView.frame.size.width / 2), rightCenter.y - (joystickRightBackgroundImageView.frame.size.height / 2));
	leftCenter = CGPointMake(joystickLeftThumbImageView.frame.origin.x + (joystickLeftThumbImageView.frame.size.width / 2), joystickLeftThumbImageView.frame.origin.y + (joystickLeftThumbImageView.frame.size.height / 2));
	joystickLeftInitialPosition = CGPointMake(leftCenter.x - (joystickLeftBackgroundImageView.frame.size.width / 2), leftCenter.y - (joystickLeftBackgroundImageView.frame.size.height / 2));
    
	joystickLeftCurrentPosition = joystickLeftInitialPosition;
	joystickRightCurrentPosition = joystickRightInitialPosition;
	
	joystickAlpha = MIN(joystickRightBackgroundImageView.alpha, joystickRightThumbImageView.alpha);
	joystickRightBackgroundImageView.alpha = joystickRightThumbImageView.alpha = joystickAlpha;
	joystickLeftBackgroundImageView.alpha = joystickLeftThumbImageView.alpha = joystickAlpha;
	
	[self setBattery:(int)([UIDevice currentDevice].batteryLevel * 100)];
    
    [self updateJoystickCenter];
    
    [self updateStatusInfoLabel];
    [self updateThrottleValueLabel];
    
    [self settingsMenuViewController:nil leftHandedValueDidChange:_settings.isLeftHanded];
    
    if(isTransmitting == NO){
        [self startTransmission];
    }
    
    if(blockViewDict == nil){
        blockViewDict = [[NSMutableDictionary alloc] init];
    }
}

- (void)viewDidUnload
{
    [setttingButton release];
    setttingButton = nil;
    [joystickLeftButton release];
    joystickLeftButton = nil;
    [joystickRightButton release];
    joystickRightButton = nil;
    [joystickLeftThumbImageView release];
    joystickLeftThumbImageView = nil;
    [joystickLeftBackgroundImageView release];
    joystickLeftBackgroundImageView = nil;
    [joystickRightThumbImageView release];
    joystickRightThumbImageView = nil;
    [joystickRightBackgroundImageView release];
    joystickRightBackgroundImageView = nil;
    [batteryLevelLabel release];
    batteryLevelLabel = nil;
    [batteryImageView release];
    batteryImageView = nil;
    [_settingMenuVC release];
    _settingMenuVC = nil;
    [warningView release];
    warningView = nil;
    [warningLabel release];
    warningLabel = nil;
    [rudderLockButton release];
    rudderLockButton = nil;
    [statusInfoLabel release];
    statusInfoLabel = nil;
    [throttleUpButton release];
    throttleUpButton = nil;
    [throttleDownButton release];
    throttleDownButton = nil;
    [downIndicatorImageView release];
    downIndicatorImageView = nil;
    [upIndicatorImageView release];
    upIndicatorImageView = nil;
    [throttleValueLabel release];
    throttleValueLabel = nil;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationLandscapeLeft);
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    [_settingMenuVC release], _settingMenuVC = nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationDismissSettingsMenuView object:nil];
    
    [self stopTransmission];
    
    [_aileronChannel release];
    [_elevatorChannel release];
    [_rudderChannel release];
    [_throttleChannel release];
    [_settings release];
    [setttingButton release];
    [joystickLeftButton release];
    [joystickRightButton release];
    [joystickLeftThumbImageView release];
    [joystickLeftBackgroundImageView release];
    [joystickRightThumbImageView release];
    [joystickRightBackgroundImageView release];
    [batteryLevelLabel release];
    [batteryImageView release];
    [_settingMenuVC release];
    [warningView release];
    [warningLabel release];
    [blockViewDict release];
    [rudderLockButton release];
    [statusInfoLabel release];
    [throttleUpButton release];
    [throttleDownButton release];
    [downIndicatorImageView release];
    [upIndicatorImageView release];
    [throttleValueLabel release];
    [super dealloc];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {  
    if ([keyPath isEqual:@"batteryLevel"] || [object isEqual:[UIDevice currentDevice]]) {  
        [self setBattery:(int)([UIDevice currentDevice].batteryLevel * 100)]; 
    }  
}  

- (void) checkAudioOuputIsOk {
    if (!audio_outputs_to_wire()) {
        [warningLabel setText: getLocalizeString(@"Plug in PPM output cable")];
        warningView.hidden = NO;
    } else if (ac_output_volume()<0.9) {
        [warningLabel setText:getLocalizeString(@"Increase Audio Volume")];
        warningView.hidden = NO;
    } else if (ac_output_volume()>0.95) {
        [warningLabel setText:getLocalizeString(@"Decrease Audio Volume")];
         warningView.hidden = NO;
    } else {
         warningView.hidden = YES;
    }
}




#pragma mark SettingsMenuViewControllerDelegate Methods

- (void)settingsMenuViewController:(SettingsMenuViewController *)ctrl interfaceOpacityValueDidChange:(float)newValue{
    joystickAlpha = newValue;
    joystickLeftBackgroundImageView.alpha = joystickAlpha;
    joystickLeftThumbImageView.alpha = joystickAlpha;
    joystickRightBackgroundImageView.alpha = joystickAlpha;
    joystickRightThumbImageView.alpha = joystickAlpha;

}

- (void)settingsMenuViewController:(SettingsMenuViewController *)ctrl leftHandedValueDidChange:(BOOL)enabled{
    isLeftHanded = enabled;
    
    [self josystickButtonDidTouchUp:joystickLeftButton forEvent:nil];
    [self josystickButtonDidTouchUp:joystickRightButton forEvent:nil];

    if(isLeftHanded){
        joystickLeftThumbImageView.image = [UIImage imageNamed:@"Joystick_Manuel_RETINA.png"];
        joystickRightThumbImageView.image = [UIImage imageNamed:@"Joystick_Gyro_RETINA.png"];
        
        rudderLockButton.center       = leftHandedRudderLockButtonCenter;
        throttleUpButton.center       = leftHandedThrottleUpButtonCenter;
        throttleDownButton.center     = leftHandedThrottleDownButtonCenter;
        upIndicatorImageView.center   = leftHandedUpIndicatorImageViewCenter;
        downIndicatorImageView.center = leftHandedDownIndicatorImageViewCenter; 
    }
    else{
        joystickLeftThumbImageView.image = [UIImage imageNamed:@"Joystick_Gyro_RETINA.png"];
        joystickRightThumbImageView.image = [UIImage imageNamed:@"Joystick_Manuel_RETINA.png"];
        
        rudderLockButton.center       = rudderLockButtonCenter;
        throttleUpButton.center       = throttleUpButtonCenter;
        throttleDownButton.center     = throttleDownButtonCenter;
        upIndicatorImageView.center   = upIndicatorImageViewCenter;
        downIndicatorImageView.center = downIndicatorImageViewCenter; 
    }
}

- (void)settingsMenuViewController:(SettingsMenuViewController *)ctrl ppmPolarityReversed:(BOOL)enabled{
    [self stopTransmission];
    [self startTransmission];
}

#pragma mark SettingsMenuViewControllerDelegate Methods end

-(void)blockJoystickHudForTakingOff{
	NSString *blockViewIdentifier = [NSString stringWithFormat:@"%d",  ViewBlockJoyStickHud];
	
	if([blockViewDict valueForKey:blockViewIdentifier] != nil)
		return;
    
    CGRect blockViewPart1Frame = self.view.frame;
    blockViewPart1Frame.origin.x = 0;
    blockViewPart1Frame.origin.y = 0;
    blockViewPart1Frame.size.width = [[UIScreen mainScreen] bounds].size.height;
    blockViewPart1Frame.size.height = joystickLeftButton.frame.origin.y + joystickLeftButton.frame.size.height;
    
	BlockViewStyle1 *blockViewPart1 = [[BlockViewStyle1 alloc] initWithFrame:blockViewPart1Frame];
	blockViewPart1.backgroundColor = [UIColor colorWithWhite:1 alpha:0];
	blockViewPart1.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
	UIView *blockView = blockViewPart1;
    
	[self.view addSubview:blockView];
	[blockViewDict setValue:blockView forKey:[NSString stringWithFormat:@"%d",  ViewBlockJoyStickHud]];
	
	[blockViewPart1 release];
}

- (void)unblockJoystickHudForTakingOff:(BOOL)animated{
	NSString *blockViewIdentifier = [NSString stringWithFormat:@"%d",  ViewBlockJoyStickHud];
	UIView *blockView = [blockViewDict valueForKey:blockViewIdentifier];
	
	if(blockView == nil)
		return;
	
	if (animated == YES) {
		[UIView animateWithDuration:1
						 animations:^{
							 blockView.alpha = 0;
						 } completion:^(BOOL finished){
							 [blockView removeFromSuperview];
							 [blockViewDict removeObjectForKey:blockViewIdentifier];
						 }
		 ];
	}
	else {
		[blockView removeFromSuperview];
		[blockViewDict removeObjectForKey:blockViewIdentifier];
	}
}

-(void)blockJoystickHudForStopping{
	NSString *blockViewIdentifier = [NSString stringWithFormat:@"%d",  ViewBlockJoyStickHud2];
	
	if([blockViewDict valueForKey:blockViewIdentifier] != nil)
		return;
    
    CGRect blockViewPart1Frame = self.view.frame;
    blockViewPart1Frame.origin.x = 0;
    blockViewPart1Frame.origin.y = joystickLeftButton.frame.origin.y;
    blockViewPart1Frame.size.width = [[UIScreen mainScreen] bounds].size.height;
    blockViewPart1Frame.size.height = joystickLeftButton.frame.origin.y + joystickLeftButton.frame.size.height - joystickLeftButton.frame.origin.y;
    
	BlockViewStyle1 *blockViewPart1 = [[BlockViewStyle1 alloc] initWithFrame:blockViewPart1Frame];
	blockViewPart1.backgroundColor = [UIColor colorWithWhite:1 alpha:0];
	blockViewPart1.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
	UIView *blockView = blockViewPart1;
    
	[self.view addSubview:blockView];
	[blockViewDict setValue:blockView forKey:[NSString stringWithFormat:@"%d",  ViewBlockJoyStickHud2]];
	
	[blockViewPart1 release];
}

- (void)unblockJoystickHudForStopping:(BOOL)animated{
	NSString *blockViewIdentifier = [NSString stringWithFormat:@"%d",  ViewBlockJoyStickHud2];
	UIView *blockView = [blockViewDict valueForKey:blockViewIdentifier];
	
	if(blockView == nil)
		return;
	
	if (animated == YES) {
		[UIView animateWithDuration:1
						 animations:^{
							 blockView.alpha = 0;
						 } completion:^(BOOL finished){
							 [blockView removeFromSuperview];
							 [blockViewDict removeObjectForKey:blockViewIdentifier];
						 }
		 ];
	}
	else {
		[blockView removeFromSuperview];
		[blockViewDict removeObjectForKey:blockViewIdentifier];
	}
}

- (void)updateStatusInfoLabel{
    if(throttleIsLocked){
        if(rudderIsLocked){
            statusInfoLabel.text = getLocalizeString(@"Throttle Rudder Locked");
        }
        else {
            statusInfoLabel.text = getLocalizeString(@"Throttle Locked");
        }
    }
    else {
        if(rudderIsLocked){
            statusInfoLabel.text = getLocalizeString(@"Rudder Locked");
        }
        else {
            statusInfoLabel.text = @"";
        }
    }
}

- (void)updateJoystickCenter{
    rightCenter = CGPointMake(joystickRightInitialPosition.x + (joystickRightBackgroundImageView.frame.size.width / 2), joystickRightInitialPosition.y +  (joystickRightBackgroundImageView.frame.size.height / 2));
    leftCenter = CGPointMake(joystickLeftInitialPosition.x + (joystickLeftBackgroundImageView.frame.size.width / 2), joystickLeftInitialPosition.y +  (joystickLeftBackgroundImageView.frame.size.height / 2));
    
    if(isLeftHanded){
        joystickLeftThumbImageView.center = CGPointMake(leftCenter.x, leftCenter.y - _throttleChannel.value * leftJoyStickOperableRadius);
    }
    else{
        joystickRightThumbImageView.center = CGPointMake(rightCenter.x, rightCenter.y - _throttleChannel.value * rightJoyStickOperableRadius);
    }
}

- (OSStatus) startTransmission {
    enum ppmPolarity polarity = PPM_POLARITY_POSITIVE;
    
    if(_settings.ppmPolarityIsNegative){
        polarity = PPM_POLARITY_NEGATIVE;
    }
    
	OSStatus s = ppm_audio_out_start(8, polarity);
    isTransmitting = !s;
    return s;
}

- (OSStatus) stopTransmission {
    if (isTransmitting) {
        OSStatus s = ppm_audio_out_stop();
        isTransmitting = s;
        return s;
    } else {
        return 0;
    }
}

- (void)dismissSettingsMenuView{
    if(_settingMenuVC.view != nil)
        [_settingMenuVC.view removeFromSuperview];
}

- (void)hideBatteryLevelUI
{
	batteryLevelLabel.hidden = YES;
	batteryImageView.hidden = YES;	
}

- (void)showBatteryLevelUI
{
	batteryLevelLabel.hidden = NO;
	batteryImageView.hidden = NO;
}


- (void)setBattery:(int)percent
{
    static int prevImage = -1;
    static int prevPercent = -1;
    static BOOL wasHidden = NO;
	if(percent < 0 && !wasHidden)
	{
		[self performSelectorOnMainThread:@selector(hideBatteryLevelUI) withObject:nil waitUntilDone:YES];		
        wasHidden = YES;
	}
	else if (percent >= 0)
	{
        if (wasHidden)
        {
            [self performSelectorOnMainThread:@selector(showBatteryLevelUI) withObject:nil waitUntilDone:YES];
            wasHidden = NO;
        }
        int imageNumber = ((percent < 10) ? 0 : (int)((percent / 33.4) + 1));
        if (prevImage != imageNumber)
        {
            UIImage *image = [UIImage imageNamed:[NSString stringWithFormat:@"Btn_Battery_%d_RETINA.png", imageNumber]];
            [batteryImageView performSelectorOnMainThread:@selector(setImage:) withObject:image waitUntilDone:YES];
            prevImage = imageNumber;
        }
        if (prevPercent != percent)
        {
            prevPercent = percent;
            [batteryLevelLabel performSelectorOnMainThread:@selector(setText:) withObject:[NSString stringWithFormat:@"%d%%", percent] waitUntilDone:YES];
        }
	}
}

- (void)refreshJoystickRight
{
	CGRect frame = joystickRightBackgroundImageView.frame;
	frame.origin = joystickRightCurrentPosition;
	joystickRightBackgroundImageView.frame = frame;
}    

- (void)refreshJoystickLeft
{
	CGRect frame = joystickLeftBackgroundImageView.frame;
	frame.origin = joystickLeftCurrentPosition;
	joystickLeftBackgroundImageView.frame = frame;
}

//更新摇杆点（joystickRightThumbImageView或joystickLeftThumbImageView）的位置，point是当前触摸点的位置
- (void)updateVelocity:(CGPoint)point isRight:(BOOL)isRight
{
    static BOOL _runOnce = YES;
    static float leftThumbWidth = 0.0;
    static float rightThumbWidth = 0.0;
    static float leftThumbHeight = 0.0;
    static float rightThumbHeight = 0.0;
    static float leftRadius = 0.0;
    static float rightRadius = 0.0;
    
    if (_runOnce)
    {
        leftThumbWidth = joystickLeftThumbImageView.frame.size.width;
        rightThumbWidth = joystickRightThumbImageView.frame.size.width;
        leftThumbHeight = joystickLeftThumbImageView.frame.size.height;
        rightThumbHeight = joystickRightThumbImageView.frame.size.height;
        leftRadius = joystickLeftBackgroundImageView.frame.size.width / 2.0;
        rightRadius = joystickRightBackgroundImageView.frame.size.width / 2.0;
        _runOnce = NO;
    }
    
	CGPoint nextpoint = CGPointMake(point.x, point.y);
	CGPoint center = (isRight ? rightCenter : leftCenter);
	UIImageView *thumbImage = (isRight ? joystickRightThumbImageView : joystickLeftThumbImageView);
	
	float dx = nextpoint.x - center.x;
	float dy = nextpoint.y - center.y;
    
    float thumb_radius = isRight ? rightJoyStickOperableRadius : leftJoyStickOperableRadius;
	
    if(fabsf(dx) > thumb_radius){
        if (dx > 0) {
            nextpoint.x = center.x + rightJoyStickOperableRadius;
        }
        else {
            nextpoint.x = center.x - rightJoyStickOperableRadius;
        }
    }
    
    if(fabsf(dy) > thumb_radius){
        if(dy > 0){
            nextpoint.y = center.y + rightJoyStickOperableRadius;
        }
        else {
             nextpoint.y = center.y - rightJoyStickOperableRadius;
        }
    }

	CGRect frame = thumbImage.frame;
	frame.origin.x = nextpoint.x - (thumbImage.frame.size.width / 2);
	frame.origin.y = nextpoint.y - (thumbImage.frame.size.height / 2);	
	thumbImage.frame = frame;
}

- (void)updateThrottleValueLabel{
    float takeOffValue = clip(-1 + _settings.takeOffThrottle * 2 + _throttleChannel.trimValue, -1.0, 1.0); 
    
    if (_throttleChannel.isReversing) {
        takeOffValue = -takeOffValue;
    }
    
    throttleValueLabel.text = [NSString stringWithFormat:@"%d", (int)(1500 + 500 * _throttleChannel.value)];
}

- (IBAction)joystickButtonDidTouchDown:(id)sender forEvent:(UIEvent *)event {
    UITouch *touch = [[event touchesForView:sender] anyObject];
	CGPoint current_location = [touch locationInView:self.view];
    static CGPoint previous_location;
    
    previous_location = current_location;
    
	if(sender == joystickRightButton)
	{
        static uint64_t right_press_previous_time = 0;
        if(right_press_previous_time == 0) right_press_previous_time = mach_absolute_time();
        
        uint64_t current_time = mach_absolute_time();
        static mach_timebase_info_data_t sRightPressTimebaseInfo;
        uint64_t elapsedNano;
        float dt = 0;
        
        //dt calculus function of real elapsed time
        if(sRightPressTimebaseInfo.denom == 0) (void) mach_timebase_info(&sRightPressTimebaseInfo);
        elapsedNano = (current_time-right_press_previous_time)*(sRightPressTimebaseInfo.numer / sRightPressTimebaseInfo.denom);
        dt = elapsedNano/1000000000.0;
        
        right_press_previous_time = current_time;
        
        if(dt > 0.1 && dt < 0.3 && !isLeftHanded){
            throttleIsLocked = !throttleIsLocked;
            
            [self updateStatusInfoLabel];
        }
        
		buttonRightPressed = YES;

		joystickRightBackgroundImageView.alpha = joystickRightThumbImageView.alpha = 1.0;
        
        joystickRightCurrentPosition.x = current_location.x - (joystickRightBackgroundImageView.frame.size.width / 2);
        
        CGPoint thumbCurrentLocation = CGPointZero;
        
        if(isLeftHanded){
            joystickRightCurrentPosition.y = current_location.y - (joystickRightBackgroundImageView.frame.size.height / 2);
            
            [self refreshJoystickRight];
            
            //摇杆中心点
            rightCenter = CGPointMake(joystickRightBackgroundImageView.frame.origin.x + (joystickRightBackgroundImageView.frame.size.width / 2), joystickRightBackgroundImageView.frame.origin.y + (joystickRightBackgroundImageView.frame.size.height / 2));
            
            thumbCurrentLocation = rightCenter;
        }
        else{
            float throttleValue = [_throttleChannel value];
            
            //NSLog(@"throttle value:%f", throttleValue);

            joystickRightCurrentPosition.y = current_location.y - (joystickRightBackgroundImageView.frame.size.height / 2) + throttleValue * rightJoyStickOperableRadius;
            
            [self refreshJoystickRight];
            
            //摇杆中心点
            rightCenter = CGPointMake(joystickRightBackgroundImageView.frame.origin.x + (joystickRightBackgroundImageView.frame.size.width / 2), joystickRightBackgroundImageView.frame.origin.y + (joystickRightBackgroundImageView.frame.size.height / 2));
            
            thumbCurrentLocation = CGPointMake(rightCenter.x, current_location.y);
        }
        
        //更新摇杆点（joystickRightThumbImageView或joystickLeftThumbImageView）的位置
        [self updateVelocity:thumbCurrentLocation isRight:YES];
	}
	else if(sender == joystickLeftButton)
	{
        static uint64_t left_press_previous_time = 0;
        if(left_press_previous_time == 0) left_press_previous_time = mach_absolute_time();
        
        uint64_t current_time = mach_absolute_time();
        static mach_timebase_info_data_t sLeftPressTimebaseInfo;
        uint64_t elapsedNano;
        float dt = 0;
        
        //dt calculus function of real elapsed time
        if(sLeftPressTimebaseInfo.denom == 0) (void) mach_timebase_info(&sLeftPressTimebaseInfo);
        elapsedNano = (current_time-left_press_previous_time)*(sLeftPressTimebaseInfo.numer / sLeftPressTimebaseInfo.denom);
        dt = elapsedNano/1000000000.0;
        
        left_press_previous_time = current_time;
        
        if(dt > 0.1 && dt < 0.3 && isLeftHanded){
            throttleIsLocked = !throttleIsLocked;
            
            [self updateStatusInfoLabel];
        }
        
		buttonLeftPressed = YES;
        
        joystickLeftBackgroundImageView.alpha = joystickLeftThumbImageView.alpha = 1.0;
		
		joystickLeftCurrentPosition.x = current_location.x - (joystickLeftBackgroundImageView.frame.size.width / 2);
        
        CGPoint thumbCurrentLocation = CGPointZero;
        
        if(isLeftHanded){
            float throttleValue = [_throttleChannel value];
            
            joystickLeftCurrentPosition.y = current_location.y - (joystickLeftBackgroundImageView.frame.size.height / 2) + throttleValue * leftJoyStickOperableRadius;
            
            [self refreshJoystickLeft];
            
            //摇杆中心点
            leftCenter = CGPointMake(joystickLeftBackgroundImageView.frame.origin.x + (joystickLeftBackgroundImageView.frame.size.width / 2),
                                     joystickLeftBackgroundImageView.frame.origin.y + (joystickLeftBackgroundImageView.frame.size.height / 2));
            
            thumbCurrentLocation = CGPointMake(leftCenter.x, current_location.y);
        }
        else{
            joystickLeftCurrentPosition.y = current_location.y - (joystickLeftBackgroundImageView.frame.size.height / 2);
            
            [self refreshJoystickLeft];
            
            //摇杆中心点
            leftCenter = CGPointMake(joystickLeftBackgroundImageView.frame.origin.x + (joystickLeftBackgroundImageView.frame.size.width / 2), joystickLeftBackgroundImageView.frame.origin.y + (joystickLeftBackgroundImageView.frame.size.height / 2));
            
            thumbCurrentLocation = leftCenter;
        }

		[self updateVelocity:thumbCurrentLocation isRight:NO];
	}
}

- (IBAction)josystickButtonDidTouchUp:(id)sender forEvent:(UIEvent *)event {
	if(sender == joystickRightButton)
	{
		buttonRightPressed = NO;

		joystickRightCurrentPosition = joystickRightInitialPosition;
		joystickRightBackgroundImageView.alpha = joystickRightThumbImageView.alpha = joystickAlpha;
		
		[self refreshJoystickRight];
        
        if (isLeftHanded) {
            [_aileronChannel setValue:0.0];
            [_elevatorChannel setValue:0.0];
            
            rightCenter = CGPointMake(joystickRightBackgroundImageView.frame.origin.x + (joystickRightBackgroundImageView.frame.size.width / 2), joystickRightBackgroundImageView.frame.origin.y + (joystickRightBackgroundImageView.frame.size.height / 2));
        }
        else{
            [_rudderChannel setValue:0.0];
            
            float throttleValue = [_throttleChannel value];
            
            rightCenter = CGPointMake(joystickRightBackgroundImageView.frame.origin.x + (joystickRightBackgroundImageView.frame.size.width / 2), 
                                      joystickRightBackgroundImageView.frame.origin.y + (joystickRightBackgroundImageView.frame.size.height / 2) - throttleValue * rightJoyStickOperableRadius);
        }

		[self updateVelocity:rightCenter isRight:YES];
	}
	else if(sender == joystickLeftButton)
	{
		buttonLeftPressed = NO;

		joystickLeftCurrentPosition = joystickLeftInitialPosition;
		joystickLeftBackgroundImageView.alpha = joystickLeftThumbImageView.alpha = joystickAlpha;
		
		[self refreshJoystickLeft];
        
        if (isLeftHanded) {
            [_rudderChannel setValue:0.0];
            
            float throttleValue = [_throttleChannel value];
            
            leftCenter = CGPointMake(joystickLeftBackgroundImageView.frame.origin.x + (joystickLeftBackgroundImageView.frame.size.width / 2), 
                                      joystickLeftBackgroundImageView.frame.origin.y + (joystickLeftBackgroundImageView.frame.size.height / 2) - throttleValue * rightJoyStickOperableRadius);
        }
        else{
            [_aileronChannel setValue:0.0];
            [_elevatorChannel setValue:0.0];
            
            leftCenter = CGPointMake(joystickLeftBackgroundImageView.frame.origin.x + (joystickLeftBackgroundImageView.frame.size.width / 2), joystickLeftBackgroundImageView.frame.origin.y + (joystickLeftBackgroundImageView.frame.size.height / 2));
        }
		
		[self updateVelocity:leftCenter isRight:NO];
	}
}

- (IBAction)joystickButtonDidDrag:(id)sender forEvent:(UIEvent *)event {
    BOOL _runOnce = YES;
    static float rightBackgoundWidth = 0.0;
    static float rightBackgoundHeight = 0.0;
    static float leftBackgoundWidth = 0.0;
    static float leftBackgoundHeight = 0.0;
    if (_runOnce)
    {
        rightBackgoundWidth = joystickRightBackgroundImageView.frame.size.width;
        rightBackgoundHeight = joystickRightBackgroundImageView.frame.size.height;
        leftBackgoundWidth = joystickLeftBackgroundImageView.frame.size.width;
        leftBackgoundHeight = joystickLeftBackgroundImageView.frame.size.height;
        _runOnce = NO;
    }
    
	UITouch *touch = [[event touchesForView:sender] anyObject];
	CGPoint point = [touch locationInView:self.view];
    
    float aileronElevatorValidBandRatio = 0.5 - _settings.aileronDeadBand / 2.0;
    
    float rudderValidBandRatio = 0.5 - _settings.rudderDeadBand / 2.0;
	
	if(sender == joystickRightButton && buttonRightPressed)
	{
        float rightJoystickXInput, rightJoystickYInput; 
        
        float rightJoystickXValidBand;  //右边摇杆x轴的无效区
        float rightJoystickYValidBand;  //右边摇杆y轴的无效区
        
        if(isLeftHanded){
            rightJoystickXValidBand = aileronElevatorValidBandRatio; //X轴操作是Aileron
            rightJoystickYValidBand = aileronElevatorValidBandRatio; //Y轴操作是Elevator
        }
        else{
            rightJoystickXValidBand = rudderValidBandRatio;    
            rightJoystickYValidBand = 0.5;   //Y轴操作是油门
        }
        
        if(!isLeftHanded && rudderIsLocked){  
            rightJoystickXInput = 0.0;  
        }
        //左右操作 (controlRatio * rightBackgoundWidth)是控制的有效区域，所以((rightBackgoundWidth / 2) - (controlRatio * rightBackgoundWidth))就是盲区了
        else if((rightCenter.x - point.x) > ((rightBackgoundWidth / 2) - (rightJoystickXValidBand * rightBackgoundWidth)))   
        {
            float percent = ((rightCenter.x - point.x) - ((rightBackgoundWidth / 2) - (rightJoystickXValidBand * rightBackgoundWidth))) / ((rightJoystickXValidBand * rightBackgoundWidth));
            if(percent > 1.0)
                percent = 1.0;
            
            rightJoystickXInput = -percent;
        }
        else if((point.x - rightCenter.x) > ((rightBackgoundWidth / 2) - (rightJoystickXValidBand * rightBackgoundWidth)))
        {
            float percent = ((point.x - rightCenter.x) - ((rightBackgoundWidth / 2) - (rightJoystickXValidBand * rightBackgoundWidth))) / ((rightJoystickXValidBand * rightBackgoundWidth));
            if(percent > 1.0)
                percent = 1.0;
            
            rightJoystickXInput = percent;
        }
        else
        {
            rightJoystickXInput = 0.0;
        }
        
        //NSLog(@"right x input:%.3f",rightJoystickXInput);
        
        if (isLeftHanded) {
            [_aileronChannel setValue:rightJoystickXInput];
        }
        else {
            [_rudderChannel setValue:rightJoystickXInput];
        }
        
        if(throttleIsLocked && !isLeftHanded){
            rightJoystickYInput = _throttleChannel.value;
        }
        //上下操作
        else if((point.y - rightCenter.y) > ((rightBackgoundHeight / 2) - (rightJoystickYValidBand * rightBackgoundHeight)))
        {
            float percent = ((point.y - rightCenter.y) - ((rightBackgoundHeight / 2) - (rightJoystickYValidBand * rightBackgoundHeight))) / ((rightJoystickYValidBand * rightBackgoundHeight));
            if(percent > 1.0)
                percent = 1.0;
            
            rightJoystickYInput = -percent;
            
        }
        else if((rightCenter.y - point.y) > ((rightBackgoundHeight / 2) - (rightJoystickYValidBand * rightBackgoundHeight)))
        {
            float percent = ((rightCenter.y - point.y) - ((rightBackgoundHeight / 2) - (rightJoystickYValidBand * rightBackgoundHeight))) / ((rightJoystickYValidBand * rightBackgoundHeight));
            if(percent > 1.0)
                percent = 1.0;
            
            rightJoystickYInput = percent;
        }
        else
        {
            rightJoystickYInput = 0.0;
        }
        
        //NSLog(@"right y input:%.3f",rightJoystickYInput);
        
        if (isLeftHanded) {
            [_elevatorChannel setValue:rightJoystickYInput];
        }
        else {
            [_throttleChannel setValue:rightJoystickYInput];
            [self updateThrottleValueLabel];
        }
	}
	else if(sender == joystickLeftButton
            && buttonLeftPressed)
	{
        float leftJoystickXInput, leftJoystickYInput;
        
        float leftJoystickXValidBand;  //右边摇杆x轴的无效区
        float leftJoystickYValidBand;  //右边摇杆y轴的无效区
        
        if(isLeftHanded){
            leftJoystickXValidBand = rudderValidBandRatio;    
            leftJoystickYValidBand = 0.5;   //Y轴操作是油门
        }
        else{
            leftJoystickXValidBand = aileronElevatorValidBandRatio; //X轴操作是Aileron
            leftJoystickYValidBand = aileronElevatorValidBandRatio; //Y轴操作是Elevator
        }
        
        if(isLeftHanded && rudderIsLocked){
            leftJoystickXInput = 0.0;
        }
		else if((leftCenter.x - point.x) > ((leftBackgoundWidth / 2) - (leftJoystickXValidBand * leftBackgoundWidth)))
		{
			float percent = ((leftCenter.x - point.x) - ((leftBackgoundWidth / 2) - (leftJoystickXValidBand * leftBackgoundWidth))) / ((leftJoystickXValidBand * leftBackgoundWidth));
			if(percent > 1.0)
				percent = 1.0;
            
            leftJoystickXInput = -percent;
            
		}
		else if((point.x - leftCenter.x) > ((leftBackgoundWidth / 2) - (leftJoystickXValidBand * leftBackgoundWidth)))
		{
			float percent = ((point.x - leftCenter.x) - ((leftBackgoundWidth / 2) - (leftJoystickXValidBand * leftBackgoundWidth))) / ((leftJoystickXValidBand * leftBackgoundWidth));
			if(percent > 1.0)
				percent = 1.0;

            leftJoystickXInput = percent;
		}
		else
		{
            leftJoystickXInput = 0.0;
		}	
        
       //NSLog(@"left x input:%.3f",leftJoystickXInput);
		
        if(isLeftHanded){
            [_rudderChannel setValue:leftJoystickXInput];
        }
        else{
            [_aileronChannel setValue:leftJoystickXInput];
        }
        
        if(throttleIsLocked && isLeftHanded){
            leftJoystickYInput = _throttleChannel.value;
        }
		else if((point.y - leftCenter.y) > ((leftBackgoundHeight / 2) - (leftJoystickYValidBand * leftBackgoundHeight)))
		{
			float percent = ((point.y - leftCenter.y) - ((leftBackgoundHeight / 2) - (leftJoystickYValidBand * leftBackgoundHeight))) / ((leftJoystickYValidBand * leftBackgoundHeight));
			if(percent > 1.0)
				percent = 1.0;
            
            leftJoystickYInput = -percent;
		}
		else if((leftCenter.y - point.y) > ((leftBackgoundHeight / 2) - (leftJoystickYValidBand * leftBackgoundHeight)))
		{
			float percent = ((leftCenter.y - point.y) - ((leftBackgoundHeight / 2) - (leftJoystickYValidBand * leftBackgoundHeight))) / ((leftJoystickYValidBand * leftBackgoundHeight));
			if(percent > 1.0)
				percent = 1.0;
            
            leftJoystickYInput = percent;
		}
		else
		{  
            leftJoystickYInput = 0.0;
		}		
        
        //NSLog(@"left y input:%.3f",leftJoystickYInput);
        
        if(isLeftHanded){
            [_throttleChannel setValue:leftJoystickYInput];
            [self updateThrottleValueLabel];
        }
        else{
            [_elevatorChannel setValue:leftJoystickYInput];
        }
	}
    
    BOOL isRight = (sender == joystickRightButton);
    if ((isRight && buttonRightPressed) ||
        (!isRight && buttonLeftPressed))
    {
        [self updateVelocity:point isRight:isRight];
    }
}

- (void)showSettingsMenuView{
    [_settingMenuVC release], _settingMenuVC = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        _settingMenuVC = [[SettingsMenuViewController alloc] initWithNibName:@"SettingsMenuViewController" bundle:nil settings:_settings];
    } else {
        _settingMenuVC = [[SettingsMenuViewController alloc] initWithNibName:@"SettingsMenuViewController_iPhone" bundle:nil settings:_settings];
    }
    
    _settingMenuVC.delegate = self;
    
    [self.view addSubview:_settingMenuVC.view];
}

- (IBAction)takoffButtonDidTouchDown:(id)sender {
    [self blockJoystickHudForTakingOff];
    
    _aileronChannel.value = 0;
    _elevatorChannel.value = 0;
    _rudderChannel.value = 0;
    
    float takeOffValue = clip(-1 + _settings.takeOffThrottle * 2 + _throttleChannel.trimValue, -1.0, 1.0); 
    
    if (_throttleChannel.isReversing) {
        takeOffValue = -takeOffValue;
    }
    
    _throttleChannel.value = takeOffValue;
    
    [self updateThrottleValueLabel];
    [self updateJoystickCenter];
}

- (IBAction)takeoffButtonDidTouchUp:(id)sender {
    [self unblockJoystickHudForTakingOff:NO];
}

- (IBAction)throttleStopButtonDidTouchDown:(id)sender {
    [self blockJoystickHudForStopping];
    
    _aileronChannel.value = 0;
    _elevatorChannel.value = 0;
    _rudderChannel.value = 0;
    _throttleChannel.value = -1;
    
    [self updateThrottleValueLabel];
    [self updateJoystickCenter];
}

- (IBAction)throttleStopButtonDidTouchUp:(id)sender {
    [self unblockJoystickHudForStopping:NO];
}

- (void)setView:(UIView *)view hidden:(BOOL)hidden{
    //view.h
}

- (IBAction)buttonDidTouchDown:(id)sender {
    if(sender == throttleUpButton){ 
        upIndicatorImageView.hidden = NO;
    }
    else if(sender == throttleDownButton){
        downIndicatorImageView.hidden = NO;
    }
}

- (IBAction)buttonDidDragEnter:(id)sender {
    if(sender == throttleUpButton || sender == throttleDownButton){ 
        [self buttonDidTouchDown:sender];
    }
}

- (IBAction)buttonDidDragExit:(id)sender {
    if(sender == throttleUpButton || sender == throttleDownButton){ 
        [self buttonDidTouchUpOutside:sender];
    }
}

- (IBAction)buttonDidTouchUpInside:(id)sender {
    if(sender == setttingButton){
        [self showSettingsMenuView];
    }
    else if(sender == rudderLockButton){
        rudderIsLocked = !rudderIsLocked;
        
        if(rudderIsLocked){
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                [rudderLockButton setImage:[UIImage imageNamed:@"Switch_On_IPAD.png"] forState:UIControlStateNormal];
            } 
            else {
                [rudderLockButton setImage:[UIImage imageNamed:@"Switch_On_RETINA.png"] forState:UIControlStateNormal];
            }
        }
        else{
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                [rudderLockButton setImage:[UIImage imageNamed:@"Switch_Off_IPAD.png"] forState:UIControlStateNormal];
            } 
            else {
                [rudderLockButton setImage:[UIImage imageNamed:@"Switch_Off_RETINA.png"] forState:UIControlStateNormal];
            }
        }
        
        [self updateStatusInfoLabel];
    }
    else if(sender == throttleUpButton){
        if(_throttleChannel.value + kThrottleFineTuningStep > 1){
            _throttleChannel.value = 1; 
        }
        else {
            _throttleChannel.value += kThrottleFineTuningStep;
        }
        [self updateJoystickCenter];
        
        if(isLeftHanded){
            joystickLeftThumbImageView.center = CGPointMake(joystickLeftThumbImageView.center.x, leftCenter.y - _throttleChannel.value * leftJoyStickOperableRadius);
        }
        else{
            joystickRightThumbImageView.center = CGPointMake(joystickRightThumbImageView.center.x, rightCenter.y - _throttleChannel.value * rightJoyStickOperableRadius);
        }   
        
        upIndicatorImageView.hidden = YES;
        
        [self updateThrottleValueLabel];
    }
    else if(sender == throttleDownButton){
        if(_throttleChannel.value - kThrottleFineTuningStep < -1){
            _throttleChannel.value = -1; 
        }
        else {
            _throttleChannel.value -= kThrottleFineTuningStep;
        }
        [self updateJoystickCenter];
        
        downIndicatorImageView.hidden = YES;
        
        [self updateThrottleValueLabel];
    }
}

- (IBAction)buttonDidTouchUpOutside:(id)sender {
    if(sender == throttleUpButton){ 
        upIndicatorImageView.hidden = YES;
    }
    else if(sender == throttleDownButton){
        downIndicatorImageView.hidden = YES;
    }
}

- (IBAction)buttonDidTouchCancel:(id)sender {
    if(sender == throttleUpButton || sender == throttleDownButton){ 
        [self buttonDidTouchUpOutside:sender];
    }
}

@end
