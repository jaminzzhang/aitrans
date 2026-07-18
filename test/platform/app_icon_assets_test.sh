#!/bin/sh

set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)

assert_png_size() {
  file_path=$1
  expected_size=$2

  if [ ! -f "$root_dir/$file_path" ]; then
    echo "Missing app icon asset: $file_path" >&2
    exit 1
  fi

  width=$(sips -g pixelWidth "$root_dir/$file_path" 2>/dev/null | awk '/pixelWidth:/ { print $2 }')
  height=$(sips -g pixelHeight "$root_dir/$file_path" 2>/dev/null | awk '/pixelHeight:/ { print $2 }')

  if [ "$width" != "$expected_size" ] || [ "$height" != "$expected_size" ]; then
    echo "Expected $file_path to be ${expected_size}x${expected_size}, got ${width}x${height}." >&2
    exit 1
  fi
}

assert_no_alpha() {
  file_path=$1
  has_alpha=$(sips -g hasAlpha "$root_dir/$file_path" 2>/dev/null | awk '/hasAlpha:/ { print $2 }')

  if [ "$has_alpha" != "no" ]; then
    echo "Expected $file_path to be opaque for App Store submission." >&2
    exit 1
  fi
}

master_path="assets/branding/app-icon-master.png"
assert_png_size "$master_path" 1254

master_hash=$(shasum -a 256 "$root_dir/$master_path" | awk '{ print $1 }')
if [ "$master_hash" != "a73727d11d2f6f7cdcf58dcf9a5736cd206209e12e162621c119a264a7df9981" ]; then
  echo "The checked-in app icon master does not match the approved source image." >&2
  exit 1
fi

assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png" 20
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png" 40
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png" 60
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png" 29
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png" 58
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png" 87
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png" 40
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png" 80
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png" 120
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png" 120
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png" 180
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png" 76
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png" 152
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png" 167
assert_png_size "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png" 1024
assert_no_alpha "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"

for size in 16 32 64 128 256 512 1024; do
  assert_png_size "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_${size}.png" "$size"
done

assert_png_size "android/app/src/main/res/mipmap-mdpi/ic_launcher.png" 48
assert_png_size "android/app/src/main/res/mipmap-hdpi/ic_launcher.png" 72
assert_png_size "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png" 96
assert_png_size "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png" 144
assert_png_size "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png" 192

assert_png_size "assets/release/app-store-icon-1024.png" 1024
assert_no_alpha "assets/release/app-store-icon-1024.png"
assert_png_size "assets/release/google-play-icon-512.png" 512

echo "App icon assets are complete for macOS, iOS, Android, and store release."
