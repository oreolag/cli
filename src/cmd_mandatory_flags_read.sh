#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_mandatory_flags_read.sh <ODEV_PATH> <KEY>
# Output:
#   MANDATORY flags string (e.g. name,ngpus)

ODEV_PATH="$1"
KEY="$2"

# shellcheck source=/dev/null
source "$ODEV_PATH/src/cmd_spec.sh"

mandatory_var="${KEY}_FLAGS_MANDATORY"
mandatory="${!mandatory_var:-}"

[[ -n "$mandatory" ]] || { echo "cmd_mandatory_flags_read: missing $mandatory_var" >&2; exit 1; }

echo "$mandatory"