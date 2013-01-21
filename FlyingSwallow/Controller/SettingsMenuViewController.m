//
//  SettingsMenuViewController.m
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

#import "SettingsMenuViewController.h"
#import "Macros.h"
#import "Channel.h"
#import "ChannelSettingsViewController.h"
#import "util.h"

#define kAileronElevatorMaxDeadBandRatio 0.2
#define kRudderMaxDeadBandRatio 0.2


@interface SettingsMenuViewController (){
    UITableViewCell *reorderTableViewCell;
    
    NSMutableArray *pageViewArray;
    NSMutableArray *pageTitleArray;
    
    int pageCount;
    
    Settings *settings;
    
    ChannelSettingsViewController *channelSettingsVC;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil;


@end

@implementation SettingsMenuViewController
@synthesize delegate = _delegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {  
    }
    
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil settings:(Settings *)settings_{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
        pageViewArray = [[NSMutableArray alloc] initWithCapacity:3];
        pageTitleArray = [[NSMutableArray alloc] initWithCapacity:3];
        
        settings = [settings_ retain];
        
         [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissChannelSetttingsView) name:kNotificationDismissChannelSettingsView object:nil];
        
    }
    
    return self;
}

- (void)updateSettingsUI{
    [self setSwitchButton:leftHandedSwitchButton withValue:settings.isLeftHanded];
    interfaceOpacitySlider.value = settings.interfaceOpacity * 100;
    interfaceOpacityLabel.text = [NSString stringWithFormat:@"%d%%", (int)(settings.interfaceOpacity * 100)];
    [self setSwitchButton:ppmPolarityReversedSwitchButton withValue:settings.ppmPolarityIsNegative];
    takeOffThrottleSlider.value = settings.takeOffThrottle;
    [self updateTakeOffThrottleLabel];
    
    [self updateAileronElevatorDeadBandLabel];
    [self updateAileronElevatorDeadBandSlider];
    [self updateRudderDeadBandLabel];
    [self updateRudderDeadBandSlider];
    
    [channelListTableView reloadData];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    leftHandedTitleLabel.text = getLocalizeString(@"LEFT HANDED");
    interfaceOpacityTitleLabel.text = getLocalizeString(@"INTERFACE OPACITY");

    [pageViewArray addObject:personalSettingsPageView];
    [pageTitleArray addObject:getLocalizeString(@"PERSONAL SETTINGS")];
    [pageViewArray addObject:channelSetttingsPageView];
    [pageTitleArray addObject:getLocalizeString(@"CHANNELS SETTINGS")];
    [pageViewArray addObject:modeSettingsPageView];
    [pageTitleArray addObject:getLocalizeString(@"MODE SETTINGS")];
    [pageViewArray addObject:aboutPageView];
    [pageTitleArray addObject:getLocalizeString(@"ABOUT")];
    
    pageCount = pageViewArray.count;
    
    CGFloat x = 0.f;
    for (UIView *pageView in pageViewArray)
    {
        CGRect frame = pageView.frame;
        frame.origin.x = x;
        [pageView setFrame:frame];
        [settingsPageScrollView addSubview:pageView];
        x += pageView.frame.size.width;
    }
    [settingsPageScrollView  setContentSize:CGSizeMake(x, settingsPageScrollView.frame.size.height)];
    
    [pageControl setNumberOfPages:pageCount];
    [pageControl setCurrentPage:0];
    
    pageTitleLabel.text = getLocalizeString(@"PERSONAL SETTINGS");
    ppmPolarityReversedTitleLabel.text = getLocalizeString(@"PPM POLARITY REVERSED");
    takeOffThrottleTitleLabel.text = getLocalizeString(@"Take Off Throttle");
    aileronElevatorDeadBandTitleLabel.text = getLocalizeString(@"Aileron/Elevator Dead Band");
    rudderDeadBandTitleLabel.text = getLocalizeString(@"Rudder Dead Band");
    [defaultSettingsButton setTitle:getLocalizeString(@"Default Settings") forState:UIControlStateNormal];
    
    channelListTableView.backgroundColor = [UIColor clearColor];
    channelListTableView.backgroundView.hidden = YES;
    
    NSURL *aboutFileURL = [NSURL fileURLWithPath: [[NSBundle mainBundle] pathForResource:@"About" ofType:@"html"]];
    NSURLRequest *request = [NSURLRequest requestWithURL:aboutFileURL];
    [aboutWebView loadRequest:request];
    
    [self updateSettingsUI];
}

