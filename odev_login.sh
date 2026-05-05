#!/usr/bin/env bash
set -euo pipefail

# get path
ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ODEV_PATH="$ODEV_PATH/odev"

# constants
BANNER_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths banner)")"
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths cmdb)")"
COLOR_OREOL=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_OREOL)
STORAGE_UNIT="TB"

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
if [ -f "$BANNER_PATH/odev_banner.sh" ]; then
  $BANNER_PATH/odev_banner.sh
fi

# similar to odev examine
os_print() {
  # print operating system information
  . /etc/os-release
  echo "  Operating system: ${bold}${NAME} ${VERSION}${normal}"
  description=$(lsb_release -d | awk -F'\t' '{print $2}' | sed 's/^[^0-9]*//')
  codename=$(lsb_release -c | awk -F':' '{print $2}' | xargs)
  linux_kernel=$(uname -r)
  uptime_info=$(uptime -p)
  echo "  Description     : ${bold}$description${normal}"
  echo "  Codename        : ${bold}$codename${normal}"
  echo "  Linux kernel    : ${bold}$linux_kernel${normal}"
  echo "  Uptime          : ${bold}$uptime_info${normal}"
  echo ""
}

cmdb_print() {
    local topo="$1"
    local cmdb="$2"

    if [[ -z "$cmdb" && -z "$topo" ]]; then
        echo "na"
    elif [[ -n "$cmdb" && "$cmdb" == "$topo" ]]; then
        echo "$cmdb"
    else
        # topo wins
        local val="${topo:-$cmdb}"
        printf "%b%s%b\n" "$italic" "$val" "$normal"
    fi
}

cpu_print() {
  # CPU model
#  model_name_system=$($CMDB_PATH/cmdb_get_model.sh)
  model_name_system=$($ODEV_PATH/src/cmdb_get_model.sh)
  model_name_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu model)
  model_name=$(cmdb_print "$model_name_system" "$model_name_cmdb")

  # CPU count
  #cpu_count_system=$($CMDB_PATH/cmdb_get_cpu.sh)
  cpu_count_system=$($ODEV_PATH/src/cmdb_get_cpu.sh)
  cpu_count_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu count)
  cpu_count=$(cmdb_print "$cpu_count_system" "$cpu_count_cmdb")

  # total memory
  #total_memory_system=$($CMDB_PATH/cmdb_get_memory.sh)
  total_memory_system=$($ODEV_PATH/src/cmdb_get_memory.sh)
  total_memory_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu memory)
  total_memory=$(cmdb_print "$total_memory_system" "$total_memory_cmdb")

  # total storage
  #total_storage_system=$($CMDB_PATH/cmdb_get_storage.sh "$STORAGE_UNIT")
  total_storage_system=$($ODEV_PATH/src/cmdb_get_storage.sh "$STORAGE_UNIT")
  total_storage_cmdb=$($ODEV_PATH/src/cmdb_get.py --db $CMDB_PATH/$hostname.yml cpu storage)
  total_storage=$(cmdb_print "$total_storage_system" "$total_storage_cmdb")

  # print CPU information
  echo "  CPU model       : ${bold}$model_name${normal}"
  echo "  CPU(s)          : ${bold}$cpu_count${normal}"
  echo "  Total memory    : ${bold}$total_memory${normal}"
  echo "  Total storage   : ${bold}$total_storage${normal}"
  echo ""
}

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

# check on build
is_build=$($ODEV_PATH/src/is_server.sh "$ODEV_PATH" "build")

# run 
if [ "$is_build" = "1" ]; then
  echo "This is a ${bold}development${normal} server:"
  echo ""
  os_print
  cpu_print
  $ODEV_PATH/src/odev_login_build.sh
else
  echo "This is a ${bold}deployment${normal} server:"
  echo ""
  os_print
  cpu_print
  $ODEV_PATH/src/odev_login_deployment.sh
fi

sleep 0.5

#print welcome message (2/2)
weekday=$(date +%A)
echo "Have a nice ${bold}$weekday!${normal}"
echo ""