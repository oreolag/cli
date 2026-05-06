#!/usr/bin/env bash
set -euo pipefail

# get path
ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
COLOR_NVIDIA=$($ODEV_PATH/src/constant_get.sh $ODEV_PATH COLOR_NVIDIA)

# nvidia-smi
tool="nvidia-smi"
is_installed=$($ODEV_PATH/src/required_tools_print.sh "$ODEV_PATH" "$tool")
if [ "$is_installed" = "1" ]; then
    gpus=$(nvidia-smi --query-gpu=name --format=csv,noheader \
        | sort | uniq -c \
        | awk '{$1=$1; print}' \
        | paste -sd ', ' -)
    driver=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader | head -n1)
    cuda=$(nvidia-smi | grep "CUDA Version" | awk '{print $9}')

    echo -e "${COLOR_NVIDIA}  $tool${normal}"
    echo "  GPUs            : ${bold}$gpus${normal}"
    echo "  Driver          : ${bold}$driver${normal}"
    echo "  CUDA            : ${bold}$cuda${normal}"
fi

echo ""