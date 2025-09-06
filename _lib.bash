#!/usr/bin/env bash

# set -e

# TODO: if ran directly, exit with warning

function_exists() {
  [[ $(declare -f "$1") ]]
}

shew() {
  if [[ $# -lt 1 ]]; then
    printf 'usage: shew <func> [args...]\n' >&2
    return 2
  fi

  local sub=${1//[^[:alnum:]_]/_}
  shift || true

  local fn="shew__${sub}"
  if ! [[ $(declare -F "$fn") ]]; then
    printf 'shew: subcommand not found: %s\n' "$sub" >&2
    return 1
  fi

  "$fn" "$@"
}

if function_exists "my_function"; then
  _prt "lib already in env!"
else
    _lib_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    # echo $_lib_dir

  # shellcheck disable=SC1091
  source "$_lib_dir/lib/_colors.bash"
  source "$_lib_dir/lib/_confirm.bash"
  source "$_lib_dir/lib/_debug.bash"
  source "$_lib_dir/lib/_dryrun.bash"
  source "$_lib_dir/lib/_figlet.bash"
  source "$_lib_dir/lib/_filter.bash"
  source "$_lib_dir/lib/_input.bash"
  source "$_lib_dir/lib/_parseargs.bash"
  source "$_lib_dir/lib/_prettyjson.bash"
  source "$_lib_dir/lib/_prt.bash"
  source "$_lib_dir/lib/_spin.bash"
  source "$_lib_dir/lib/_write.bash"

  source "$_lib_dir/lib/__ttyhelp.bash"

  # ========================

  shew__setupcolors
fi


