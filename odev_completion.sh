#!/usr/bin/env bash
#
# Bash completion for odev
#
# Supports:
#   - Folder-based commands:   /opt/odev/cmd/<cmd>/<subcmd>.sh
#   - Virtual commands:        examine, etc.
#   - Global flags:            --help, --version, ...
#
# Requires:
#   export ODEV_PATH=/opt/odev
#   (or odev available on PATH)

# ------------------------------------------------------------
# Resolve odev root directory
# ------------------------------------------------------------
_odev_script_dir() {
  local odev_path
  odev_path="$(command -v odev 2>/dev/null || true)"

  if [[ -n "${ODEV_PATH:-}" && -d "$ODEV_PATH" ]]; then
    echo "$ODEV_PATH"
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
# Load flags definitions (command_flags.sh or cmd_flags.sh)
# ------------------------------------------------------------
_odev_source_flags() {
  local base="$1"

  if [[ -f "$base/src/command_flags.sh" ]]; then
    # shellcheck source=/dev/null
    source "$base/src/command_flags.sh"
    return 0
  fi

  if [[ -f "$base/src/cmd_flags.sh" ]]; then
    # shellcheck source=/dev/null
    source "$base/src/cmd_flags.sh"
    return 0
  fi

  return 0
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

  _odev_source_flags "$base"

  # -----------------------------
  # Global flags (only at top-level: odev --<TAB>)
  # -----------------------------
  if [[ $cword -eq 1 && "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "--help -h --version -v" -- "$cur") )
    return 0
  fi

  # -----------------------------
  # Top-level commands (odev <TAB>)
  # -----------------------------
  if [[ $cword -eq 1 ]]; then
    local extra_cmds="examine"
    local cmds
    cmds="$(_odev_list_commands "$root") $extra_cmds"
    COMPREPLY=( $(compgen -W "$cmds" -- "$cur") )
    return 0
  fi

  # -----------------------------
  # Subcommands (odev <cmd> <TAB>)
  # -----------------------------
  if [[ $cword -eq 2 ]]; then
    local cmd="${words[1]}"
    COMPREPLY=( $(compgen -W "$(_odev_list_subcommands "$root" "$cmd")" -- "$cur") )
    return 0
  fi

  # -----------------------------
  # Subcommand flags (odev <cmd> <subcmd> --<TAB>)
  # -----------------------------
  if [[ $cword -ge 3 && "$cur" == -* ]]; then
    local cmd="${words[1]}"
    local subcmd="${words[2]}"

    # build uppercase variable name: e.g. VALIDATE_NCCL_FLAGS
    local cmd_u sub_u varname
    cmd_u="$(printf '%s' "$cmd" | tr '[:lower:]' '[:upper:]')"
    sub_u="$(printf '%s' "$subcmd" | tr '[:lower:]' '[:upper:]')"
    varname="${cmd_u}_${sub_u}_FLAGS"

    # Pull array by name robustly
    local -a flags=()
    if eval "[[ \${#${varname}[@]} -gt 0 ]]"; then
      eval "flags=(\"\${${varname}[@]}\")"
    fi

    local -a opts=()
    local entry name short rest
    for entry in "${flags[@]}"; do
      # entry format: "name,short,Description,range,default"
      IFS=',' read -r name short rest <<< "$entry"
      [[ -n "$name" ]] && opts+=("--$name")
      [[ -n "$short" ]] && opts+=("-$short")
    done

    # Only include help here (do NOT inject --version for subcommands)
    opts+=(--help -h)

    # de-dup
    local -A seen=()
    local -a uniq_opts=()
    local o
    for o in "${opts[@]}"; do
      [[ -n "$o" && -z "${seen[$o]:-}" ]] || continue
      uniq_opts+=("$o")
      seen["$o"]=1
    done

    COMPREPLY=( $(compgen -W "${uniq_opts[*]}" -- "$cur") )
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