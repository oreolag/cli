#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_prompt.sh --required "name type" --params "${FLAGS[@]}" -- "$parsed_flags"
# Output:
#   key=value   (one per line)  (updated)

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

# Read existing parsed flags (passed as ONE multi-line argument)
declare -A V RANGE DESC DEF RAWDEF
while IFS= read -r line || [[ -n "$line" ]]; do
  [[ "$line" == *=* ]] || continue
  k="${line%%=*}"; v="${line#*=}"
  V["$k"]="$v"
done < <(printf '%s\n' "${1:-}")

# Build meta from PARAMS
for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short desc range def <<< "$p"
  RANGE["$name"]="$range"
  DESC["$name"]="$desc"
  RAWDEF["$name"]="$def"
  # Treat "-" as "no default" for prompting purposes
  if [[ "$def" == "-" ]]; then
    DEF["$name"]=""
  else
    DEF["$name"]="$def"
  fi
done

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

validate_value() {
  local name="$1" value="$2" range="${RANGE[$name]:-}"

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

  return 0
}

# Prompt via /dev/tty so this works even inside $(...)
if [[ ! -r /dev/tty || ! -w /dev/tty ]]; then
  echo "cmd_prompt: not interactive" >&2
  exit 1
fi

read -r -a REQUIRED <<< "$required_csv"
for name in "${REQUIRED[@]}"; do
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"

  # Treat "name=-" (from cmd_parse default) as missing if RAW default was "-"
  while true; do
    cur="${V[$name]:-}"
    if [[ -n "$cur" ]]; then
      if [[ "$cur" != "-" ]]; then
        break
      fi
      # cur == "-" : only consider missing if RAWDEF was "-" (meaning "no default")
      if [[ "${RAWDEF[$name]:-}" != "-" ]]; then
        break
      fi
    fi

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

    printf '%s' "$prompt" > /dev/tty
    read -r input < /dev/tty

    [[ -z "$input" && -n "$def" ]] && input="$def"
    [[ -z "$input" ]] && continue

    validate_value "$name" "$input" || continue
    V["$name"]="$input"
    break
  done
done

for k in "${!V[@]}"; do
  echo "$k=${V[$k]}"
done