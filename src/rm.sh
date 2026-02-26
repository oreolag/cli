#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 2 ]] || exit 1

ODEV_PATH="$1"
target="$2"

target="$(readlink -f -- "$target")" || exit 1
[[ -e "$target" ]] || exit 1
[[ -f "$target" ]] || exit 1

rm -f -- "$target"