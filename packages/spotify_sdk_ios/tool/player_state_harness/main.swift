import Foundation
import SpotifyiOS

// A trap ends the process before stdout would flush.
setvbuf(stdout, nil, _IONBF, 0)

struct Expected {
    var contextType: String
    var contextURI: String
    var trackURI: String?
    var artistName: String = "Artist"
    var albumName: String = "Album"
    var imageIdentifier: String = "spotify:image:i"
    var canSeek: Bool = true
}

func fullTrack() -> FakeTrack {
    let artist = FakeArtist()
    artist.nameValue = "Artist"
    artist.uriValue = "spotify:artist:a"
    let album = FakeAlbum()
    album.nameValue = "Album"
    album.uriValue = "spotify:album:b"
    let track = FakeTrack()
    track.nameValue = "Song"
    track.uriValue = "spotify:track:t"
    track.artistValue = artist
    track.albumValue = album
    track.imageIdentifierValue = "spotify:image:i"
    track.durationValue = 1000
    return track
}

func state(contextURI: NSURL?, track: FakeTrack? = fullTrack()) -> FakePlayerState {
    let state = FakePlayerState()
    state.contextTitleValue = "Context"
    // KVC keeps the NSURL as is; a Swift assignment would round-trip it through URL.
    state.setValue(contextURI, forKey: "contextURIValue")
    state.trackValue = track
    state.optionsValue = FakeOptions()
    state.restrictionsValue = FakeRestrictions()
    return state
}

let playlist = "spotify:playlist:abc"

let cases: [String: (make: () -> FakePlayerState, expected: Expected)] = [
    "playlistURI": (
        { state(contextURI: NSURL(string: playlist)) },
        Expected(contextType: "playlist", contextURI: playlist, trackURI: "spotify:track:t")
    ),
    "noColonURI": (
        { state(contextURI: NSURL(string: "remote-session")) },
        Expected(contextType: "", contextURI: "remote-session", trackURI: "spotify:track:t")
    ),
    "emptyURI": (
        { state(contextURI: NSURL(string: "")) },
        Expected(contextType: "", contextURI: "", trackURI: "spotify:track:t")
    ),
    "nilURI": (
        { state(contextURI: nil) },
        Expected(contextType: "", contextURI: "", trackURI: "spotify:track:t")
    ),
    "trackMissingParts": (
        {
            let track = fullTrack()
            track.artistValue = nil
            track.albumValue = nil
            track.imageIdentifierValue = nil
            return state(contextURI: NSURL(string: playlist), track: track)
        },
        Expected(contextType: "playlist", contextURI: playlist, trackURI: "spotify:track:t",
                 artistName: "", albumName: "", imageIdentifier: "")
    ),
    "trackMissingStrings": (
        {
            let track = fullTrack()
            track.artistValue?.nameValue = nil
            track.albumValue?.nameValue = nil
            return state(contextURI: NSURL(string: playlist), track: track)
        },
        Expected(contextType: "playlist", contextURI: playlist, trackURI: "spotify:track:t",
                 artistName: "", albumName: "")
    ),
    "nilOptionsAndRestrictions": (
        {
            let s = state(contextURI: NSURL(string: playlist))
            s.optionsValue = nil
            s.restrictionsValue = nil
            return s
        },
        Expected(contextType: "playlist", contextURI: playlist, trackURI: "spotify:track:t", canSeek: false)
    ),
    "nilTrack": (
        { state(contextURI: NSURL(string: playlist), track: nil) },
        Expected(contextType: "playlist", contextURI: playlist, trackURI: nil)
    ),
]

if CommandLine.arguments.count < 2 {
    print(cases.keys.sorted().joined(separator: " "))
    exit(0)
}

let name = CommandLine.arguments[1]
guard let testCase = cases[name] else {
    print("unknown case \(name)")
    exit(2)
}

// Round-trip through the JSON the plugin actually sends, so a value that does
// not serialize fails here too.
func decoded(_ dictionary: [String : Any]) -> [String : Any] {
    let data = dictionary.json.data(using: .utf8) ?? Data()
    return (try? JSONSerialization.jsonObject(with: data)) as? [String : Any] ?? [:]
}

let playerState = testCase.make()
let stateJSON = decoded(State.playerStateDictionary(playerState))
let contextJSON = decoded(State.playerContextDictionary(playerState))
let track = stateJSON["track"] as? [String : Any]
let restrictions = stateJSON["playback_restrictions"] as? [String : Any]

let actual = Expected(
    contextType: contextJSON["type"] as? String ?? "<missing>",
    contextURI: contextJSON["uri"] as? String ?? "<missing>",
    trackURI: track?["uri"] as? String,
    artistName: track.map { ($0["artist"] as? [String : Any])?["name"] as? String ?? "<missing>" } ?? "Artist",
    albumName: track.map { ($0["album"] as? [String : Any])?["name"] as? String ?? "<missing>" } ?? "Album",
    imageIdentifier: track.map { ($0["image_id"] as? [String : Any])?["raw"] as? String ?? "<missing>" } ?? "spotify:image:i",
    canSeek: restrictions?["can_seek"] as? Bool ?? true
)

let expected = testCase.expected
var mismatches: [String] = []
if actual.contextType != expected.contextType { mismatches.append("context type \"\(actual.contextType)\", expected \"\(expected.contextType)\"") }
if actual.contextURI != expected.contextURI { mismatches.append("context uri \"\(actual.contextURI)\", expected \"\(expected.contextURI)\"") }
if actual.trackURI != expected.trackURI { mismatches.append("track uri \(String(describing: actual.trackURI)), expected \(String(describing: expected.trackURI))") }
if actual.artistName != expected.artistName { mismatches.append("artist \"\(actual.artistName)\", expected \"\(expected.artistName)\"") }
if actual.albumName != expected.albumName { mismatches.append("album \"\(actual.albumName)\", expected \"\(expected.albumName)\"") }
if actual.imageIdentifier != expected.imageIdentifier { mismatches.append("image \"\(actual.imageIdentifier)\", expected \"\(expected.imageIdentifier)\"") }
if actual.canSeek != expected.canSeek { mismatches.append("can_seek \(actual.canSeek), expected \(expected.canSeek)") }

if mismatches.isEmpty {
    print("context type=\"\(actual.contextType)\" uri=\"\(actual.contextURI)\" track=\(actual.trackURI ?? "none")")
    exit(0)
}
print(mismatches.joined(separator: "; "))
exit(1)
