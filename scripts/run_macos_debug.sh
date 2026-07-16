#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
BUILT_APP_PATH="$PROJECT_ROOT/build/macos/Build/Products/Debug/aitrans.app"
INSTALL_DIRECTORY="$HOME/Applications"
APP_PATH="$INSTALL_DIRECTORY/AITrans Debug.app"
STAGING_APP_PATH="$INSTALL_DIRECTORY/.AITrans Debug.$$.app"
BUNDLE_ID="com.aitrans.aitrans"
SERVICE_MENU_ITEM="使用 AITrans 翻译"
LSREGISTER_PATH="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
PBS_PATH="/System/Library/CoreServices/pbs"

cd "$PROJECT_ROOT"

running_pids() {
  pgrep -x "aitrans" 2>/dev/null || true
}

if [[ -n "$(running_pids)" ]]; then
  osascript -e "tell application id \"$BUNDLE_ID\" to quit" >/dev/null 2>&1 || true

  for _ in {1..50}; do
    [[ -z "$(running_pids)" ]] && break
    sleep 0.1
  done

  if [[ -n "$(running_pids)" ]]; then
    print -u2 "AITrans is still running. Close it normally, then retry."
    exit 1
  fi
fi

flutter build macos --debug

mkdir -p "$INSTALL_DIRECTORY"
rm -rf "$STAGING_APP_PATH"
trap 'rm -rf "$STAGING_APP_PATH"' EXIT
ditto "$BUILT_APP_PATH" "$STAGING_APP_PATH"
rm -rf "$APP_PATH"
mv "$STAGING_APP_PATH" "$APP_PATH"
trap - EXIT

"$LSREGISTER_PATH" -f "$APP_PATH"
"$PBS_PATH" -update

registered_menu_item="$(
  /usr/libexec/PlistBuddy \
    -c "Print :NSServices:0:NSMenuItem:default" \
    "$APP_PATH/Contents/Info.plist"
)"
service_dump="$("$PBS_PATH" -dump)"
if [[ "$registered_menu_item" != "$SERVICE_MENU_ITEM" ]] ||
   [[ "$service_dump" != *"NSBundlePath = \"$APP_PATH\""* ]]; then
  print -u2 "AITrans macOS Service registration did not survive the Services database refresh."
  exit 1
fi

open "$APP_PATH"

for _ in {1..50}; do
  [[ -n "$(running_pids)" ]] && break
  sleep 0.1
done

pids=("${(@f)$(running_pids)}")
if (( ${#pids[@]} != 1 )); then
  print -u2 "Expected exactly one AITrans process, found ${#pids[@]}."
  exit 1
fi

sleep 2
if ! kill -0 "$pids[1]" 2>/dev/null; then
  print -u2 "AITrans exited during startup."
  exit 1
fi

print "AITrans debug build is running (PID $pids[1])."
