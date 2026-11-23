#!/usr/bin/env bash
set -euo pipefail

# These helpers are also copied into project directories.
ODEV_PATH="${ODEV_PATH:-/opt/odev}"

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
  echo "    --file       Project file name (optional; if omitted, the whole project is staged)"
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
      python3 "$ODEV_PATH/src/odev_messages.py" --error unknown_option -- "$1"
      exit 1
      ;;
  esac
done

# interactive prompts
if [[ -z "$workflow" ]]; then
  printf "workflow: " > /dev/tty
  read -r workflow < /dev/tty
fi

if [[ -z "$project" ]]; then
  printf "project: " > /dev/tty
  read -r project < /dev/tty
fi

# optional file prompt (press Enter to skip → whole project)
if [[ -z "$file" ]]; then
  printf "file (optional): " > /dev/tty
  read -r file < /dev/tty
fi

if [[ "$msg" == "Update" ]]; then
  printf "comment: " > /dev/tty
  read -r msg < /dev/tty
fi

# validate workflow
if [[ ! -d "$workflow" ]]; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error workflow_not_found -- "$workflow"
  exit 1
fi

# validate project
if [[ ! -d "$workflow/$project" ]]; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error project_not_found -- "$workflow/$project"
  exit 1
fi

# enter repository
repo="$workflow/$project"

if [[ ! -d "$repo/.git" ]]; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error invalid_git_repository -- "$repo"
  exit 1
fi

# ensure GitHub authentication
if ! gh auth status >/dev/null 2>&1; then
  gh auth login
fi

cd "$repo"

# set target
if [[ -n "$file" ]]; then
  target="$file"

  # validate file (existing or tracked-for-deletion)
  if [[ ! -f "$target" ]] && ! git ls-files --error-unmatch "$target" >/dev/null 2>&1; then
    python3 "$ODEV_PATH/src/odev_messages.py" --error file_not_found -- "$target"
    exit 1
  fi
else
  target="."
fi

# configure git identity if missing
if ! git config user.name >/dev/null; then
  git config user.name "$(gh api user --jq .login)"
fi

if ! git config user.email >/dev/null; then
  git config user.email "$(gh api user --jq .login)@users.noreply.github.com"
fi

# stage file change (including deletion)
git add -A -- "$target"

if git diff --cached --quiet; then
  echo "Nothing to commit: $target"
  exit 0
fi

git commit -m "$msg"
git push