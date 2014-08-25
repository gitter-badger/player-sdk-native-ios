//
//  KALPlayer.m
//  KalPlayerSDK
//
//  Created by Eliza Sapir on 8/13/14.
//  Copyright (c) 2014 Kaltura. All rights reserved.
//

#import "KALPlayer.h"

@implementation KALPlayer {
    // Player Params
    BOOL isSeeking;
    BOOL isFullScreen, isPlaying, isResumePlayer, isPlayCalled;
    CGRect originalViewControllerFrame;
    CGAffineTransform fullScreenPlayerTransform;
    UIDeviceOrientation prevOrientation, deviceOrientation;
    NSString *playerSource;
    NSMutableDictionary *appConfigDict;
    BOOL openFullScreen;
    UIButton *btn;
    BOOL isCloseFullScreenByTap;
    // AirPlay Params
    MPVolumeView *volumeView;
    NSArray *prevAirPlayBtnPositionArr;
    
    BOOL isJsCallbackReady;
    NSMutableDictionary *kPlayerEventsDict;
    NSMutableDictionary *kPlayerEvaluatedDict;
    
#if !(TARGET_IPHONE_SIMULATOR)
    // WideVine Params
    BOOL isWideVine, isWideVineReady;
    WVSettings* wvSettings;
#endif
}

@synthesize delegate;
@synthesize currentPlaybackTime;
@synthesize view;
@synthesize controlStyle;
@synthesize playbackState;
@synthesize loadState;
@synthesize isPreparedToPlay;
@synthesize contentURL;

- (void) copyParamsFromPlayer:(id<KalturaPlayer>) player {
    if (self) {
        if ( [self isPreparedToPlay] ) {
            self.currentPlaybackTime = player.currentPlaybackTime;
        }
        
        [self setContentURL: [player contentURL]];
    }
}

-(NSURL *)contentURL {
    return super.contentURL;
}
-(void)setContentURL:(NSURL *)cs {
    super.contentURL = [cs copy];
}

-(int)controlStyle {
    return [super controlStyle];
}

-(void)setControlStyle:(int)cs {
    [super setControlStyle:cs];
}

- (void)play {
    NSLog( @"Play Player Enter" );
    
    isPlayCalled = YES;
    
#if !(TARGET_IPHONE_SIMULATOR)
    if ( isWideVine  && !isWideVineReady ) {
        return;
    }
#endif
    
    if( !( self.playbackState == MPMoviePlaybackStatePlaying ) ) {
        [self prepareToPlay];
        [super play];
    }
    
    [self callSelectorOnDelegate: @selector(kPlayerDidPlay)];
    
    NSLog( @"Play Player Exit" );
}

- (void)pause {
    NSLog(@"Pause Player Enter");
    
    isPlayCalled = NO;
    
    if ( !( self.playbackState == MPMoviePlaybackStatePaused ) ) {
        [super pause];
    }
    
    [ self callSelectorOnDelegate: @selector(kPlayerDidPause) ];
    
    NSLog(@"Pause Player Exit");
}

- (void)stop {
    NSLog(@"Stop Player Enter");
    
    [super stop];
    isPlaying = NO;
    isPlayCalled = NO;
    
#if !(TARGET_IPHONE_SIMULATOR)
    // Stop WideVine
    if ( isWideVine ) {
        [wvSettings stopWV];
        isWideVine = NO;
        isWideVineReady = NO;
    }
#endif
    
    [ self callSelectorOnDelegate: @selector(kPlayerDidStop) ];
    
    NSLog(@"Stop Player Exit");
}

- (void)callSelectorOnDelegate:(SEL) selector {
    if ( delegate && [delegate respondsToSelector: selector] ) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [delegate performSelector: selector];
#pragma clang diagnostic pop
    }
}

- (id)view {
    return [super view];
}

- (double)currentPlaybackTime {
    return [super currentPlaybackTime];
}


- (int)playbackState {
    return [super playbackState];
}

- (int)loadState {
    return [super loadState];
}

- (void)prepareToPlay {
    [super prepareToPlay];
}

- (BOOL)isPreparedToPlay {
    return [super isPreparedToPlay];
}


- (double)playableDuration {
    return [super playableDuration];
}

- (double)duration {
    return [super duration];
}

- (void)setCurrentPlaybackTime:(NSTimeInterval)currPlaybackTime {
    if ([self isPreparedToPlay]) {
        [super setCurrentPlaybackTime: currPlaybackTime];
    }
}

- (void)bindPlayerEvents {
    NSMutableDictionary *eventsDictionary = [[NSMutableDictionary alloc] init];
    
    [eventsDictionary setObject: MPMoviePlayerLoadStateDidChangeNotification
                         forKey: @"triggerLoadPlabackEvents:"];
    [eventsDictionary setObject: MPMoviePlayerPlaybackDidFinishNotification
                         forKey: @"triggerFinishPlabackEvents:"];
    [eventsDictionary setObject: MPMoviePlayerPlaybackStateDidChangeNotification
                         forKey: @"triggerMoviePlabackEvents:"];
    [eventsDictionary setObject: MPMoviePlayerTimedMetadataUpdatedNotification
                         forKey: @"metadataUpdate:"];
    [eventsDictionary setObject: MPMovieDurationAvailableNotification
                         forKey: @"onMovieDurationAvailable:"];
    
    for (id functionName in eventsDictionary){
        id event = [eventsDictionary objectForKey:functionName];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:NSSelectorFromString(functionName) name:event object:self];
    }
}

