#!/usr/bin/env bash
set -euo pipefail

# constants
ODEV_PATH="${ODEV_PATH:-/opt/odev}"

# format
bold=$(tput bold)
normal=$(tput sgr0)

print_help() {
  echo "Download fork and community updates into local main and my_workflows."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  github_pull.sh"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "  -h, --help     Show this help"
}

# parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --help|-h)
      print_help
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# get repository and branch
cd "$(git rev-parse --show-toplevel)"
GITHUB_PUSH_BRANCH="$(cat ./GITHUB_PUSH_BRANCH)"

# preserve local edits; Git reports differences or an unfinished merge
git diff --exit-code HEAD --

# check on GitHub CLI
if ! gh auth status >/dev/null 2>&1; then
  gh auth login
fi

# configure git identity if missing
if ! git config user.name >/dev/null; then
  git config user.name "$(gh api user --jq .login)"
fi
if ! git config user.email >/dev/null; then
  git config user.email "$(gh api user --jq .login)@users.noreply.github.com"
fi

# ensure upstream exists
if ! git remote | grep -qx upstream; then
  git remote add upstream https://github.com/oreolag/workflows.git
fi

git fetch --prune upstream
git fetch --prune origin

# update local main without discarding local commits
if git show-ref --verify --quiet refs/heads/main; then
  git checkout main
  git merge --ff-only upstream/main
else
  git checkout -b main upstream/main
fi

# merge work from other servers, then community updates
if git show-ref --verify --quiet "refs/heads/$GITHUB_PUSH_BRANCH"; then
  git checkout "$GITHUB_PUSH_BRANCH"
else
  git checkout -b "$GITHUB_PUSH_BRANCH" --track "origin/$GITHUB_PUSH_BRANCH"
fi
git merge --no-edit "origin/$GITHUB_PUSH_BRANCH"
git merge --no-edit upstream/main

# make downloaded workflows available immediately
"$ODEV_PATH/src/workflows_links.sh" "$PWD"
