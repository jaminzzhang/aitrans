#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
APP_PATH="$PROJECT_ROOT/build/macos/Build/Products/Debug/aitrans.app"
EXECUTABLE_PATH="$APP_PATH/Contents/MacOS/aitrans"
BUNDLE_ID="com.aitrans.aitrans"

cd "$PROJECT_ROOT"

running_pids() {
  pgrep -f "$EXECUTABLE_PATH" 2>/dev/null || true
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
