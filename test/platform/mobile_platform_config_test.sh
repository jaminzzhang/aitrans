#!/bin/sh

set -eu

project_root=$(CDPATH= cd -- "$(dirname -- "$0")/../.." && pwd)
android_manifest="$project_root/android/app/src/main/AndroidManifest.xml"
ios_info_plist="$project_root/ios/Runner/Info.plist"

assert_contains() {
  file=$1
  expected=$2
  description=$3
  if ! grep -Fq "$expected" "$file"; then
    echo "FAIL: $description"
    exit 1
  fi
}

assert_contains \
  "$android_manifest" \
  '<uses-permission android:name="android.permission.INTERNET"/>' \
  'Android main manifest must grant INTERNET to release builds.'

assert_contains \
  "$android_manifest" \
  'android:label="AITrans"' \
  'Android application label must use the AITrans product name.'

ios_display_name=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleDisplayName' "$ios_info_plist")
if [ "$ios_display_name" != 'AITrans' ]; then
  echo "FAIL: iOS CFBundleDisplayName must be AITrans."
  exit 1
fi

echo 'PASS: mobile platform configuration is complete.'
