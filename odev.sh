#!/usr/bin/env bash
set -euo pipefail

export ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# early exit
is_odev_user=$($ODEV_PATH/src/is_member.sh $USER odev-users)
if [ "$is_odev_user" = "0" ]; then
  exit 1
fi

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# constants
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths cmdb)")"
PLAYBOOKS_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths playbooks)")"
WORKFLOWS_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/vars.yml" paths workflows)")"

# command descriptions
command_descriptions="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "ALL")"
while IFS='=' read -r key description; do
  printf -v "$key" '%s' "$description"
done <<< "$command_descriptions"

# check on GitHub CLI
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "gh")"
gh_status=""
wf_repo_status=""
pb_repo_status=""
if [[ "$installed" == "1" ]]; then
  logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
  if [[ "$logged_in" == "1" ]]; then
    github_user="$(gh api user --jq .login 2>/dev/null)" || github_user=""
    if [[ -n "$github_user" ]]; then
      gh_status="You are logged into the GitHub CLI as ${bold}$github_user${normal}"
    fi

    # check on workflows
    #if [ ! -d "$WORKFLOWS_PATH" ]; then
    #  wf_repo_status="Create a new accelerated workflow with ${bold}odev new workflow${normal}"
    #else
    #  wf_repo_status="Continue working on your workflows in ${bold}$WORKFLOWS_PATH${normal}"
    #fi

    # check on playbooks
    #if [ ! -d "$PLAYBOOKS_PATH" ]; then
    #  pb_repo_status="Add a new Ansible playbook with ${bold}odev new playbook${normal}"
    #else
    #  pb_repo_status="Find your playbooks in ${bold}$PLAYBOOKS_PATH${normal}"
    #fi
  else
    gh_status="Please authenticate with the GitHub CLI using ${bold}gh auth login${normal}"
  fi
else
  gh_status="Please install the GitHub CLI"
fi

# check on community repositories
# workflows
if [ ! -d "$WORKFLOWS_PATH" ]; then
  wf_repo_status="Create a new accelerated workflow with ${bold}odev new workflow${normal}"
else
  wf_repo_status="Continue working on your workflows in ${bold}$WORKFLOWS_PATH${normal}"
fi

# playbooks
if [ ! -d "$PLAYBOOKS_PATH" ]; then
  pb_repo_status="Add a new Ansible playbook with ${bold}odev new playbook${normal}"
else
  pb_repo_status="Find your playbooks in ${bold}$PLAYBOOKS_PATH${normal}"
fi

# check on tailscale
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "tailscale")"
ts_status=""
if [[ "$installed" == "1" ]]; then
  logged_in="$("$ODEV_PATH/src/tailscale_auth_status.sh")"
  if [[ "$logged_in" == "1" ]]; then
    ts_user="$(tailscale whoami 2>/dev/null | awk '/^User:/ {user=1; next} user && $1 == "Name:" {print $2; exit}')" || ts_user=""
    if [[ -n "$ts_user" ]]; then
      ts_status="Tailscale is connected as ${bold}$ts_user${normal}"
    #else
    #  ts_status="Tailscale is connected"
    fi
  else
    ts_status="Tailscale is not connected. Log in to start using ${bold}sudo tailscale up --ssh${normal}"
  fi
else
  ts_status="Please install the Tailscale CLI"
fi

# check on build
# Booking status is optional; configuration errors must not disable other commands.
if ! is_booking=$("$ODEV_PATH/src/is_server.sh" "$ODEV_PATH" "booking"); then
  is_booking=0
fi
is_build=$($ODEV_PATH/src/is_server.sh "$ODEV_PATH" "build")

print_booking_status() {
  if [[ "$is_booking" != "1" ]]; then
    return
  fi

  local availability total free server red="" strong="" reset=""
  if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
    strong="$bold"
    reset="$normal"
  fi
  if availability="$(timeout 2s python3 "$ODEV_PATH/booking/client.py" --odev-path "$ODEV_PATH" \
    --availability 2>/dev/null)"; then
    IFS=$'\t' read -r total free server <<< "$availability"
    printf '  The booking service is %sup and running%s.' "$strong" "$reset"
    if [[ "$total" == 0 ]]; then
      :
    elif [[ "$free" == "$total" ]]; then
      printf ' %sAll servers are free%s.' "$strong" "$reset"
    elif [[ "$free" == 0 ]]; then
      printf ' %sAll servers are booked%s.' "$strong" "$reset"
    elif [[ "$free" == 1 ]]; then
      printf ' Only %s%s%s is free.' "$strong" "$server" "$reset"
    else
      printf ' %s%s of %s servers are free%s.' "$strong" "$free" "$total" "$reset"
    fi
    printf '\n'
  else
    if [[ -t 1 && "${TERM:-dumb}" != "dumb" ]]; then
      red="$("$ODEV_PATH/src/constant_get.sh" "$ODEV_PATH" COLOR_FAILED)"
    fi
    printf '  The booking service is %s%bunavailable%s.\n' "$strong" "$red" "$reset"
  fi
}

