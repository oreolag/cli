#!/usr/bin/env bash
set -euo pipefail

# These helpers are also copied into project directories.
ODEV_PATH="${ODEV_PATH:-/opt/odev}"

workflow=""
project=""
file=""

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "Show git differences for a project file."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  git_diff.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --workflow   Workflow name"
  echo "    --project    Project name"
  echo "    --file       File name"
  echo
  echo "${bold}INHERITED FLAGS:${normal}"
  echo "  -h, --help       Show this help"
}

# -----------------------------
# Parse flags
# -----------------------------
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

# -----------------------------
# Interactive prompt
# -----------------------------
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

# -----------------------------
# Validate workflow
# -----------------------------
if [[ ! -d "$workflow" ]]; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error workflow_not_found -- "$workflow"
  exit 1
fi

# -----------------------------
# Validate project
# -----------------------------
if [[ ! -d "$workflow/$project" ]]; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error project_not_found -- "$workflow/$project"
  exit 1
fi

# -----------------------------
# Enter repository
# -----------------------------
repo="$workflow/$project"

if [[ ! -d "$repo/.git" ]]; then
  python3 "$ODEV_PATH/src/odev_messages.py" --error invalid_git_repository -- "$repo"
  exit 1
fi

cd "$repo"

# -----------------------------
# Determine file
# -----------------------------
if [[ -n "$file" ]]; then

  if [[ ! -f "$file" ]] && ! git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
    python3 "$ODEV_PATH/src/odev_messages.py" --error file_not_found -- "$file"
    exit 1
  fi

  if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then

    if git diff --quiet -- "$file"; then
      echo "Nothing to commit: $file"
    else
      git diff -- "$file"
    fi

  else
    python3 "$ODEV_PATH/src/odev_messages.py" --error missing_prerequisite github_push.sh
    exit 1
  fi

else
  # diff entire project
  changed=0

  while read -r f; do
    if git ls-files --error-unmatch "$f" >/dev/null 2>&1; then
      if ! git diff --quiet -- "$f"; then
        git diff -- "$f"
        changed=1
      fi
    else
      python3 "$ODEV_PATH/src/odev_messages.py" --error missing_prerequisite github_push.sh
      exit 1
    fi
  done < <(find . -type f)

  if [[ "$changed" == "0" ]]; then
    echo "Nothing to commit."
  fi
fi