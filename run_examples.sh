#!/bin/bash

. ./_util.sh

# choose
. ./choose.sh
options=("Option 1" "Option 2" "Option 3")
chosen=$(choose "${options[@]}")
echo "You selected: $chosen"

# input
. ./input.sh
input_with_placeholder "placeholder text"