- (void)viewDidUnload
{
    [personalSettingsPageView release];
    personalSettingsPageView = nil;
    [channelSetttingsPageView release];
    channelSetttingsPageView = nil;
    [modeSettingsPageView release];
    modeSettingsPageView = nil;
    [settingsPageScrollView release];
    settingsPageScrollView = nil;
    [previousPageButton release];
    previousPageButton = nil;
    [nextPageButton release];
    nextPageButton = nil;
    [pageTitleLabel release];
    pageTitleLabel = nil;
    [okButton release];
    okButton = nil;
    
    [pageViewArray release], pageViewArray = nil;
    [pageTitleArray release], pageViewArray = nil;
    
    [pageControl release];
    pageControl = nil;
    [aboutPageView release];
    aboutPageView = nil;
    [leftHandedTitleLabel release];
    leftHandedTitleLabel = nil;
    [leftHandedSwitchButton release];
    leftHandedSwitchButton = nil;
    [interfaceOpacityTitleLabel release];
    interfaceOpacityTitleLabel = nil;
    [interfaceOpacitySlider release];
    interfaceOpacitySlider = nil;
    [interfaceOpacityLabel release];
    interfaceOpacityLabel = nil;
    [channelListTableView release];
    channelListTableView = nil;
    
    [reorderTableViewCell release], reorderTableViewCell = nil;
    
    [ppmPolarityReversedTitleLabel release];
    ppmPolarityReversedTitleLabel = nil;
    [ppmPolarityReversedSwitchButton release];
    ppmPolarityReversedSwitchButton = nil;
    [defaultSettingsButton release];
    defaultSettingsButton = nil;
    [takeOffThrottleTitleLabel release];
    takeOffThrottleTitleLabel = nil;
    [takeOffThrottleLabel release];
    takeOffThrottleLabel = nil;
    [takeOffThrottleSlider release];
    takeOffThrottleSlider = nil;
    [aileronElevatorDeadBandTitleLabel release];
    aileronElevatorDeadBandTitleLabel = nil;
    [aileronElevatorDeadBandSlider release];
    aileronElevatorDeadBandSlider = nil;
    [aileronElevatorDeadBandLabel release];
    aileronElevatorDeadBandLabel = nil;
    [rudderDeadBandTitleLabel release];
    rudderDeadBandTitleLabel = nil;
    [rudderDeadBandSlider release];
    rudderDeadBandSlider = nil;
    [rudderDeadBandLabel release];
    rudderDeadBandLabel = nil;
    [aboutWebView release];
    aboutWebView = nil;
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    
    if([channelSettingsVC.view superview] == nil)
        [channelSettingsVC release], channelSettingsVC = nil;

}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kNotificationDismissChannelSettingsView object:nil];

    [personalSettingsPageView release];
    [channelSetttingsPageView release];
    [modeSettingsPageView release];
    [settingsPageScrollView release];
    [previousPageButton release];
    [nextPageButton release];
    [pageTitleLabel release];
    [okButton release];
    
    [pageViewArray release];
    [pageTitleArray release];
    
    [pageControl release];
    [aboutPageView release];
    [leftHandedTitleLabel release];
    [leftHandedSwitchButton release];
    [interfaceOpacityTitleLabel release];
    [interfaceOpacitySlider release];
    [interfaceOpacityLabel release];
    [channelListTableView release];
    [reorderTableViewCell release];
    [settings release];
    [channelSettingsVC release];
    [ppmPolarityReversedTitleLabel release];
    [ppmPolarityReversedSwitchButton release];
    [defaultSettingsButton release];
    [takeOffThrottleTitleLabel release];
    [takeOffThrottleLabel release];
    [takeOffThrottleSlider release];
    [aileronElevatorDeadBandTitleLabel release];
    [aileronElevatorDeadBandSlider release];
    [aileronElevatorDeadBandLabel release];
    [rudderDeadBandTitleLabel release];
    [rudderDeadBandSlider release];
    [rudderDeadBandLabel release];
    [aboutWebView release];
    [super dealloc];
}

