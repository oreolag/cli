#!/usr/bin/env bash
set -euo pipefail

# get path
ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# get username
username="$(id -un)"

# constants
WORKFLOWS_USER_PATH="$1"
WORKFLOW_COMMAND_PATH="$ODEV_PATH/users/$username/workflows"

# check on users and checkout
[[ " $(id -Gn) " == *" odev-developers "* ]] || exit 1
[[ -d "$WORKFLOWS_USER_PATH/.git" ]] || exit 1

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
