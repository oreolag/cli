#!/usr/bin/env bash
set -euo pipefail

CLI_NAME="$1"
COMMAND="$2"
WORKFLOW="$3"
COMMAND_DESCRIPTION="$4"
print_range="$5"
print_default="$6"
print_both="$7"
shift 7

PARAMS=("$@")

bold=$(tput bold 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

echo "$COMMAND_DESCRIPTION"
echo ""
echo "${bold}USAGE:${normal}"
echo "  ${CLI_NAME} ${COMMAND} ${WORKFLOW} [flags]"
echo ""
echo "${bold}FLAGS:${normal}"

for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short desc range def <<< "$p"

  suffix=""
  if [[ "$print_both" == "1" ]]; then
    if [[ -n "$range" && -n "$def" ]]; then
      suffix=" (range: $range, default: $def)"
    elif [[ -n "$range" ]]; then
      suffix=" (range: $range)"
    elif [[ -n "$def" ]]; then
      suffix=" (default: $def)"
    fi
  else
    if [[ "$print_range" == "1" && -n "$range" ]]; then
      suffix+=" (range: $range)"
    fi
    if [[ "$print_default" == "1" && -n "$def" ]]; then
      if [[ -n "$suffix" ]]; then
        suffix="${suffix%)}"
        suffix+=", default: $def)"
      else
        suffix=" (default: $def)"
      fi
    fi
  fi

  printf "  -%-1s, --%-10s %s%s\n" \
    "$short" "$name" "$desc" "$suffix"
done

echo ""
echo "${bold}INHERITED FLAGS:${normal}"
echo "  -h, --help      Show this help"
