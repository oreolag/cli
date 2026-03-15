#!/usr/bin/env bash
set -euo pipefail

msg="Update"
workflow=""
project=""
file=""

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "Commit and push git changes for a project."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  git_push.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --workflow   Workflow name"
  echo "    --project    Project name"
  echo "    --file       Project file name (add, modify, or delete)"
  echo "    --comment    Commit subject"
  echo
  echo "${bold}INHERITED FLAGS:${normal}"
  echo "  -h, --help       Show this help"
}

# parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
    --workflow)
      workflow="${2:-}"
      shift 2
      ;;
    --project)
      project="${2:-}"
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

# interactive prompts
if [[ -z "$workflow" ]]; then
  printf "workflow: " > /dev/tty
  read -r workflow < /dev/tty
fi

if [[ -z "$project" ]]; then
  printf "project: " > /dev/tty
  read -r project < /dev/tty
fi

if [[ -z "$file" ]]; then
  printf "file: " > /dev/tty
  read -r file < /dev/tty
fi

if [[ "$msg" == "Update" ]]; then
  printf "comment: " > /dev/tty
  read -r msg < /dev/tty
fi

# set file
file="$workflow/$project/$file"

# validate workflow
if [[ ! -d "$workflow" ]]; then
  echo "Project not found: $workflow/$project"
  exit 1
fi

# validate project
if [[ ! -d "$workflow/$project" ]]; then
  echo "Project not found: $workflow/$project"
  exit 1
fi

# validate file (existing or tracked-for-deletion)
if [[ ! -f "$file" ]] && ! git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
  echo "File not found: $file"
  exit 1
fi

# configure git identity if missing
if ! git config user.name >/dev/null; then
  git config user.name "$(gh api user --jq .login)"
fi

if ! git config user.email >/dev/null; then
  git config user.email "$(gh api user --jq .login)@users.noreply.github.com"
fi

# stage file change (including deletion)
git add -A -- "$file"

if git diff --cached --quiet; then
  echo "Nothing to commit."
  exit 0
fi

git commit -m "$msg"
git push