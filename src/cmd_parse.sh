#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   parse_cmd.sh --params "${PARAMS[@]}" -- "$@"
#
# Output:
#   key=value   (one per line)

[[ "$1" == "--params" ]] || exit 2
shift

PARAMS=()
while [[ "$1" != "--" ]]; do
  PARAMS+=("$1")
  shift
done
shift

declare -A V

# init defaults
for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short desc range def <<< "$p"
  V["$name"]="$def"
done

# parse argv
while [[ $# -gt 0 ]]; do
  matched=false
  for p in "${PARAMS[@]}"; do
    IFS=',' read -r name short desc range def <<< "$p"
    if [[ "$1" == "--$name" || "$1" == "-$short" ]]; then
      V["$name"]="${2:-}"
      shift 2
      matched=true
      break
    fi
  done
  [[ "$matched" == true ]] || { echo "Unknown option: $1" >&2; exit 1; }
done

# emit results
for k in "${!V[@]}"; do
  echo "$k=${V[$k]}"
done
