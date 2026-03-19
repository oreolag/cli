#!/usr/bin/env bash
set -euo pipefail

# usage:
#   get_num_gpu <MODEL> [NUMA]
#
# examples:
#   get_num_gpu GB10
#   get_num_gpu GB10 0

# get ODEV_PATH
ODEV_PATH="${ODEV_PATH:-$(dirname "$(dirname "$0")")}"

[[ $# -ge 1 && $# -le 2 ]] || {
  echo "Usage: $(basename "$0") <MODEL> [NUMA]"
  exit 1
}

model="$1"
numa="${2:-}"

# constants
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths tmp)")"

count_file() {
  local file="$1"
  [[ -f "$file" ]] || { echo 0; return; }

  awk -v model="$model" '$3 == model { c++ } END { print c+0 }' "$file"
}

# run examine silently
#$ODEV_PATH/cmd/examine.sh > /dev/null 2>&1
if ! compgen -G "$TMP_PATH/examine_*" > /dev/null; then
  "$ODEV_PATH/cmd/examine.sh" > /dev/null 2>&1
fi

# count
total=0
if [[ -n "$numa" ]]; then
  file="$TMP_PATH/examine_gpu_$numa"
  total="$(count_file "$file")"
else
  shopt -s nullglob
  for file in "$TMP_PATH"/examine_gpu_*; do
    n="$(count_file "$file")"
    total=$((total + n))
  done
fi

echo "$total"