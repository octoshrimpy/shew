#! /usr/bin/env bash

# _confirm: Ask user for confirmation
# use: _confirm --affirmative "aye!" --negative "nay.." --prompt "Are ye a pirate?" --default false --timeout 5
# shellcheck disable=SC2120
_confirm() {
    __tty_enter

    local affirmative="Yes"
    local negative="No"
    local prompt="Are you sure?"
    local timeout=0
    local selected=0 # 0 = affirmative, 1 = negative
    local last_time_left=-1

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
    printf "\033[?25l" # hide cursor

    if [[ $timeout -gt 0 ]]; then
        local now_time
        now_time=$(date +%s)

        local end_time=$((now_time + timeout))
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
        printf "\033[?25h" # show cursor
        stty echo
        __tty_leave
    }

    draw_buttons

    # disable input echo
    stty -echo
    while true; do

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
            $'\e[C')
                selected=1
                draw_buttons
                ;; # Right arrow
            $'\e[D')
                selected=0
                draw_buttons
                ;; # Left arrow
            "") break ;;
            esac
        fi
        sleep 0.1

    done

    cleanup && return 130
}
