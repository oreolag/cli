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
build="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "BUILD")"
get="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "GET")"
ifconfig="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "IFCONFIG")"
new="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "NEW")"
program="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "PROGRAM")"
run="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "RUN")"
set="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "SET")"
update="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "UPDATE")"
validate="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "VALIDATE")"
examine="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "EXAMINE")"
workflow="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "WORKFLOW")"

# check on GitHub CLI
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "gh")"
gh_status=""
wf_repo_status=""
pb_repo_status=""
if [[ "$installed" == "1" ]]; then
  logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
  if [[ "$logged_in" == "1" ]]; then
    github_user="$(gh api user --jq .login)"
    gh_status="You are logged into the GitHub CLI as ${bold}$github_user${normal}"

    # check on workflows
    if [ ! -d "$WORKFLOWS_PATH" ]; then
      wf_repo_status="Create a new accelerated workflow with ${bold}odev new workflow${normal}"
    else
      wf_repo_status="Continue working on your workflows in ${bold}$WORKFLOWS_PATH${normal}"
    fi

    # check on playbooks
    if [ ! -d "$PLAYBOOKS_PATH" ]; then
      pb_repo_status="Add a new Ansible playbook with ${bold}odev new playbook${normal}"
    else
      pb_repo_status="Find your playbooks in ${bold}$PLAYBOOKS_PATH${normal}"
    fi
  else
    gh_status="Please authenticate with the GitHub CLI using ${bold}gh auth login${normal}"
  fi
else
  gh_status="Please install the GitHub CLI"
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
is_build=$($ODEV_PATH/src/is_server.sh "$ODEV_PATH" "build")

print_help() {
  echo "The CLI for hetero${italic}genius${normal} computing."
  echo ""
  echo "${bold}USAGE${normal}"
  echo "  odev <command> <subcommand> [flags]"
  echo ""
  echo "${bold}CORE COMMANDS${normal}"
  echo "  build:           $build"
  echo "  examine:         $examine"
  echo "  new:             $new"
  echo "  program:         $program"
  echo "  run:             $run"
  echo "  set:             $set"
  echo "  update:          $update"
  echo "  validate:        $validate"
  echo "  workflow:        $workflow"
  echo ""
  echo "${bold}ADDITIONAL COMMANDS${normal}"
  echo "  get:             $get"
  echo "  ifconfig:        $ifconfig"
  echo ""
  echo "${bold}FLAGS${normal}"
  echo "  -h, --help       Show help for command"
  echo "  -v, --version    Show odev version"
  echo ""
  echo "${bold}EXAMPLES${normal}"
  echo "  $ odev examine"
  echo "  $ odev set mtu"
  echo ""
  echo "${bold}SERVER STATUS${normal}"
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

  # print community repos status
  if [ ! "$wf_repo_status" = "" ] || [ ! "$pb_repo_status" = "" ]; then
    echo ""
    echo "${bold}COMMUNITY REPOSITORIES${normal}"
    if [ ! "$wf_repo_status" = "" ]; then
      echo "  $wf_repo_status"
    fi
    if [ ! "$pb_repo_status" = "" ]; then
      echo "  $pb_repo_status"
    fi
  fi

  echo ""
  echo "${bold}LEARN MORE${normal}"
  echo "  Use ${bold}odev <command> <subcommand> --help${normal} for more information about a command."
  echo "  Read the manual at books.oreol.ch/6/cli"
  #if [ ! "$gh_status" = "" ]; then
  #  echo ""
  #  echo $gh_status
  #fi
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