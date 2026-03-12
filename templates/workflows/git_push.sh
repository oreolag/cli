#!/usr/bin/env bash
set -euo pipefail

msg="${1:-Update}"

# ensure we are inside a git repository
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: not inside a git repository"
  exit 1
}

git add -A

if git diff --cached --quiet; then
  echo "Nothing to commit."
  exit 0
fi

git commit -m "$msg"
git push origin "$(git rev-parse --abbrev-ref HEAD)"