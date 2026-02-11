#!/bin/bash

# usage:       $CLI_PATH/hdev validate opennic --commit $commit_name_shell $commit_name_driver --device $device_index --fec $fec_option --version $vivado_version
# example: /opt/hdev/cli/hdev validate opennic --commit            8077751             1cf2578 --device             1 --fec 1           --version          2022.2

# get script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKFLOW="$(basename "${BASH_SOURCE[0]}" .sh)"

# derive from SCRIPT_DIR
CLI_NAME="$(basename "$(dirname "$(dirname "$SCRIPT_DIR")")")"
COMMAND="$(basename "$SCRIPT_DIR")"
ODEV_PATH="${ODEV_PATH:-"$(dirname "$SCRIPT_DIR")"}"

# format
bold=$(tput bold)
italic=$(tput sitm 2>/dev/null || true)
normal=$(tput sgr0)

# command description and parameters
COMMAND_DESCRIPTION="Validate NCCL"
PARAMS=(
  "ngpus,g,Number of GPUs,1-10,1"
  "nthreads,t,Number of Threads,1-1024,10"
  "minbytes,b,Minimum Bytes,1B-1G,8M"
  "maxbytes,e,Maximum Bytes,1B-16G,100M"
)

declare -A V

# init defaults
for p in "${PARAMS[@]}"; do
  IFS=',' read -r name short def desc <<< "$p"
  V["$name"]="$def"
done

# help formatting toggles (0|1)
print_range=1
print_default=1
print_range_and_default=1  # if 1, overrides the two above and prints both when available

print_help() {
  echo "$COMMAND_DESCRIPTION"
  echo ""
  echo "${bold}USAGE:${normal}"
  echo "  $CLI_NAME $COMMAND $WORKFLOW [flags]"
  echo ""
  echo "${bold}FLAGS:${normal}"
  for p in "${PARAMS[@]}"; do
    IFS=',' read -r name short desc range def <<< "$p"

    suffix=""
    if [[ "${print_range_and_default:-0}" == "1" ]]; then
      if [[ -n "$range" && -n "$def" ]]; then
        suffix=" (range: $range, default: $def)"
      elif [[ -n "$range" ]]; then
        suffix=" (range: $range)"
      elif [[ -n "$def" ]]; then
        suffix=" (default: $def)"
      fi
    else
      if [[ "${print_range:-0}" == "1" && -n "$range" ]]; then
        suffix+=" (range: $range)"
      fi
      if [[ "${print_default:-0}" == "1" && -n "$def" ]]; then
        if [[ -n "$suffix" ]]; then
          suffix="${suffix%)}"
          suffix+=", default: $def)"
        else
          suffix=" (default: $def)"
        fi
      fi
    fi

    printf "  -%-1s, --%-10s %-1s%s\n" \
      "$short" "$name" "$desc" "$suffix"
  done
  echo ""
  echo "${bold}INHERITED FLAGS:${normal}"
  echo "  -h, --help      Show this help"
}

# parse
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help) print_help; exit 0 ;;
  esac

  matched=false
  for p in "${PARAMS[@]}"; do
    IFS=',' read -r name short def desc <<< "$p"
    if [[ "$1" == "--$name" || "$1" == "-$short" ]]; then
      V["$name"]="${2:-}"
      shift 2
      matched=true
      break
    fi
  done

  if [[ "$matched" == false ]]; then
    echo "Unknown option: $1"
    exit 1
  fi
done

# Example: print received values
echo "ngpus=${V[ngpus]}"
echo "minbytes=${V[minbytes]}"

echo "hola"
exit


# early exit
url="${HOSTNAME}"
hostname="${url%%.*}"

# constants
CMDB_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths cmdb)")"
PROJECTS_PATH="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$ODEV_PATH/constants.yml" paths projects)")"
VALIDATION_PROJECT_PATH="$PROJECTS_PATH/validate.$WORKFLOW.$hostname"

# derived
MPI_HOME="$(eval echo "$("$ODEV_PATH/src/read_yml.py" --db "$CMDB_PATH/vars.yml" mpi home)")"

# create folders
rm -rf "$VALIDATION_PROJECT_PATH"
mkdir -p "$VALIDATION_PROJECT_PATH"

# copy files from template
cp -r "$ODEV_PATH/templates/nvidia/nccl-tests/." "$VALIDATION_PROJECT_PATH"

# build tets (for local tests, MPI flag is not needed)
cd "$VALIDATION_PROJECT_PATH"
make MPI=1 MPI_HOME=$MPI_HOME

# run
#cd "$VALIDATION_PROJECT_PATH/build"
#./all_gather_perf -g 1 -b 8M -e 1G -f 2