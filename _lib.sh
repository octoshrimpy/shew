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
    echo -e "$result"

}


# _input: Single-line interactive input with optional header, prompt, placeholder, value preset, and password masking.
# flags: --header str, --prompt str, --placeholder str, --value str, --password
# use: _input --header "Username:" --prompt "> " --placeholder "Enter your username"
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

# _write: Interactive multiline text input with header, placeholder, and cursor navigation.
# flags: --header str, --placeholder str
# use: _write --header "Tell me a story:" --placeholder "Once upon a time..."
_write() {
  local HEADER="" PLACEHOLDER=""
  local -a INPUT_BUF=("")
  local LINE_INDEX=0 CURSOR=0
  local PROMPT="▏ "
  local ANCHOR_ROW=0 ANCHOR_COL=0
  local TERM_HEIGHT=24
  local PAD_LINES=8
  local HEADER_LINES=0

  # Get terminal height using stty
  _get_term_height() {
    local sz
    sz=$(stty size 2>/dev/null) || sz="24 80"
    TERM_HEIGHT="${sz%% *}"
    [ -z "$TERM_HEIGHT" ] && TERM_HEIGHT=24
  }

  # Parse arguments
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --header) HEADER="${C_CYAN}$2${C_NC}"; HEADER_LINES=1; shift 2 ;;
      --placeholder) PLACEHOLDER="${C_B_BLACK}$2${C_NC}"; shift 2 ;;
      *) echo "Unknown option: $1" >&2; return 1 ;;
    esac
  done

  stty -echo -icanon time 1 min 0
  trap 'stty sane; printf "\033[?25h\n"; return 130' INT

  [ -n "$HEADER" ] && printf "%b\n" "$HEADER"

  # Cursor anchor
  _get_cursor() {
    printf '\033[6n' > /dev/tty
    IFS=';' read -srdR -p "" pos < /dev/tty || pos="[1;1"
    local row col
    row="${pos#*[}"; col="${pos#*;}"
    row="${row%%;*}"; col="${col%%R*}"
    ANCHOR_ROW=${row:-1}
    ANCHOR_COL=${col:-1}
  }

  # Move to line relative to anchor, scrolling if needed
  _move_to_line() {
    local line="$1"
    local target_row=$((ANCHOR_ROW + line))
    _get_term_height
    while (( target_row > TERM_HEIGHT )); do
      printf "\n"
      ANCHOR_ROW=$((ANCHOR_ROW - 1))
      target_row=$((ANCHOR_ROW + line))
    done
    printf "\033[%d;%dH" "$target_row" "$((ANCHOR_COL))"
  }

  # Redraw a single line
  _redraw_line() {
    printf "\033[?25l"
    _move_to_line "$LINE_INDEX"
    printf "\033[1G\033[K%s" "$PROMPT"
    if [ -z "${INPUT_BUF[LINE_INDEX]}" ] && [ "$LINE_INDEX" -eq 0 ] && [ -n "$PLACEHOLDER" ] && [ "${#INPUT_BUF[@]}" -eq 1 ]; then
      printf "%b" "$PLACEHOLDER"
      printf "\033[1G\033[%dC" "${#PROMPT}"
    else
      printf "%s" "${INPUT_BUF[LINE_INDEX]}"
      printf "\033[1G\033[%dC" "$(( ${#PROMPT} + CURSOR ))"
    fi
    printf "\033[?25h"
  }

  # Redraw lines from index (for newlines, deletes, etc)
  _redraw_lines_from() {
    printf "\033[?25l"
    local idx="$1"
    local i
    for ((i=idx;i<${#INPUT_BUF[@]};i++)); do
      _move_to_line "$i"
      printf "\033[1G\033[K%s" "$PROMPT"
      if [ -z "${INPUT_BUF[i]}" ] && [ "$i" -eq 0 ] && [ -n "$PLACEHOLDER" ] && [ "${#INPUT_BUF[@]}" -eq 1 ]; then
        printf "%b" "$PLACEHOLDER"
      else
        printf "%s" "${INPUT_BUF[i]}"
      fi
    done
    for ((;i<=idx+PAD_LINES;i++)); do
      _move_to_line "$i"
      printf "\033[1G\033[K"
    done
    _move_to_line "$LINE_INDEX"
    printf "\033[1G\033[%dC" "$(( ${#PROMPT} + CURSOR ))"
    printf "\033[?25h"
  }

  _trim_trailing() {
    while [ ${#INPUT_BUF[@]} -gt 1 ] && [ -z "${INPUT_BUF[-1]}" ]; do
      unset 'INPUT_BUF[${#INPUT_BUF[@]}-1]'
    done
  }

  _get_cursor
  _redraw_line

  local last_esc_time=0
  while :; do
    IFS= read -rsn1 key
    if [[ "$key" == $'\x1b' ]]; then
      IFS= read -rsn1 -t 0.01 k1
      if [[ "$k1" == "[" ]]; then
        IFS= read -rsn1 arrow
        case "$arrow" in
          A) # Up
            if [ "$LINE_INDEX" -gt 0 ]; then
              LINE_INDEX=$((LINE_INDEX - 1))
              [ "$CURSOR" -gt "${#INPUT_BUF[LINE_INDEX]}" ] && CURSOR=${#INPUT_BUF[LINE_INDEX]}
              _redraw_line
            else
              CURSOR=0
              _redraw_line
            fi
            ;;
          B) # Down
            if [ "$LINE_INDEX" -lt $((${#INPUT_BUF[@]}-1)) ]; then
              LINE_INDEX=$((LINE_INDEX + 1))
              [ "$CURSOR" -gt "${#INPUT_BUF[LINE_INDEX]}" ] && CURSOR=${#INPUT_BUF[LINE_INDEX]}
              _redraw_line
            fi
            ;;
          C) # Right
            if [ "$CURSOR" -lt "${#INPUT_BUF[LINE_INDEX]}" ]; then
              CURSOR=$((CURSOR+1))
              _redraw_line
            elif [ "$LINE_INDEX" -lt $((${#INPUT_BUF[@]}-1)) ]; then
              LINE_INDEX=$((LINE_INDEX+1))
              CURSOR=0
              _redraw_line
            else
              # At last line, move to end
              CURSOR=${#INPUT_BUF[LINE_INDEX]}
              _redraw_line
            fi
            ;;
          D) # Left
            if [ "$CURSOR" -gt 0 ]; then
              CURSOR=$((CURSOR-1))
              _redraw_line
            elif [ "$LINE_INDEX" -gt 0 ]; then
              LINE_INDEX=$((LINE_INDEX-1))
              CURSOR=${#INPUT_BUF[LINE_INDEX]}
              _redraw_line
            fi
            ;;
          H) CURSOR=0; _redraw_line ;;
          F) CURSOR=${#INPUT_BUF[LINE_INDEX]}; _redraw_line ;;
        esac
        continue
      fi
      local now=$(date +%s%3N)
      if (( now - last_esc_time < 500 )); then printf "\n"; break; fi
      last_esc_time=$now
      continue
    fi

    case "$key" in
      "") # Enter
        # If placeholder is showing and we're at line 0, remove it
        if [ "$LINE_INDEX" -eq 0 ] && [ -z "${INPUT_BUF[0]}" ] && [ -n "$PLACEHOLDER" ]; then
          INPUT_BUF[0]=""
        fi
        local before="${INPUT_BUF[LINE_INDEX]:0:CURSOR}"
        local after="${INPUT_BUF[LINE_INDEX]:CURSOR}"
        INPUT_BUF=("${INPUT_BUF[@]:0:$LINE_INDEX}" "$before" "$after" "${INPUT_BUF[@]:$((LINE_INDEX+1))}")
        LINE_INDEX=$((LINE_INDEX + 1))
        CURSOR=0
        _redraw_lines_from $((LINE_INDEX-1))
        ;;
      $'\x03') # Ctrl+C aborts
        stty sane; printf "\033[?25h\n"; return 130
        ;;
      $'\x7f') # Backspace
        if [ "$CURSOR" -gt 0 ]; then
          INPUT_BUF[LINE_INDEX]="${INPUT_BUF[LINE_INDEX]:0:CURSOR-1}${INPUT_BUF[LINE_INDEX]:CURSOR}"
          CURSOR=$((CURSOR - 1))
          _redraw_line
        elif [ "$LINE_INDEX" -gt 0 ]; then
          local len_above=${#INPUT_BUF[LINE_INDEX-1]}
          INPUT_BUF[LINE_INDEX-1]+="${INPUT_BUF[LINE_INDEX]}"
          unset 'INPUT_BUF[LINE_INDEX]'
          INPUT_BUF=("${INPUT_BUF[@]}")
          LINE_INDEX=$((LINE_INDEX - 1))
          CURSOR=$len_above
          _redraw_lines_from "$LINE_INDEX"
        fi
        ;;
      $'\x01') # Ctrl-A (Home)
        CURSOR=0
        _redraw_line
        ;;
      $'\x05') # Ctrl-E (End)
        CURSOR=${#INPUT_BUF[LINE_INDEX]}
        _redraw_line
        ;;
      *)
        [[ "$key" =~ [[:print:]] ]] || continue
        # If placeholder is showing, clear line first
        if [ -z "${INPUT_BUF[LINE_INDEX]}" ] && [ "$LINE_INDEX" -eq 0 ] && [ -n "$PLACEHOLDER" ] && [ "${#INPUT_BUF[@]}" -eq 1 ]; then
          INPUT_BUF[LINE_INDEX]="$key"
          CURSOR=1
          _redraw_line
        else
          if [ "$CURSOR" -eq "${#INPUT_BUF[LINE_INDEX]}" ]; then
            INPUT_BUF[LINE_INDEX]+="$key"
            CURSOR=$((CURSOR + 1))
            printf "%s" "$key"
          else
            INPUT_BUF[LINE_INDEX]="${INPUT_BUF[LINE_INDEX]:0:CURSOR}${key}${INPUT_BUF[LINE_INDEX]:CURSOR}"
            CURSOR=$((CURSOR + 1))
            _redraw_line
          fi
        fi
        ;;
    esac
  done

  stty sane
  printf "\033[?25l" # Hide cursor

  _trim_trailing

  # Move to anchor (col 1)
  printf "\033[%d;1H" "$ANCHOR_ROW"
  # If there was a header, move up one line to it
  if [ "$HEADER_LINES" = 1 ]; then
    printf "\033[1A"
  fi
  printf "\033[1G" # Move to column 1
  printf "\033[J"   # Clear everything from here down

  printf "\033[?25h" # Show cursor

  for line in "${INPUT_BUF[@]}"; do
    printf "%s\n" "$line"
  done
}

# _filter: Interactive single/multi-choice selector with header, prompt, fuzzy filtering, and keyboard navigation.
# flags: --header str, --prompt str, --multi, --strict, --reverse, --limit int, --selected str, --label/--labels str
# use: _filter --header "Choose your favorite:" --prompt "Pick one:" --multi --limit 3 --label "Apple|a Banana|b Cherry|c"
_filter() {
  local HEADER="" PROMPT="" MULTI=0 STRICT=0 REVERSE=0 LIMIT=0
  local -a OPTIONS=() RAW_OPTIONS=() LABELS=() VALUES=() SELECTED_ITEMS=() SELECTED=()
  local SELECTED_STR=""
  local POINTER=">" SELECTABLE="●" UNSELECTABLE="᳃" CHECKED="✔"

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --header) HEADER="$2"; shift 2 ;;
      --prompt) PROMPT="$2"; shift 2 ;;
      --multi) MULTI=1; shift ;;
      --strict) STRICT=1; shift ;;
      --reverse) REVERSE=1; shift ;;
      --limit) LIMIT="$2"; shift 2 ;;
      --selected) SELECTED_STR="$2"; shift 2 ;;
      --label|--labels)
        IFS=' ' read -r -a RAW_OPTIONS <<< "$2"
        shift 2 ;;
      --) shift; break ;;
      *) OPTIONS+=("$1"); shift ;;
    esac
  done

  if [[ ${#RAW_OPTIONS[@]} -gt 0 ]]; then
    for item in "${RAW_OPTIONS[@]}"; do
      LABELS+=("${item%%|*}")
      VALUES+=("${item#*|}")
    done
    OPTIONS=("${LABELS[@]}")
  fi

  [[ $REVERSE -eq 1 ]] && OPTIONS=("$(printf "%s\n" "${OPTIONS[@]}" | tac)")
  [[ ${#RAW_OPTIONS[@]} -gt 0 && $REVERSE -eq 1 ]] && VALUES=("$(printf "%s\n" "${VALUES[@]}" | tac)")

  if [[ -n $SELECTED_STR ]]; then
    IFS=' ' read -r -a SELECTED_ITEMS <<< "$SELECTED_STR"
  fi

  for ((i=0; i<${#OPTIONS[@]}; i++)); do
    SELECTED[i]=0
    for sel in "${SELECTED_ITEMS[@]}"; do [[ "${OPTIONS[i]}" == "$sel" ]] && SELECTED[i]=1 && break; done
  done

  local -a ORIG_OPTIONS=("${OPTIONS[@]}")
  local -a FILTERED=("${ORIG_OPTIONS[@]}")
  local -a FILTERED_IDX=()
  for i in "${!ORIG_OPTIONS[@]}"; do FILTERED_IDX+=("$i"); done

  local FILTER="" FILTER_MODE=0 CURSOR=0 HEADER_LINES=0
  local COUNT_LINE=$((MULTI && LIMIT > 0 ? 1 : 0))

  # TODO: rethink prompt logic
  printf "\033[?25l"
  [[ -n "$PROMPT" ]] && echo -ne "${PROMPT} " && ((HEADER_LINES++))
  printf "\033[s"

  _move_to_line() { printf "\033[u"; (( $1 > 0 )) && printf "\033[%dB" "$1"; }

  _draw_header() {
    _move_to_line 0
    printf "\033[2K\r"
    if ((FILTER_MODE)); then
      printf "%b" "${C_B_BLACK}"
      [[ -z "$FILTER" ]] && printf "%s" "$HEADER" || printf "%s" "$FILTER"
      printf "%b" "${C_NC}"
      printf "\r"
      [[ ${#FILTER} -gt 0 ]] && printf "\033[%dC" "${#FILTER}"
      printf "\033[?25h"
    else
      printf "${C_CYAN}%s${C_NC}" "$HEADER"
      printf "\033[?25l"
    fi
  }

  _draw_count() {
    if [[ $MULTI -eq 1 && $LIMIT -gt 0 ]]; then
      local selected_count=0
      for n in "${SELECTED[@]}"; do ((selected_count+=n)); done
      _move_to_line 1
      printf "\033[2K\r"
      echo -e "${C_ITALIC}${C_B_BLACK}${selected_count}/${LIMIT} selected${C_NC}"
    fi
  }

  _highlight_match() {
    local text="$1" pat="$2" iscursor="$3"
    # If no pattern, just print (bold if iscursor)
    if [[ -z "$pat" ]]; then
      if [[ -n "$iscursor" && "$iscursor" != "0" ]]; then
        echo -ne "${C_BOLD}${text}${C_UNBOLD}"
      else
        echo -ne "$text"
      fi
      return
    fi
    local lc_text="${text,,}" lc_pat="${pat,,}" idx
    idx=$(awk -v a="$lc_text" -v b="$lc_pat" 'BEGIN{print index(a,b)}')
    if (( idx > 0 )); then
      local pre="${text:0:$((idx-1))}"
      local match="${text:$((idx-1)):$((${#pat}))}"
      local post="${text:$((idx-1+${#pat}))}"

      if [[ -n "$iscursor" && "$iscursor" != "0" ]]; then
        # Bold everything, only match is cyan+bold
        echo -ne "${C_BOLD}${pre}${C_CYAN}${match}${C_RESET_FG}${C_BOLD}${post}${C_UNBOLD}"
      else
        # Only match is cyan+bold
        echo -ne "$pre${C_CYAN}${C_BOLD}$match${C_NC}${C_UNBOLD}$post"
      fi
    else
      # No match, but if iscursor, bold whole line
      if [[ -n "$iscursor" && "$iscursor" != "0" ]]; then
        echo -ne "${C_BOLD}${text}${C_UNBOLD}"
      else
        echo -ne "$text"
      fi
    fi
  }

  _fuzzy_filter() {
    FILTERED=()
    FILTERED_IDX=()
    if [[ -z "$FILTER" ]]; then
      FILTERED=("${ORIG_OPTIONS[@]}")
      for i in "${!ORIG_OPTIONS[@]}"; do FILTERED_IDX+=($i); done
    else
      for i in "${!ORIG_OPTIONS[@]}"; do
        [[ "${ORIG_OPTIONS[i],,}" == *"${FILTER,,}"* ]] && FILTERED+=("${ORIG_OPTIONS[i]}") && FILTERED_IDX+=("$i")
      done
    fi
    (( CURSOR >= ${#FILTERED[@]} )) && CURSOR=0
  }

  _draw_option() {
    local fidx=$1
    local idx="${FILTERED_IDX[$fidx]}"
    local opt="${FILTERED[$fidx]}"
    local selected_count=0 prefix="" symbol=""
    for n in "${SELECTED[@]}"; do ((selected_count+=n)); done
    if [[ $MULTI -eq 1 ]]; then
      if [[ ${SELECTED[idx]} -eq 1 ]]; then
        symbol="${C_GREEN}${CHECKED}${C_NC}"
      else
        if [[ $LIMIT -gt 0 && $selected_count -ge $LIMIT ]]; then symbol="${C_B_BLACK}${UNSELECTABLE}${C_NC}"
        else symbol="${C_B_BLACK}${SELECTABLE}${C_NC}"; fi
      fi
      prefix+="$symbol"
    fi
    if [[ $fidx -eq $CURSOR ]]; then
      printf "\033[2K\r"
      echo -ne "${C_NC}${POINTER} $prefix ${C_BOLD}"
      _highlight_match "$opt" "$FILTER" "true"
      echo -e "${C_UNBOLD}${C_NC}"
    else
      printf "\033[2K\r"
      echo -ne "  $prefix "
      _highlight_match "$opt" "$FILTER"
      echo -e "${C_NC}"
    fi
  }

  _draw_menu() {
    local total_lines=$((1 + COUNT_LINE + ${#ORIG_OPTIONS[@]}))
    _move_to_line 0
    for ((i=0; i<total_lines; i++)); do printf "\033[2K\r"; ((i < total_lines - 1)) && printf "\033[1B"; done
    _move_to_line 0
    _draw_header
    [[ $MULTI -eq 1 && $LIMIT -gt 0 ]] && _draw_count
    local start=$((1+COUNT_LINE))
    for ((i=0; i<${#FILTERED[@]}; i++)); do _move_to_line $((start+i)); _draw_option "$i"; done
    if ((FILTER_MODE)); then
      _move_to_line 0; printf "\r"
      [[ ${#FILTER} -gt 0 ]] && printf "\033[%dC" "${#FILTER}"
      printf "\033[?25h"
    else
      printf "\033[?25l"
    fi
  }

  _fuzzy_filter
  _draw_menu

  trap 'stty sane; printf "\033[?25h"; return 130' INT
  stty -echo -icanon time 0 min 1

  while IFS= read -rsn1 key; do
    if ((FILTER_MODE)); then
      if [[ $key == $'\x1b' ]]; then
        read -rsn2 -t 0.01 key2
        case "$key2" in
          "[A") ((CURSOR > 0)) && ((CURSOR--)); _draw_menu ;; # Up
          "[B") ((CURSOR < ${#FILTERED[@]}-1)) && ((CURSOR++)); _draw_menu ;; # Down
        esac
        continue
      fi
      case "$key" in
        $'\t') # Tab: select/deselect in filter mode
          if [[ $MULTI -eq 1 && ${#FILTERED[@]} -gt 0 ]]; then
            local idx="${FILTERED_IDX[$CURSOR]}"
            local selected_count=0
            for n in "${SELECTED[@]}"; do ((selected_count+=n)); done
            if [[ ${SELECTED[idx]} -eq 1 ]]; then
              SELECTED[idx]=0
            elif [[ $LIMIT -gt 0 && $selected_count -ge $LIMIT ]]; then
              tput bel
            else
              SELECTED[idx]=1
            fi
            _draw_menu
          fi
          ;;
        $'\177'|$'\010') # Backspace
          if [[ -n "$FILTER" ]]; then
            FILTER="${FILTER:0:-1}"
            _fuzzy_filter
            _draw_menu
          fi
          ;;
        "") # Enter: leave filter mode
          FILTER_MODE=0; _draw_menu ;;
        $'\x1b') # Esc: leave filter mode
          FILTER_MODE=0; _draw_menu ;;
        *)
          FILTER="$FILTER$key"
          _fuzzy_filter
          _draw_menu
          ;;
      esac
      continue
    fi

    if [[ $key == $'\x1b' ]]; then
      read -rsn2 -t 0.01 key2
      case "$key2" in
        "[A") ((CURSOR > 0)) && ((CURSOR--)); _draw_menu ;;
        "[B") ((CURSOR < ${#FILTERED[@]}-1)) && ((CURSOR++)); _draw_menu ;;
      esac
      continue
    fi
    case "$key" in
      $'\t')
        if [[ $MULTI -eq 1 && ${#FILTERED[@]} -gt 0 ]]; then
          local idx="${FILTERED_IDX[$CURSOR]}"
          local selected_count=0
          for n in "${SELECTED[@]}"; do ((selected_count+=n)); done
          if [[ ${SELECTED[idx]} -eq 1 ]]; then
            SELECTED[idx]=0
          elif [[ $LIMIT -gt 0 && $selected_count -ge $LIMIT ]]; then
            tput bel
          else
            SELECTED[idx]=1
          fi
          _draw_menu
        fi
        ;;
      "/") FILTER_MODE=1; _draw_menu ;;
      "") # Enter
        stty sane; printf "\033[u"
        for ((i=0; i<${#ORIG_OPTIONS[@]}+COUNT_LINE+1; i++)); do printf "\033[2K\r"; ((i < ${#ORIG_OPTIONS[@]}+COUNT_LINE)) && printf "\033[1B"; done
        printf "\033[u"
        if ((HEADER_LINES > 0)); then for ((i=0; i<HEADER_LINES; i++)); do printf "\033[1A"; done
          for ((i=0; i<HEADER_LINES; i++)); do printf "\033[2K\r"; ((i < HEADER_LINES - 1)) && printf "\033[1B"; done
        fi
        printf "\033[?25h"
        local out=()
        if [[ $MULTI -eq 1 ]]; then
          for i in "${!ORIG_OPTIONS[@]}"; do [[ ${SELECTED[i]} -eq 1 ]] && out+=("${ORIG_OPTIONS[i]}"); done
        else
          out=("${FILTERED[$CURSOR]}")
        fi
        if [[ ${#RAW_OPTIONS[@]} -gt 0 && $STRICT -eq 0 ]]; then
          local final=()
          for sel in "${out[@]}"; do for j in "${!LABELS[@]}"; do [[ "${LABELS[j]}" == "$sel" ]] && final+=("${VALUES[j]}"); done; done
          echo "${final[*]}"
        else echo "${out[*]}"; fi
        return 0 ;;
    esac
  done

  stty sane
  printf "\033[?25h"
  return 0
}