- (void)dismissChannelSetttingsView{
    [channelSettingsVC.view removeFromSuperview];
    [channelListTableView reloadData];
}

- (void)updateTakeOffThrottleLabel{
    Channel *throttleChannel = [settings channelByName:kChannelNameThrottle];
    
    float outputValue = clip(-1 + settings.takeOffThrottle * 2 + throttleChannel.trimValue, -1.0, 1.0); 
    
    if (throttleChannel.isReversing) {
        outputValue = -outputValue;
    }
    
    float takeOffThrottle = 1500 + 500 * (outputValue * throttleChannel.outputAdjustabledRange);
    
    takeOffThrottleLabel.text = [NSString stringWithFormat:@"%.2f, %dus", settings.takeOffThrottle, (int)takeOffThrottle];
}

- (void)updateRudderDeadBandLabel{
    rudderDeadBandLabel.text = [NSString stringWithFormat:@"%.2f%%", settings.rudderDeadBand * 100];
}

- (void)updateRudderDeadBandSlider{
    rudderDeadBandSlider.value = settings.rudderDeadBand / (float)kRudderMaxDeadBandRatio;
}

- (void)updateAileronElevatorDeadBandLabel{
    aileronElevatorDeadBandLabel.text = [NSString stringWithFormat:@"%.2f%%", settings.aileronDeadBand * 100];
}

- (void)updateAileronElevatorDeadBandSlider{
    aileronElevatorDeadBandSlider.value = settings.aileronDeadBand / (float)kAileronElevatorMaxDeadBandRatio;
}


#pragma mark UIWebViewDelegate Methods
- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
	if (navigationType == UIWebViewNavigationTypeLinkClicked) {
		[[UIApplication sharedApplication] openURL:[request URL]];
		return NO;
	} else {
		return YES;
	}
}
#pragma mark UIWebViewDelegate Methods end


#pragma mark UITableViewDelegate Methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if([indexPath section] == ChannelListTableViewSectionChannels){
        Channel *channel = [settings channelAtIndex:[indexPath row]];
        
        if(channelSettingsVC == nil){
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                channelSettingsVC  = [[ChannelSettingsViewController alloc] initWithNibName:@"ChannelSettingsViewController" bundle:nil channel:channel];
            } else {
                channelSettingsVC  = [[ChannelSettingsViewController alloc] initWithNibName:@"ChannelSettingsViewController_iPhone" bundle:nil channel:channel];
            }
        }
        channelSettingsVC.channel = channel;
        
        [self.view addSubview:channelSettingsVC.view];
    }
}

#pragma mark UITableViewDelegate Methods end

