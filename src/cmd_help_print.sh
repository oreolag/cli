#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_help_print.sh --maybe <CLI_NAME> <COMMAND> <SUBCOMMAND> <DESCRIPTION> \
#                     <print_range> <print_default> <print_both> \
#                     <param1> <param2> ... -- <argv...>
#     Output:
#       prints help and exits 0 if -h|--help is found in <argv...>
#       exits 2 if no help flag is found
#
#   cmd_help_print.sh <CLI_NAME> <COMMAND> <SUBCOMMAND> <DESCRIPTION> \
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
#SUBCOMMAND="$2"
#COMMAND="$3"
COMMAND="$2"
SUBCOMMAND="$3"
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

echo "$COMMAND_DESCRIPTION."
echo ""

# usage
echo "${bold}USAGE:${normal}"
if [ "$SUBCOMMAND" = "examine" ] || [ "$SUBCOMMAND" = "update" ]; then
  echo "  $CLI_NAME $SUBCOMMAND [flags]"
  echo ""
  echo "${bold}FLAGS:${normal}"
elif [ "$COMMAND" = "new" ] && [ "$SUBCOMMAND" = "workflow" ]; then
  echo "  $CLI_NAME $COMMAND $SUBCOMMAND [--fork] [flags]"
  echo ""
  echo "${bold}FLAGS:${normal}"
elif [ "$SUBCOMMAND" = "ifconfig" ]; then
  echo "  $CLI_NAME $SUBCOMMAND [flags]"
  echo ""
  echo "${bold}FLAGS:${normal}"
  echo "  This command has no flags."
elif [ ! "$COMMAND" = "" ] && [ "$SUBCOMMAND" = "-" ]; then
  # cmd/new.sh
  #usage="${CLI_NAME} ${COMMAND}"
  echo "  $CLI_NAME $COMMAND [command]"
  echo ""
  echo "${bold}COMMANDS:${normal}"
elif [ ! "$COMMAND" = "" ] && [ ! "$SUBCOMMAND" = "" ]; then
  # cmd/new/nccl.sh
  #usage="${CLI_NAME} ${COMMAND} ${SUBCOMMAND}"
  echo "  $CLI_NAME $COMMAND $SUBCOMMAND [flags]"
  echo ""
  echo "${bold}FLAGS:${normal}"
fi

# print commands or flags
for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short desc range def <<< "$p"

  [[ "$range" == "-" ]] && range=""
  [[ "$def" == "-" ]] && def=""

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

  if [ ! "$COMMAND" = "" ] && [ "$SUBCOMMAND" = "-" ]; then
    printf "  %-16s %s\n" "$name" "$desc"
  elif [ ! "$COMMAND" = "" ] && [ ! "$SUBCOMMAND" = "" ]; then
    printf "  -%-1s, --%-10s %s%s\n" "$short" "$name" "$desc" "$suffix"
  fi
done

echo ""
echo "${bold}INHERITED FLAGS:${normal}"
echo "  -h, --help      Show this help"