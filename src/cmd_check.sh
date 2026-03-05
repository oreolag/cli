#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_check.sh --required "name,others" --params "${FLAGS[@]}" -- "$@"

[[ "${1:-}" == "--required" ]] || exit 2
required_csv="${2:-}"
shift 2

[[ "${1:-}" == "--params" ]] || exit 2
shift

PARAMS=()
while [[ "${1:-}" != "--" ]]; do
  PARAMS+=("$1")
  shift
done
shift # consume --

ARGV=( "$@" )

declare -A SHORT
declare -A RANGE

# store metadata from PARAMS
for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short desc range def <<< "$p"
  SHORT["$name"]="$short"
  RANGE["$name"]="$range"
done

# ------------------------------------------------------------
# Reject unknown options (same logic spirit as cmd_parse.sh)
# ------------------------------------------------------------

declare -A KNOWN_LONG
declare -A KNOWN_SHORT

for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short desc range def <<< "$p"
  KNOWN_LONG["$name"]=1
  [[ -n "$short" ]] && KNOWN_SHORT["$short"]=1
done

i=0
while [[ $i -lt ${#ARGV[@]} ]]; do
  arg="${ARGV[$i]}"

  if [[ "$arg" == --* ]]; then
    name="${arg#--}"
    if [[ -z "${KNOWN_LONG[$name]+x}" ]]; then
      echo "Unknown option: $arg" >&2
      exit 1
    fi
    ((i+=2))
    continue
  fi

  if [[ "$arg" == -* && "$arg" != "-" ]]; then
    short="${arg#-}"
    if [[ -z "${KNOWN_SHORT[$short]+x}" ]]; then
      echo "Unknown option: $arg" >&2
      exit 1
    fi
    ((i+=2))
    continue
  fi

  ((i++))
done

# ------------------------------------------------------------
# Validate required flags
# ------------------------------------------------------------

find_value() {
  local name="$1"
  local short="${SHORT[$name]:-}"

  local i=0
  while [[ $i -lt ${#ARGV[@]} ]]; do
    local a="${ARGV[$i]}"

    if [[ "$a" == "--$name" || ( -n "$short" && "$a" == "-$short" ) ]]; then
      local val="${ARGV[$((i+1))]:-}"

      if [[ -z "$val" || "$val" == --* || "$val" == -* ]]; then
        echo "__EMPTY__"
        return
      fi

      echo "$val"
      return
    fi

    ((i++))
  done

  echo "__MISSING__"
}

read -r -a REQUIRED <<< "$required_csv"

for name in "${REQUIRED[@]}"; do
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"

  val="$(find_value "$name")"

  if [[ "$val" == "__MISSING__" ]]; then
    echo "Missing required flag: --$name" >&2
    exit 1
  fi

  if [[ "$val" == "__EMPTY__" ]]; then
    echo "Invalid value for --$name" >&2
    exit 1
  fi
done