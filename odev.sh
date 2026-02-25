#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# early exit
is_odev_user=$($ODEV_PATH/src/is_member.sh $USER odev-users)
if [ "$is_odev_user" = "0" ]; then
  exit 1
fi

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# command descriptions
new="$("$ODEV_PATH/src/description_read.sh" "$ODEV_PATH" "NEW")"
validate="$("$ODEV_PATH/src/description_read.sh" "$ODEV_PATH" "VALIDATE")"
examine="$("$ODEV_PATH/src/description_read.sh" "$ODEV_PATH" "EXAMINE")"

print_help() {
  echo "The CLI for hetero${italic}genius${normal} computing."
  echo ""
  echo "${bold}USAGE${normal}"
  echo "  odev <command> <subcommand> [flags]"
  echo ""
  echo "${bold}CORE COMMANDS${normal}"
  echo "  new:             $new"
  echo "  validate:        $validate"
  echo "  examine:         $examine"
  echo ""
  echo "${bold}FLAGS${normal}"
  echo "  -h, --help       Show help for command"
  echo "  -v, --version    Show odev version"
  echo ""
  echo "${bold}EXAMPLES${normal}"
  echo "  $ odev new vllm"
  echo "  $ odev validate nccl"
  echo "  $ odev examine"
  echo ""
  echo "${bold}LEARN MORE${normal}"
  echo "  Use ${bold}odev <command> <subcommand> --help${normal} for more information about a command."
  echo "  Read the manual at https://books.oreol.ch/6/cli"
}

print_version() {
  local ver date

  if [[ -f "$ODEV_PATH/VERSION" ]]; then
    ver="$(cat "$ODEV_PATH/VERSION")"
  else
    ver="unknown"
  fi

  if [[ -f "$ODEV_PATH/RELEASE_DATE" ]]; then
    date="$(cat "$ODEV_PATH/RELEASE_DATE")"
  else
    date="unknown"
  fi

  echo "odev version ${ver} (${date})"
  echo "https://github.com/oreolag/cli/releases/tag/v${ver}"
}

# ------------------------------------------------------------
# Global flags / help / version
# ------------------------------------------------------------
case "${1:-}" in
  ""|-h|--help)
    print_help
    exit 0
    ;;
  -v|--version)
    print_version
    exit 0
    ;;
esac

cmd="${1:-}"
subcmd="${2:-}"

# ------------------------------------------------------------
# Script resolution with flag support
# ------------------------------------------------------------
if [[ -z "$cmd" || "$cmd" == -* ]]; then
  print_help
  exit 0
fi

# Single-command scripts: odev examine [flags]
if [[ -z "$subcmd" || "$subcmd" == -* ]]; then
  script="${ODEV_PATH}/cmd/${cmd}.sh"
  shift 1
else
  script="${ODEV_PATH}/cmd/${cmd}/${subcmd}.sh"
  shift 2
fi

if [[ ! -x "$script" ]]; then
  echo "Error: command not found: ${cmd} ${subcmd:-}"
  exit 1
fi

exec "$script" "$@"