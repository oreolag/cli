#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_check.sh --required "name,ngpus" --params "${FLAGS[@]}" -- "$@"
#
# - Missing required flag => "Missing required flag: --name"
# - Present but empty/missing value => "Invalid value for --name"

[[ "${1:-}" == "--required" ]] || exit 2
required_csv="${2:-}"; shift 2

[[ "${1:-}" == "--params" ]] || exit 2
shift

PARAMS=()
while [[ "${1:-}" != "--" ]]; do
  PARAMS+=("$1")
  shift
done
shift # consume --

ARGV=( "$@" )

declare -A SHORT RANGE
for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short desc range def <<< "$p"
  SHORT["$name"]="$short"
  RANGE["$name"]="$range"
done

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

validate_value() {
  local name="$1" value="$2" range="${RANGE[$name]:-}"

  # required => must be non-empty
  [[ -n "$value" ]] || return 1

  # empty range => accept anything non-empty
  [[ -z "$range" ]] && return 0

  # enum: a|b|c
  if [[ "$range" == *"|"* ]]; then
    IFS='|' read -r -a choices <<< "$range"
    for c in "${choices[@]}"; do
      [[ "$value" == "$c" ]] && return 0
    done
    return 1
  fi

  # int range: N-M
  if [[ "$range" =~ ^[0-9]+-[0-9]+$ ]]; then
    local lo="${range%-*}" hi="${range#*-}"
    is_int "$value" || return 1
    (( value >= lo && value <= hi )) || return 1
    return 0
  fi

  return 0
}

find_value() {
  local name="$1"
  local short="${SHORT[$name]:-}"
  local i=0

  while [[ $i -lt ${#ARGV[@]} ]]; do
    local a="${ARGV[$i]}"
    if [[ "$a" == "--$name" || ( -n "$short" && "$a" == "-$short" ) ]]; then
      # flag present
      local v="${ARGV[$((i+1))]:-}"

      # missing value (end of argv) OR next token is another option
      if [[ -z "$v" || "$v" == --* || ( -n "$short" && "$v" == -* ) ]]; then
        echo "__EMPTY__"
        return 0
      fi

      echo "$v"
      return 0
    fi
    ((i++))
  done

  echo "__MISSING__"
}

IFS=',' read -r -a REQUIRED <<< "$required_csv"

for name in "${REQUIRED[@]}"; do
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"

  val="$(find_value "$name")"

  if [[ "$val" == "__MISSING__" ]]; then
    echo "Missing required flag: --$name" >&2
    exit 1
  fi

  if [[ "$val" == "__EMPTY__" ]] || ! validate_value "$name" "$val"; then
    echo "Invalid value for --$name" >&2
    exit 1
  fi
done