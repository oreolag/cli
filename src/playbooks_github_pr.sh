#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="${ODEV_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

community_repository="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github playbooks_repo)"

logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
if [[ "$logged_in" == "0" ]]; then
  echo "Login failed: use gh auth login"
  exit 1
fi

branch="$(git symbolic-ref --quiet --short HEAD)" || exit 1
origin="$(git remote get-url origin)" || exit 1
owner="$(gh repo view "$origin" --json owner --jq '.owner.login')" || exit 1
exec gh pr create --repo "$community_repository" --base main --head "$owner:$branch" --fill

