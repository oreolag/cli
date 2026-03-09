#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   workflow_commands_read.sh <ODEV_PATH> <KEY>
# Output:
#   subcommand: Description (one per line)
#
# Example:
#   workflow_commands_read.sh /opt/odev NEW
#   vllm:        Creates a vLLM project
#   hugging:     Creates a Hugging Face project

ODEV_PATH="$1"
KEY="$2"

# shellcheck source=/dev/null
source "$ODEV_PATH/src/cmd_spec.sh"

# gather variable names that start with "${KEY}_"
mapfile -t vars < <(compgen -v "${KEY}_" | sort)

for v in "${vars[@]:-}"; do
  if [[ "$v" =~ ^${KEY}_(.+)_DESCRIPTION$ ]]; then
    suffix="${BASH_REMATCH[1]}"
    # normalize name: lowercase and replace underscores with hyphens
    name="${suffix,,}"
    name="${name//_/-}"
    # indirect expansion to fetch the description value
    desc="${!v}"
    [[ -n "$desc" ]] || continue
    printf "%-12s %s\n" "${name}:" "$desc"
  fi
done

exit 0