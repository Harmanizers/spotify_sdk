#!/bin/bash
# Runs the iOS player-state serializer (Classes/PlayerState/PlayerState.swift)
# against player states the Spotify app can send but the SDK headers say it
# cannot: a context URI that is nil, empty or has no colon, and a nil track,
# artist, album, image id, playback options or restrictions.
#
# The plugin has no Swift test target, and the serializer imports Flutter only
# through its callers, so this compiles PlayerState.swift and Dictionary.swift
# on their own against the vendored SpotifyiOS headers, with Objective-C fakes
# for the objects the Spotify app hands over. Each case runs in its own
# process on a booted iOS simulator, since a trap ends the process, and is
# built twice: -Onone (what a debug app compiles the plugin with) and -O.
#
# Usage: run.sh            (uses the first booted iPhone simulator)
#        DEVICE=<udid> run.sh
# Exits non-zero when any case crashes or emits an unexpected payload.
set -u
HERE=$(cd "$(dirname "$0")" && pwd)
IOS=$HERE/../../ios/spotify_sdk_ios
CLASSES=$IOS/Classes
FWDIR=$IOS/ios-sdk/SpotifyiOS.xcframework/ios-arm64_x86_64-simulator
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path)
TARGET=$(uname -m)-apple-ios15.0-simulator
OUT=$(mktemp -d)
trap 'rm -rf "$OUT"' EXIT

DEVICE=${DEVICE:-$(xcrun simctl list devices booted | grep -m1 -o 'iPhone[^(]*([0-9A-F-]*)' | grep -o '[0-9A-F-]\{36\}')}
if [ -z "$DEVICE" ]; then
  echo "No booted iPhone simulator. Boot one (xcrun simctl boot <udid>) or pass DEVICE=<udid>." >&2
  exit 2
fi

xcrun --sdk iphonesimulator clang -fobjc-arc -target "$TARGET" -isysroot "$SDK" -F "$FWDIR" \
  -c "$HERE/Fakes.m" -o "$OUT/Fakes.o" || exit 2

failed=0
for opt in -Onone -O; do
  xcrun --sdk iphonesimulator swiftc $opt -target "$TARGET" -sdk "$SDK" -F "$FWDIR" \
    -import-objc-header "$HERE/Fakes.h" \
    "$HERE/main.swift" "$CLASSES/PlayerState/PlayerState.swift" "$CLASSES/Extension/Dictionary.swift" \
    "$OUT/Fakes.o" -framework SpotifyiOS -Xlinker -rpath -Xlinker "$FWDIR" \
    -o "$OUT/harness$opt" || exit 2
  for name in $(xcrun simctl spawn "$DEVICE" "$OUT/harness$opt"); do
    output=$(xcrun simctl spawn "$DEVICE" "$OUT/harness$opt" "$name" 2>&1)
    code=$?
    if [ $code -eq 0 ]; then
      echo "ok   $opt $name: $output"
    else
      failed=1
      echo "FAIL $opt $name (exit $code): $(echo "$output" | tr '\n' ' ')"
    fi
  done
done
exit $failed
