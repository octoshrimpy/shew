#! /usr/bin/env bash

# _write: Interactive multiline text input with header, placeholder, and cursor navigation.
# flags: --header str, --placeholder str
# use: _write --header "Tell me a story:" --placeholder "Once upon a time..."
_write() {
  __tty_enter
  
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
    --header)
      HEADER="${C_CYAN}$2${C_NC}"
      HEADER_LINES=1
      shift 2
      ;;
    --placeholder)
      PLACEHOLDER="${C_B_BLACK}$2${C_NC}"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      return 1
      ;;
    esac
  done

  stty -echo -icanon time 1 min 0
  trap 'stty sane; printf "\033[?25h\n"; return 130' INT

  [ -n "$HEADER" ] && printf "%b\n" "$HEADER"

  # Cursor anchor
  _get_cursor() {
    printf '\033[6n' >/dev/tty
    IFS=';' read -srdR -p "" pos </dev/tty || pos="[1;1"
    local row col
    row="${pos#*[}"
    col="${pos#*;}"
    row="${row%%;*}"
    col="${col%%R*}"
    ANCHOR_ROW=${row:-1}
    ANCHOR_COL=${col:-1}
  }

  # Move to line relative to anchor, scrolling if needed
  _move_to_line() {
    local line="$1"
    local target_row=$((ANCHOR_ROW + line))
    _get_term_height
    while ((target_row > TERM_HEIGHT)); do
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
      printf "\033[1G\033[%dC" "$((${#PROMPT} + CURSOR))"
    fi
    printf "\033[?25h"
  }

  # Redraw lines from index (for newlines, deletes, etc)
  _redraw_lines_from() {
    printf "\033[?25l"
    local idx="$1"
    local i
    for ((i = idx; i < ${#INPUT_BUF[@]}; i++)); do
      _move_to_line "$i"
      printf "\033[1G\033[K%s" "$PROMPT"
      if [ -z "${INPUT_BUF[i]}" ] && [ "$i" -eq 0 ] && [ -n "$PLACEHOLDER" ] && [ "${#INPUT_BUF[@]}" -eq 1 ]; then
        printf "%b" "$PLACEHOLDER"
      else
        printf "%s" "${INPUT_BUF[i]}"
      fi
    done
    for (( ; i <= idx + PAD_LINES; i++)); do
      _move_to_line "$i"
      printf "\033[1G\033[K"
    done
    _move_to_line "$LINE_INDEX"
    printf "\033[1G\033[%dC" "$((${#PROMPT} + CURSOR))"
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
          if [ "$LINE_INDEX" -lt $((${#INPUT_BUF[@]} - 1)) ]; then
            LINE_INDEX=$((LINE_INDEX + 1))
            [ "$CURSOR" -gt "${#INPUT_BUF[LINE_INDEX]}" ] && CURSOR=${#INPUT_BUF[LINE_INDEX]}
            _redraw_line
          fi
          ;;
        C) # Right
          if [ "$CURSOR" -lt "${#INPUT_BUF[LINE_INDEX]}" ]; then
            CURSOR=$((CURSOR + 1))
            _redraw_line
          elif [ "$LINE_INDEX" -lt $((${#INPUT_BUF[@]} - 1)) ]; then
            LINE_INDEX=$((LINE_INDEX + 1))
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
            CURSOR=$((CURSOR - 1))
            _redraw_line
          elif [ "$LINE_INDEX" -gt 0 ]; then
            LINE_INDEX=$((LINE_INDEX - 1))
            CURSOR=${#INPUT_BUF[LINE_INDEX]}
            _redraw_line
          fi
          ;;
        H)
          CURSOR=0
          _redraw_line
          ;;
        F)
          CURSOR=${#INPUT_BUF[LINE_INDEX]}
          _redraw_line
          ;;
        esac
        continue
      fi
      local now=$(date +%s%3N)
      if ((now - last_esc_time < 500)); then
        printf "\n"
        break
      fi
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
      INPUT_BUF=("${INPUT_BUF[@]:0:$LINE_INDEX}" "$before" "$after" "${INPUT_BUF[@]:$((LINE_INDEX + 1))}")
      LINE_INDEX=$((LINE_INDEX + 1))
      CURSOR=0
      _redraw_lines_from $((LINE_INDEX - 1))
      ;;
    $'\x03') # Ctrl+C aborts
      stty sane
      printf "\033[?25h\n"
      return 130
      ;;
    $'\x7f') # Backspace
      if [ "$CURSOR" -gt 0 ]; then
        INPUT_BUF[LINE_INDEX]="${INPUT_BUF[LINE_INDEX]:0:CURSOR-1}${INPUT_BUF[LINE_INDEX]:CURSOR}"
        CURSOR=$((CURSOR - 1))
        _redraw_line
      elif [ "$LINE_INDEX" -gt 0 ]; then
        local len_above=${#INPUT_BUF[LINE_INDEX - 1]}
        INPUT_BUF[LINE_INDEX - 1]+="${INPUT_BUF[LINE_INDEX]}"
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
  printf "\033[J"  # Clear everything from here down

  printf "\033[?25h" # Show cursor

  __tty_leave
  
  for line in "${INPUT_BUF[@]}"; do
    printf "%s\n" "$line"
  done
}
