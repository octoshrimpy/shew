#! /usr/bin/env bash

# _debug: Run command with rundebug=true if debug is on.
# use: _debug my_func
export rundebug=false
lib::_debug() {
  if [ "$DEBUG" = true ]; then
    rundebug=true
    "$@"
    rundebug=false
  fi
}
