#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 1
ODEV_PATH="$1"
target="$2"

# constants
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths tmp)")"

# Only files in allowed folders can be removed
ALLOWED_FOLDERS=(
  "$TMP_PATH"
  "$ODEV_PATH"
)

# normalize allowed folders
for i in "${!ALLOWED_FOLDERS[@]}"; do
  ALLOWED_FOLDERS[$i]="$(readlink -f -- "${ALLOWED_FOLDERS[$i]}")"
done

# normalize only the parent directory, NOT the target itself
target_dir="$(dirname -- "$target")"
target_base="$(basename -- "$target")"
target_dir="$(readlink -f -- "$target_dir")" || exit 1
target="$target_dir/$target_base"

# allow regular files OR symlinks
[[ -f "$target" || -L "$target" ]] || exit 1

allowed=false
for a in "${ALLOWED_FOLDERS[@]}"; do
  [[ "$target" == "$a" || "$target" == "$a/"* ]] && allowed=true && break
done

$allowed || exit 1

rm -f -- "$target"