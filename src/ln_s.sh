#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 3 ]] || exit 1

ODEV_PATH="$1"
origin_file="$2"
destination_file="$3"

dest_dir="$(dirname "$destination_file")"
dest_dir="$(readlink -f -- "$dest_dir")" || exit 1

# ensure destination is inside ODEV_PATH
[[ "$dest_dir" == "$ODEV_PATH"* ]] || exit 1

ln -s -- "$origin_file" "$destination_file"