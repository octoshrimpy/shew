#!/usr/bin/env bash

set -euo pipefail

# enter alternate screen
# echo -e "\e[?1049h"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
. "$SCRIPT_DIR/_lib.sh" \
  || { echo "→ ❌ FAILED to source _lib.sh (exit $?)"; exit 1; }

_setupcolors

export setappname="UNIT TESTS"

# Helper function to display section headers for readability
section() {
  printf "\n\n%b\n" "${C_GRAY}==== ${C_BLUE}$1 ${C_GRAY}====${C_NC}"
}


##############################################################################
# Begin tests

# 1. _dryrun
section "Testing _dryrun"

# Test with debug=false (default).  Expect the command to execute normally.
export DEBUG=false
_prt "_dryrun executes command when DEBUG=false" 
_dryrun echo "Hello from _dryrun (DEBUG=false)"

# Test with debug=true.  Expect it to print a 'Skipping:' message and not
# execute the command.  We set debug back to false afterwards so that later
# tests are unaffected.
DEBUG=true
_prt "_dryrun prints a skip message when DEBUG=true" 
_dryrun echo "This should not run"
DEBUG=false


# 2. _debug
section "Testing _debug"

# Define a test function that sets a flag when run
testfunc_run_flag=false
testfunc() {
  testfunc_run_flag=true
  echo "testfunc executed"
}

# When debug=true, _debug should execute the function and set rundebug to true
export DEBUG=true
_prt "_debug executes function when DEBUG=true" 
_debug testfunc
echo "rundebug after _debug: $rundebug (expected: false after call)"
echo "testfunc_run_flag: $testfunc_run_flag (expected: true)"
DEBUG=false
echo


# 3. _prettyjson
section "Testing _prettyjson"

# Provide a simple JSON string.  The output should be pretty printed if jq is
# available, otherwise it will be minimally formatted by the fallback.  Either
# way the result should be human-readable.
json_input='{"name":"alice","age":30,"admin":false}'
_prt "Pretty print JSON (arg)" 
_prettyjson "$json_input"


# 4. _prt
section "Testing _prt"

# Test normal informational message
_prt "_prt default (info)" 
_prt "This is a normal message"

# Test warning message
_prt "_prt with -w flag (warning)" 
_prt -w "This is a warning"

# Test error message
_prt "_prt with -e flag (error)" 
_prt -e "This is an error"

# Test silent message: prefix replaced with spaces
_prt "_prt with -s flag (silent)" 
_prt -s "This message uses a silent prefix"

# Test debug styling: when rundebug is true the colours invert.  We'll set
# rundebug manually and call _prt; you should see different colours.
rundebug=true
_prt "_prt during debug call (rundebug=true)" 
_prt "Message inside debug context"
rundebug=false


# 5. _prtty
section "Testing _prtty"

# _prtty writes directly to /dev/tty, so when you run this script interactively
# you should see the message appear in the terminal.  We'll invoke it here
# without capturing the output.  Expect a bold error prefix and message.
echo "Calling _prtty (error): you should see the output in your terminal"
_prtty -e "This error is written to /dev/tty"
echo


# 6. _stripcolors
section "Testing _stripcolors"

# Create a coloured string manually using ANSI escape codes then strip them.
coloured_string="${C_RED}Red${C_NC} and ${C_GREEN}Green${C_NC}"
echo "Original string with colours: $coloured_string"
stripped=$(_stripcolors "$coloured_string")
echo "After _stripcolors: $stripped (expected: 'Red and Green' with no escape codes)"
echo


# 7. _nocolor
section "Testing _nocolor"

# A literal ANSI‐CSI for red
TEST_ESC=$'\033[0;31m'
TEST_RESET=$'\033[0m'
for state in unset true; do
  if [[ $state == unset ]]; then
    unset NO_COLOR
  else
    export NO_COLOR=true
    echo
  fi

  echo "→ NO_COLOR=$state"
  color=$(_nocolor "$TEST_ESC")

  # 1) raw (may actually turn the prompt red)
  printf "  raw output:   [%s]\n" "$color test $TEST_RESET"

  # 2) quoted repr so you see the escapes
  printf "  quoted repr:  %q\n" "$color test $TEST_RESET"
