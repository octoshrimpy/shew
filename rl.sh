#!/usr/bin/env bash

# === Require External Files ===
# shellcheck source=_colors.sh
# shellcheck source=_util.sh
source ./_colors.sh   # Optional: ANSI color codes
source ./_util.sh     # Event handling and utilities

# === Terminal Safety ===
cleanup() {
    disable_mouse
    stty sane
    tput cnorm
    clear
    exit
}
trap cleanup INT TERM EXIT

# === Game State ===
declare -A MAP

# shellcheck disable=SC2034
declare -A KEY_EVENT_HANDLERS
# shellcheck disable=SC2034
declare -A MOUSE_EVENT_HANDLERS

PLAYER_X=5
PLAYER_Y=5
MAP_WIDTH=20
MAP_HEIGHT=10

# === Init Map ===
init_map() {
    for ((y=0; y<MAP_HEIGHT; y++)); do
        for ((x=0; x<MAP_WIDTH; x++)); do
            MAP["$x,$y"]="."
        done
    done
    MAP["10,5"]="#"
    MAP["15,2"]="~"
}

# === Render Map ===
render() {
    clear
    for ((y=0; y<MAP_HEIGHT; y++)); do
        for ((x=0; x<MAP_WIDTH; x++)); do
            if [[ $x -eq $PLAYER_X && $y -eq $PLAYER_Y ]]; then
                printf "@"
            else
                printf "%s" "${MAP["$x,$y"]}"
            fi
        done
        echo
    done
    echo "Use arrow keys or WASD. Press q to quit."
}

# === Movement Functions ===
try_move_player() {
    local dx=$1
    local dy=$2
    local new_x=$((PLAYER_X + dx))
    local new_y=$((PLAYER_Y + dy))

    if (( new_x >= 0 && new_x < MAP_WIDTH && new_y >= 0 && new_y < MAP_HEIGHT )); then
        PLAYER_X=$new_x
        PLAYER_Y=$new_y
    fi

    render
}

handle_up()    { try_move_player  0 -1; }
handle_down()  { try_move_player  0  1; }
handle_left()  { try_move_player -1  0; }
handle_right() { try_move_player  1  0; }

# === Key & Quit Logic ===
handle_quit() {
    echo "Exiting..."
    KEY_EVENT_HANDLERS["exit_event"]="true"
}

handle_key() {
    case "$1" in
        q) handle_quit ;;
        w) handle_up ;;
        s) handle_down ;;
        a) handle_left ;;
        d) handle_right ;;
    esac
}

# === Mouse (Stub) ===
handle_left_click()  { echo "Left click at ($1,$2)"; }
handle_scroll_up()   { echo "Scrolled up at ($1,$2)"; }
handle_scroll_down() { echo "Scrolled down at ($1,$2)"; }

# === Game Entry Point ===
main() {
    tput civis
    init_map
    render

    # Key bindings
    on_key "up_arrow"    handle_up
    on_key "down_arrow"  handle_down
    on_key "left_arrow"  handle_left
    on_key "right_arrow" handle_right
    on_key "key"         handle_key

    # Mouse bindings
    on_mouse "left_click"  handle_left_click
    on_mouse "scroll_up"   handle_scroll_up
    on_mouse "scroll_down" handle_scroll_down

    listen_for_events
}

main
