#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_prompt.sh --required "name,ngpus" --params "${FLAGS[@]}" -- "$parsed_flags"
# Output:
#   key=value (one per line)  (updated)

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

# read existing parsed flags
declare -A V RANGE DESC DEF
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == *=* ]] || continue
  k="${line%%=*}"; v="${line#*=}"
  V["$k"]="$v"
done < <(printf '%s\n' "${1:-}")

# build meta from PARAMS
for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short desc range def <<< "$p"
  RANGE["$name"]="$range"
  DESC["$name"]="$desc"
  DEF["$name"]="$def"
done

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

validate_value() {
  local name="$1" value="$2" range="${RANGE[$name]:-}"
  [[ -z "$range" ]] && return 0
  if [[ "$range" == *"|"* ]]; then
    IFS='|' read -r -a choices <<< "$range"
    for c in "${choices[@]}"; do [[ "$value" == "$c" ]] && return 0; done
    echo "Invalid value for --$name: '$value' (allowed: $range)" >&2
    return 1
  fi
  if [[ "$range" =~ ^[0-9]+-[0-9]+$ ]]; then
    local lo="${range%-*}" hi="${range#*-}"
    is_int "$value" || { echo "Invalid value for --$name: '$value' (expected integer in range: $range)" >&2; return 1; }
    (( value >= lo && value <= hi )) || { echo "Invalid value for --$name: '$value' (expected range: $range)" >&2; return 1; }
    return 0
  fi
  return 0
}

# only prompt if interactive
if ! [[ -t 0 && -t 1 ]]; then
  echo "cmd_prompt: not interactive" >&2
  exit 1
fi

IFS=',' read -r -a REQUIRED <<< "$required_csv"
for name in "${REQUIRED[@]}"; do
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"

  while [[ -z "${V[$name]:-}" ]]; do
    range="${RANGE[$name]:-}"
    def="${DEF[$name]:-}"
    prompt="$name"
    if [[ -n "$range" || -n "$def" ]]; then
      prompt+=" ("
      [[ -n "$range" ]] && prompt+="$range"
      [[ -n "$range" && -n "$def" ]] && prompt+=", "
      [[ -n "$def" ]] && prompt+="default $def"
      prompt+=")"
    fi
    prompt+=": "

    read -r -p "$prompt" input
    [[ -z "$input" && -n "$def" ]] && input="$def"
    [[ -z "$input" ]] && continue
    validate_value "$name" "$input" || { V["$name"]=""; continue; }
    V["$name"]="$input"
  done
done

for k in "${!V[@]}"; do
  echo "$k=${V[$k]}"
done