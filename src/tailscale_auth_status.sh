#!/usr/bin/env bash
set -euo pipefail

# Report whether Tailscale is running; failures are treated as disconnected.
logged_in="0"
if tailscale status --json 2>/dev/null | python3 -c '
import json
import sys

try:
    status = json.load(sys.stdin)
    sys.exit(0 if status.get("BackendState") == "Running" else 1)
except (ValueError, AttributeError):
    sys.exit(1)
' 2>/dev/null; then
    logged_in="1"
fi

printf '%s\n' "$logged_in"
