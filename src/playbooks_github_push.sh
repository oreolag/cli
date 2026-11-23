#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="${ODEV_PATH:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"

# With no internal selectors, push existing commits on the current branch.
if [[ $# == 0 ]]; then
  logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
  if [[ "$logged_in" == "0" ]]; then
    python3 "$ODEV_PATH/src/odev_messages.py" --error login_failed gh
    exit 1
  fi
  
  gh_path="$(command -v gh)" || exit 1
  branch="$(git symbolic-ref --quiet --short HEAD)" || exit 1
  exec git -c credential.helper= \
    -c "credential.https://github.com.helper=!\"$gh_path\" auth git-credential" \
    push -u origin "HEAD:refs/heads/$branch"
fi


msg="Update"
playbook=""

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "Commit and push git changes for a playbook."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  github_push.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --playbook   Playbook to commit (omit to push existing commits only)"
  echo "    --comment    Commit subject"
  echo
  echo "${bold}INHERITED FLAGS:${normal}"
  echo "  -h, --help     Show this help"
}

# parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --playbook)
      playbook="${2:-}"
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
      python3 "$ODEV_PATH/src/odev_messages.py" --error unknown_option -- "$1"
      exit 1
      ;;
  esac
done

# ensure we are inside a git repository
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  python3 "$ODEV_PATH/src/odev_messages.py" --error invalid_git_repository -- "$PWD"
  exit 1
}

cd "$(git rev-parse --show-toplevel)"

# ensure GitHub authentication
if ! gh auth status >/dev/null 2>&1; then
  gh auth login
fi

# get the configured branch
github_branch="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github push_branch_playbooks)"

# select the configured playbook branch
if [[ "$(git branch --show-current)" != "$github_branch" ]]; then
  if git show-ref --verify --quiet "refs/heads/$github_branch"; then
    git checkout "$github_branch"
  elif git show-ref --verify --quiet "refs/remotes/origin/$github_branch"; then
    git checkout -b "$github_branch" --track "origin/$github_branch"
  else
    git checkout -b "$github_branch"
  fi
fi

# without a playbook selection, upload existing commits only
if [[ -z "$playbook" ]]; then
  git push -u origin "$github_branch"
  exit 0
fi

# set target
if [[ ! "$playbook" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error invalid_playbook_name -- "$playbook"
  exit 1
fi
target="$playbook.yml"

# validate file (existing or tracked-for-deletion)
if [[ ! -f "$target" ]] && ! git ls-files --error-unmatch -- "$target" >/dev/null 2>&1; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error playbook_not_found -- "$playbook"
  exit 1
fi

# configure git identity if missing
if ! git config user.name >/dev/null; then
  git config user.name "$(gh api user --jq .login)"
fi

if ! git config user.email >/dev/null; then
  git config user.email "$(gh api user --jq .login)@users.noreply.github.com"
fi

# include new, changed, or deleted companion variables
targets=("$target")
if [[ -e "${playbook}_vars.yml" ]] || git ls-files --error-unmatch -- "${playbook}_vars.yml" >/dev/null 2>&1; then
  targets+=("${playbook}_vars.yml")
fi

# stage and commit only the selected changes
git add -A -- "${targets[@]}"
if ! git diff --cached --quiet -- "${targets[@]}"; then
  if [[ "$msg" == "Update" ]]; then
    printf "comment: " > /dev/tty
    read -r msg < /dev/tty
  fi
  git commit --only -m "$msg" -- "${targets[@]}"
fi

# also push commits created by github_pull.sh when no new commit is needed
git push -u origin "$github_branch"
