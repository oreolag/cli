#!/bin/bash

set -euo pipefail

# Always run from the repository root (where this script lives)
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

SUBMODULE_DIR="submodules"

# Update all submodules under SUBMODULE_DIR to the latest commit on their tracked branches
git submodule update --remote --merge -- "$SUBMODULE_DIR"
echo "git submodule update --remote --merge $SUBMODULE_DIR"
sleep 0.5

# Stage updated submodule pointers (only direct children under submodules/)
git add -- "$SUBMODULE_DIR"
echo "git add $SUBMODULE_DIR"
sleep 0.5

# Commit only if there is something to commit
if git diff --cached --quiet; then
  echo "No submodule updates to commit."
  sleep 0.5
  exit 0
fi

git commit -m "Update submodules"
echo "git commit -m \"Update submodules\""
sleep 0.5