#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="$1"
tool="${2:-}"

mapfile -t required_tools < "$ODEV_PATH/src/required_tools"

if [[ -z "$tool" ]]; then
  for t in "${required_tools[@]}"; do
    installed="$("$ODEV_PATH/src/which.sh" "$t")"
    if [[ "$installed" == "0" ]]; then
      echo "👎 $t"
    else
      echo "✅ $t"
    fi
  done
else
  installed="$("$ODEV_PATH/src/which.sh" "$tool")"
  echo "$installed"
fi