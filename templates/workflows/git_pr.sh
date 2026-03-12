#!/usr/bin/env bash
set -euo pipefail

# ensure we are inside a git repository
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: not inside a git repository"
  exit 1
}

cd "$(git rev-parse --show-toplevel)"

# configure git identity if missing
if ! git config user.name >/dev/null; then
  git config user.name "$(gh api user --jq .login)"
fi

if ! git config user.email >/dev/null; then
  git config user.email "$(gh api user --jq .login)@users.noreply.github.com"
fi

branch="$(git rev-parse --abbrev-ref HEAD)"

if [[ "$branch" == "main" ]]; then
  echo "Error: cannot create PR from main"
  exit 1
fi

git push origin "$branch"
git fetch upstream main

gh pr create \
  --repo oreolag/workflows \
  --base main \
  --head "$(gh api user --jq .login):$branch" \
  --fill