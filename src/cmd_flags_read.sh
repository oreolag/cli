#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_flags_read.sh <ODEV_ROOT> <KEY>
# Output:
#   first line:  DESCRIPTION=<...>
#   next lines:  FLAG=<spec>

ODEV_ROOT="$1"
KEY="$2"

# load centralized flags (internal source; caller reminds clean)
# shellcheck source=/dev/null
source "$ODEV_ROOT/src/cmd_flags.sh"

desc_var="${KEY}_DESCRIPTION"
flags_var="${KEY}_FLAGS"

desc="${!desc_var:-}"
[[ -n "$desc" ]] || { echo "cmd_flags_read: missing $desc_var" >&2; exit 1; }

echo "DESCRIPTION=$desc"

# indirect array expansion
eval "for f in \"\${${flags_var}[@]}\"; do echo \"FLAG=\$f\"; done" \
  || { echo "cmd_flags_read: missing/invalid $flags_var" >&2; exit 1; }
