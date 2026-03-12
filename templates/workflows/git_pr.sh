#!/usr/bin/env bash
set -euo pipefail

# ensure we are inside a git repository
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: not inside a git repository"
  exit 1
}

# move to repo root
cd "$(git rev-parse --show-toplevel)"

# current branch
branch="$(git rev-parse --abbrev-ref HEAD)"

# ensure upstream exists
git remote get-url upstream >/dev/null 2>&1 || {
  echo "Error: upstream remote not configured"
  exit 1
}

# push branch to origin if needed
git push origin "$branch"

# create pull request
gh pr create --repo oreolag/workflows --head "$(gh api user --jq .login):$branch" --fill