#! /usr/bin/env bash

# _confirm: Ask user for confirmation with optional timeout and custom labels
# usage:
#   _confirm --affirmative "aye!" --negative "nay.." --prompt "Are ye a pirate?" --default false --timeout 5
# returns:
#   0 if the user selects the affirmative option
#   1 if the user selects the negative option
#   130 on timeout or Ctrl+C

_confirm() {
    __tty_enter

    local affirmative="Yes"
    local negative="No"
    local prompt="Are you sure?"
    local timeout=0
    local selected=0 # 0 = affirmative, 1 = negative
    local last_time_left=-1  # used to avoid redrawing if timer hasn’t changed

    # Trap Ctrl+C and Ctrl+Q
    trap "" SIGQUIT
    trap 'echo -ne "\e[3B\e[1A\e[2K\e[1A\e[1A\e[2K\e[1G\033[?25h"; stty echo; return 130;' SIGINT

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
        --affirmative)
            shift
            affirmative="$1"
            ;;
        --negative)
            shift
            negative="$1"
            ;;
        --prompt)
            shift
            prompt="$1"
            ;;
        --timeout)
            shift
            timeout="$1"
            ;;
        --default)
            shift
            # if default is false, pre-select negative
            [[ "$1" == false ]] && selected=1
            ;;
        *)
            echo "Unknown option: $1"
            return 1
            ;;
        esac
        shift
    done

    # Hide cursor
    printf "\033[?25l"

    # If using a timeout, calculate end time
    if [[ $timeout -gt 0 ]]; then
        local now_time
        now_time=$(date +%s)

        local end_time=$((now_time + timeout))
        local time_left
        time_left="$timeout"
    fi

    # --- Inner function: draw_buttons ---
    # Redraws the prompt line, timer (if any), and both buttons,
    # highlighting the currently selected option.
    draw_buttons() {
        local time_prefix=""
        if [[ $timeout -gt 0 ]]; then
            # Show countdown in seconds before the prompt
            time_prefix="${C_YELLOW}${time_left}s${C_B_BLACK} :: ${C_NC}"
        fi

        # Print prompt line (with optional timer)
        echo -e "${time_prefix}${C_CYAN}${C_ITALIC}$prompt${C_NC}\n"

        # Print affirmative and negative "buttons"
        if [[ $selected -eq 0 ]]; then
            # highlight affirmative
            echo -e " ${C_BLACK}${C_BG_MAGENTA} $affirmative ${C_NC}  $negative ${C_NC}"
        else
            # highlight negative
            echo -e "  $affirmative ${C_NC} ${C_BLACK}${C_BG_MAGENTA} $negative ${C_NC}"
        fi

        # Move cursor back up so we can overwrite on next draw
        echo -ne "\e[3A\e[1G" 
    }

    # --- Inner function: cleanup ---
    # Restores cursor visibility, clears prompt lines, resets terminal state,
    # and calls __tty_leave to exit raw mode.
    cleanup() {
        # Show cursor again
        echo -ne "\e[3B\e[1A\e[2K\e[1A\e[1A\e[2K\e[1G"
        printf "\033[?25h" # show cursor
        stty echo
        __tty_leave
    }

    # Initial draw
    draw_buttons

    # disable input echo
    stty -echo
    while true; do

        # Update and redraw timer if needed
        if [[ $timeout -gt 0 ]]; then
            now_time=$(date +%s)
            time_left=$((end_time - now_time))
            if ((time_left <= 0)); then
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
            $'\e[C')              # Right arrow → select "No"
                selected=1
                draw_buttons
                ;; # Right arrow
            $'\e[D')              # Left arrow → select "Yes"
                selected=0
                draw_buttons
                ;; # Left arrow
            "") break ;;          # Enter key → break and accept current selection
            esac
        fi
        sleep 0.1

    done

    cleanup && return 130
}
