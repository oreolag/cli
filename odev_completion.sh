#!/usr/bin/env bash
#
# Bash completion for odev
#

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
# Load flags definitions
# ------------------------------------------------------------
_odev_source_flags() {
  local base="$1"

  if [[ -f "$base/src/command_flags.sh" ]]; then
    # shellcheck source=/dev/null
    source "$base/src/command_flags.sh"
    return 0
  fi

  if [[ -f "$base/src/commands.sh" ]]; then
    # shellcheck source=/dev/null
    source "$base/src/commands.sh"
    return 0
  fi

  return 0
}

# ------------------------------------------------------------
# Completion function
# ------------------------------------------------------------
_odev_completions() {

  # only allow odev-users (similar to is_member.sh)
  if ! getent group "odev-users" | grep -q "$USER"; then
    COMPREPLY=()
    return 0
  fi

  local cur prev words cword
  _init_completion -n : || return

  local base root
  base="$(_odev_script_dir)"
  root="$base/cmd"

  _odev_source_flags "$base"

  # -----------------------------
  # Global flags (odev --<TAB>)
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
  # Always offer --help/-h for top-level commands (odev <cmd> --<TAB>)
  # -----------------------------
  if [[ $cword -eq 2 && "$cur" == -* ]]; then
    COMPREPLY=( $(compgen -W "--help -h" -- "$cur") )
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

    # Build option lists and maps
    local -a opts=()
    declare -A long_to_short=()
    declare -A short_to_long=()

    local entry name short rest
    for entry in "${flags[@]}"; do
      # entry format: "name,short,Description,range,default"
      IFS=',' read -r name short rest <<< "$entry"
      if [[ -n "$name" ]]; then
        opts+=("--$name")
      fi
      if [[ -n "$short" ]]; then
        opts+=("-$short")
      fi
      # mappings for exclusion later
      if [[ -n "$name" && -n "$short" ]]; then
        long_to_short["$name"]="$short"
        short_to_long["$short"]="$name"
      fi
    done

    # Collect flags already present in the command line (words[1]..words[cword-1])
    declare -A used=()
    local i w key stripped other_used=false help_used=false
    for (( i=1; i < cword; i++ )); do
      w="${words[i]}"
      # long form --foo or --foo=bar
      if [[ "$w" == --* ]]; then
        # strip leading -- and any =value
        stripped="${w#--}"
        key="${stripped%%=*}"
        used["--$key"]=1
        # if we know a short alias, mark it used too
        if [[ -n "${long_to_short[$key]:-}" ]]; then
          used["-${long_to_short[$key]}"]=1
        fi
        # mark that a non-help flag has been used
        if [[ "$key" != "help" ]]; then
          other_used=true
        else
          help_used=true
        fi
      elif [[ "$w" == -? ]]; then
        # short form -x
        key="${w#-}"
        used["-$key"]=1
        # if we know long alias, mark long used too
        if [[ -n "${short_to_long[$key]:-}" ]]; then
          used["--${short_to_long[$key]}"]=1
          if [[ "${short_to_long[$key]}" != "help" ]]; then
            other_used=true
          else
            help_used=true
          fi
        else
          # plain short (not mapped), treat it as "other used" unless it's -h
          if [[ "$key" != "h" ]]; then
            other_used=true
          else
            help_used=true
          fi
        fi
      fi
      # Note: combined shorts (e.g. -ab) are not specially parsed here.
    done

    # If help was used, do not offer any other flags (and don't re-offer help)
    if [[ "$help_used" = true ]]; then
      COMPREPLY=()
      return 0
    fi

    # Only include --help/-h if no other flags are present so far
    if [[ "$other_used" = false ]]; then
      opts+=(--help -h)
    fi

    # Filter out used options
    local -a filtered=()
    local o
    for o in "${opts[@]}"; do
      [[ -n "${used[$o]:-}" ]] && continue
      filtered+=("$o")
    done

    # remove duplicates (stable)
    local -A seen=()
    local -a uniq_opts=()
    for o in "${filtered[@]}"; do
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