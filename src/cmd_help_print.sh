#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_help_print.sh --maybe <CLI_NAME> <WORKFLOW> <COMMAND> <DESCRIPTION> \
#                     <print_range> <print_default> <print_both> \
#                     <param1> <param2> ... -- <argv...>
#     Output:
#       prints help and exits 0 if -h|--help is found in <argv...>
#       exits 2 if no help flag is found
#
#   cmd_help_print.sh <CLI_NAME> <WORKFLOW> <COMMAND> <DESCRIPTION> \
#                     <print_range> <print_default> <print_both> \
#                     <param1> <param2> ...
#     Output:
#       always prints help and exits 0

# ---------------------------------------
# Mode handling
# ---------------------------------------
mode="--print"
if [[ "${1:-}" == "--maybe" || "${1:-}" == "--print" ]]; then
  mode="$1"
  shift
fi

# ---------------------------------------
# Fixed arguments
# ---------------------------------------
CLI_NAME="$1"
#COMMAND="$2"
#WORKFLOW="$3"
WORKFLOW="$2"
COMMAND="$3"
COMMAND_DESCRIPTION="$4"
print_range="$5"
print_default="$6"
print_both="$7"
shift 7

# ---------------------------------------
# Read PARAMS until --
# ---------------------------------------
PARAMS=()
while [[ $# -gt 0 && "$1" != "--" ]]; do
  PARAMS+=("$1")
  shift
done

# Consume "--" if present
if [[ "${1:-}" == "--" ]]; then
  shift
fi

# Remaining args (original CLI argv)
ARGV=("$@")

# ---------------------------------------
# Maybe-mode: detect help flags
# ---------------------------------------
if [[ "$mode" == "--maybe" ]]; then
  found=0
  for a in "${ARGV[@]}"; do
    if [[ "$a" == "-h" || "$a" == "--help" ]]; then
      found=1
      break
    fi
  done
  [[ "$found" == "1" ]] || exit 2
fi

# ---------------------------------------
# Formatting
# ---------------------------------------
bold=$(tput bold 2>/dev/null || true)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0 2>/dev/null || true)

# ---------------------------------------
# Print help
# ---------------------------------------

echo "$COMMAND_DESCRIPTION"
echo ""


# usage
echo "${bold}USAGE:${normal}"
if [ "$WORKFLOW" = "-" ] && [ ! "$COMMAND" = "-" ]; then
  # examine
  #usage="${CLI_NAME} ${COMMAND}"
  echo "  $CLI_NAME $COMMAND [flags]"
  echo ""
  echo "${bold}FLAGS:${normal}"
  echo "  ${italic}This command has no flags.${normal}"
elif [ ! "$WORKFLOW" = "" ] && [ "$COMMAND" = "-" ]; then
  # cmd/new.sh
  #usage="${CLI_NAME} ${WORKFLOW}"
  echo "  $CLI_NAME $WORKFLOW [commands]"
  echo ""
  echo "${bold}COMMANDS:${normal}"
elif [ ! "$WORKFLOW" = "" ] && [ ! "$COMMAND" = "" ]; then
  # cmd/new/nccl.sh
  #usage="${CLI_NAME} ${WORKFLOW} ${COMMAND}"
  echo "  $CLI_NAME $WORKFLOW $COMMAND [flags]"
  echo ""
  echo "${bold}FLAGS:${normal}"
fi

# flags
#if (( ${#PARAMS[@]} == 0 )); then
#  #echo "  ${usage}"
#  #echo ""
#  echo "${bold}FLAGS:${normal}"
#  echo "  ${italic}This command has no flags.${normal}"
#else
#  echo "  ${usage} [flags]"
#  echo ""
#  echo "${bold}FLAGS:${normal}"

  for p in "${PARAMS[@]}"; do
    IFS=',' read -r name short desc range def <<< "$p"

    suffix=""
    if [[ "$print_both" == "1" ]]; then
      if [[ -n "$range" && -n "$def" ]]; then
        suffix=" ($range, default: $def)"
      elif [[ -n "$range" ]]; then
        suffix=" ($range)"
      elif [[ -n "$def" ]]; then
        suffix=" (default: $def)"
      fi
    else
      if [[ "$print_range" == "1" && -n "$range" ]]; then
        suffix+=" ($range)"
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
#fi

echo ""
echo "${bold}INHERITED FLAGS:${normal}"
echo "  -h, --help      Show this help"