#!/usr/bin/env bash
set -euo pipefail

[[ $# -eq 3 ]] || exit 1

USER_NAME="$1"
GROUP_NAME="$2"
TARGET="$3"

chown -R "${USER_NAME}:${GROUP_NAME}" "$TARGET"