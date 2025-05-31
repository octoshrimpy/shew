#!/usr/bin/env bash

set -e

# TODO: if ran directly, exit with warning

debug=false
# skip command if debug but tell user
function _dryrun() {
  if ! $debug; then
  "$@"
  else
    _prt "Skipping: ${C_GRAY}${C_ITALIC}$(echo "$@")"
  fi
}

rundebug=false
# toggle want-once debug features
function _debug() {
  if $debug; then
    rundebug=true
    "$@"
    rundebug=false
  fi
}

# prettify JSON strings
function _prettyjson() {
  echo "$*" \
  | grep -Eo '"[^"]*" *(: *([0-9]*|"[^"]*")[^{}\["]*|,)?|[^"\]\[\}\{]*|\{|\},?|\[|\],?|[0-9 ]*,?' \
  | awk '{if ($0 ~ /^[}\]]/ ) offset-=4; printf "%*c%s\n", offset, " ", $0; if ($0 ~ /^[{\[]/) offset+=4}'
}

# nice print with debug features
function _prt() {
  
  local appname=${setappname:-"PDBAPI"}

  local brcolor=${C_CYAN}
  local txcolor=${C_GRAY}
  local prefix_default=

  local appname_spaces=${#appname}
  local prefix_space=
  prefix_space="     $(printf "%${appname_spaces}s")"
 
  local prefix=
  local input=
  local silent=false

  # warn
  if [ "$1" = "-w" ]; then
    txcolor=${C_BOLD}${C_YELLOW}
    prefix="${C_YELLOW}${C_BOLD}Warn${C_NC}: "
    shift
  fi

  # error
  if [ "$1" = "-e" ]; then
    txcolor=${C_BOLD}${C_RED}
    prefix="${C_RED}${C_BOLD}Error${C_NC}: "
    shift  
  fi
  
  # silent mode
  if [ "$1" = "-s" ]; then
    silent=true
    shift  
  fi

  if $rundebug; then 
    brcolor=${C_BOLD_RED}
    txcolor=${C_REVERSE}${C_BOLD_RED}
  fi

  prefix_default="${brcolor}[ ${txcolor}$appname${C_NC} ${brcolor}] ${C_NC}$prefix${C_NC}"

  # Check if there are arguments
  if [ "$#" -gt 0 ]; then
      input="$*"
  else
      # Read from stdin
      while IFS= read -r line; do
          input+="$line\n"
      done
  fi


  local lnc=0
  IFS=$'\n'
  for line in $input;
  do
    if [ "$silent" == true ] || [ "$lnc" -gt 0 ]; then
      printf "%b\n" "$prefix_space$line${C_NC}"
    else
      printf "%b\n" "$prefix_default$line${C_NC}"
    fi
    ((lnc+=1))
  done

  return 
}

# _prt but directly to TTY, can print from within functions
function _prtty() {
  _prt "$@" > /dev/tty
}

# fake gum spins the given function and persists its variables
#  _spin --show-output yourfunc
# _spin --spinner globe --title "Locating" find_carmen
function _spin() {
    command echo -ne "\e[?25l"  # Hide cursor
    set +m # hide job control

    local gum_args=()
    local func=""
    local has_title=false
    local spinner="dots"
    local title=""
    local show_output=false
    local fps=0.1
    local -a frames
    
    while [[ $# -gt 1 ]]; do
        case "$1" in
        --title)
            has_title=true
            title="$2"
            shift 2
            ;;
        --spinner)
            spinner="$2"
            shift 2
            ;;
        --show-output)
            show_output=true
            shift
            ;;
        *)
            gum_args+=("$1")
            shift
            ;;
        esac
    done

    func="$1"

    # convert func name to title if no title passed
    if ! $has_title; then
        title="${func//[_-]/ }"
        title="${title^} "
    fi

    # borrowed from gum spin
    # https://github.com/charmbracelet/gum#spin
    # https://github.com/charmbracelet/bubbles/blob/master/spinner/spinner.go 
    case "$spinner" in
        line)      frames=( "|" "/" "-" "\\" ); fps=0.1 ;;
        dots)      frames=( "⣾" "⣽" "⣻" "⢿" "⡿" "⣟" "⣯" "⣷" ); fps=0.1 ;;
        minidots)  frames=( "⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏" ); fps=0.083 ;;
        jump)      frames=( "⢄" "⢂" "⢁" "⡁" "⡈" "⡐" "⡠" ); fps=0.1 ;;
        pulse)     frames=( "█" "▓" "▒" "░" ); fps=0.125 ;;
        points)    frames=( "∙∙∙" "●∙∙" "∙●∙" "∙∙●" ); fps=0.143 ;;
        globe)     frames=( "🌍" "🌎" "🌏" ); fps=0.25 ;;
        moon)      frames=( "🌑" "🌒" "🌓" "🌔" "🌕" "🌖" "🌗" "🌘" ); fps=0.125 ;;
        monkey)    frames=( "🙈" "🙉" "🙊" ); fps=0.333 ;;
        meter)     frames=( "▱▱▱" "▰▱▱" "▰▰▱" "▰▰▰" "▰▰▱" "▰▱▱" "▱▱▱" ); fps=0.143 ;;
        hamburger) frames=( "☱" "☲" "☴" "☲" ); fps=0.333 ;;
        ellipsis)  frames=( "  " ".  " ".. " "..." " .." "  ." "   " ); fps=0.143 ;;
        *)         frames=( "|" "/" "-" "\\" ); fps=0.1 ;;
    esac

    # =================================================

    start_spinner() {
        local title="$1"
        spinner_running=true

        {
            i=0
            while $spinner_running; do
                printf "\r\033[K${C_MAGENTA}%s${C_NC} %s" "${frames[i]}" "$title"
                i=$(( (i + 1) % ${#frames[@]} ))
                sleep "$fps"
            done
        } &
        SPINNER_PID=$!
        disown $SPINNER_PID   
    }

    stop_spinner(){
        spinner_running=false
        kill "$SPINNER_PID" 2>/dev/null
        printf "%b" "\033[2K\r" # clear the line
    }

    _spin_print() {
      while IFS= read -r line; do
        printf "%b" "\033[2K\r" # clear the line
        echo -e "${C_GRAY}│${C_NC} $line"
      done
    }

    # =================================================
    
    start_spinner "$title"

    if [[ $show_output == "true" ]]; then
      tmp_fifo=$(mktemp -u)
      mkfifo "$tmp_fifo"
      _spin_print < "$tmp_fifo" &
      "$func" > "$tmp_fifo"
      wait 
    else
      "$func" >/dev/null 2>&1
    fi
    
    stop_spinner
    
    printf "%b\n" "\r\033[K${C_GRAY}╰─ ${C_GREEN}✓${C_NC} $title\n" # all done!
    printf "%b" "\e[?25h"  # show cursor again
    set -m
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

