#!/usr/bin/env bash
set -euo pipefail

workflow=""
file=""

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "Show local changes for a workflow or a selected file."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  git_diff.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --workflow   Workflow name"
  echo "    --file       File name (optional; defaults to the whole workflow)"
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

# set target
target="$workflow"
if [[ -n "$file" ]]; then
  target="$workflow/$file"
fi

# include tracked deletions as well as existing files
if [[ ! -e "$target" && ! -L "$target" ]] &&
   ! git ls-files --error-unmatch -- ":(literal)$target" >/dev/null 2>&1; then
  echo "Path not found: $target"
  exit 1
fi

# staged and unstaged changes compared with the last commit
git --no-pager diff HEAD -- ":(literal)$target"

# show new files without staging them
while IFS= read -r -d '' new_file; do
  git --no-pager diff --no-index -- /dev/null "$new_file" || {
    status=$?
    [[ "$status" == "1" ]] || exit "$status"
  }
done < <(git ls-files --others --exclude-standard -z -- ":(literal)$target")
