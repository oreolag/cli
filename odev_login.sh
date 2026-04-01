#!/usr/bin/env bash
set -euo pipefail

# get path
ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#get username
username=$(getent passwd ${SUDO_UID})
username=${username%%:*}

#check on root
if [ "$username" = "root" ]; then
    exit 1
fi

#get hostname
url="${HOSTNAME}"
hostname="${url%%.*}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
BANNER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths banner)")"
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths cmdb)")"

# print banner
if [ -f "$BANNER_PATH/banner" ]; then
  cat "$BANNER_PATH/banner"
fi

# check on build
is_build=$($ODEV_PATH/src/is_server.sh "$CMDB_PATH" "build")

is_build="0"
if [ "$is_build" = "1" ]; then

else

fi