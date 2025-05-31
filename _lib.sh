#!/usr/bin/env bash

set -e

# TODO: if ran directly, exit with warning


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

# _debug: Run command with rundebug=true if debug is on.
# use: _debug my_func
rundebug=false
_debug() {
  if [ "$debug" = true ]; then
    rundebug=true
    "$@"
    rundebug=false
  fi
}

# _prettyjson: Format JSON with jq or a fallback if jq is missing.
# use: echo '{"x":1}' | _prettyjson
_prettyjson() {
  local json_input

  # Read from argument(s) or stdin
  if [ $# -gt 0 ]; then
    json_input="$*"
  else
    json_input=$(cat)
  fi

  # Try using jq if available
  if command -v jq >/dev/null 2>&1; then
    echo "$json_input" | jq .
    return
  fi

  # Fallback: minimal formatter using grep + awk
  echo "$json_input" \
  | grep -Eo '"[^"]*" *(: *([0-9]*|"[^"]*")[^{}\["]*|,)?|[^"\]\[\}\{]*|\{|\},?|\[|\],?|[0-9 ]*,?' \
  | awk '{if ($0 ~ /^[}\]]/ ) offset-=4; printf "%*c%s\n", offset, " ", $0; if ($0 ~ /^[{\[]/) offset+=4}'
}

# _prt: Print message with prefix, colors, and multiline support.
# flags: -w warning, -e error, -s replace prefix with spaces
# use: _prt -w "Check your input"
_prt() {
  local appname="${setappname:-PDBAPI}"
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
      -w) txcolor="${C_BOLD}${C_YELLOW}"; prefix="${C_YELLOW}${C_BOLD}Warn${C_NC}: "; shift ;;
      -e) txcolor="${C_BOLD}${C_RED}"; prefix="${C_RED}${C_BOLD}Error${C_NC}: "; shift ;;
      -s) silent=true; shift ;;
      *) break ;;
    esac
  done

  # If we're in debug mode, adjust styling for visibility
  if [ "$rundebug" = true ]; then
    brcolor="$C_BOLD_RED"
    txcolor="${C_REVERSE}${C_BOLD_RED}"
  fi

  # Format the prefix: [ appname ] prefix: message
  local prefix_default="${brcolor}[ ${txcolor}${appname}${C_NC} ${brcolor}] ${C_NC}${prefix}"

  # Prefix space padding: convert appname to an equal-length string of spaces
  # so multiline messages align with the appname block.
  local appname_spaces=""
  # shellcheck disable=SC2034
  for _ in $(printf "%s" "$appname" | fold -w1); do
    appname_spaces="${appname_spaces} "
  done
  local prefix_space="     ${appname_spaces}"  # 5-space left margin + appname space

  # Input may be passed as arguments, or piped via stdin
  if [ "$#" -gt 0 ]; then
    input="$*"
  else
    while IFS= read -r line; do
      input="${input}${line}"$'\n'
    done
  fi

  # POSIX-safe line-by-line iteration over input
  # Note: quoting is critical here. $input may include embedded newlines.
  # This uses printf piped into read loop to preserve formatting.
  local lnc=0
  printf "%s" "$input" | while IFS= read -r line; do
    if [ "$silent" = true ] || [ "$lnc" -gt 0 ]; then
      printf "%b\n" "${prefix_space}${line}${C_NC}"
    else
      printf "%b\n" "${prefix_default}${line}${C_NC}"
    fi
    lnc=$((lnc + 1))
  done
}

# _prtty: Same as _prt but always writes to terminal.
# use: _prtty -e "Critical failure"
function _prtty() {
  _prt "$@" > /dev/tty
}

