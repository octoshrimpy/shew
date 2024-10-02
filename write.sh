#!/usr/bin/env bash

input_with_placeholder() {
    local prefix="┃ "
    local placeholder="${1:-'Write something...'}"
    local input_lines=("")
    local line=""
    local key=""
    local first_input=true

    # Print initial lines with prefix
    for ((i = 0; i < 5; i++)); do
        if [ "$i" -eq 0 ]; then
            # Print the first line with placeholder in gray
            echo -e "${GRAY}$prefix$placeholder"
        else
            # Print empty lines with the prefix
            echo -e "${GRAY}$prefix"
        fi
    done

    # Move cursor to the beginning of the first line for user input
    cursor_move up 5
    cursor_move right ${#prefix}

    while IFS= read -r -s -n1 key; do
        case "$key" in
            $'\x1b')  # Handle escape sequences (arrow keys)
                read -r -s -n2 -t 0.1 arrow_key
                case "$arrow_key" in
                    '[A')  # Up arrow key
                        if [ $current_line -gt 0 ]; then
                            cursor_move up 1
                            ((current_line--))
                        fi
                        ;;
                    '[B')  # Down arrow key
                        if [ $current_line -lt $((total_lines - 1)) ]; then
                            cursor_move down 1
                            ((current_line++))
                        fi
                        ;;
                    '[C')  # Right arrow key
                        if [ $current_line -lt $((total_lines - 1)) ]; then
                            cursor_move down 1
                            ((current_line++))
                        fi
                        ;;
                    '[D')  # Left arrow key
                        if [ $current_line -lt $((total_lines - 1)) ]; then
                            cursor_move down 1
                            ((current_line++))
                        fi
                        ;;

                esac
                ;;
            $'\x0D'|$'\x0A'|$'\x00') # Enter key (Carriage Return or Line Feed)
                # Append the current line to the list of input lines
                input_lines+=("$line")
                line=''  # Clear the current line variable for new input
                printf "\n${GRAY}$prefix${NC}"
                first_input=true
                ;;
            $'\x7F') # Backspace key
                if [ -n "$line" ]; then
                    # Remove the last character from the current line
                    line="${line%?}"
                    printf "\b \b"
                else
                    # If the user is on an empty line and there are previous lines
                    if [ ${#input_lines[@]} -gt 1 ]; then
                        # Move up to the previous line
                        cursor_move up 1
                        # # Clear that line
                        line_clear
                        # Move back to the start of the cleared line
                        printf "${GRAY}$prefix${NC}"
                        # Retrieve the last element as the current line
                        line="${input_lines[-1]}"
                        # Remove the last element from the array
                        unset 'input_lines[-1]'
                        # Print the previous line's content and set the cursor correctly
                        printf "%s" "$line"
                    elif [ ${#input_lines[@]} -eq 1 ]; then
                        # If it's the first line and empty, re-display the placeholder
                        line_clear
                        printf "${GRAY}$prefix$placeholder${NC}"
                        cursor_move right ${#prefix}
                        # Since we're at the first line, reset the array
                        input_lines=()
                        first_input=true
                    fi
                fi
                ;;
            *)  
                if [[ $first_input == true ]]; then
                  line_clear
                  printf "${GRAY}$prefix${NC}"
                  first_input=false
                fi 
                echo -n "$key"
                line+="$key"
                ;;
        esac
    done

    # If input was canceled (Ctrl+C), clear the lines and exit
    trap 'cursor_move down 5; for i in {1..5}; do line_clear; done; exit 1' SIGINT


    # Erase all 5 lines
    cursor_move up $(( ${#input_lines[@]} < 5 ? ${#input_lines[@]} : 5 ))
    for i in {1..5}; do
        line_clear
        # Move to the next line if not on the last iteration
        [ $i -lt 5 ] && cursor_move down 1
    done

    # Print the text that was typed without the vertical bars
    for input_line in "${input_lines[@]}"; do
        printf "%s\n" "$input_line"
    done
    # Print the current line if it's not empty
    [ -n "$line" ] && printf "%s\n" "$line"
}

# Call the function with a placeholder
input_with_placeholder "Type here"
