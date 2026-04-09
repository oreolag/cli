#!/usr/bin/env bash
set -euo pipefail

model_name_lscpu=$(lscpu | awk -F: '/Model name/ {print $2}' | xargs)
if [[ "$model_name_lscpu" == *Cortex-* ]]; then
    model_name_lscpu=$(echo "$model_name_lscpu" | awk '{print $1}')
    model_name_lscpu="ARM $model_name_lscpu"
fi
echo "$model_name_lscpu"