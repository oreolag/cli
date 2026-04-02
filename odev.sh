#!/usr/bin/env bash
set -euo pipefail

ODEV_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths cmdb)")"

# command descriptions
build="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "BUILD")"
get="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "GET")"
ifconfig="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "IFCONFIG")"
new="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "NEW")"
program="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "PROGRAM")"
run="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "RUN")"
validate="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "VALIDATE")"
examine="$("$ODEV_PATH/src/cmd_description_read.sh" "$ODEV_PATH" "EXAMINE")"

# check on GitHub CLI
installed="$("$ODEV_PATH/src/required_tools_print.sh" "$ODEV_PATH" "gh")"
if [[ "$installed" == "1" ]]; then
  logged_in="$("$ODEV_PATH/src/gh_auth_status.sh")"
  if [[ "$logged_in" == "1" ]]; then
    github_user="$(gh api user --jq .login)"
    gh_status="You are logged in to GitHub CLI as ${bold}$github_user${normal}"
  else
    gh_status="Please use login to GitHub CLI with ${bold}gh auth login${normal}"
  fi
fi

# check on build
is_build=$($ODEV_PATH/src/is_server.sh "$CMDB_PATH" "build")

print_help() {
  echo "The CLI for hetero${italic}genius${normal} computing."
  echo ""
  echo "${bold}USAGE${normal}"
  echo "  odev <command> <subcommand> [flags]"
  echo ""
  echo "${bold}CORE COMMANDS${normal}"
  echo "  build:           $build"
  echo "  new:             $new"
  echo "  program:         $program"
  echo "  run:             $run"
  echo "  validate:        $validate"
  echo "  examine:         $examine"
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
  echo "  $ odev validate nccl"
  echo ""
  echo "${bold}SERVER STATUS${normal}"
  if [ "$is_build" = "0" ]; then
    echo "  This is a ${bold}deployment${normal} server"
  else
    echo "  This is a ${bold}development${normal} server"
  fi
  if [ ! "$gh_status" = "" ]; then
    echo "  $gh_status"
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
  echo "https://github.com/oreolag/cli/releases/tag/v${ver}"
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
  script="${ODEV_PATH}/cmd/${cmd}/${subcmd}.sh"
  shift 2
fi

if [[ ! -x "$script" ]]; then
  echo "Command not found: ${cmd} ${subcmd:-}"
  exit 1
fi

exec "$script" "$@"