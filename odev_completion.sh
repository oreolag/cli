#!/usr/bin/env bash

# Bash completion for odev
#
# Supports:
#   - Folder-based commands:   /opt/odev/cmd/<cmd>/<subcmd>.sh
#   - Virtual commands:        examine, etc.
#   - Global flags:            --help, --version, ...
#
# Requires:
#   export ODEV_ROOT=/opt/odev
#   (or odev available on PATH)

# ------------------------------------------------------------
# Resolve odev root directory
# ------------------------------------------------------------
_odev_script_dir() {
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

  pwd
}

# ------------------------------------------------------------
# Filesystem-based commands
# ------------------------------------------------------------
_odev_list_commands() {
  local root="$1"
  find "$root" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null | sort
}

_odev_list_subcommands() {
  local root="$1"
  local cmd="$2"
  find "$root/$cmd" -mindepth 1 -maxdepth 1 -type f -name '*.sh' -printf '%f\n' 2>/dev/null \
    | sed 's/\.sh$//' \
    | sort
}

# ------------------------------------------------------------
# Completion function
# ------------------------------------------------------------
_odev_completions() {
  local cur prev words cword
  _init_completion -n : || return

  local base root
  base="$(_odev_script_dir)"
  root="$base/cmd"

  # -----------------------------
  # Global flags
  # -----------------------------
  if [[ $cword -eq 1 && "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "--help -h --version -v" -- "$cur") )
    return 0
  fi

  # -----------------------------
  # Top-level commands
  # -----------------------------
  if [[ $cword -eq 1 ]]; then
    local extra_cmds="examine"
    local cmds

    cmds="$(_odev_list_commands "$root") $extra_cmds"
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return 0
  fi

  # -----------------------------
  # Subcommands
  # -----------------------------
  if [[ $cword -eq 2 ]]; then
    local cmd="${words[1]}"
    COMPREPLY=( $(compgen -W "$(_odev_list_subcommands "$root" "$cmd")" -- "$cur") )
    return 0
  fi

  return 0
}

# ------------------------------------------------------------
# Minimal fallback if bash-completion is not loaded
# ------------------------------------------------------------
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

# ------------------------------------------------------------
# Register completion
# ------------------------------------------------------------
complete -F _odev_completions odev