#!/usr/bin/env bash
set -euo pipefail

msg="Update"
workflow=""
file=""

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "Commit and push git changes for a workflow."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  github_push.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --workflow   Workflow to commit (omit to push existing commits only)"
  echo "    --file       Workflow file name (optional; if omitted, the whole workflow is staged)"
  echo "    --comment    Commit subject"
  echo
  echo "${bold}INHERITED FLAGS:${normal}"
  echo "  -h, --help     Show this help"
}

# parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workflow)
      workflow="${2:-}"
      shift 2
      ;;
    --file)
      file="${2:-}"
      shift 2
      ;;
    --comment)
      msg="${2:-}"
      shift 2
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

# ensure we are inside a git repository
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: not inside a git repository"
  exit 1
}

cd "$(git rev-parse --show-toplevel)"

# ensure GitHub authentication
if ! gh auth status >/dev/null 2>&1; then
  gh auth login
fi

# get GITHUB_PUSH_BRANCH
github_branch="$(cat "./GITHUB_PUSH_BRANCH")"

# select the configured workflow branch
if [[ "$(git branch --show-current)" != "$github_branch" ]]; then
  if git show-ref --verify --quiet "refs/heads/$github_branch"; then
    git checkout "$github_branch"
  elif git show-ref --verify --quiet "refs/remotes/origin/$github_branch"; then
    git checkout -b "$github_branch" --track "origin/$github_branch"
  else
    git checkout -b "$github_branch"
  fi
fi

# without a workflow selection, upload existing commits only
if [[ -z "$workflow" ]]; then
  git push -u origin "$github_branch"
  exit 0
fi

# validate workflow
if [[ ! -d "$workflow" ]] && ! git ls-files --error-unmatch "$workflow" >/dev/null 2>&1; then
  echo "Workflow not found: $workflow"
  exit 1
fi

# set target
if [[ -n "$file" ]]; then
  target="$workflow/$file"

  # validate file (existing or tracked-for-deletion)
  if [[ ! -f "$target" ]] && ! git ls-files --error-unmatch "$target" >/dev/null 2>&1; then
    echo "File not found: $target"
    exit 1
  fi
else
  target="$workflow"
fi

# configure git identity if missing
if ! git config user.name >/dev/null; then
  git config user.name "$(gh api user --jq .login)"
fi

if ! git config user.email >/dev/null; then
  git config user.email "$(gh api user --jq .login)@users.noreply.github.com"
fi

# stage and commit only the selected changes
git add -A -- "$target"
if ! git diff --cached --quiet -- "$target"; then
  if [[ "$msg" == "Update" ]]; then
    printf "comment: " > /dev/tty
    read -r msg < /dev/tty
  fi
  git commit --only -m "$msg" -- "$target"
fi

# also push commits created by github_pull.sh when no new commit is needed
git push -u origin "$github_branch"
