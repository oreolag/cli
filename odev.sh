#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# format
bold=$(tput bold)
italic=$(tput sitm)
normal=$(tput sgr0)

cmd="${1:-}"
subcmd="${2:-}"

if [[ -z "$cmd" || -z "$subcmd" ]]; then
    echo "The CLI for hetero${italic}genius${normal} computing."
    echo ""
    echo "${bold}USAGE${normal}"
    echo "  odev <command> <subcommand> [flags]"
    echo ""
    echo "${bold}CORE COMMANDS${normal}"
    echo "  new:          Create a new project"
    echo "  validate:     Infrastructure functionality assessment"
    echo ""
    echo "${bold}FLAGS${normal}"
    echo "  --help        Show help for command"
    echo "  --version     Show odev version"
    echo ""
    echo "${bold}EXAMPLES${normal}"
    echo "  $ odev new vllm"
    echo "  $ odev validate nccl"
    echo ""
    echo "${bold}LEARN MORE${normal}"
    echo "  Use ${bold}odev <command> <subcommand> --help${normal} for more information about a command."
    echo "  Read the manual at https://books.oreol.ch/6/cli"
    echo ""
    exit 1
fi

script="${ODEV_PATH}/cmd/${cmd}/${subcmd}.sh"

if [[ ! -x "$script" ]]; then
    echo "Error: command not found: $cmd $subcmd"
    exit 1
fi

exec "$script" "${@:3}"