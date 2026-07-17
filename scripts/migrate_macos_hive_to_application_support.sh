#!/bin/zsh

set -euo pipefail

DOCUMENTS_DIRECTORY="$HOME/Documents"
APPLICATION_SUPPORT_DIRECTORY="$HOME/Library/Application Support/com.aitrans.aitrans"
USES_DEFAULT_DIRECTORIES=true

usage() {
  print "Usage: $0 [--documents-dir PATH --application-support-dir PATH]"
}

while (( $# > 0 )); do
  case "$1" in
    --documents-dir)
      (( $# >= 2 )) || { usage >&2; exit 2; }
      DOCUMENTS_DIRECTORY="$2"
      USES_DEFAULT_DIRECTORIES=false
      shift 2
      ;;
    --application-support-dir)
      (( $# >= 2 )) || { usage >&2; exit 2; }
      APPLICATION_SUPPORT_DIRECTORY="$2"
      USES_DEFAULT_DIRECTORIES=false
      shift 2
      ;;
    --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

if [[ "$USES_DEFAULT_DIRECTORIES" == true ]] && pgrep -x aitrans >/dev/null 2>&1; then
  print -u2 "AITrans is running. Quit it normally before migrating local data."
  exit 1
fi

TARGET_DIRECTORY="$APPLICATION_SUPPORT_DIRECTORY/AITrans"
KEY_SOURCE="$APPLICATION_SUPPORT_DIRECTORY/.aitrans.provider.key"
if [[ "$USES_DEFAULT_DIRECTORIES" == true ]]; then
  SANDBOX_KEY_SOURCE="$HOME/Library/Containers/com.aitrans.aitrans/Data/Library/Application Support/com.aitrans.aitrans/.aitrans.provider.key"
  if [[ -e "$KEY_SOURCE" && -e "$SANDBOX_KEY_SOURCE" ]]; then
    print -u2 "Migration stopped: multiple legacy master keys exist."
    exit 1
  fi
  if [[ ! -e "$KEY_SOURCE" && -e "$SANDBOX_KEY_SOURCE" ]]; then
    KEY_SOURCE="$SANDBOX_KEY_SOURCE"
  fi
fi
typeset -a SOURCES DESTINATIONS MOVED_SOURCES MOVED_DESTINATIONS
SOURCES=(
  "$DOCUMENTS_DIRECTORY/translation_cache.hive"
  "$DOCUMENTS_DIRECTORY/settings_preferences.hive"
  "$DOCUMENTS_DIRECTORY/provider_credentials.hive"
  "$KEY_SOURCE"
)
DESTINATIONS=(
  "$TARGET_DIRECTORY/translation_cache.hive"
  "$TARGET_DIRECTORY/settings_preferences.hive"
  "$TARGET_DIRECTORY/provider_credentials.hive"
  "$TARGET_DIRECTORY/.aitrans.provider.key"
)

for index in {1..${#SOURCES[@]}}; do
  if [[ -e "${SOURCES[$index]}" && -e "${DESTINATIONS[$index]}" ]]; then
    print -u2 "Migration stopped: target already exists: ${DESTINATIONS[$index]:t}"
    exit 1
  fi
done

rollback() {
  for (( index = ${#MOVED_SOURCES[@]}; index >= 1; index-- )); do
    if [[ -e "${MOVED_DESTINATIONS[$index]}" && ! -e "${MOVED_SOURCES[$index]}" ]]; then
      mv "${MOVED_DESTINATIONS[$index]}" "${MOVED_SOURCES[$index]}" || true
    fi
  done
}

MIGRATION_COMPLETE=false
on_exit() {
  local exit_code=$?
  trap - EXIT
  if [[ "$MIGRATION_COMPLETE" != true ]]; then
    rollback
  fi
  exit "$exit_code"
}
trap on_exit EXIT

mkdir -p "$TARGET_DIRECTORY"
chmod 700 "$TARGET_DIRECTORY"

for index in {1..${#SOURCES[@]}}; do
  source_path="${SOURCES[$index]}"
  destination_path="${DESTINATIONS[$index]}"
  [[ -e "$source_path" ]] || continue
  mv "$source_path" "$destination_path"
  MOVED_SOURCES+=("$source_path")
  MOVED_DESTINATIONS+=("$destination_path")
  chmod 600 "$destination_path"
  print "Migrated ${destination_path:t}"
done

MIGRATION_COMPLETE=true
print "AITrans local data migration completed."
