#! /usr/bin/env bash

# _input: Single-line interactive input with optional header, prompt, placeholder, value preset, and password masking.
# flags: --header str, --prompt str, --placeholder str, --value str, --password
# use: _input --header "Username:" --prompt "> " --placeholder "Enter your username"
lib::_input() {
  lib::__tty_enter

  local HEADER="" PROMPT="> " PLACEHOLDER="" VALUE="" PASSWORD=false

  while [ "$#" -gt 0 ]; do
    case "$1" in
    --header)
      HEADER="${C_CYAN}$2${C_NC}"
      shift 2
      ;;
    --prompt)
      PROMPT="$2"
      shift 2
      ;;
    --placeholder)
      PLACEHOLDER="${C_B_BLACK}$2${C_NC}"
      shift 2
      ;;
    --value)
      VALUE="$2"
      shift 2
      ;;
    --password)
      PASSWORD=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      return 1
      ;;
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
    $'\x7f')     # Backspace
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
    printf "\033[1A\r\033[K" # Move up and clear
  fi

  lib::__tty_leave
  printf "%s\n" "$INPUT"

}
