#!/usr/bin/env bash
# Check booking availability explicitly; exit nonzero when unavailable.
set -euo pipefail
ODEV_PATH="$1"
booking_db="${BOOKING_DB_FILE:-}"
if [[ -z "$booking_db" ]]; then
  booking_db=$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths booking)
fi
booking_db=${booking_db:-/opt/booking.yml}
is_booking=$(python3 "$ODEV_PATH/src/booking_is_server.py" --db "$booking_db" "${@:2}")
if [[ "$is_booking" != 1 ]]; then
  echo "Command not available: odev booking"
  exit 1
fi
if [[ "${2:-}" == "--participant" ]]; then
  is_local=$(python3 "$ODEV_PATH/src/booking_is_server.py" --db "$booking_db")
  if [[ "$is_local" != 1 && "$("$ODEV_PATH/src/tailscale_auth_status.sh")" != 1 ]]; then
    echo "Login failed: tailscale" >&2
    exit 1
  fi
fi
