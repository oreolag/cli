#!/usr/bin/env bash
set -euo pipefail

# fixed install location (must match sudoers path)
ODEV_PATH="/opt/odev"

[[ $# -eq 1 ]] || exit 1
target="$1"

# constants (trusted file only)
TMP_PATH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths tmp)"

# allowed directories
ALLOWED_DIRS=(
  "$TMP_PATH"
)

target="$(readlink -f -- "$target")" || exit 1
[[ -e "$target" ]] || exit 1
[[ -f "$target" ]] || exit 1

allowed=false
for d in "${ALLOWED_DIRS[@]}"; do
  case "$target" in
    "$d"/*) allowed=true; break ;;
  esac
done

$allowed || exit 1

rm -f -- "$target"