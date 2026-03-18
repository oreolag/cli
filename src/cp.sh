#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 3 ]] || exit 1
ODEV_PATH="$1"
src="$2"
dst="$3"

# constants
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths tmp)")"

# Only allowed folders
ALLOWED_FOLDERS=(
  "$TMP_PATH"
  "$ODEV_PATH"
)

# normalize allowed folders
for i in "${!ALLOWED_FOLDERS[@]}"; do
  ALLOWED_FOLDERS[$i]="$(readlink -f -- "${ALLOWED_FOLDERS[$i]}")"
done

# normalize src
src="$(readlink -f -- "$src")" || exit 1

# normalize dst (only parent!)
dst_dir="$(dirname -- "$dst")"
dst_base="$(basename -- "$dst")"
dst_dir="$(readlink -f -- "$dst_dir")" || exit 1
dst="$dst_dir/$dst_base"

# check src exists (file, dir, or symlink)
[[ -e "$src" ]] || exit 1

# check src allowed
allowed_src=false
for a in "${ALLOWED_FOLDERS[@]}"; do
  [[ "$src" == "$a" || "$src" == "$a/"* ]] && allowed_src=true && break
done
$allowed_src || exit 1

# check dst allowed
allowed_dst=false
for a in "${ALLOWED_FOLDERS[@]}"; do
  [[ "$dst" == "$a" || "$dst" == "$a/"* ]] && allowed_dst=true && break
done
$allowed_dst || exit 1

# copy (file or directory)
if [[ -d "$src" ]]; then
  cp -a -- "$src" "$dst"
else
  cp -f -- "$src" "$dst"
fi