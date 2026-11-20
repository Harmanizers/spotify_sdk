#import "Fakes.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnullable-to-nonnull-conversion"

@implementation FakeArtist
- (NSString *)name { return self.nameValue; }
- (NSString *)URI { return self.uriValue; }
@end

@implementation FakeAlbum
- (NSString *)name { return self.nameValue; }
- (NSString *)URI { return self.uriValue; }
@end

@implementation FakeTrack
- (NSString *)name { return self.nameValue; }
- (NSString *)URI { return self.uriValue; }
- (NSUInteger)duration { return self.durationValue; }
- (id<SPTAppRemoteArtist>)artist { return self.artistValue; }
- (id<SPTAppRemoteAlbum>)album { return self.albumValue; }
- (NSString *)imageIdentifier { return self.imageIdentifierValue; }
- (BOOL)isSaved { return NO; }
- (BOOL)isEpisode { return NO; }
- (BOOL)isPodcast { return NO; }
- (BOOL)isAdvertisement { return NO; }
@end

@implementation FakeOptions
- (BOOL)isShuffling { return NO; }
- (SPTAppRemotePlaybackOptionsRepeatMode)repeatMode { return SPTAppRemotePlaybackOptionsRepeatModeOff; }
@end

@implementation FakeRestrictions
- (BOOL)canSkipNext { return YES; }
- (BOOL)canSkipPrevious { return YES; }
- (BOOL)canRepeatTrack { return YES; }
- (BOOL)canRepeatContext { return YES; }
- (BOOL)canToggleShuffle { return YES; }
- (BOOL)canSeek { return YES; }
@end

@implementation FakePlayerState
- (id<SPTAppRemoteTrack>)track { return self.trackValue; }
- (NSInteger)playbackPosition { return 0; }
- (float)playbackSpeed { return 1; }
- (BOOL)isPaused { return NO; }
- (id<SPTAppRemotePlaybackRestrictions>)playbackRestrictions { return self.restrictionsValue; }
- (id<SPTAppRemotePlaybackOptions>)playbackOptions { return self.optionsValue; }
- (NSString *)contextTitle { return self.contextTitleValue; }
- (NSURL *)contextURI { return self.contextURIValue; }
@end

#pragma clang diagnostic pop
