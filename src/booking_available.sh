#!/usr/bin/env bash
# Check booking availability explicitly; exit nonzero when unavailable.
set -euo pipefail
ODEV_PATH="$1"
booking_db="${BOOKING_DB_FILE:-}"
if [[ -z "$booking_db" ]]; then
  booking_db=$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths booking)
fi
participant=$(python3 "$ODEV_PATH/src/booking_is_server.py" --db "$booking_db" --participant)
if [[ "$participant" != 1 ]]; then
  echo "Command not available: odev booking"
  exit 1
fi
