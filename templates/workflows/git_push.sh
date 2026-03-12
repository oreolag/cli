#!/usr/bin/env bash
set -euo pipefail

msg="${1:-Update}"

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

# if still on main, create a branch automatically from the first workflow folder found
branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$branch" == "main" ]]; then
  workflow_name="$(find . -mindepth 1 -maxdepth 1 -type d ! -name '.git' | head -n 1 | sed 's|^\./||')"
  if [[ -z "$workflow_name" ]]; then
    echo "Error: could not derive workflow branch name"
    exit 1
  fi
  git checkout -b "$workflow_name"
  branch="$workflow_name"
fi

git add -A

if git diff --cached --quiet; then
  echo "Nothing to commit."
  exit 0
fi

git commit -m "$msg"
git push -u origin "$branch"