#pragma mark UITableViewDataSource Methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    switch (section) {
        case ChannelListTableViewSectionChannels:
            return 8;
            break;
        default:
            return 0;
            break;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    switch (section) {
        case ChannelListTableViewSectionChannels:
            return getLocalizeString(@"CHANNELS");
            break;
        default:
            return @"";
            break;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	switch ([indexPath section]) {
		case ChannelListTableViewSectionChannels: {
			static NSString *ChannelCellId = @"ChannelListTableViewChannelCell";
			UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ChannelCellId];
			if (cell == nil) {
				cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ChannelCellId] autorelease];
				[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
			}
            
            Channel *channel = [settings channelAtIndex:[indexPath row]];
            
            cell.textLabel.text = [NSString stringWithFormat:@"%d: %@", [channel idx] + 1, [channel name]]; 
            
            int minOutputPpm = (int)(1500 + 500 * clip(-1 + channel.trimValue, -1, 1) * channel.outputAdjustabledRange);
            int maxOutputPpm = (int)(1500 + 500 * clip(1 + channel.trimValue, -1, 1) * channel.outputAdjustabledRange);
            
            NSString *ppmRangeText = [NSString stringWithFormat:@"%d~%dus", minOutputPpm, maxOutputPpm];
 
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@:%.2f %@:%.2f %@", [channel isReversing] ? getLocalizeString(@"Reversed"):getLocalizeString(@"Normal"), getLocalizeString(@"Trim"), [channel trimValue], getLocalizeString(@"Adjustable"), [channel outputAdjustabledRange], ppmRangeText];
            
			return cell;
		}
	}

	return nil;
}

#pragma mark UITableViewDataSource Methods end


- (void)setSwitchButton:(UIButton *)switchButton withValue:(BOOL)active
{
    if (active)
    {
        switchButton.tag = SWITCH_BUTTON_CHECKED;
        [switchButton setImage:[UIImage imageNamed:@"Btn_ON.png"] forState:UIControlStateNormal];
    }
    else
    {
        switchButton.tag = SWITCH_BUTTON_UNCHECKED;
        [switchButton setImage:[UIImage imageNamed:@"Btn_OFF.png"] forState:UIControlStateNormal];
    }
}

- (void)toggleSwitchButton:(UIButton *)switchButton
{
    [self setSwitchButton:switchButton withValue:(SWITCH_BUTTON_UNCHECKED == switchButton.tag) ? YES : NO];
}


- (void)scrollViewDidScroll:(UIScrollView *)_scrollView
{
	int currentPage = (int) (settingsPageScrollView.contentOffset.x + .5f * settingsPageScrollView.frame.size.width) / settingsPageScrollView.frame.size.width;
    
    if (currentPage == 0)
    {
        [previousPageButton setHidden:YES];
        [nextPageButton setHidden:NO];
    }
    else if (currentPage == (pageCount - 1))
    {
        [previousPageButton setHidden:NO];
        [nextPageButton setHidden:YES];
    }
    else if (currentPage >= pageCount)
    {
        currentPage = pageCount - 1;
        [previousPageButton setHidden:NO];
        [nextPageButton setHidden:YES];
    }
    else
    {
        [previousPageButton setHidden:NO];
        [nextPageButton setHidden:NO];
    }
    
    [pageControl setCurrentPage:currentPage];
    [pageTitleLabel setText:[pageTitleArray objectAtIndex:currentPage]];
}

- (void)showPreviousPageView{
    int nextPage = ((int) (settingsPageScrollView.contentOffset.x + .5f * settingsPageScrollView.frame.size.width) / settingsPageScrollView.frame.size.width) - 1;
    if (0 > nextPage)
        nextPage = 0;
    CGFloat nextOffset = nextPage * settingsPageScrollView.frame.size.width;
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3f];
    [settingsPageScrollView setContentOffset:CGPointMake(nextOffset, 0.f) animated:NO];
    [UIView commitAnimations];
}

- (void)showNextPageView{
    int nextPage = ((int) (settingsPageScrollView.contentOffset.x + .5f * settingsPageScrollView.frame.size.width) / settingsPageScrollView.frame.size.width) + 1;
    if (pageCount <= nextPage)
        nextPage = pageCount - 1;
    CGFloat nextOffset = nextPage *settingsPageScrollView.frame.size.width;
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3f];
    [settingsPageScrollView setContentOffset:CGPointMake(nextOffset, 0.f) animated:NO];
    [UIView commitAnimations];
}

