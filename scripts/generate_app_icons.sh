#!/bin/sh

set -eu

root_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
master_path="$root_dir/assets/branding/app-icon-master.png"
source_path=${1:-$master_path}

if [ ! -f "$source_path" ]; then
  echo "App icon source not found: $source_path" >&2
  exit 1
fi

source_width=$(sips -g pixelWidth "$source_path" 2>/dev/null | awk '/pixelWidth:/ { print $2 }')
source_height=$(sips -g pixelHeight "$source_path" 2>/dev/null | awk '/pixelHeight:/ { print $2 }')

if [ "$source_width" != "$source_height" ] || [ "$source_width" -lt 1024 ]; then
  echo "App icon source must be a square PNG of at least 1024x1024 pixels." >&2
  exit 1
fi

mkdir -p "$root_dir/assets/branding" "$root_dir/assets/release"

if [ "$source_path" != "$master_path" ]; then
  cp "$source_path" "$master_path"
fi

resize_icon() {
  size=$1
  destination=$2
  sips -z "$size" "$size" "$master_path" --out "$root_dir/$destination" >/dev/null
}

resize_icon 20 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@1x.png"
resize_icon 40 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@2x.png"
resize_icon 60 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-20x20@3x.png"
resize_icon 29 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@1x.png"
resize_icon 58 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@2x.png"
resize_icon 87 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-29x29@3x.png"
resize_icon 40 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@1x.png"
resize_icon 80 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@2x.png"
resize_icon 120 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-40x40@3x.png"
resize_icon 120 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@2x.png"
resize_icon 180 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-60x60@3x.png"
resize_icon 76 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@1x.png"
resize_icon 152 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-76x76@2x.png"
resize_icon 167 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-83.5x83.5@2x.png"
resize_icon 1024 "ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png"

for size in 16 32 64 128 256 512 1024; do
  resize_icon "$size" "macos/Runner/Assets.xcassets/AppIcon.appiconset/app_icon_${size}.png"
done

resize_icon 48 "android/app/src/main/res/mipmap-mdpi/ic_launcher.png"
resize_icon 72 "android/app/src/main/res/mipmap-hdpi/ic_launcher.png"
resize_icon 96 "android/app/src/main/res/mipmap-xhdpi/ic_launcher.png"
resize_icon 144 "android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png"
resize_icon 192 "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"

resize_icon 1024 "assets/release/app-store-icon-1024.png"
resize_icon 512 "assets/release/google-play-icon-512.png"

echo "Generated macOS, iOS, Android, and store release icons from $master_path"
