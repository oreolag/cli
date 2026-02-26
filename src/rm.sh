#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 1
ODEV_PATH="$1"
target="$2"

target="$(readlink -f -- "$target")" || exit 1
[[ -e "$target" ]] || exit 1
[[ -f "$target" ]] || exit 1

# constants
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths tmp)")"

# Only files in allowed folders can be removed
ALLOWED_FOLDERS=(
  "$TMP_PATH"
)

# normalize allowed folders
for i in "${!ALLOWED_FOLDERS[@]}"; do
  ALLOWED_FOLDERS[$i]="$(readlink -f -- "${ALLOWED_FOLDERS[$i]}")"
done

# get first root component ("/tmp" from "/tmp/foo/bar" or "/tmp")
root="/$(cut -d/ -f2 <<< "$target")"
root="$(readlink -f -- "$root" 2>/dev/null || true)"

allowed=false
for a in "${ALLOWED_FOLDERS[@]}"; do
  [[ "$root" == "$a" ]] && allowed=true && break
done

$allowed || exit 1

rm -f -- "$target"