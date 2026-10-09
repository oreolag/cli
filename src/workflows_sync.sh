#!/usr/bin/env bash
set -euo pipefail

# get path
ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# get username
username="$(id -un)"

# check on users (active groups are required for sudo)
[[ " $(id -Gn) " == *" odev-developers "* ]] || exit 0

# check on tools
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "gh")"
if [ "$installed" != "1" ]; then
  exit 0
fi

# check on GitHub CLI
logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
if [ "$logged_in" != "1" ]; then
  exit 0
fi

# constants
WORKFLOWS_TEMPLATE_PATH="$ODEV_PATH/templates/workflows"
WORKFLOW_COMMAND_PATH="$ODEV_PATH/users/$username/workflows"
WORKFLOWS_USER_PATH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths workflows)"
WORKFLOWS_USER_PATH="${WORKFLOWS_USER_PATH//\$\{HOME\}/$HOME}"
WORKFLOWS_USER_PATH="${WORKFLOWS_USER_PATH//\$HOME/$HOME}"
WORKFLOWS_USER_PATH="${WORKFLOWS_USER_PATH/#\~/$HOME}"
GITHUB_PUSH_BRANCH="$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" github push_branch_workflows)"

# get the existing fork when this user has no local checkout
if [[ ! -e "$WORKFLOWS_USER_PATH" && ! -L "$WORKFLOWS_USER_PATH" ]]; then
  github_user="$(timeout 20s gh api user --jq .login)" || exit 0
  is_fork="$(timeout 20s gh api "repos/$github_user/workflows" \
    --jq '.fork and .parent.full_name == "oreolag/workflows"')" || exit 0
  if [ "$is_fork" != "true" ]; then
    exit 0
  fi

  mkdir -p -- "$(dirname "$WORKFLOWS_USER_PATH")"
  timeout 30s env GIT_TERMINAL_PROMPT=0 git clone --quiet \
    --branch "$GITHUB_PUSH_BRANCH" \
    "https://github.com/$github_user/workflows.git" "$WORKFLOWS_USER_PATH" || exit 0
  git -C "$WORKFLOWS_USER_PATH" remote add upstream https://github.com/oreolag/workflows.git
  echo "$GITHUB_PUSH_BRANCH" > "$WORKFLOWS_USER_PATH/GITHUB_PUSH_BRANCH"
fi

# check on local checkout and branch
[[ -d "$WORKFLOWS_USER_PATH/.git" ]] || exit 0
# copy missing helper scripts
for script in git_diff.sh github_pr.sh github_push.sh github_sync.sh; do
  if [[ ! -e "$WORKFLOWS_USER_PATH/$script" && ! -L "$WORKFLOWS_USER_PATH/$script" ]]; then
    cp "$WORKFLOWS_TEMPLATE_PATH/$script" "$WORKFLOWS_USER_PATH/" || exit 1
  fi
done

cd "$WORKFLOWS_USER_PATH"
[[ "$(git branch --show-current)" == "$GITHUB_PUSH_BRANCH" ]] || exit 0

# Creation installs these local files; other uncommitted files block syncing.
changes="$(git status --porcelain --untracked-files=all)"
changes="$(printf '%s\n' "$changes" | sed \
  -e '/^?? GITHUB_PUSH_BRANCH$/d' \
  -e '/^?? git_diff\.sh$/d' \
  -e '/^?? github_pr\.sh$/d' \
  -e '/^?? github_push\.sh$/d' \
  -e '/^?? github_sync\.sh$/d')"
[[ -z "$changes" ]] || exit 0

# Bound network waits at login. Never reset, stash, commit or push user work.
timeout 20s env GIT_TERMINAL_PROMPT=0 git fetch --quiet origin "refs/heads/$GITHUB_PUSH_BRANCH" || exit 0
git merge-base --is-ancestor HEAD FETCH_HEAD || exit 0
git merge --ff-only --quiet FETCH_HEAD || exit 0

# create symlinks for workflows commands
for command in new build program run validate delete; do
  # Remove obsolete links, but never regular files or another user's links.
  for link in "$WORKFLOW_COMMAND_PATH/$command/"*.sh; do
    [[ -L "$link" ]] || continue
    name="$(basename "$link" .sh)"
    source="$WORKFLOWS_USER_PATH/$name/$command.sh"
    if [[ -d "$ODEV_PATH/submodules/workflows/$name" || ! -f "$source" ||
        "$(readlink -f "$link")" != "$(readlink -f "$source")" ]]; then
      sudo -n "$ODEV_PATH/src/rm.sh" "$ODEV_PATH" "$link" || exit 1
    fi
  done

  for directory in "$WORKFLOWS_USER_PATH/"*/; do
    [[ -d "$directory" ]] || continue
    name="$(basename "$directory")"
    [[ -d "$ODEV_PATH/submodules/workflows/$name" ]] && continue
    source="$WORKFLOWS_USER_PATH/$name/$command.sh"
    link="$WORKFLOW_COMMAND_PATH/$command/$name.sh"
    [[ -f "$source" ]] || continue
    [[ -e "$link" || -L "$link" ]] && continue
    sudo -n "$ODEV_PATH/src/ln_s.sh" "$ODEV_PATH" "$source" "$link" || exit 1
  done
done
