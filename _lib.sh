#!/usr/bin/env bash

# set -e

# TODO: if ran directly, exit with warning

function_exists() {
  declare -f "$1" > /dev/null
}

if function_exists "my_function"; then
  _prt "lib already in env!"
else
    _lib_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
    # echo $_lib_dir

    # shellcheck disable=SC1091
    source "$_lib_dir/lib/_colors.sh"
    source "$_lib_dir/lib/_confirm.sh"
    source "$_lib_dir/lib/_debug.sh"
    source "$_lib_dir/lib/_dryrun.sh"
    source "$_lib_dir/lib/_figlet.sh"
    source "$_lib_dir/lib/_filter.sh"
    source "$_lib_dir/lib/_input.sh"
    source "$_lib_dir/lib/_parseargs.sh"
    source "$_lib_dir/lib/_prettyjson.sh"
    source "$_lib_dir/lib/_prt.sh"
    source "$_lib_dir/lib/_spin.sh"
    source "$_lib_dir/lib/_write.sh"
    source "$_lib_dir/lib/_colors.sh"

    source "$_lib_dir/lib/__ttyhelp.sh"

    # ========================

    lib::_setupcolors
fi


