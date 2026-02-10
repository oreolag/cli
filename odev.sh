#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cmd="${1:-}"
subcmd="${2:-}"

if [[ -z "$cmd" || -z "$subcmd" ]]; then
    echo "Usage: odev <command> <subcommand>"
    exit 1
fi

script="${ODEV_PATH}/${cmd}/${subcmd}.sh"

if [[ ! -x "$script" ]]; then
    echo "Error: command not found: $cmd $subcmd"
    exit 1
fi

exec "$script" "${@:3}"