- (void)triggerLoadPlabackEvents: (NSNotification *)note{
    NSLog(@"triggerLoadPlabackEvents Enter");
    
    NSString *loadStateName = [[NSString alloc]init];
    
    switch ( [self loadState] ) {
        case MPMovieLoadStateUnknown:
            loadStateName = @"MPMovieLoadStateUnknown";
            NSLog(@"MPMovieLoadStateUnknown");
            break;
        case MPMovieLoadStatePlayable:
            loadStateName = @"canplay";
            [self triggerKPlayerEvents: @"durationchange" withValue: @{@"durationchange": [NSString stringWithFormat: @"%f", [self duration]]}];
            [self triggerKPlayerEvents: @"loadedmetadata"  withValue: @{@"loadedmetadata": @""}];
            NSLog(@"MPMovieLoadStatePlayable");
            break;
        case MPMovieLoadStatePlaythroughOK:
            loadStateName = @"MPMovieLoadStatePlaythroughOK";
            NSLog(@"MPMovieLoadStatePlaythroughOK");
            break;
        case MPMovieLoadStateStalled:
            loadStateName = @"stalled";
            NSLog(@"MPMovieLoadStateStalled");
            break;
        default:
            break;
    }
    
    [self triggerKPlayerEvents: loadStateName withValue: nil];
    
    NSLog(@"triggerLoadPlabackEvents Exit");
}

- (void)triggerMoviePlabackEvents: (NSNotification *)note{
    NSLog(@"triggerMoviePlabackEvents Enter");
    
    NSString *playBackName = [[NSString alloc] init];
    
    
    if (isSeeking) {
        isSeeking = NO;
        playBackName = @"seeked";
        NSLog(@"MPMoviePlaybackStateStopSeeking");
        //called because there is another event that will be fired
        [self triggerKPlayerEvents: playBackName withValue: nil];
    }
    
    switch ( [self playbackState] ) {
        case MPMoviePlaybackStateStopped:
            isPlaying = NO;
            playBackName = @"stop";
            NSLog(@"MPMoviePlaybackStateStopped");
            break;
        case MPMoviePlaybackStatePlaying:
            isPlaying = YES;
            playBackName = @"";
            if( ( [self playbackState] == MPMoviePlaybackStatePlaying ) ) {
                playBackName = @"play";
            }
            
            NSLog(@"MPMoviePlaybackStatePlaying");
            break;
        case MPMoviePlaybackStatePaused:
            isPlaying = NO;
            playBackName = @"";
            if ( ( [self playbackState] == MPMoviePlaybackStatePaused ) ) {
                playBackName = @"pause";
            }
            
            NSLog(@"MPMoviePlaybackStatePaused");
            break;
        case MPMoviePlaybackStateInterrupted:
            playBackName = @"MPMoviePlaybackStateInterrupted";
            NSLog(@"MPMoviePlaybackStateInterrupted");
            break;
        case MPMoviePlaybackStateSeekingForward:
        case MPMoviePlaybackStateSeekingBackward:
            isSeeking = YES;
            playBackName = @"seeking";
            NSLog(@"MPMoviePlaybackStateSeeking");
            break;
        default:
            break;
    }
    
    [self triggerKPlayerEvents: playBackName withValue: nil];
    
    NSLog(@"triggerMoviePlabackEvents Exit");
}

- (void)triggerFinishPlabackEvents:(NSNotification*)notification {
    NSLog(@"triggerFinishPlabackEvents Enter");
    
    NSString *finishPlayBackName = [[NSString alloc]init];
    NSNumber* reason = [[notification userInfo] objectForKey:MPMoviePlayerPlaybackDidFinishReasonUserInfoKey];
    
    switch ( [reason intValue] ) {
        case MPMovieFinishReasonPlaybackEnded:
            finishPlayBackName = @"ended";
            NSLog(@"playbackFinished. Reason: Playback Ended");
            break;
        case MPMovieFinishReasonPlaybackError:
            finishPlayBackName = @"error";
            NSLog(@"playbackFinished. Reason: Playback Error");
            break;
        case MPMovieFinishReasonUserExited:
            finishPlayBackName = @"MPMovieFinishReasonUserExited";
            NSLog(@"playbackFinished. Reason: User Exited");
            break;
        default:
            break;
    }
    
    [self triggerKPlayerEvents: finishPlayBackName withValue: nil];
    
    NSLog(@"triggerFinishPlabackEvents Exit");
}

- (void)triggerKPlayerEvents: (NSString *)notName withValue: (NSDictionary *)notValueDict {
    NSLog(@"triggerKPlayerEvents Enter");
    
    [[NSNotificationCenter defaultCenter] postNotificationName: notName object: nil userInfo: notValueDict];
    
    NSLog(@"triggerKPlayerEvents Exit");
}

- (void) onMovieDurationAvailable:(NSNotification *)notification {
    NSLog(@"onMovieDurationAvailable Enter");
    
//    [[NSNotificationCenter defaultCenter] removeObserver: self];
    
    NSLog(@"onMovieDurationAvailable Exit");
}

//KALPlayer *kp = [KALPlayer new];
//[kp setDelegate: self];



@end