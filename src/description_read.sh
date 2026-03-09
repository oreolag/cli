#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   description_read.sh <ODEV_PATH> <KEY>
# Output:
#   DESCRIPTION text only

ODEV_PATH="$1"
KEY="$2"

# shellcheck source=/dev/null
source "$ODEV_PATH/src/cmd_spec.sh"

desc_var="${KEY}_DESCRIPTION"
desc="${!desc_var:-}"

[[ -n "$desc" ]] || { echo "cmd_description_read: missing $desc_var" >&2; exit 1; }

echo "$desc"