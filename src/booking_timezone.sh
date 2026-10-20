#!/usr/bin/env bash
set -euo pipefail
ODEV_PATH="$1"
booking_db="${BOOKING_DB_FILE:-}"
if [[ -z "$booking_db" ]]; then
  booking_db=$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths booking)
fi
booking_db=${booking_db:-/opt/booking.yml}
python3 "$ODEV_PATH/src/booking_is_server.py" --db "$booking_db" --timezone
