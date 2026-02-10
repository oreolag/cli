#!/usr/bin/env bash

# Bash completion for odev
# Usage:
#   source /path/to/odev_completion.sh
#   complete -F _odev_completions odev
#
# Optional:
#   alias odev="/path/to/odev.sh"

_odev_script_dir() {
  # Best effort: locate directory containing odev.sh
  # 1) If odev is a function/alias, this may not work; use ODEV_ROOT env var then.
  # 2) If installed on PATH as "odev", use its resolved path.
  local odev_path
  odev_path="$(command -v odev 2>/dev/null || true)"

  if [[ -n "${ODEV_ROOT:-}" && -d "$ODEV_ROOT" ]]; then
    echo "$ODEV_ROOT"
    return
  fi

  if [[ -n "$odev_path" && -e "$odev_path" ]]; then
    echo "$(cd "$(dirname "$odev_path")" && pwd)"
    return
  fi

  # Fallback: current directory
  pwd
}

_odev_list_commands() {
  local root="$1"
  # Commands are directories directly under root that contain any *.sh file (or just exist)
  find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

_odev_list_subcommands() {
  local root="$1"
  local cmd="$2"
  find "$root/$cmd" -mindepth 1 -maxdepth 1 -type f -name '*.sh' -printf '%f\n' 2>/dev/null \
    | sed 's/\.sh$//' \
    | sort
}

_odev_completions() {
  local cur prev words cword
  _init_completion -n : || return

  local root
  #root="$(_odev_script_dir)"
  root="$(_odev_script_dir)/cmd"

  # Completing the 1st arg: command
  if [[ $cword -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$(_odev_list_commands "$root")" -- "$cur") )
    return 0
  fi

  # Completing the 2nd arg: subcommand (based on command)
  if [[ $cword -eq 2 ]]; then
    local cmd="${words[1]}"
    COMPREPLY=( $(compgen -W "$(_odev_list_subcommands "$root" "$cmd")" -- "$cur") )
    return 0
  fi

  # After subcommand: no opinion (let bash complete files, etc.)
  return 0
}

# If bash-completion is not loaded, _init_completion won't exist.
# Provide a tiny fallback so this still works in minimal environments.
if ! declare -F _init_completion >/dev/null 2>&1; then
  _init_completion() {
    COMPREPLY=()
    cur="${COMP_WORDS[COMP_CWORD]}"
    prev="${COMP_WORDS[COMP_CWORD-1]}"
    words=("${COMP_WORDS[@]}")
    cword="$COMP_CWORD"
    return 0
  }
fi

complete -F _odev_completions odev