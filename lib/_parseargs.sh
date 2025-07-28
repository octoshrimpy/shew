#! /usr/bin/env bash

# parsing flag arguments
function _parseargs() {
  _debug _prtty "parsing $1"

  # ensure $2 exists and isn’t another flag
  if [[ $# -ge 2 && "$2" != -* ]]; then
    echo "$2"
  else
    _prtty -e "${C_BLUE}${C_ITALIC}$1${C_NC} requires a value"  >&2
    return 1
  fi
}
