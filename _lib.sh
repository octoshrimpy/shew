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


# _confirm: Ask user for confirmation
# use: _confirm --affirmative "aye!" --negative "nay.." --prompt "Are ye a pirate?" --default false --timeout 5
# shellcheck disable=SC2120
_confirm() {
    local affirmative="Yes"
    local negative="No"
    local prompt="Are you sure?"
    local timeout=0
    local selected=0  # 0 = affirmative, 1 = negative

    # Trap Ctrl+C and Ctrl+Q
    trap "" SIGQUIT
    trap 'echo -ne "\e[3B\e[1A\e[2K\e[1A\e[1A\e[2K\e[1G\033[?25h"; stty echo; return 130;' SIGINT

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --affirmative) shift; affirmative="$1" ;;
            --negative) shift; negative="$1" ;;
            --prompt) shift; prompt="$1" ;;
            --timeout) shift; timeout="$1" ;;
            --default) shift; [[ "$1" == false ]] && selected=1 ;;
            *) echo "Unknown option: $1"; return 1 ;;
        esac
        shift
    done

    # Hide cursor
    printf "\033[?25l"  # hide cursor

    if [[ $timeout -gt 0 ]]; then
        local now_time
        now_time=$(date +%s)

        local end_time=$(( now_time + timeout ))
        local time_left
        time_left="$timeout"
    fi

    # Draw buttons
    draw_buttons() {
        local time_prefix=""
        if [[ $timeout -gt 0 ]]; then
            time_prefix="${C_YELLOW}${time_left}s${C_B_BLACK} :: ${C_NC}"
        fi
        
        echo -e "${time_prefix}${C_CYAN}${C_ITALIC}$prompt${C_NC}\n"

        if [[ $selected -eq 0 ]]; then
            echo -e " ${C_BLACK}${C_BG_MAGENTA} $affirmative ${C_NC}  $negative ${C_NC}"
        else
            echo -e "  $affirmative ${C_NC} ${C_BLACK}${C_BG_MAGENTA} $negative ${C_NC}"
        fi
        echo -ne "\e[3A\e[1G" # move cursor up two and to line start
    }

    cleanup() {
        # Show cursor again
        echo -ne "\e[3B\e[1A\e[2K\e[1A\e[1A\e[2K\e[1G"
        printf "\033[?25h"  # show cursor
        stty echo
    }

    draw_buttons

    # disable input echo
    stty -echo
    while true; do
    
        if [[ $timeout -gt 0 ]]; then
            now_time=$(date +%s)
            time_left=$(( end_time - now_time ))
            if (( time_left <= 0 )); then
                cleanup
                echo -e "${C_B_BLACK}Timed out${C_NC}"
                return 130
            fi
        fi

        # Only redraw if the countdown changed
        if [[ "$time_left" -ne "$last_time_left" ]]; then
            last_time_left=$time_left
            draw_buttons
        fi

        # Non-blocking input check
        if read -rsn3 -t 0.1 key; then
            case "$key" in
                $'\e[C') selected=1; draw_buttons ;;  # Right arrow
                $'\e[D') selected=0; draw_buttons ;;  # Left arrow
                "") break ;;
            esac
        fi
        sleep 0.1

    done

    cleanup && return 130
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

# Always removes ANSI color codes from input (stdin or args).
# Example: printf '\033[0;31mRed\033[0m\n' | _stripcolors
_stripcolors() {
  local ansi_regex=$'\033\\[[0-9;]*m'
  local input=""

  if [ "$#" -gt 0 ]; then
    input="$*"
  else
    while IFS= read -r line; do
      input="${input}${line}"$'\n'
    done
  fi

  printf "%s" "$input" | sed -E "s/${ansi_regex}//g"
}


# Echoes color code only if colors are allowed (NO_COLOR not set, and stdout is terminal)
# Example: RED=$(_nocolor '\033[0;31m')
_nocolor() {
  if [ "${NO_COLOR:-}" = "true" ] || [ ! -t 1 ]; then
    printf ""
  else
    printf "%s" "$1"
  fi
}

