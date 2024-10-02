#!/usr/bin/env bash
LPWD="$PWD/$(dirname ${BASH_SOURCE[0]})"

# Assuming necessary utilities and functions are sourced
# . ./_util.sh

box() {

    # if 2 args: width, height
    # if 4 args: width, height, position x, position y
    # if 5 args: width, height, position x, position y, point of calculation 
    #   topleft         topcenter       topright
    #   centerleft      center          centerright
    #   bottomleft      bottomcenter    bottomright
    

    # local options=("$@") # Capture all arguments as an array of options
    local width=$1
    local height=$2

    local _width=$((width-2))
    local _height=$((height-2))


    # TODO get cursor position
    # TODO calculate position of box relative to cursor pos and box point of calculation 

    # top bar
    printf "┌"
    for ((i = 0; i < $_width; i++)); do
        printf "─"
    done
    printf "┐"
    
    # next line
    cursor_move down 1
    cursor_move left $width

    for ((i = 0; i < $_height; i++)); do
        printf "│"
        cursor_move right $_width
        printf "│"
        cursor_move down 1
        cursor_move left $width
    done
    
    # bottom bar
    printf "└"
    for ((i = 0; i < $_width; i++)); do
        printf "─"
    done
    
    printf "┘"
    

    return 0  # Success code
}


export -f box

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    box 5 5
fi
