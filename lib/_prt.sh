#! /usr/bin/env bash

# _prt: Print message with prefix, colors, and multiline support.
# flags: -w warning, -e error, -s replace prefix with spaces
# use: _prt -w "Check your input"
_prt() {

  local appname="${setappname:-APPNAME}"
  local brcolor="$C_CYAN"
  local txcolor="$C_GRAY"
  local prefix=""
  local input=""
  local silent=false

  # POSIX-compatible flag parsing: checks if $1 starts with a dash (-)
  # instead of using [[ "$1" =~ ^- ]], which is Bash-only.
  # TODO: make case in more readable
  while [ "${1#-}" != "$1" ]; do
    case "$1" in
    -w)
      txcolor="${C_NC}${C_YELLOW}${C_BOLD}"
      prefix="Warn: "
      shift
      ;;
    -e)
      txcolor="${C_NC}${C_RED}${C_BOLD}"
      prefix="Error: "
      shift
      ;;
    -s)
      silent=true
      shift
      ;;
    *) break ;;
    esac
  done

  # If we're in debug mode, adjust styling for visibility
  if [ "${rundebug:-false}" = true ]; then
    brcolor="${C_NC}${C_RED}${C_BOLD}"
    txcolor="${C_NC}${C_RED}${C_BOLD}${C_REVERSE}"
  fi

  # Format the prefix: [ appname ] prefix: message
  local prefix_default="${brcolor}[ ${txcolor}${appname}${C_NC} ${brcolor}] ${txcolor}${prefix}${C_NC}"

  # Prefix space padding: convert appname to an equal-length string of spaces
  # so multiline messages align with the appname block.
  local appname_spaces=""
  # shellcheck disable=SC2034
  for _ in $(printf "%b" "$appname" | fold -w1); do
    appname_spaces+=" "
  done
  local prefix_space="      ${appname_spaces}" # 5-space left margin + appname space

  # Input may be passed as arguments, or piped via stdin
  if (($# > 0)); then
    input="$*"
  elif [[ ! -t 0 ]]; then
    input="$(cat)"
  else
    return 0
  fi

  # POSIX-safe line-by-line iteration over input
  # Note: quoting is critical here. $input may include embedded newlines.
  # This uses printf piped into read loop to preserve formatting.
  local lnc=0
  while IFS= read -r line; do
    if [[ "$silent" = true || $lnc -gt 0 ]]; then
      printf "%b\n" "${prefix_space}${line}${C_NC}"
    else
      printf "%b\n" "${prefix_default}${line}${C_NC}"
    fi
    lnc=$((lnc + 1))
  done <<<"$input"
}

# _prtty: Same as _prt but always writes to terminal.
# use: _prtty -e "Critical failure"
function _prtty() {
  _prt "$@" >/dev/tty
}
