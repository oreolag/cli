#!/usr/bin/env bash
set -euo pipefail

workflow=""
file=""

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "Show git differences for a workflow file."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  git_diff.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --workflow   Workflow name"
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
    --file)
      file="${2:-}"
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

# -----------------------------
# Ensure inside git repository
# -----------------------------
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || {
  echo "Error: not inside a git repository"
  exit 1
}

cd "$(git rev-parse --show-toplevel)"

# -----------------------------
# Interactive prompt
# -----------------------------
if [[ -z "$workflow" ]]; then
  printf "workflow: " > /dev/tty
  read -r workflow < /dev/tty
fi

if [[ -z "$file" ]]; then
  printf "file: " > /dev/tty
  read -r file < /dev/tty
fi

# -----------------------------
# Determine file
# -----------------------------
if [[ -n "$file" ]]; then
  file="$workflow/$file"

  if [[ ! -d "$workflow" ]] || [[ ! -f "$file" ]]; then
    echo "File not found: $file"
    exit 1
  fi

  if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
    git diff -- "$file"
  else
    echo "Error: use git_push.sh first"
    exit 1
  fi
else
  # diff entire workflow
  while read -r file; do
    if git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
      git diff -- "$file"
    else
      echo "Error: use git_push.sh first"
      exit 1
    fi
  done < <(find "$workflow" -type f)
fi