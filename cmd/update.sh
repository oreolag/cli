#!/bin/bash

# example: odev update

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMMAND="-"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$SCRIPT_DIR")")"
SUBCOMMAND="update"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# get hostname
url="${HOSTNAME}"
hostname="${url%%.*}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
COLOR_PASSED=$($ODEV_PATH/src/color_get.sh $ODEV_PATH COLOR_PASSED)
ODEV_REPO="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" github odev_repo)")"
TMP_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths tmp)")"

# check on users
is_odev_admins=$($ODEV_PATH/src/is_member.sh $USER odev-admins)
if [ "$is_odev_admins" = "0" ]; then
  echo "Permission denied: $USER"
  exit 1
fi

# check on tools
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "gh")"
if [[ "$installed" == "0" ]]; then
  echo "Missing tool: $tool"
fi

# set KEY
KEY="$(printf '%s' "$SUBCOMMAND" | tr '[:lower:]' '[:upper:]')"

# read command description, command flags
command_description="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "$KEY")"
mapfile -t flags < <("$ODEV_PATH/src/cmd_flags_read.sh" "$ODEV_PATH" "$KEY")

# (maybe) print help
print_range="0"
print_default="0"
print_both="0"
"$ODEV_PATH/src/cmd_help_print.sh" --maybe \
  "$CLI_NAME" "$COMMAND" "$SUBCOMMAND" "$command_description" \
  "$print_range" "$print_default" "$print_both" \
  "${flags[@]}" -- "$@" && exit 0 || true

# parse and assign flags
flag=$1

# check on flags
if [[ -n "$flag" && "$flag" != "--main" && "$flag" != "-m" ]]; then
    echo "Unknown flag: $flag"
    exit 1
fi

# set command flags
# ...

# derived
CHECKOUT_PATH="$TMP_PATH/odev"

# remove first
rm -rf -- "$CHECKOUT_PATH"

# repository checkout
msg=""
if [[ "$flag" == "--main" ]] || [[ "$flag" == "-m" ]]; then
  git clone --branch main "$ODEV_REPO" "$CHECKOUT_PATH"
  msg="${COLOR_PASSED}✓${normal} odev updated: main"
else
  tag="$(gh release view --repo oreolag/cli --json tagName -q .tagName)"

  if [[ -z "$tag" ]]; then
    tag="$(git ls-remote --tags "$ODEV_REPO" | awk -F/ '{print $3}' | sort -V | tail -n1)"
  fi

  git clone --branch "$tag" "$ODEV_REPO" "$CHECKOUT_PATH"
  msg="${COLOR_PASSED}✓${normal} odev updated: $tag"
fi

# get submodules
git -C "$CHECKOUT_PATH" submodule update --init --recursive

# top level files
for f in LICENSE README.md RELEASE_DATE VERSION cli-removebg.png constants.yml odev_completion.sh submodules_update.sh; do
  if [[ -f "$CHECKOUT_PATH/$f" ]]; then
    sudo cp -f -- "$CHECKOUT_PATH/$f" "$ODEV_PATH/$f"
  fi
done

# compile and copy odev
chmod +x "$CHECKOUT_PATH/odev.sh"
mv "$CHECKOUT_PATH/odev.sh" "$CHECKOUT_PATH/odev"
sudo cp -f -- "$CHECKOUT_PATH/odev" "$ODEV_PATH/odev"

# cmd (keep user symlinks)
sudo mv "$ODEV_PATH/cmd" "$ODEV_PATH/cmd_tmp"
sudo cp -a "$CHECKOUT_PATH/cmd" "$ODEV_PATH/cmd"
folders=(new build program run validate delete)
for dir in "${folders[@]}"; do
  src="$ODEV_PATH/cmd_tmp/$dir"
  dst="$ODEV_PATH/cmd/$dir"
  [[ -d "$src" ]] || continue
  find "$src" -maxdepth 1 -type l | while read -r link; do
    target="$(readlink "$link")"
    # user symlinks do NOT start with ../../
    if [[ "$target" != ../../* ]]; then
      name="$(basename "$link")"
      if [[ ! -e "$dst/$name" ]]; then
        sudo cp -a "$link" "$dst/$name"
      fi
    fi
  done
done
sudo rm -rf -- "$ODEV_PATH/cmd_tmp"

# src
sudo rm -rf -- "$ODEV_PATH/src"
sudo cp -a "$CHECKOUT_PATH/src" "$ODEV_PATH/src"

# submodules
sudo rm -rf -- "$ODEV_PATH/submodules"
sudo cp -a "$CHECKOUT_PATH/submodules" "$ODEV_PATH/submodules"

# templates
sudo rm -rf -- "$ODEV_PATH/templates"
sudo cp -a "$CHECKOUT_PATH/templates" "$ODEV_PATH/templates"

# Install completion (system-wide)
sudo install -o root -g root -m 0644 \
  "$ODEV_PATH/odev_completion.sh" \
  /usr/share/bash-completion/completions/odev

# Add extended capabilities
sudo install -o root -g root -m 0440 \
  "$ODEV_PATH/src/odev-users" \
  /etc/sudoers.d/odev-users

sudo install -o root -g root -m 0440 \
  "$ODEV_PATH/src/odev-developers" \
  /etc/sudoers.d/odev-developers

sudo install -o root -g root -m 0440 \
  "$ODEV_PATH/src/odev-admins" \
  /etc/sudoers.d/odev-admins

# consolidate ownership
sudo chown -R root:root "$ODEV_PATH"

# print 
echo -e "$msg"

# author: https://github.com/jmoya82