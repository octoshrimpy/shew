#!/bin/bash

# Assuming necessary utilities and functions are sourced
. ./_util.sh

input_with_placeholder() {
    local prompt="> "
    local placeholder="${1:-' '}"
    local input=""
    local key=""
    local dirty=""
    local base_prompt="${WHITE}$prompt${GRAY}$placeholder"

    printf "$base_prompt"
    cursor_move left $(( ${#placeholder} ))
    printf "${WHITE}"
    
    while IFS= read -r -s -n1 key; do
        if [ ${#input} -gt 0 ]; then
          dirty=1
        else
          dirty=""
        fi
        
        case "$key" in
            $'\x0D'|$'\x0A'|$'\x00') # Enter key (Carriage Return or Line Feed)
                line_clear
                echo "$input"
                break
                ;;
            $'\x7F') # Backspace key
                if [ -n "$input" ]; then
                    input="${input::-1}"
                    echo -en "\b \b"
                fi                
                if [ -z "$input" ]; then
                    # If all input has been deleted, show the placeholder again
                    dirty=""
                    line_clear
                    printf "$base_prompt"  # Reprint the prompt with placeholder
                    cursor_move left $(( ${#placeholder} ))
                fi
                ;;
            *)  
                if [ -z $dirty ]; then
                  dirty=1
                  line_clear
                  printf "${WHITE}$prompt"
                fi
                  input+="$key"
                  echo -n "$key"
                ;;
        esac
    done

    return 0  # Success code
}

export -f input_with_placeholder


if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    input_with_placeholder "Enter your name"
fi
