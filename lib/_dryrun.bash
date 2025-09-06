#!/usr/bin/env bash


# _dryrun: Run command, or print it if debug is on.
# use: _dryrun rm file.txt
debug=false
shew__dryrun() {
  if [[ "${debug:-}" != true ]]; then
    "$@"
  else
    shew__prt "Skipping: ${C_GRAY}${C_ITALIC}$*${C_NC}"
  fi
}
