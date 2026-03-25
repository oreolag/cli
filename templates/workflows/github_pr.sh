#!/usr/bin/env bash
set -euo pipefail

my_workflow=""
workflow=""
msg=""

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "Creates a PR to oreolag/workflows."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  github_pr.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --my_workflow  Workflow name in my_workflows branch"
  echo "    --title        Pull request title"
  echo "    --workflow     Workflow name in upstream oreolag/workflows (optional; if omitted, the workflow will use the same name)"
  echo
  echo "${bold}INHERITED FLAGS:${normal}"
  echo "  -h, --help       Show this help"
}

# parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --my_workflow)
      my_workflow="${2:-}"
      shift 2
      ;;
    --workflow)
      workflow="${2:-}"
      shift 2
      ;;
    --title)
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

source_branch="$(cat ./GITHUB_PUSH_BRANCH)"

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
if [[ -z "$my_workflow" ]]; then
  printf "my_workflow: " > /dev/tty
  read -r my_workflow < /dev/tty
fi

if [[ -z "$msg" ]]; then
  printf "title: " > /dev/tty
  read -r msg < /dev/tty
fi

if [[ -z "$workflow" ]]; then
  printf "workflow (optional): " > /dev/tty
  read -r workflow < /dev/tty
fi

# default target workflow
if [[ -z "$workflow" ]]; then
  workflow="$my_workflow"
fi

pr_branch="pr-$workflow"
git fetch upstream main
git fetch origin "$pr_branch:refs/remotes/origin/$pr_branch" >/dev/null 2>&1 || true

# validate source workflow in source branch
if ! git ls-tree -d --name-only "$source_branch" -- "$my_workflow" | grep -q .; then
  echo "Workflow not found: $my_workflow"
  exit 1
fi

# validate target workflow in upstream/main when different
if [[ "$workflow" != "$my_workflow" ]] && ! git ls-tree -d --name-only upstream/main -- "$workflow" | grep -q .; then
  echo "Workflow not found: $workflow"
  exit 1
fi

git checkout -B "$pr_branch" upstream/main

# copy/replace tracked files from source branch into PR branch
while IFS= read -r src; do
  rel="${src#$my_workflow/}"
  dst="$workflow/$rel"

  mkdir -p "$(dirname "$dst")"
  git show "$source_branch:$src" > "$dst"
  git add -A -- "$dst"
done < <(git ls-tree -r --name-only "$source_branch" -- "$my_workflow")

if git diff --cached --quiet; then
  echo "Nothing to commit: $workflow"
  exit 0
fi

#git commit -m "$msg"
#git push --force-with-lease -u origin "$pr_branch"
git commit -m "$msg"
git fetch --prune origin
git push --force-with-lease -u origin "$pr_branch"

gh pr create \
  --repo oreolag/workflows \
  --base main \
  --head "$(gh api user --jq .login):$pr_branch" \
  --title "$msg" \
  --body "This PR updates workflow '$workflow' using 'my_workflows:$my_workflow'."