print_help() {
  echo "The CLI for hetero${italic}genius${normal} computing."
  echo ""
  echo "${bold}USAGE${normal}"
  echo "  odev <command> <subcommand> [flags]"
  echo ""
  echo "${bold}CORE COMMANDS${normal}"
  echo "  build:           $build"
  echo "  examine:         $examine"
  echo "  gh:              $gh_description"
  echo "  new:             $new"
  echo "  program:         $program"
  echo "  run:             $run"
  echo "  set:             $set"
  echo "  update:          $update"
  echo "  validate:        $validate"
  echo ""
  echo "${bold}ADDITIONAL COMMANDS${normal}"
  echo "  booking:         List, add, share or cancel bookings"
  echo "  get:             $get"
  echo "  ifconfig:        $ifconfig"
  echo ""
  echo "  ${italic}Type odev followed by a space, then press Tab to explore commands.${normal}"
  echo ""
  echo "${bold}FLAGS${normal}"
  echo "  -h, --help       Show help for command"
  echo "  -v, --version    Show odev version"
  echo ""

  # print community repos status
  echo "${bold}COMMUNITY REPOSITORIES${normal}"
  #if [ ! "$wf_repo_status" = "" ] || [ ! "$pb_repo_status" = "" ]; then
    #echo "${bold}COMMUNITY REPOSITORIES${normal}"
    if [ ! "$wf_repo_status" = "" ]; then
      echo "  $wf_repo_status"
    fi
    if [ ! "$pb_repo_status" = "" ]; then
      echo "  $pb_repo_status"
    fi
  #fi

  # print server status
  echo ""  
  printf '%s\n' "${bold}SERVER STATUS${normal}"

  # development or deployment
  if [ "$is_build" = "0" ]; then
    echo "  This is a ${bold}deployment${normal} server"
  else
    echo "  This is a ${bold}development${normal} server"
  fi

  # print gh_status
  if [ ! "$gh_status" = "" ]; then
    echo "  $gh_status"
  fi

  # print ts_status
  if [ ! "$ts_status" = "" ]; then
    echo "  $ts_status"
  fi
  print_booking_status

  echo ""
  echo "${bold}EXAMPLES${normal}"
  echo "  $ odev examine"
  echo "  $ odev set mtu"

  echo ""
  echo "${bold}LEARN MORE${normal}"
  echo "  Use ${bold}odev <command> <subcommand> --help${normal} for more information about a command."
  echo "  Read the manual at books.oreol.ch/6/cli"
}

print_version() {
  local ver date

  if [[ -f "$ODEV_PATH/VERSION" ]]; then
    ver="$(cat "$ODEV_PATH/VERSION")"
  else
    ver="unknown"
  fi

  if [[ -f "$ODEV_PATH/RELEASE_DATE" ]]; then
    date="$(cat "$ODEV_PATH/RELEASE_DATE")"
  else
    date="unknown"
  fi

  echo "odev version ${ver} (${date})"
  if [ "$ver" = "main" ]; then
    echo "https://github.com/oreolag/cli/tree/main"
  else
    echo "https://github.com/oreolag/cli/releases/tag/${ver}"
  fi
}

# ------------------------------------------------------------
# Global flags / help / version
# ------------------------------------------------------------
case "${1:-}" in
  ""|-h|--help)
    print_help
    exit 0
    ;;
  -v|--version)
    print_version
    exit 0
    ;;
esac

cmd="${1:-}"
subcmd="${2:-}"

# ------------------------------------------------------------
# Script resolution with flag support
# ------------------------------------------------------------
if [[ -z "$cmd" || "$cmd" == -* ]]; then
  print_help
  exit 0
fi

# Single-command scripts: odev examine [flags]
if [[ -z "$subcmd" || "$subcmd" == -* ]]; then
  script="${ODEV_PATH}/cmd/${cmd}.sh"
  shift 1
else
  script="$("$ODEV_PATH/src/workflow_command_path.sh" "$ODEV_PATH" "$cmd" "$subcmd")" || script=""
  shift 2
fi

if [[ ! -x "$script" ]]; then
  echo "Command not found: ${cmd} ${subcmd:-}"
  exit 1
fi

exec "$script" "$@"
