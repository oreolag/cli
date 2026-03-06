#!/usr/bin/env bash
set -euo pipefail

app="$1"

if command -v "$app" >/dev/null 2>&1; then
  echo "1"
else
  echo "0"
fi