# Initializes terminal color/style variables, respecting NO_COLOR or non-TTY.
# Call early in script to safely use exported C_* vars.
function _setupcolors() {

  # Terminal color and style definitions
  # Author: Roman Ožana <roman@ozana.cz>
  # Modified by: octoshrimpy <shew@octo.sh>
  # License: MIT

  # 🎨 16-color Foreground Palette
  C_BLACK="$(_nocolor '\033[0;30m')"
  C_RED="$(_nocolor '\033[0;31m')"
  C_GREEN="$(_nocolor '\033[0;32m')"
  C_YELLOW="$(_nocolor '\033[0;33m')"
  C_BLUE="$(_nocolor '\033[0;34m')"
  C_MAGENTA="$(_nocolor '\033[0;35m')"
  C_CYAN="$(_nocolor '\033[0;36m')"
  C_WHITE="$(_nocolor '\033[0;37m')"

  export C_BLACK C_RED C_GREEN C_YELLOW 
  export C_BLUE C_MAGENTA C_CYAN C_WHITE

  # 🌈 Bright Foreground Colors
  C_B_BLACK="$(_nocolor '\033[0;90m')"   # often used as gray
  C_B_RED="$(_nocolor '\033[0;91m')"
  C_B_GREEN="$(_nocolor '\033[0;92m')"
  C_B_YELLOW="$(_nocolor '\033[0;93m')"
  C_B_BLUE="$(_nocolor '\033[0;94m')"
  C_B_MAGENTA="$(_nocolor '\033[0;95m')"
  C_B_CYAN="$(_nocolor '\033[0;96m')"
  C_B_WHITE="$(_nocolor '\033[0;97m')"

  export C_B_BLACK C_B_RED C_B_GREEN C_B_YELLOW 
  export C_B_BLUE C_B_MAGENTA C_B_CYAN C_B_WHITE

  # 🔲 Background Colors (standard)
  C_BG_BLACK="$(_nocolor '\033[40m')"
  C_BG_RED="$(_nocolor '\033[41m')"
  C_BG_GREEN="$(_nocolor '\033[42m')"
  C_BG_YELLOW="$(_nocolor '\033[43m')"
  C_BG_BLUE="$(_nocolor '\033[44m')"
  C_BG_MAGENTA="$(_nocolor '\033[45m')"
  C_BG_CYAN="$(_nocolor '\033[46m')"
  C_BG_WHITE="$(_nocolor '\033[47m')"

  export C_BG_BLACK C_BG_RED C_BG_GREEN C_BG_YELLOW 
  export C_BG_BLUE C_BG_MAGENTA C_BG_CYAN C_BG_WHITE

  # 🌈 Bright Backgrounds (some terminals only)
  C_BG_B_BLACK="$(_nocolor '\033[100m')"
  C_BG_B_RED="$(_nocolor '\033[101m')"
  C_BG_B_GREEN="$(_nocolor '\033[102m')"
  C_BG_B_YELLOW="$(_nocolor '\033[103m')"
  C_BG_B_BLUE="$(_nocolor '\033[104m')"
  C_BG_B_MAGENTA="$(_nocolor '\033[105m')"
  C_BG_B_CYAN="$(_nocolor '\033[106m')"
  C_BG_B_WHITE="$(_nocolor '\033[107m')"

  export C_BG_B_BLACK C_BG_B_RED C_BG_B_GREEN C_BG_B_YELLOW 
  export C_BG_B_BLUE C_BG_B_MAGENTA C_BG_B_CYAN C_BG_B_WHITE

  # ✨ Styles
  C_BOLD="$(_nocolor '\033[1m')"
  C_DIM="$(_nocolor '\033[2m')"       # aka faint
  C_ITALIC="$(_nocolor '\033[3m')"    # not widely supported
  C_UNDER="$(_nocolor '\033[4m')"
  C_BLINK="$(_nocolor '\033[5m')"
  C_REVERSE="$(_nocolor '\033[7m')"
  C_HIDDEN="$(_nocolor '\033[8m')"
  C_STRIKE="$(_nocolor '\033[9m')"

  export C_BOLD C_DIM C_ITALIC C_UNDER 
  export C_BLINK C_REVERSE C_HIDDEN C_STRIKE

  # 🔄 Undo Styles
  C_UNBOLD="$(_nocolor '\033[21m')"
  C_UNDIM="$(_nocolor '\033[22m')"
  C_UNITALIC="$(_nocolor '\033[23m')"
  C_UNUNDER="$(_nocolor '\033[24m')"
  C_UNBLINK="$(_nocolor '\033[25m')"
  C_UNREVERSE="$(_nocolor '\033[27m')"
  C_UNHIDDEN="$(_nocolor '\033[28m')"
  C_UNSTRIKE="$(_nocolor '\033[29m')"

  export C_UNBOLD C_UNDIM C_UNITALIC C_UNUNDER 
  export C_UNBLINK C_UNREVERSE C_UNHIDDEN C_UNSTRIKE

  # 🧼 Reset Colors
  C_RESET_FG="$(_nocolor '\033[39m')"
  C_RESET_BG="$(_nocolor '\033[49m')"
  C_NC="$(_nocolor '\033[0m')" # reset all (colors + styles)

  export C_RESET_FG C_RESET_BG C_NC
}

