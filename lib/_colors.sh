#! /usr/bin/env bash

# Always removes ANSI color codes from input (stdin or args).
# Example: printf '\033[0;31mRed\033[0m\n' | _stripcolors
_stripcolors() {
  # Sed pattern to remove ANSI CSI sequences (real ESC and literal "\033")
  local sed_pat='s/\x1B\[[0-9;]*[mK]//g; s/\\033\[[0-9;]*m//g'

  if (($#)); then
    # If there are args, use printf '%b' so that any "\033" in them
    # becomes a real ESC (for real‑escape stripping), then run sed
    while (($#)); do
      printf '%b\n' "$1"
      shift
    done | sed -r "$sed_pat"
  else
    # No args → read from stdin
    sed -r "$sed_pat"
  fi
}

# Echoes color code only if colors are allowed (NO_COLOR not set, and stdout is terminal)
# Example: RED=$(_nocolor '\033[0;31m')
_nocolor() {
  # if NO_COLOR is unset (empty) AND stdout is a terminal, print the code
  if [[ -z "${NO_COLOR:-}" ]]; then
    printf '%b' "$1"
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
  C_B_BLACK="$(_nocolor '\033[0;90m')" # often used as gray
  C_B_RED="$(_nocolor '\033[0;91m')"
  C_B_GREEN="$(_nocolor '\033[0;92m')"
  C_B_YELLOW="$(_nocolor '\033[0;93m')"
  C_B_BLUE="$(_nocolor '\033[0;94m')"
  C_B_MAGENTA="$(_nocolor '\033[0;95m')"
  C_B_CYAN="$(_nocolor '\033[0;96m')"
  C_B_WHITE="$(_nocolor '\033[0;97m')"

  C_GRAY="$(_nocolor '\033[0;90m')"

  export C_B_BLACK C_B_RED C_B_GREEN C_B_YELLOW
  export C_B_BLUE C_B_MAGENTA C_B_CYAN C_B_WHITE
  export C_GRAY

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
  C_DIM="$(_nocolor '\033[2m')"    # aka faint
  C_ITALIC="$(_nocolor '\033[3m')" # not widely supported
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

_colortest() {

  clear
  echo -e "${C_BOLD}== Foreground Colors ==${C_NC}"
  echo -e "${C_BLACK}C_BLACK${C_NC}      ${C_RED}C_RED${C_NC}       ${C_GREEN}C_GREEN${C_NC}   ${C_YELLOW}C_YELLOW${C_NC}   ${C_BLUE}C_BLUE${C_NC}     ${C_MAGENTA}C_MAGENTA${C_NC}   ${C_CYAN}C_CYAN${C_NC}     ${C_WHITE}C_WHITE${C_NC}"
  echo -e "${C_B_BLACK}C_B_BLACK${C_NC}   ${C_B_RED}C_B_RED${C_NC}   ${C_B_GREEN}C_B_GREEN${C_NC} ${C_B_YELLOW}C_B_YELLOW${C_NC} ${C_B_BLUE}C_B_BLUE${C_NC}   ${C_B_MAGENTA}C_B_MAGENTA${C_NC} ${C_B_CYAN}C_B_CYAN${C_NC}   ${C_B_WHITE}C_B_WHITE${C_NC}"

  echo
  echo -e "${C_BOLD}== Background Colors ==${C_NC}"
  echo -e "${C_BG_BLACK}C_BG_BLACK${C_NC}   ${C_BG_RED}C_BG_RED${C_NC}   ${C_BG_GREEN}C_BG_GREEN${C_NC} ${C_BG_YELLOW}C_BG_YELLOW${C_NC} ${C_BG_BLUE}C_BG_BLUE${C_NC}   ${C_BG_MAGENTA}C_BG_MAGENTA${C_NC} ${C_BG_CYAN}C_BG_CYAN${C_NC}   ${C_BG_WHITE}C_BG_WHITE${C_NC}"
  echo -e "${C_BG_B_BLACK}C_BG_B_BLACK${C_NC} ${C_BG_B_RED}C_BG_B_RED${C_NC} ${C_BG_B_GREEN}C_BG_B_GREEN${C_NC} ${C_BG_B_YELLOW}C_BG_B_YELLOW${C_NC} ${C_BG_B_BLUE}C_BG_B_BLUE${C_NC} ${C_BG_B_MAGENTA}C_BG_B_MAGENTA${C_NC} ${C_BG_B_CYAN}C_BG_B_CYAN${C_NC} ${C_BG_B_WHITE}C_BG_B_WHITE${C_NC}"

  echo
  echo -e "${C_BOLD}== Styles ==${C_NC}"
  echo -e "${C_BOLD}C_BOLD${C_NC}    ${C_DIM}C_DIM${C_NC}      ${C_ITALIC}C_ITALIC${C_NC}      ${C_UNDER}C_UNDER${C_NC}    ${C_BLINK}C_BLINK${C_NC}    ${C_REVERSE}C_REVERSE${C_NC}    ${C_HIDDEN}C_HIDDEN${C_NC}    ${C_STRIKE}C_STRIKE${C_NC}"

  echo
  echo -e "${C_BOLD}== Undo Styles ==${C_NC}"
  echo -e "${C_UNBOLD}C_UNBOLD${C_NC} ${C_UNDIM}C_UNDIM${C_NC} ${C_UNITALIC}C_UNITALIC${C_NC} ${C_UNUNDER}C_UNUNDER${C_NC} ${C_UNBLINK}C_UNBLINK${C_NC} ${C_UNREVERSE}C_UNREVERSE${C_NC} ${C_UNHIDDEN}C_UNHIDDEN${C_NC} ${C_UNSTRIKE}C_UNSTRIKE${C_NC}"

  echo
  echo -e "${C_BOLD}== Resets ==${C_NC}"
  echo -e "${C_RESET_FG}C_RESET_FG${C_NC} ${C_RESET_BG}C_RESET_BG${C_NC} ${C_NC}C_NC (reset all)${C_NC}"

  echo
  echo -e "${C_BOLD}== Combo Example ==${C_NC}"
  echo -e "${C_B_YELLOW}${C_BG_B_BLUE}${C_BOLD}Bright Yellow on Bright Blue Bold${C_NC}"
  echo -e "${C_CYAN}${C_BG_B_BLACK}${C_UNDER}Cyan on Bright Black Underline${C_NC}"
  echo -e "${C_RED}${C_BG_WHITE}${C_STRIKE}Red on White Strikethrough${C_NC}"
}
