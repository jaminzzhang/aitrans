#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h:h}"
SCRIPT="$PROJECT_ROOT/scripts/migrate_macos_hive_to_application_support.sh"
TEMP_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEMP_ROOT"' EXIT

DOCUMENTS="$TEMP_ROOT/Documents"
APPLICATION_SUPPORT="$TEMP_ROOT/Application Support"
TARGET="$APPLICATION_SUPPORT/AITrans"
mkdir -p "$DOCUMENTS" "$APPLICATION_SUPPORT"

DEFAULT_HOME="$TEMP_ROOT/default-home"
mkdir -p "$DEFAULT_HOME/Documents"
DEFAULT_SANDBOX_SUPPORT="$DEFAULT_HOME/Library/Containers/com.aitrans.aitrans/Data/Library/Application Support/com.aitrans.aitrans"
mkdir -p "$DEFAULT_SANDBOX_SUPPORT"
print -n "sandbox-key" > "$DEFAULT_SANDBOX_SUPPORT/.aitrans.provider.key"
HOME="$DEFAULT_HOME" zsh "$SCRIPT"
[[ -d "$DEFAULT_HOME/Library/Application Support/com.aitrans.aitrans/AITrans" ]]
[[ -f "$DEFAULT_HOME/Library/Application Support/com.aitrans.aitrans/AITrans/.aitrans.provider.key" ]]
[[ ! -e "$DEFAULT_SANDBOX_SUPPORT/.aitrans.provider.key" ]]

for file in translation_cache.hive settings_preferences.hive provider_credentials.hive; do
  print -n "fixture-$file" > "$DOCUMENTS/$file"
done
print -n "fixture-key" > "$APPLICATION_SUPPORT/.aitrans.provider.key"
print -n "stale-lock" > "$DOCUMENTS/translation_cache.lock"

migration_output="$(
  zsh "$SCRIPT" \
    --documents-dir "$DOCUMENTS" \
    --application-support-dir "$APPLICATION_SUPPORT" 2>&1
)"
[[ "$migration_output" != *"read-only variable"* ]]
print "$migration_output"

for file in translation_cache.hive settings_preferences.hive provider_credentials.hive; do
  [[ -f "$TARGET/$file" ]]
  [[ ! -e "$DOCUMENTS/$file" ]]
done
[[ -f "$TARGET/.aitrans.provider.key" ]]
[[ ! -e "$APPLICATION_SUPPORT/.aitrans.provider.key" ]]
[[ -f "$DOCUMENTS/translation_cache.lock" ]]

CONFLICT_ROOT="$TEMP_ROOT/conflict"
CONFLICT_DOCUMENTS="$CONFLICT_ROOT/Documents"
CONFLICT_SUPPORT="$CONFLICT_ROOT/Application Support"
mkdir -p "$CONFLICT_DOCUMENTS" "$CONFLICT_SUPPORT/AITrans"
print -n "legacy" > "$CONFLICT_DOCUMENTS/translation_cache.hive"
print -n "existing" > "$CONFLICT_SUPPORT/AITrans/translation_cache.hive"

if zsh "$SCRIPT" \
  --documents-dir "$CONFLICT_DOCUMENTS" \
  --application-support-dir "$CONFLICT_SUPPORT"; then
  print -u2 "Expected migration conflict to fail."
  exit 1
fi

[[ "$(<"$CONFLICT_DOCUMENTS/translation_cache.hive")" == "legacy" ]]
[[ "$(<"$CONFLICT_SUPPORT/AITrans/translation_cache.hive")" == "existing" ]]

print "macOS Hive migration script tests passed."
