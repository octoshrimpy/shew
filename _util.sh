#!/bin/bash
# Guide: https://github.com/dylanaraps/writing-a-tui-in-bash
# This script provides various utilities for terminal UI manipulation in Bash.

# Cursor Management
# These functions control the cursor's visibility, position, and movement within the terminal.

. ./_colors.sh

# Hide the cursor
# Usage: cursor_hide
cursor_hide() {
  printf '\033[?25l'
}

# Show the cursor
# Usage: cursor_show
cursor_show() {
  printf '\033[?25h'
}

# Moves the cursor to specific X Y coordinates
# Usage: cursor_goto 1 12
cursor_goto() {
  local row=$1
  local col=$2
  printf '\033[%s;%dH' "$row" "$col"
}

# Move the cursor in a specified direction by a given amount
# Usage: cursor_move up 3
cursor_move() {
  local direction=$1
  local amount=$2

  case $direction in
    up)
      printf '\033[%dA' "$amount"
      ;;
    down)
      printf '\033[%dB' "$amount"
      ;;
    left)
      printf '\033[%dD' "$amount"
      ;;
    right)
      printf '\033[%dC' "$amount"
      ;;
    *)
      echo "Invalid direction: $direction"
      ;;
  esac
}

# Save the cursor position
# Usage: cursor_save
cursor_save() {
  printf '\033[s'
}

# Restore the cursor position
# Usage: cursor_restore
cursor_restore() {
  printf '\033[u'
}

# get cursor's current position
# Usage: get_cursor_pos
get_cursor_pos() {
  # Save cursor position
  printf '\033[s'

  # Query cursor position
  printf '\033[6n'

  # Read response from standard input
  local CURSOR_POSITION
  IFS=';' read -r -s CURSOR_POSITION

  # Extract row and column from response
  CURSOR_POSITION="${CURSOR_POSITION#*[}"
  local CURSOR_ROW="${CURSOR_POSITION%%;*}"
  local CURSOR_COLUMN="${CURSOR_POSITION#*;}"

  # Restore cursor position
  printf '\033[u'

  # Return cursor position
  echo "$CURSOR_ROW $CURSOR_COLUMN"
}

# Screen Management
# These functions control the terminal screen, including clearing, resizing, and saving/restoring states.

# Clear the screen
# Usage: screen_clear
screen_clear() {
  printf '\033[2J'
}

# Clear the line
# Usage: line_clear
line_clear() {
  printf '\033[2K\r'
}

# Save the user's terminal screen
# Usage: save_terminal_screen
save_terminal_screen() {
  printf '\033[?1049h'
}

# Restore the user's terminal screen
# Usage: restore_terminal_screen
restore_terminal_screen() {
  printf '\033[?1049l'
}

# Set the scrolling area between the specified top and bottom lines
# Usage: set_scrolling_area 0 10
set_scrolling_area() {
  local top_line=$1
  local bottom_line=$2
  printf '\033[%d;%dr' "$top_line" "$bottom_line"
}

# Reset the scrolling area to the default
# Usage: reset_scrolling_area
reset_scrolling_area() {
  printf '\033[r'
}

# Enable line wrapping
# Usage: linewrap_enable
linewrap_enable() {
  printf '\033[?7h'
}

# Disable line wrapping
# Usage: linewrap_disable
linewrap_disable() {
  printf '\033[?7l'
}

# System Information
# These functions provide information about the operating system and terminal.

# Get the operating system name
# Usage: get_os
get_os() {
  os=$(uname -s)

  case $os in
    Linux*)     echo "Linux" ;;
    Darwin*)    echo "macOS" ;;
    CYGWIN*)    echo "Cygwin" ;;
    MINGW*)     echo "MinGW" ;;
    *)          echo "Unknown" ;;
  esac
}

# Get the terminal size in columns and rows
# Usage: get_term_size
get_term_size() {
  if [ -n "$TERM" ]; then
    rows=$(tput lines)
    cols=$(tput cols)
    echo "$rows $cols"
  else
    echo "not in term!"
  fi
}

# Event Handling
# These functions and event handlers manage key and mouse interactions.

# Enable mouse tracking
# Usage: enable_mouse
enable_mouse() {
    echo -e "\033[?1000h"
}

# Disable mouse tracking
# Usage: disable_mouse
disable_mouse() {
    echo -e "\033[?1000l"
}

# Register key event handler
# Usage: on_key "key_identifier" "handler_function"
on_key() {
    local key_identifier=$1
    local handler_function=$2
    KEY_EVENT_HANDLERS[$key_identifier]=$handler_function
}

# Register mouse event handler
# Usage: on_mouse "mouse_event" "handler_function"
on_mouse() {
    local mouse_event=$1
    local handler_function=$2
    MOUSE_EVENT_HANDLERS[$mouse_event]=$handler_function
}

# Main Event Loop
# This function listens for and dispatches events to their respective handlers.
# Usage: listen_for_events
listen_for_events() {
    enable_mouse
    local keep_running=true

    while $keep_running; do
        IFS= read -r -s -n1 key

        # Adjusted read command for longer sequences
        case "$key" in
            $'\e')
                read -r -s -n5 -t 0.2 seq
                case "$seq" in
                    "[A") event_type="up_arrow" ;;
                    "[B") event_type="down_arrow" ;;
                    "[C") event_type="right_arrow" ;;
                    "[D") event_type="left_arrow" ;;
                    "[M"*) # Begin mouse event sequence
                        event_type="mouse_event"
                        # Process mouse event sequence here (Placeholder)
                        ;;
                    *) event_type="unknown" ;;
                esac
                ;;
            $'\x0D'|$'\x0A') # Enter key
                event_type="enter"
                ;;
            $'\x7F') # Backspace key
                event_type="backspace"
                ;;
            *)
                event_type="key"
                payload="$key"
                ;;
        esac

        # Handle the event
        if [[ -n ${KEY_EVENT_HANDLERS[$event_type]} ]]; then
            ${KEY_EVENT_HANDLERS[$event_type]} "$payload"
        elif [[ -n ${MOUSE_EVENT_HANDLERS[$event_type]} ]]; then
            ${MOUSE_EVENT_HANDLERS[$event_type]} "$payload"
        else
            echo "Unhandled event: $event_type"
            # User feedback for unhandled events
        fi

        if [[ $event_type == "exit_event" ]]; then
            keep_running=false
        fi
    done

    disable_mouse
}

# Set text color
# Usage: set_text_color foreground_color background_color
# Color codes: 0-7 are the standard colors, 30-37 for foreground, 40-47 for background
set_text_color() {
  local fg_color=$1
  local bg_color=$2
  printf '\033[%s;%sm' "$fg_color" "$bg_color"
}

# Reset text color to default
# Usage: reset_text_color
reset_text_color() {
  printf '\033[0m'
}