- (void)resetToDefaultSettings{
    [settings resetToDefault];
    [settings save];
    
    [self updateSettingsUI];
    
    if([_delegate respondsToSelector:@selector(settingsMenuViewController:leftHandedValueDidChange:)]){
        [_delegate settingsMenuViewController:self leftHandedValueDidChange:settings.isLeftHanded];
    }
    
    if([_delegate respondsToSelector:@selector(settingsMenuViewController:ppmPolarityReversed:)]){
        [_delegate settingsMenuViewController:self ppmPolarityReversed:settings.ppmPolarityIsNegative];
    }
    
    if([_delegate respondsToSelector:@selector(settingsMenuViewController:interfaceOpacityValueDidChange:)]){
        [_delegate settingsMenuViewController:self interfaceOpacityValueDidChange:settings.interfaceOpacity];
    }
}

- (IBAction)buttonClick:(id)sender {
    if(sender == okButton){
        [[NSNotificationCenter defaultCenter] postNotificationName:kNotificationDismissSettingsMenuView object:self userInfo:nil];
    }
    else if(sender == previousPageButton){
        [self showPreviousPageView];
    }
    else if(sender == nextPageButton){
        [self showNextPageView];
    }
    else if(sender == defaultSettingsButton){
        [self resetToDefaultSettings];
    }else {
        ;
    }
}

- (IBAction)switchButtonClick:(id)sender {
    [self toggleSwitchButton:sender];
    
    if(sender == leftHandedSwitchButton){
        settings.isLeftHanded = (SWITCH_BUTTON_CHECKED == [sender tag]) ? YES : NO;
        [settings save];
        
        if([_delegate respondsToSelector:@selector(settingsMenuViewController:leftHandedValueDidChange:)]){
            [_delegate settingsMenuViewController:self leftHandedValueDidChange:settings.isLeftHanded];
        }
    }
    else if(sender == ppmPolarityReversedSwitchButton){
        settings.ppmPolarityIsNegative = (SWITCH_BUTTON_CHECKED == [sender tag]) ? YES : NO;
        [settings save];
        
        if([_delegate respondsToSelector:@selector(settingsMenuViewController:ppmPolarityReversed:)]){
            [_delegate settingsMenuViewController:self ppmPolarityReversed:settings.ppmPolarityIsNegative];
        }
    }
    else{
        ;
    }
}

- (IBAction)sliderRelease:(id)sender {
    if(sender == interfaceOpacitySlider){
        [settings save];

        if([_delegate respondsToSelector:@selector(settingsMenuViewController:interfaceOpacityValueDidChange:)]){
            [_delegate settingsMenuViewController:self interfaceOpacityValueDidChange:settings.interfaceOpacity];
        }
    }
    else if(sender == takeOffThrottleSlider){
        [settings save];
    }
    else if(sender == aileronElevatorDeadBandSlider) {
        [settings save];
    }
    else if(sender == rudderDeadBandSlider){
        [settings save];
    }
}

- (IBAction)sliderValueChanged:(id)sender {
    if(sender == interfaceOpacitySlider){
        interfaceOpacityLabel.text = [NSString stringWithFormat:@"%d %%", (int)interfaceOpacitySlider.value];
        settings.interfaceOpacity = interfaceOpacitySlider.value / 100.0f;
    }
    else if(sender == takeOffThrottleSlider){
        settings.takeOffThrottle = takeOffThrottleSlider.value;
        [self updateTakeOffThrottleLabel];
    }
    else if(sender == aileronElevatorDeadBandSlider){ //无效区在0~kAileronElevatorMaxDeadBandRatio之间
        settings.aileronDeadBand = kAileronElevatorMaxDeadBandRatio * aileronElevatorDeadBandSlider.value;  
        settings.elevatorDeadBand = settings.aileronDeadBand;
        
        [self updateAileronElevatorDeadBandLabel];
    }
    else if(sender == rudderDeadBandSlider){ //无效区在0~kRudderMaxDeadBandRatio之间
        settings.rudderDeadBand = kRudderMaxDeadBandRatio * rudderDeadBandSlider.value;
        [self updateRudderDeadBandLabel];
    }
    else {
        
    }
}
@end
