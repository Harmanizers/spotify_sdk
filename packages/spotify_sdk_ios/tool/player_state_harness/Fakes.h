#import <Foundation/Foundation.h>
#import <SpotifyiOS/SpotifyiOS.h>

// Stand-ins for what the Spotify app hands the SDK. Every backing value is
// nullable so a case can report what the nonnull headers say cannot happen.
NS_ASSUME_NONNULL_BEGIN

@interface FakeArtist : NSObject <SPTAppRemoteArtist>
@property (nonatomic, copy, nullable) NSString *nameValue;
@property (nonatomic, copy, nullable) NSString *uriValue;
@end

@interface FakeAlbum : NSObject <SPTAppRemoteAlbum>
@property (nonatomic, copy, nullable) NSString *nameValue;
@property (nonatomic, copy, nullable) NSString *uriValue;
@end

@interface FakeTrack : NSObject <SPTAppRemoteTrack>
@property (nonatomic, copy, nullable) NSString *nameValue;
@property (nonatomic, copy, nullable) NSString *uriValue;
@property (nonatomic, strong, nullable) FakeArtist *artistValue;
@property (nonatomic, strong, nullable) FakeAlbum *albumValue;
@property (nonatomic, copy, nullable) NSString *imageIdentifierValue;
@property (nonatomic) NSUInteger durationValue;
@end

@interface FakeOptions : NSObject <SPTAppRemotePlaybackOptions>
@end

@interface FakeRestrictions : NSObject <SPTAppRemotePlaybackRestrictions>
@end

@interface FakePlayerState : NSObject <SPTAppRemotePlayerState>
@property (nonatomic, strong, nullable) FakeTrack *trackValue;
@property (nonatomic, copy, nullable) NSString *contextTitleValue;
@property (nonatomic, strong, nullable) NSURL *contextURIValue;
@property (nonatomic, strong, nullable) FakeOptions *optionsValue;
@property (nonatomic, strong, nullable) FakeRestrictions *restrictionsValue;
@end

NS_ASSUME_NONNULL_END
