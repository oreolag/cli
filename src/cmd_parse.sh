#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_parse.sh --params "${FLAGS[@]}" -- "$@"
# Output:
#   key=value   (one per line)

[[ "${1:-}" == "--params" ]] || exit 2
shift

PARAMS=()
while [[ "${1:-}" != "--" ]]; do
  PARAMS+=("$1")
  shift
done
shift # consume --

declare -A V
declare -A RANGE
declare -A DESC

# store range/desc for validation (no defaults)
for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short desc range def <<< "$p"
  RANGE["$name"]="$range"
  DESC["$name"]="$desc"
done

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

validate_value() {
  local name="$1"
  local value="$2"
  local range="${RANGE[$name]}"

  # empty range => accept anything
  [[ -z "$range" ]] && return 0

  # enum: a|b|c
  if [[ "$range" == *"|"* ]]; then
    local ok=0
    IFS='|' read -r -a choices <<< "$range"
    for c in "${choices[@]}"; do
      [[ "$value" == "$c" ]] && { ok=1; break; }
    done
    [[ "$ok" == "1" ]] && return 0
    echo "Invalid value for --$name: '$value' (allowed: $range)" >&2
    return 1
  fi

  # int range: N-M
  if [[ "$range" =~ ^[0-9]+-[0-9]+$ ]]; then
    local lo="${range%-*}"
    local hi="${range#*-}"
    if ! is_int "$value"; then
      echo "Invalid value for --$name: '$value' (expected integer in range: $range)" >&2
      return 1
    fi
    if (( value < lo || value > hi )); then
      echo "Invalid value for --$name: '$value' (expected range: $range)" >&2
      return 1
    fi
    return 0
  fi

  # unknown pattern => accept (or tighten later)
  return 0
}

# parse argv
while [[ $# -gt 0 ]]; do
  matched=false
  for p in "${PARAMS[@]}"; do
    IFS=',' read -r name short desc range def <<< "$p"
    if [[ "$1" == "--$name" || "$1" == "-$short" ]]; then
      val="${2:-}"
      validate_value "$name" "$val"
      V["$name"]="$val"
      shift 2
      matched=true
      break
    fi
  done

  [[ "$matched" == true ]] || { echo "Unknown option: $1" >&2; exit 1; }
done

# emit results (only provided flags)
for k in "${!V[@]}"; do
  echo "$k=${V[$k]}"
done