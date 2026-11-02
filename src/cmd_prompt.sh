#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_prompt.sh --required "name,type" --params "${FLAGS[@]}" -- "$parsed_flags"
# Optional: --field NAME asks only for NAME; --field "" only fills optional defaults.
# Output:
#   key=value   (one per line)  (updated)

[[ "${1:-}" == "--required" ]] || exit 2
required_csv="${2:-}"; shift 2

prompt_required="$required_csv"
if [[ "${1:-}" == "--field" ]]; then
  prompt_required="$2"
  shift 2
fi

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

# NEW: build set of mandatory flags (from --required "a,b,c")
declare -A MANDATORY
IFS=',' read -r -a __REQ <<< "$required_csv"
for m in "${__REQ[@]}"; do
  m="${m#"${m%%[![:space:]]*}"}"
  m="${m%"${m##*[![:space:]]}"}"
  [[ -n "$m" ]] && MANDATORY["$m"]=1
done

# NEW: ensure all NON-mandatory flags exist in V with their default (including "-" or "1")
for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short desc range def <<< "$p"
  if [[ -z "${MANDATORY[$name]+x}" ]]; then
    if [[ -z "${V[$name]+x}" ]]; then
      V["$name"]="$def"
    fi
  fi
done

is_int() { [[ "$1" =~ ^[0-9]+$ ]]; }

validate_value() {
  local name="$1" value="$2" range="${RANGE[$name]:-}"

  # empty range => accept anything
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
    local lo="${range%-*}"
    local hi="${range#*-}"
    is_int "$value" || return 1
    (( value >= lo && value <= hi )) || return 1
    return 0
  fi

  return 0
}

IFS=',' read -r -a REQUIRED <<< "$prompt_required"
for name in "${REQUIRED[@]}"; do
  name="${name#"${name%%[![:space:]]*}"}"
  name="${name%"${name##*[![:space:]]}"}"

  [[ -n "$name" ]] || continue

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
    if [[ -n "$range" && "$range" != "-" ]]; then
      prompt+=" ($range)"
    fi
    if [[ -n "$def" && "$def" != "-" ]]; then
      prompt+=" [$def]"
    fi
    prompt+=": "

    # Require a terminal only when a question is needed.
    if ! { exec 3<>/dev/tty; } 2>/dev/null; then
      echo "cmd_prompt: missing required --$name (not interactive)" >&2
      exit 1
    fi
    printf '%s' "$prompt" >&3
    read -r input <&3 || exit 1

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
