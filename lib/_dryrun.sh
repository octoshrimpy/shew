#! /usr/bin/env bash

# _dryrun: Run command, or print it if debug is on.
# use: _dryrun rm file.txt
debug=false
_dryrun() {
  if [ "$debug" != true ]; then
    "$@"
  else
    _prt "Skipping: ${C_GRAY}${C_ITALIC}$*${C_NC}"
  fi
}
