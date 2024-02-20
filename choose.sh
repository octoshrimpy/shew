#!/bin/bash

# Function to display a selection menu and return the selected option
choose() {
    local PS3="Please select an option: " # Custom prompt
    local options=("$@") # Capture all arguments as an array of options
    select option in "${options[@]}"; do
        if [ -n "$option" ]; then
            echo "$option"
            break
        else
            echo "Invalid selection."
        fi
    done
}

# Example usage
# options=("Option 1" "Option 2" "Option 3")
# chosen=$(choose "${options[@]}")
# echo "You selected: $chosen"
