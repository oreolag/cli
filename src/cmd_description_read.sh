#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   cmd_description_read.sh <ODEV_PATH> <KEY> [--db CMD_SPEC]
#
# Output:
#   DESCRIPTION text only
#
# Examples:
#   cmd_description_read.sh /opt/odev NEW
#   cmd_description_read.sh /opt/odev NEW --db /opt/odev/workflows/foo/cmd_spec.sh

ODEV_PATH="$1"
KEY="$2"
shift 2

CMD_SPEC="$ODEV_PATH/src/cmd_spec.sh"

# optional arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)
      CMD_SPEC="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 1
      ;;
  esac
done

# shellcheck source=/dev/null
source "$CMD_SPEC"

desc_var="${KEY}_DESCRIPTION"
desc="${!desc_var:-}"

[[ -n "$desc" ]] || { echo "cmd_description_read: missing $desc_var" >&2; exit 1; }

echo "$desc"