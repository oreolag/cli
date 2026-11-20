#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="${ODEV_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
if [[ "$logged_in" == "0" ]]; then
  echo "Login failed: use gh auth login"
  exit 1
fi

gh_path="$(command -v gh)" || exit 1
git -c credential.helper= \
  -c "credential.https://github.com.helper=!\"$gh_path\" auth git-credential" \
  fetch --quiet --no-tags origin || exit 1
exec git status

