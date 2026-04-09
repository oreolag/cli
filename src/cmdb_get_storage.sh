#!/usr/bin/env bash
set -euo pipefail

unit="${1:-GB}"
numa_index="${2:-}"

total_bytes=0

if [ -z "$numa_index" ]; then
    # total storage
    for d in /sys/block/nvme*n1; do
        [[ -f "$d/size" ]] || continue
        sectors=$(<"$d/size")
        total_bytes=$(( total_bytes + sectors*512 ))
    done

else
    if command -v lstopo-no-graphics >/dev/null 2>&1; then
        lstopo_cmd="lstopo-no-graphics 2>/dev/null"
    elif command -v lstopo >/dev/null 2>&1; then
        lstopo_cmd="lstopo --no-graphics 2>/dev/null"
    else
        total_bytes=0
    fi

    devs=$(
        eval "$lstopo_cmd" | awk -v i="$numa_index" '
          $0 ~ ("NUMANode L#" i) {f=1; next}
          f && $0 ~ /^NUMANode L#/ {exit}
          f { print }
        ' 2>/dev/null | sed -nE 's/.*Block\(Disk\)[[:space:]]+"([^"]+)".*/\1/p'
    )

    for dev in $devs; do
        dev_name="${dev##*/}"
        sys_path="/sys/block/$dev_name/size"
        [[ -f "$sys_path" ]] || continue
        sectors=$(<"$sys_path")
        total_bytes=$(( total_bytes + sectors * 512 ))
    done
fi

# ---- single output block ----
case "$unit" in
    B)  printf "%sB\n"  "$total_bytes" ;;
    KB) printf "%.0fKB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024}')" ;;
    MB) printf "%.0fMB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024}')" ;;
    GB) printf "%.0fGB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024/1024}')" ;;
    TB) printf "%.1fTB\n" "$(awk -v b="$total_bytes" 'BEGIN{print b/1024/1024/1024/1024}')" ;;
    *)  printf "%s\n" "$total_bytes" ;;
esac