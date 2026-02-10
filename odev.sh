#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "The CLI for hetero${italic}genius${normal} computing."
  echo ""
  echo "${bold}USAGE${normal}"
  echo "  odev <command> <subcommand> [flags]"
  echo "  odev examine"
  echo ""
  echo "${bold}CORE COMMANDS${normal}"
  echo "  new:          Create a new project"
  echo "  validate:     Infrastructure functionality assessment"
  echo "  examine:      Show environment / installation details"
  echo ""
  echo "${bold}FLAGS${normal}"
  echo "  -h, --help        Show help for command"
  echo "  -v, --version     Show odev version"
  echo ""
  echo "${bold}EXAMPLES${normal}"
  echo "  $ odev new vllm"
  echo "  $ odev validate nccl"
  echo "  $ odev examine"
  echo ""
  echo "${bold}LEARN MORE${normal}"
  echo "  Use ${bold}odev <command> <subcommand> --help${normal} for more information about a command."
  echo "  Read the manual at https://books.oreol.ch/6/cli"
  echo ""
}

print_version() {
  # Option A: git describe if repo exists
  if command -v git >/dev/null 2>&1 && [[ -d "$ODEV_PATH/.git" ]]; then
    git -C "$ODEV_PATH" describe --tags --always 2>/dev/null && return 0
  fi
  # Option B: VERSION file (optional)
  if [[ -f "$ODEV_PATH/VERSION" ]]; then
    cat "$ODEV_PATH/VERSION" && return 0
  fi
  # Fallback
  echo "odev (version unknown)"
}

# Handle global flags / single-word commands early
case "${1:-}" in
  ""|-h|--help)
    print_help
    exit 0
    ;;
  -v|--version)
    print_version
    exit 0
    ;;
  examine)
    script="${ODEV_PATH}/cmd/examine.sh"
    if [[ -x "$script" ]]; then
      exec "$script" "${@:2}"
    fi
    echo "Error: command not found: examine"
    exit 1
    ;;
esac

cmd="${1:-}"
subcmd="${2:-}"

if [[ -z "$cmd" || -z "$subcmd" ]]; then
  print_help
  exit 1
fi

script="${ODEV_PATH}/cmd/${cmd}/${subcmd}.sh"

if [[ ! -x "$script" ]]; then
  echo "Error: command not found: $cmd $subcmd"
  exit 1
fi

exec "$script" "${@:3}"