# converts given text to pixelart 3x3 figlet font
# _fig "sphynx of black quartz, hear my vow - 12345678 and 9"
# shellcheck disable=SC2120
# shellcheck disable=SC2034
function _fig() {
    T_a=" ▄▄\033[1B\033[3D▀▄█\033[1A\033[1C" # a
    T_b="▄  \033[1B\033[3D███\033[1A\033[1C" # b
    T_c="▄▄▄\033[1B\033[3D█▄▄\033[1A\033[1C" # c
    T_d="  ▄\033[1B\033[3D███\033[1A\033[1C" # d
    T_e=" ▄▄\033[1B\033[3D▀█▄\033[1A\033[1C" # e
    T_f="▄▄▄\033[1B\033[3D█▀ \033[1A\033[1C" # f
    T_g="▄▄▄\033[1B\033[3D▀▄█\033[1A\033[1C" # g
    T_h="▄ ▄\033[1B\033[3D█▀█\033[1A\033[1C" # h
    T_i="▄▄▄\033[1B\033[3D▄█▄\033[1A\033[1C" # i
    T_j="  ▄\033[1B\033[3D█▄█\033[1A\033[1C" # j
    T_k="▄ ▄\033[1B\033[3D█▀▄\033[1A\033[1C" # k
    T_l="▄  \033[1B\033[3D█▄▄\033[1A\033[1C" # l
    T_m="▄▄▄\033[1B\033[3D█▀█\033[1A\033[1C" # m
    T_n="▄▄ \033[1B\033[3D█ █\033[1A\033[1C" # n
    T_o="▄▄▄\033[1B\033[3D█▄█\033[1A\033[1C" # o
    T_p="▄▄▄\033[1B\033[3D█▀▀\033[1A\033[1C" # p
    T_q="▄▄▄\033[1B\033[3D▀▀█\033[1A\033[1C" # q
    T_r=" ▄▄\033[1B\033[3D█ ▀\033[1A\033[1C" # r
    T_s=" ▄▄\033[1B\033[3D▄█ \033[1A\033[1C" # s
    T_t="▄▄▄\033[1B\033[3D █ \033[1A\033[1C" # t
    T_u="▄ ▄\033[1B\033[3D█▄█\033[1A\033[1C" # u
    T_v="▄ ▄\033[1B\033[3D▀▄▀\033[1A\033[1C" # v
    T_w="▄ ▄\033[1B\033[3D██▀\033[1A\033[1C" # w
    T_x="▄ ▄\033[1B\033[3D▄▀▄\033[1A\033[1C" # x
    T_y="▄ ▄\033[1B\033[3D▀█▀\033[1A\033[1C" # y
    T_z="▄▄ \033[1B\033[3D █▄\033[1A\033[1C" # z
    
    T_space="\033[2C" # ` `

    T_1="▄▄ \033[1B\033[3D▄█▄\033[1A\033[1C" # 1
    T_2="▄  \033[1B\033[3D █▄\033[1A\033[1C" # 2
    T_3="▄▄▄\033[1B\033[3D▄█▀\033[1A\033[1C" # 3
    T_4="▄ ▄\033[1B\033[3D▀▀█\033[1A\033[1C" # 4
    T_5=" ▄▄\033[1B\033[3D▄▀ \033[1A\033[1C" # 5
    T_6="▄  \033[1B\033[3D███\033[1A\033[1C" # 6
    T_7="▄▄▄\033[1B\033[3D  █\033[1A\033[1C" # 7
    T_8=" ▄▄\033[1B\033[3D██▀\033[1A\033[1C" # 8
    T_9="▄▄▄\033[1B\033[3D▀▀█\033[1A\033[1C" # 9
    T_0=" ▄▄\033[1B\033[3D█▄▀\033[1A\033[1C" # 0

    T_dash="   \033[1B\033[3D▀▀▀\033[1A\033[1C" # -
    T_comma="   \033[1B\033[3D▄▀ \033[1A\033[1C" # ,
    T_period="   \033[1B\033[3D▄  \033[1A\033[1C" # ,


    local string="$*"
    processing="$string"
    result=

    # TODO: switch case, and more chars
    for (( i=0; i<${#processing}; i++ )); do
        letter="${processing:$i:1}"
        varname="T_$letter"
        if [[ $letter == " " ]]; then
            varname="T_space"
        elif [[ $letter == "-" ]]; then
            varname="T_dash"
        elif [[ $letter == "," ]]; then
            varname="T_comma"
        elif [[ $letter == "." ]]; then
            varname="T_period"
        fi
        value="${!varname}"

        result+="$value"
    done

    # not -e on purpose, so user can handle it later
    echo "$result"

}



_input() {
  local HEADER="" PROMPT="> " PLACEHOLDER="" VALUE="" PASSWORD=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --header) HEADER="${C_CYAN}$2${C_NC}"; shift 2 ;;
      --prompt) PROMPT="$2"; shift 2 ;;
      --placeholder) PLACEHOLDER="${C_B_BLACK}$2${C_NC}"; shift 2 ;;
      --value) VALUE="$2"; shift 2 ;;
      --password) PASSWORD=true; shift ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done

  stty -echo -icanon min 1 time 0
  trap 'stty sane; echo; return 130' INT

  [ -n "$HEADER" ] && printf "%b\n" "$HEADER"
  printf "%b" "$PROMPT"

  local INPUT="$VALUE"
  local CURSOR=${#INPUT}
  local PLACEHOLDER_SHOWN=false

  if [ -z "$INPUT" ] && [ -n "$PLACEHOLDER" ]; then
    printf "%b" "$PLACEHOLDER"
    PLACEHOLDER_SHOWN=true
    # Move cursor back to input start
    printf "\r%b" "$PROMPT"
  else
    [ "$PASSWORD" = true ] && printf "%s" "$(printf "%${#INPUT}s" | tr ' ' '*')" || printf "%s" "$INPUT"
  fi

  while :; do
    IFS= read -r -n1 key
    case "$key" in
      "") break ;; # Enter
      $'\x7f') # Backspace
        if [ "$CURSOR" -gt 0 ]; then
          INPUT="${INPUT:0:CURSOR-1}${INPUT:CURSOR}"
          CURSOR=$((CURSOR - 1))
          local tail="${INPUT:CURSOR}"
          printf "\b%s \b" "$tail"
          for _ in $(seq "${#tail}"); do printf "\b"; done
        fi
        if [ -z "$INPUT" ] && [ -n "$PLACEHOLDER" ] && [ "$PLACEHOLDER_SHOWN" = false ]; then
          printf "\r%b\033[K%b" "$PROMPT" "$PLACEHOLDER"
          printf "\r%b" "$PROMPT"
          PLACEHOLDER_SHOWN=true
        fi
        ;;
      $'\033') # Escape sequence
        read -r -n2 rest
        case "$rest" in
          '[D') [ "$CURSOR" -gt 0 ] && CURSOR=$((CURSOR - 1)) && printf "\b" ;;
          '[C')
            if [ "$CURSOR" -lt "${#INPUT}" ]; then
              [ "$PASSWORD" = true ] && printf "*" || printf "%s" "${INPUT:$CURSOR:1}"
              CURSOR=$((CURSOR + 1))
            fi
            ;;
        esac
        ;;
      *)
        if [ "$PLACEHOLDER_SHOWN" = true ]; then
          printf "\r%b\033[K" "$PROMPT"
          PLACEHOLDER_SHOWN=false
        fi
        INPUT="${INPUT:0:CURSOR}${key}${INPUT:CURSOR}"
        CURSOR=$((CURSOR + 1))
        local tail="${INPUT:CURSOR}"
        [ "$PASSWORD" = true ] && printf "*%s" "$(printf "%${#tail}s" | tr ' ' '*')" || printf "%s%s" "$key" "$tail"
        for _ in $(seq "${#tail}"); do printf "\b"; done
        ;;
    esac
  done
  
    stty sane

    # Clear input line
    printf "\r\033[K"

    # Clear header line if it was printed
    if [ -n "$HEADER" ]; then
    printf "\033[1A\r\033[K"  # Move up and clear
    fi

    # Output final input
    printf "%s\n" "$INPUT"

}