done
unset NO_COLOR


# 8. _setupcolors
section "Testing _setupcolors"

# Initialise colours and demonstrate their use.  After calling _setupcolors
# colour variables like $C_RED should be defined.  We'll print a sample
# coloured string and then strip colours to show that _stripcolors removes
# them correctly.
_setupcolors
echo -e "${C_GREEN}This should appear green${C_NC}"
echo "Raw output without colours removed:"
printf '%q\n' "${C_GREEN}This should appear green${C_NC}"
echo "After stripping colours:"
printf '%s\n' "$(_stripcolors "${C_GREEN}This should appear green${C_NC}")"
echo


# 9. _parseargs
section "Testing _parseargs"

# When provided a flag and a value, _parseargs should echo the value.  If the
# next argument looks like another flag, it should emit an error via _prtty
# and exit.  To prevent the test script from exiting on error we run
# _parseargs in a subshell.

echo "Valid case: flag followed by value"
value=$( _parseargs --flag value )
echo "Returned value: '$value' (expected: 'value')"

echo "Error case: flag without value (should print error and exit)"
{
  set +e
  output=$(_parseargs --flag 2>&1)
  status=$?
  set -e
}
if [[ $status -ne 0 && "$output" == *"requires a value"* ]]; then
  echo "Error case passed (exitcode=$status, message='$output')"
else
  echo "Error case FAILED (exitcode=$status, message='$output')"
fi
echo


# 10. _fig
section "Testing _fig"

# Convert a sample string to 3x3 pixel art using _fig.  The result uses
# cursor movement codes; you should see stylised characters printed one after
# another.  Note that escape sequences may not render perfectly in all
# environments.
fig_output=$(_fig "aaa")
printf "%b" "$fig_output"
echo


# 11. _spin
section "Testing _spin (interactive)"

# _spin animates a spinner while running a function.  We'll define a short
# function that sleeps and prints some output, then run it with a spinner.

spin_test_func() {
  echo "First line of work"
  sleep 1
  echo "Second line of work"
  sleep 1
  echo "Done"
}

echo "Running _spin with a sample function.  You should see a spinner with a title and lines of output."
_spin --spinner minidots --title "Processing" --show-output spin_test_func
echo


# 12. _confirm
section "Testing _confirm (interactive)"

# _confirm prompts the user for confirmation and returns with exit code 130
# after the user presses Enter.  The selected option (Yes or No) isn't
# returned directly; you should watch the UI to verify that the buttons
# highlight when you press the left/right arrow keys.  We'll set a short
# timeout so that the prompt doesn't block forever.
echo "Invoke _confirm with custom labels.  Use arrow keys to choose then press Enter.  If no input is given it will time out after 5 seconds."
_confirm --affirmative "Proceed" --negative "Cancel" --prompt "Do you want to continue?" --timeout 5 || true
echo "_confirm returned exit status $? (130 indicates timeout or Enter)"
echo


# 13. _input
section "Testing _input (interactive)"

echo "Test _input: please type a short line of text at the prompt.  The function will echo back your input after you press Enter."
input_result=$(_input --header "Enter some text:" --prompt "# " --placeholder "Type here...")
echo "You entered: '$input_result'"
echo


# 14. _write
section "Testing _write (interactive)"

echo "Test _write: please type multiple lines.  Press Enter for new lines and press Escape twice to finish.  The function will echo back your input."
write_result=$(_write --header "Write something:" --placeholder "Start typing...")
echo "Your multi-line input was:"
echo "$write_result"
echo


# 15. _filter
section "Testing _filter (interactive)"

echo "Test _filter: use arrow keys to navigate and Tab to select/deselect (multi-select).  Press Enter to finish.  Selected values will be printed."
filter_result=$(_filter --header "Choose fruits:" --prompt "Pick some:" --multi --limit 2 --labels "Apple|1 Banana|2 Cherry|3 Date|4")
echo "_filter returned: '$filter_result'"
echo

# exit alternate screen
# echo -e "\e[?1049l"

echo "All tests complete."