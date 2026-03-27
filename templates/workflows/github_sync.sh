#!/usr/bin/env bash
set -euo pipefail

sync_main="0"
sync_workflows="0"
push="0"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "Sync selected local fork branches with upstream oreolag/workflows."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  github_sync.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --main          Sync local main with upstream/main"
  echo "    --my_workflows  Merge upstream/main into my_workflows"
  echo "    --push          Push synced branches to origin"
  echo
  echo "${bold}INHERITED FLAGS:${normal}"
  echo "  -h, --help     Show this help"
}

# parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --main)
      sync_main="1"
      shift
      ;;
    --my_workflows)
      sync_workflows="1"
      shift
      ;;
    --push)
      push="1"
      shift
      ;;
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

# require explicit branch selection
if [[ "$sync_main" == "0" && "$sync_workflows" == "0" ]]; then
  echo "Error: specify --main and/or --my_workflows"
  exit 1
fi

# ensure we are inside a git repository
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: not inside a git repository"
  exit 1
}

cd "$(git rev-parse --show-toplevel)"

dev_branch="$(cat ./GITHUB_PUSH_BRANCH)"

cleanup() {
  git checkout "$dev_branch" >/dev/null 2>&1 || true
}
trap cleanup EXIT

# ensure GitHub authentication
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

# sync main
if [[ "$sync_main" == "1" ]]; then
  git checkout -B main upstream/main

  if [[ "$push" == "1" ]]; then
    git push --force-with-lease origin main
  fi
fi

# sync my_workflows
if [[ "$sync_workflows" == "1" ]]; then
  git checkout "$dev_branch"

  if ! git rev-parse --verify "$dev_branch" >/dev/null 2>&1; then
    echo "Branch not found: $dev_branch"
    exit 1
  fi

  # merge upstream/main into development branch
  git merge --no-edit upstream/main

  if [[ "$push" == "1" ]]; then
    git push origin "$dev_branch"
  fi
fi

# print summary
if [[ "$sync_main" == "1" && "$sync_workflows" == "1" ]]; then
  if [[ "$push" == "1" ]]; then
    echo "Branches synced and pushed: main, $dev_branch"
  else
    echo "Branches synced locally: main, $dev_branch"
  fi
elif [[ "$sync_main" == "1" ]]; then
  if [[ "$push" == "1" ]]; then
    echo "Branch synced and pushed: main"
  else
    echo "Branch synced locally: main"
  fi
else
  if [[ "$push" == "1" ]]; then
    echo "Branch synced and pushed: $dev_branch"
  else
    echo "Branch synced locally: $dev_branch"
  fi
fi