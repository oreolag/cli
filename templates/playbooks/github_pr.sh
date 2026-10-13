#!/usr/bin/env bash
set -euo pipefail

my_playbook=""
playbook=""
#msg=""

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "Creates a PR to oreolag/playbooks."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  github_pr.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --my_playbook  Playbook name in my_playbooks branch"
  echo "    --playbook     Playbook name in upstream oreolag/playbooks (optional; if omitted, the playbook will use the same name)"
  echo
  echo "${bold}INHERITED FLAGS:${normal}"
  echo "  -h, --help       Show this help"
}

# parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --my_playbook)
      my_playbook="${2:-}"
      shift 2
      ;;
    --playbook)
      playbook="${2:-}"
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

source_branch="$(cat ./GITHUB_PUSH_BRANCH)"

# preserve tracked local work before changing branches
git diff --exit-code --
git diff --cached --exit-code --

cleanup() {
  git checkout "$source_branch" >/dev/null 2>&1 || true
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

# interactive prompts
if [[ -z "$my_playbook" ]]; then
  printf "my_playbook: " > /dev/tty
  read -r my_playbook < /dev/tty
fi

#if [[ -z "$msg" ]]; then
#  printf "title: " > /dev/tty
#  read -r msg < /dev/tty
#fi

if [[ -z "$playbook" ]]; then
  printf "playbook (optional): " > /dev/tty
  read -r playbook < /dev/tty
fi

# default target playbook
if [[ -z "$playbook" ]]; then
  playbook="$my_playbook"
fi

# playbook names identify one top-level YAML file
if [[ ! "$my_playbook" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ||
      ! "$playbook" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_-]*$ ]]; then
  echo "Invalid playbook name"
  exit 1
fi

pr_branch="pr-$playbook"
git fetch upstream main
git fetch origin "$pr_branch:refs/remotes/origin/$pr_branch" >/dev/null 2>&1 || true

# validate source playbook in source branch
if ! git ls-tree --name-only "$source_branch" -- "$my_playbook.yml" | grep -q .; then
  echo "Playbook not found: $my_playbook"
  exit 1
fi

# validate target playbook in upstream/main when different
if [[ "$playbook" != "$my_playbook" ]] && ! git ls-tree --name-only upstream/main -- "$playbook.yml" | grep -q .; then
  echo "Playbook not found: $playbook"
  exit 1
fi

git checkout -B "$pr_branch" upstream/main

# preserve any untracked file at the target path
if [[ -n "$(git ls-files --others -- "$playbook.yml" "${playbook}_vars.yml")" ]]; then
  echo "File already exists: $playbook.yml"
  exit 1
fi

# copy the selected committed playbook into the PR branch
targets=("$playbook.yml")
if git cat-file -e "$source_branch:${my_playbook}_vars.yml" 2>/dev/null ||
   git ls-files --error-unmatch -- "${playbook}_vars.yml" >/dev/null 2>&1; then
  targets+=("${playbook}_vars.yml")
fi
git rm --ignore-unmatch -- "${targets[@]}"
git show "$source_branch:$my_playbook.yml" > "$playbook.yml"
if git cat-file -e "$source_branch:${my_playbook}_vars.yml" 2>/dev/null; then
  git show "$source_branch:${my_playbook}_vars.yml" > "${playbook}_vars.yml"
  if [[ "$my_playbook" != "$playbook" ]]; then
    git show "$source_branch:$my_playbook.yml" |
      sed "s/${my_playbook}_vars\.yml/${playbook}_vars.yml/g" > "$playbook.yml"
  fi
fi
git add -A -- "${targets[@]}"

# commit only the selected playbook
if git diff --cached --quiet -- "${targets[@]}"; then
  echo "Nothing to commit: $playbook"
  exit 0
fi
git commit --only -m "Files changed with github_pr" -- "${targets[@]}"
git fetch --prune origin
git push --force-with-lease -u origin "$pr_branch"

# create pull request
gh pr create \
  --repo oreolag/playbooks \
  --base main \
  --head "$(gh api user --jq .login):$pr_branch" \
  --title "$pr_branch" \
  --body "This PR updates playbook '$playbook' using 'my_playbooks:$my_playbook'."