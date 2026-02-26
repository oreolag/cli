#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 1
ODEV_PATH="$1"
target="$2"

target="$(readlink -f -- "$target")" || exit 1
[[ -e "$target" ]] || exit 1
[[ -f "$target" ]] || exit 1

ALLOWED_FOLDERS=(
  "/tmp"
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