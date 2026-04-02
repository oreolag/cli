#!/usr/bin/env bash
set -euo pipefail

# get path
ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODEV_PATH="$ODEV_PATH/odev"

# constants
#BANNER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths banner)")"
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths cmdb)")"
COLOR_OREOL=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_OREOL)

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

# print banner
#if [ -f "$BANNER_PATH/banner" ]; then
#  cat "$BANNER_PATH/banner"
#fi

echo ""

# run examine silently
echo -ne "${COLOR_OREOL}Starting odev${normal}"
"$ODEV_PATH/cmd/examine.sh" > /dev/null 2>&1 &
pid=$!
while kill -0 "$pid" 2>/dev/null; do
  echo -ne "${COLOR_OREOL}.${normal}"
  sleep 0.5
done
wait "$pid"
echo ""

#print welcome message (1/2)
echo ""
echo "Welcome, ${bold}$username!${normal}"
echo ""

sleep 0.5

# print operating system information (similar to odev examine)
. /etc/os-release
echo "${bold}${NAME} ${VERSION}${normal}"
description=$(lsb_release -d | awk -F'\t' '{print $2}' | sed 's/^[^0-9]*//')
codename=$(lsb_release -c | awk -F':' '{print $2}' | xargs)
linux_kernel=$(uname -r)
uptime_info=$(uptime -p)
echo "Description : ${bold}$description${normal}"
echo "Codename    : ${bold}$codename${normal}"
echo "Linux kernel: ${bold}$linux_kernel${normal}"
echo "Uptime      : ${bold}$uptime_info${normal}"
echo ""

# check on build
is_build=$($ODEV_PATH/src/is_server.sh "$CMDB_PATH" "build")

# run 
if [ "$is_build" = "1" ]; then
  $ODEV_PATH/src/odev_login_build.sh
else
  $ODEV_PATH/src/odev_login_deployment.sh
fi

sleep 0.5

#print welcome message (2/2)
weekday=$(date +%A)
echo "Have a nice ${bold}$weekday!${normal}"
echo ""