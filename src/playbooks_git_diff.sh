#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="${ODEV_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

exec git diff
