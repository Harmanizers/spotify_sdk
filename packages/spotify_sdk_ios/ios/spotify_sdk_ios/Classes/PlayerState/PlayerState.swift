import SpotifyiOS

struct State {
    static func playerStateDictionary(_ playerState: SPTAppRemotePlayerState) -> [String : Any] {
        let options: SPTAppRemotePlaybackOptions? = object(#selector(getter: SPTAppRemotePlayerState.playbackOptions), of: playerState)
        let restrictions: SPTAppRemotePlaybackRestrictions? = object(#selector(getter: SPTAppRemotePlayerState.playbackRestrictions), of: playerState)

        let playbackOptions: [String : Any] = [
            "shuffle" : options?.isShuffling ?? false,
            "repeat" : (options?.repeatMode ?? .off).rawValue
        ]

        let playbackRestrictions = [
            "can_skip_next" : restrictions?.canSkipNext ?? false,
            "can_skip_prev" : restrictions?.canSkipPrevious ?? false,
            "can_repeat_track" : restrictions?.canRepeatTrack ?? false,
            "can_repeat_context" : restrictions?.canRepeatContext ?? false,
            "can_toggle_shuffle" : restrictions?.canToggleShuffle ?? false,
            "can_seek" : restrictions?.canSeek ?? false
        ]

        var dictionary: [String : Any] = [
            "is_paused" : playerState.isPaused,
            "playback_speed" : playerState.playbackSpeed,
            "playback_position" : playerState.playbackPosition,
            "playback_options" : playbackOptions,
            "playback_restrictions" : playbackRestrictions
        ]
        if let track: SPTAppRemoteTrack = object(#selector(getter: SPTAppRemotePlayerState.track), of: playerState) {
            dictionary["track"] = trackDictionary(track)
        }
        return dictionary
    }

    private static func trackDictionary(_ track: SPTAppRemoteTrack) -> [String : Any] {
        let trackArtist: SPTAppRemoteArtist? = object(#selector(getter: SPTAppRemoteTrack.artist), of: track)
        let trackAlbum: SPTAppRemoteAlbum? = object(#selector(getter: SPTAppRemoteTrack.album), of: track)

        let artist = [
            "name" : trackArtist?.name ?? "",
            "uri" : trackArtist?.uri ?? ""
        ]

        let album = [
            "name" : trackAlbum?.name ?? "",
            "uri" : trackAlbum?.uri ?? ""
        ]

        let imageIdentifier = [
            "raw" : track.imageIdentifier
        ]

        return [
            "album" : album,
            "artist" : artist,
            "artists" : [artist],
            "duration_ms" : track.duration,
            "image_id" : imageIdentifier,
            "is_episode" : track.isEpisode,
            "is_podcast" : track.isPodcast,
            "name" : track.name,
            "uri" : track.uri
        ]
    }

    static func playerContextDictionary(_ playerState: SPTAppRemotePlayerState) -> [String : Any] {
        let contextURI: URL? = object(#selector(getter: SPTAppRemotePlayerState.contextURI), of: playerState)
        let uri = contextURI?.absoluteString ?? ""
        let uriParts = uri.components(separatedBy: ":")
        return [
            "title" : playerState.contextTitle,
            "subtitle" : playerState.contextTitle,
            "type" : uriParts.count > 1 ? uriParts[1] : "",
            "uri" : uri
        ]
    }

    /// The SDK headers declare every property nonnull, so Swift reads one with
    /// no nil check: a nil URL traps in the bridge, and a nil object is
    /// undefined behavior that crashes an unoptimized build. Reading through
    /// `perform(_:)` makes the nil visible. A nil NSString needs none of this;
    /// it bridges to "".
    private static func object<Value>(_ getter: Selector, of owner: NSObjectProtocol) -> Value? {
        return owner.perform(getter)?.takeUnretainedValue() as? Value
    }

    static func crossfadeStateDictionary(_ crossfadeState: SPTAppRemoteCrossfadeState) -> [String : Any] {
        return [
            "duration": crossfadeState.duration,
            "isEnabled": crossfadeState.isEnabled,
        ]
    }

    static func userCapabilitiesDictionary(_ userCapabilities: SPTAppRemoteUserCapabilities) -> [String : Any] {
        return [
            "can_play_on_demand": userCapabilities.canPlayOnDemand
        ]
    }
    
    static func libraryStateDictionary(_ libraryState: SPTAppRemoteLibraryState) -> [String : Any] {
        return [
            "uri": libraryState.uri,
            "saved": libraryState.isAdded,
            "can_save": libraryState.canAdd,
        ]
    }
}