# _spin: Animate a spinner while running a command.
# flags: --title str, --spinner type, --show-output
# use: _spin --spinner dots --title "Waiting" do_thing
_spin() {
  printf "\033[?25l"  # hide cursor
  set +m              # disable job control

  local func=""
  local spinner="dots"
  local title=""
  local has_title=false
  local show_output=false
  local fps=0.1
  local frames

  # Parse flags
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --title)       shift; title=$1; has_title=true ;;
      --spinner)     shift; spinner=$1 ;;
      --show-output) show_output=true ;;
      *) func=$1; break ;;
    esac
    shift
  done

  # Default title from func name
  if [ "$has_title" != true ]; then
    title=$(printf "%s" "$func" | tr '_-' ' ')
    title="$(printf "%s" "${title^}") "
  fi

  # Spinner frames
  case "$spinner" in
    line)      frames='| / - \';;
    dots)      frames='⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷';;
    minidots)  frames='⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏';;
    jump)      frames='⢄ ⢂ ⢁ ⡁ ⡈ ⡐ ⡠';;
    pulse)     frames='█ ▓ ▒ ░';;
    points)    frames='∙∙∙ ●∙∙ ∙●∙ ∙∙●';;
    globe)     frames='🌍 🌎 🌏';;
    moon)      frames='🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘';;
    monkey)    frames='🙈 🙉 🙊';;
    meter)     frames='▱▱▱ ▰▱▱ ▰▰▱ ▰▰▰ ▰▰▱ ▰▱▱ ▱▱▱';;
    hamburger) frames='☱ ☲ ☴ ☲';;
    ellipsis)  frames='   .  .. ... .. .   ';;
    *)         frames='| / - \';;
  esac

  # Spinner loop
  start_spinner() {
    local title="$1"
    spinner_running=true
    local i=0

    (
      while [ "$spinner_running" = true ]; do
        set -- $frames
        eval "frame=\${$(($i + 1))}"
        printf "\r\033[K${C_MAGENTA}%s${C_NC} %s" "$frame" "$title"
        i=$(( (i + 1) % $# ))
        sleep "$fps"
      done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID"
  }

  stop_spinner() {
    spinner_running=false
    kill "$SPINNER_PID" 2>/dev/null
    printf "\r\033[K"
  }

  _spin_print() {
    while IFS= read -r line; do
      printf "\r\033[K"
      printf "%b\n" "${C_GRAY}│${C_NC} $line"
    done
  }

  start_spinner "$title"

  if [ "$show_output" = true ]; then
    tmp_fifo=$(mktemp -u)
    mkfifo "$tmp_fifo"
    _spin_print < "$tmp_fifo" &
    spin_pid=$!

    line_count=$(
      "$func" 2>&1 \
      | tee "$tmp_fifo" \
      | wc -l
    )

    wait "$spin_pid"
    rm -f "$tmp_fifo"
  else
    "$func" >/dev/null 2>&1
    line_count=0
  fi

  stop_spinner

  # Done message (with alignment if prior output shown)
  if [ "$line_count" -gt 0 ]; then
    printf "%b\n" "\r\033[K${C_GRAY}╰─ ${C_GREEN}✓${C_NC} $title"
  else
    printf "%b\n" "\r\033[K     ${C_GREEN}✓${C_NC} $title"
  fi

  printf "\033[?25h"  # show cursor
  set -m              # restore job control
}


# parsing flag arguments
function _parseargs() {
  _debug _prtty "parsing $1"
  if [[ -n "$2" && "$2" != -* ]]; then
    echo "$2" # return statement
  else
    _prtty -e "${C_BLUE}${C_ITALIC}$1${C_NC} requires a value"
    exit 1
  fi  
}

# remove color from outputs we can't control (gum, etc)
function _stripcolors() {

  local input
  # Check if there are arguments
  if [ "$#" -gt 0 ]; then
      input="$*"
  else
      # Read from stdin
      while IFS= read -r line; do
          input+="$line\n"
      done
  fi

 # if not forcing, and NO_COLOR is not set
  if [ "$1" = "-f" ] \
     ||  [[ "$NO_COLOR" == "true" ]]\
     || [[ ! -t 1 && -n "$PS1" ]]; then
    echo -e "$input" #| cat
  else
    echo -e "$input"
  fi
}

# Helper function for setupcolors
function _nocolor() {

  # Check if script.sh is sourced, 
  # or no_color flagged,
  # or output is not a terminal 
  if [[ "$NO_COLOR" == "true" ]] \
     || [[ ! -t 1 && -n "$PS1" ]]; then
    echo ""
  else
    echo "$1"
  fi
}

# parse ENV:NO_COLOR 
function _setupcolors() {

  # This script is used to define colors for bash scripts
  # GitHub: https://github.com/OzzyCzech/colors.sh
  # Author: Roman Ožana <roman@ozana.cz>
  # License: MIT
  # 
  # Expanded by octoshrimpy
  # https://github.com/octoshrimpy

  # Resets
  C_NC="$(_nocolor '\033[0m')" # reset color
  C_RESET="$(_nocolor '\033[0m')" # reset color
  C_FG_RESET="$(_nocolor "\e[39m")" # Reset foreground color
  C_BG_RESET="$(_nocolor "\e[49m")" # Reset background color

  # Basic colors
  C_RED="$(_nocolor '\033[0;31m')"
  C_GREEN="$(_nocolor '\033[0;32m')"
  C_YELLOW="$(_nocolor '\033[0;33m')"
  C_BLUE="$(_nocolor '\033[0;34m')"
  C_MAGENTA="$(_nocolor '\033[0;35m')"
  C_CYAN="$(_nocolor '\033[0;36m')"
  C_BLACK="$(_nocolor '\033[0;30m')"
  C_WHITE="$(_nocolor '\033[0;37m')"
  C_GRAY="$(_nocolor '\033[0;90m')"

  # Styles
  C_BOLD="$(_nocolor '\033[1m')"
  C_DIM="$(_nocolor '\033[2m')"
  C_ITALIC="$(_nocolor '\033[3m')"
  C_UNDERLINE="$(_nocolor '\033[4m')"
  C_BLINK="$(_nocolor '\033[5m')"
  C_REVERSE="$(_nocolor '\033[7m')"
  C_STRIKE="$(_nocolor '\033[9m')"

  # Unstyles
  C_UNBOLD="$(_nocolor '\033[22m')"
  C_UNDIM="$(_nocolor '\033[22m')"
  C_UNITALIC="$(_nocolor '\033[23m')"
  C_UNDERLINE_OFF="$(_nocolor '\033[24m')"
  C_UNBLINK="$(_nocolor '\033[25m')"
  C_UNREVERSE="$(_nocolor '\033[27m')"
  C_UNSTRIKE="$(_nocolor '\033[29m')"

  # exports
  # https://www.shellcheck.net/wiki/SC2155
  export C_NC
  export C_RESET
  export C_FG_RESET
  export C_BG_RESET
  export C_RED
  export C_GREEN
  export C_YELLOW
  export C_BLUE
  export C_MAGENTA
  export C_CYAN
  export C_BLACK
  export C_WHITE
  export C_GRAY
  export C_BOLD
  export C_DIM
  export C_ITALIC
  export C_UNDERLINE
  export C_BLINK
  export C_REVERSE
  export C_STRIKE
  export C_UNBOLD
  export C_UNDIM
  export C_UNITALIC
  export C_UNDERLINE_OFF
  export C_UNBLINK
  export C_UNREVERSE
  export C_UNSTRIKE
}

