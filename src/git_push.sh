#!/usr/bin/env bash
set -euo pipefail

msg="Update"
if [[ $# -gt 0 && "$1" != --* ]]; then
  msg="$1"
  shift
fi

# get GITHUB_PUSH_BRANCH
github_branch=$(cat ./GITHUB_PUSH_BRANCH)

workflow=""
command=""

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

print_help() {
  echo "Commit and push git changes for a workflow command."
  echo
  echo "${bold}USAGE:${normal}"
  echo "  git_push.sh [flags]"
  echo
  echo "${bold}FLAGS:${normal}"
  echo "    --workflow   Workflow name"
  echo "    --command    Command name (new, build, ${italic}program,${normal} run, validate)"
  echo "    --comment    Commit subject"
  echo 
  echo "${bold}INHERITED FLAGS:${normal}"
  echo "  -h, --help       Show this help"
}

# parse flags
while [[ $# -gt 0 ]]; do
  case "$1" in
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
printf "workflow: " > /dev/tty
read -r workflow < /dev/tty

printf "command: " > /dev/tty
read -r command < /dev/tty

printf "comment: " > /dev/tty
read -r msg < /dev/tty

# resolve file
if [[ "$command" == *.sh ]]; then
  file="$workflow/$command"
  command_name="${command%.sh}"
else
  file="$workflow/$command.sh"
  command_name="$command"
fi

# validate workflow + command together (odev style)
if [[ ! -d "$workflow" ]] || [[ ! -f "$file" ]]; then
  echo "Command not found: $workflow $command_name"
  exit 1
fi

# configure git identity if missing
if ! git config user.name >/dev/null; then
  git config user.name "$(gh api user --jq .login)"
fi

if ! git config user.email >/dev/null; then
  git config user.email "$(gh api user --jq .login)@users.noreply.github.com"
fi

# create branch if needed
branch="$(git rev-parse --abbrev-ref HEAD)"
if [[ "$branch" == "main" ]]; then
  git checkout -b my_workflows
  branch="my_workflows"
fi

git add "$file"

if git diff --cached --quiet; then
  echo "Nothing to commit."
  exit 0
fi

git commit -m "$msg"
git push -u origin "$branch"