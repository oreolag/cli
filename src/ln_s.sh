#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 3 ]] || exit 1

ODEV_PATH="$1"
origin_file="$2"
destination_file="$3"

ODEV_PATH="$(readlink -f -- "$ODEV_PATH")"
dest_dir="$(dirname "$destination_file")"
dest_dir="$(readlink -m -- "$dest_dir")" || exit 1

# ensure destination is inside ODEV_PATH
[[ "$dest_dir" == "$ODEV_PATH/"* ]] || exit 1

# Only create personal links inside the invoking user's workflow directory.
if [[ "$dest_dir" == "$ODEV_PATH/users" || "$dest_dir" == "$ODEV_PATH/users/"* ]]; then
    username="$(id -nu "${SUDO_UID:-$(id -u)}")"
    [[ "$dest_dir" == "$ODEV_PATH/users/$username/workflows/"* ]] || exit 1
    mkdir -p -- "$dest_dir"
fi

ln -s -- "$origin_file" "$dest_dir/$(basename "$destination_file")"
