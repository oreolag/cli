#!/usr/bin/env bash
set -euo pipefail
ODEV_PATH="$1"
command="$2"
workflow="$3"
[[ "$command" != */* && "$workflow" != */* && "$command" != .* && "$workflow" != .* ]] || exit 1
username="$(id -un)"
shared="$ODEV_PATH/cmd/$command/$workflow.sh"
personal="$ODEV_PATH/users/$username/workflows/$command/$workflow.sh"

# Regular built-ins and community workflows retain precedence.
if [[ -f "$shared" && ! -L "$shared" ]] || [[ -d "$ODEV_PATH/submodules/workflows/$workflow" ]]; then
    printf '%s\n' "$shared"
elif [[ -f "$personal" ]]; then
    printf '%s\n' "$personal"
elif [[ -L "$shared" ]]; then
    # Keep existing personal links usable only by their owning workflow user.
    workflows="$(python3 "$ODEV_PATH/src/odev_path.py" workflows)" || exit 1
    target="$(readlink -f "$shared")" || exit 1
    [[ "$target" == "$(readlink -f "$workflows")/"* ]] || exit 1
    printf '%s\n' "$shared"
else
    exit 1
fi
