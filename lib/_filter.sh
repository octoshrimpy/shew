#! /usr/bin/env bash

# TODO: overflow cleanly.
# brew list | _filter --multi

# _filter: Interactive single/multi-choice selector with header, prompt, fuzzy filtering, and keyboard navigation.
# flags: --header str, --prompt str, --multi, --strict, --reverse, --limit int, --selected str, --label/--labels str
# use: _filter --header "Choose your favorite:" --prompt "Pick one:" --multi --limit 3 --label "Apple|a Banana|b Cherry|c"
_filter() {

    local HEADER="" PROMPT="" MULTI=0 STRICT=0 REVERSE=0 LIMIT=0
    local -a OPTIONS=() RAW_OPTIONS=() LABELS=() VALUES=() SELECTED_ITEMS=() SELECTED=()
    local SELECTED_STR=""
    local POINTER=">" SELECTABLE="●" UNSELECTABLE="᳃" CHECKED="✔"

    while [[ $# -gt 0 ]]; do
        case "$1" in
        --header)
            HEADER="$2"
            shift 2
            ;;
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        --multi)
            MULTI=1
            shift
            ;;
        --strict)
            STRICT=1
            shift
            ;;
        --reverse)
            REVERSE=1
            shift
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --selected)
            SELECTED_STR="$2"
            shift 2
            ;;
        --label | --labels)
            IFS=' ' read -r -a RAW_OPTIONS <<<"$2"
            shift 2
            ;;
        --)
            shift
            break
            ;;
        *)
            OPTIONS+=("$1")
            shift
            ;;
        esac
    done
    
    # read from stdin
    if (( ${#OPTIONS[@]} == 0 )) && [[ ! -t 0 ]]; then
        local stdin_data
        stdin_data="$(cat)"
        
        mapfile -t OPTIONS <<<"$stdin_data"
    fi

    __tty_enter
    if [[ ${#RAW_OPTIONS[@]} -gt 0 ]]; then
        for item in "${RAW_OPTIONS[@]}"; do
            LABELS+=("${item%%|*}")
            VALUES+=("${item#*|}")
        done
        OPTIONS=("${LABELS[@]}")
    fi

    [[ $REVERSE -eq 1 ]] && OPTIONS=("$(printf "%s\n" "${OPTIONS[@]}" | tac)")
    [[ ${#RAW_OPTIONS[@]} -gt 0 && $REVERSE -eq 1 ]] && VALUES=("$(printf "%s\n" "${VALUES[@]}" | tac)")

    if [[ -n $SELECTED_STR ]]; then
        IFS=' ' read -r -a SELECTED_ITEMS <<<"$SELECTED_STR"
    fi

    for ((i = 0; i < ${#OPTIONS[@]}; i++)); do
        SELECTED[i]=0
        for sel in "${SELECTED_ITEMS[@]}"; do [[ "${OPTIONS[i]}" == "$sel" ]] && SELECTED[i]=1 && break; done
    done

    local -a ORIG_OPTIONS=("${OPTIONS[@]}")
    local -a FILTERED=("${ORIG_OPTIONS[@]}")
    local -a FILTERED_IDX=()
    for i in "${!ORIG_OPTIONS[@]}"; do FILTERED_IDX+=("$i"); done

    local FILTER="" FILTER_MODE=0 CURSOR=0 HEADER_LINES=0
    local COUNT_LINE=$((MULTI && LIMIT > 0 ? 1 : 0))

    # TODO: rethink prompt logic
    printf "\033[?25l"
    [[ -n "$PROMPT" ]] && echo -ne "${PROMPT} " && ((HEADER_LINES++))
    printf "\033[s"

    # _move_to_line
    # Restore the cursor to the saved position (via ESC[s]), then move it down by N lines.
    # Arguments:
    #   $1  Number of lines to move the cursor down from the saved point.
    _move_to_line() {
        printf "\033[u"
        (($1 > 0)) && printf "\033[%dB" "$1"
    }

    # _draw_header
    # Redraw the header area: either the live filter prompt (in filter mode) or the static header text.
    # In filter mode, shows the current FILTER string (or HEADER if empty) on a single line with inverted colors,
    # positions the cursor at the end of the filter, and makes it visible.
    # In normal mode, prints HEADER in cyan, then hides the cursor.
    _draw_header() {
        _move_to_line 0
        printf "\033[2K\r"
        if ((FILTER_MODE)); then
            printf "%b" "${C_B_BLACK}"
            [[ -z "$FILTER" ]] && printf "%s" "$HEADER" || printf "%s" "$FILTER"
            printf "%b" "${C_NC}"
            printf "\r"
            [[ ${#FILTER} -gt 0 ]] && printf "\033[%dC" "${#FILTER}"
            printf "\033[?25h"
        else
            printf "${C_CYAN}%s${C_NC}\n" "$HEADER"
            printf "\033[?25l"
        fi
    }

    # _draw_count
    # When in multi-select mode with a LIMIT, display how many items have been picked.
    # Shows “X/Y selected” on the line immediately below the header, plus a hint
    # (“/ to filter” or “[enter] to apply, [esc] to cancel”) based on FILTER_MODE.
    _draw_count() {
        local filter="/ to filter"

        if ((FILTER_MODE)); then
            filter=" [enter] to apply, [esc] to cancel"
        fi
        if [[ $MULTI -eq 1 && $LIMIT -gt 0 ]]; then
            local selected_count=0
            for n in "${SELECTED[@]}"; do ((selected_count += n)); done
            _move_to_line 1
            printf "\033[2K\r"
            echo -e "${C_ITALIC}${C_B_BLACK}${selected_count}/${LIMIT} selected. $filter${C_NC}"
        fi
    }

    # _highlight_match
    # Print a text string with occurrences of the current filter pattern highlighted.
    # Performs case-insensitive matching.
    # If iscursor is true, bolds the whole line and renders the match in cyan;
    # otherwise only the matched substring is colored and bolded.
    # Arguments:
    #   $1  The full text of the option.
    #   $2  The filter pattern.
    #   $3  Optional flag (“true”/nonzero) indicating whether this line is the current cursor.
    _highlight_match() {
        local text="$1" pat="$2" iscursor="${3:-false}"
        # If no pattern, just print (bold if iscursor)
        if [[ -z "$pat" ]]; then
            if [[ -n "$iscursor" && "$iscursor" != "0" ]]; then
                echo -ne "${C_BOLD}${text}${C_UNBOLD}"
            else
                echo -ne "$text"
            fi
            return
        fi
        local lc_text="${text,,}" lc_pat="${pat,,}" idx
        idx=$(awk -v a="$lc_text" -v b="$lc_pat" 'BEGIN{print index(a,b)}')
        if ((idx > 0)); then
            local pre="${text:0:$((idx - 1))}"
            local match="${text:$((idx - 1)):$((${#pat}))}"
            local post="${text:$((idx - 1 + ${#pat}))}"

            if [[ -n "$iscursor" && "$iscursor" != "0" ]]; then
                # Bold everything, only match is cyan+bold
                echo -ne "${C_BOLD}${pre}${C_CYAN}${match}${C_RESET_FG}${C_BOLD}${post}${C_UNBOLD}"
            else
                # Only match is cyan+bold
                echo -ne "$pre${C_CYAN}${C_BOLD}$match${C_NC}${C_UNBOLD}$post"
            fi
        else
            # No match, but if iscursor, bold whole line
            if [[ -n "$iscursor" && "$iscursor" != "0" ]]; then
                echo -ne "${C_BOLD}${text}${C_UNBOLD}"
            else
                echo -ne "$text"
            fi
        fi
    }

    # _fuzzy_filter
    # Rebuild the FILTERED and FILTERED_IDX arrays based on the current FILTER string.
    # If FILTER is empty, includes all ORIG_OPTIONS; otherwise includes only those
    # whose lowercase form contains the lowercase FILTER.
    # Also ensures CURSOR stays within the new filtered list bounds.
    _fuzzy_filter() {
        FILTERED=()
        FILTERED_IDX=()
        if [[ -z "$FILTER" ]]; then
            FILTERED=("${ORIG_OPTIONS[@]}")
            for i in "${!ORIG_OPTIONS[@]}"; do FILTERED_IDX+=($i); done
        else
            for i in "${!ORIG_OPTIONS[@]}"; do
                [[ "${ORIG_OPTIONS[i],,}" == *"${FILTER,,}"* ]] && FILTERED+=("${ORIG_OPTIONS[i]}") && FILTERED_IDX+=("$i")
            done
        fi
        ((CURSOR >= ${#FILTERED[@]})) && CURSOR=0
    }

    # _draw_option
    # Render a single option line in the menu, given its position in the FILTERED array.
    # Adds a pointer (>) for the cursor line, shows a checkbox or bullet for multi-select,
    # applies highlighting to the matched substring, and bolds the focused line.
    # Arguments:
    #   $1  Index into FILTERED/FILTERED_IDX for which option to draw.
    _draw_option() {
        local fidx=$1
        local idx="${FILTERED_IDX[$fidx]}"
        local opt="${FILTERED[$fidx]}"
        local selected_count=0 prefix="" symbol=""
        for n in "${SELECTED[@]}"; do ((selected_count += n)); done
        if [[ $MULTI -eq 1 ]]; then
            if [[ ${SELECTED[idx]} -eq 1 ]]; then
                symbol="${C_GREEN}${CHECKED}${C_NC}"
            else
                if [[ $LIMIT -gt 0 && $selected_count -ge $LIMIT ]]; then
                    symbol="${C_B_BLACK}${UNSELECTABLE}${C_NC}"
                else symbol="${C_B_BLACK}${SELECTABLE}${C_NC}"; fi
            fi
            prefix+="$symbol"
        fi
        if [[ $fidx -eq $CURSOR ]]; then
            printf "\033[2K\r"
            echo -ne "${C_NC}${POINTER} $prefix ${C_BOLD}"
            _highlight_match "$opt" "$FILTER" "true"
            echo -e "${C_UNBOLD}${C_NC}"
        else
            printf "\033[2K\r"
            echo -ne "  $prefix "
            _highlight_match "$opt" "$FILTER"
            echo -e "${C_NC}"
        fi
    }

    # _draw_menu
    # Clear the full menu area then redraw every part of the interface:
    #   1. The header (_draw_header)
    #   2. The count line (_draw_count), if in multi-select with a limit
    #   3. Each filtered option (_draw_option)
    # Manages cursor visibility depending on whether filter mode is active.
    _draw_menu() {
        local total_lines=$((1 + COUNT_LINE + ${#ORIG_OPTIONS[@]}))
        _move_to_line 0
        for ((i = 0; i < total_lines; i++)); do
            printf "\033[2K\r"
            ((i < total_lines - 1)) && printf "\033[1B"
        done
        _move_to_line 0
        _draw_header
        [[ $MULTI -eq 1 && $LIMIT -gt 0 ]] && _draw_count
        local start=$((1 + COUNT_LINE))
        for ((i = 0; i < ${#FILTERED[@]}; i++)); do
            _move_to_line $((start + i))
            _draw_option "$i"
        done
        if ((FILTER_MODE)); then
            _move_to_line 0
            printf "\r"
            [[ ${#FILTER} -gt 0 ]] && printf "\033[%dC" "${#FILTER}"
            printf "\033[?25h"
        else
            printf "\033[?25l"
        fi
    }

    _fuzzy_filter
    _draw_menu

    trap 'stty sane; printf "\033[?25h"; return 130' INT
    stty -echo -icanon time 0 min 1

    while IFS= read -rsn1 key; do
        if ((FILTER_MODE)); then
            if [[ $key == $'\x1b' ]]; then
                # try to read an arrow‐sequence suffix
                read -rsn2 -t 0.01 key2
                if [[ -z "$key2" ]]; then
                    # plain Esc → cancel filter
                    FILTER=""
                    FILTER_MODE=0
                    _fuzzy_filter
                    _draw_menu
                else
                    # actual CSI: handle arrows
                    case "$key2" in
                    "[A")
                        ((CURSOR > 0)) && ((CURSOR--))
                        _draw_menu
                        ;;
                    "[B")
                        ((CURSOR < ${#FILTERED[@]} - 1)) && ((CURSOR++))
                        _draw_menu
                        ;;
                    esac
                fi
                continue
            fi
            case "$key" in
            $'\t') # Tab: select/deselect in filter mode
                if [[ $MULTI -eq 1 && ${#FILTERED[@]} -gt 0 ]]; then
                    local idx="${FILTERED_IDX[$CURSOR]}"
                    local selected_count=0
                    for n in "${SELECTED[@]}"; do ((selected_count += n)); done
                    if [[ ${SELECTED[idx]} -eq 1 ]]; then
                        SELECTED[idx]=0
                    elif [[ $LIMIT -gt 0 && $selected_count -ge $LIMIT ]]; then
                        tput bel
                    else
                        SELECTED[idx]=1
                    fi
                    _draw_menu
                fi
                ;;
            $'\177' | $'\010') # Backspace
                if [[ -n "$FILTER" ]]; then
                    FILTER="${FILTER:0:-1}"
                    _fuzzy_filter
                    _draw_menu
                fi
                ;;
            "") # Enter: leave filter mode
                FILTER_MODE=0
                _draw_menu
                ;;
            $'\x1b') # Esc: leave filter mode
                FILTER=""
                FILTER_MODE=0
                _fuzzy_filter
                _draw_menu
                ;;
            *)
                FILTER="$FILTER$key"
                _fuzzy_filter
                _draw_menu
                ;;
            esac
            continue
        fi

        if [[ $key == $'\x1b' ]]; then
            read -rsn2 -t 0.01 key2
            case "$key2" in
            "[A")
                ((CURSOR > 0)) && ((CURSOR--))
                _draw_menu
                ;;
            "[B")
                ((CURSOR < ${#FILTERED[@]} - 1)) && ((CURSOR++))
                _draw_menu
                ;;
            esac
            continue
        fi
        case "$key" in
        $'\t')
            if [[ $MULTI -eq 1 && ${#FILTERED[@]} -gt 0 ]]; then
                local idx="${FILTERED_IDX[$CURSOR]}"
                local selected_count=0
                for n in "${SELECTED[@]}"; do ((selected_count += n)); done
                if [[ ${SELECTED[idx]} -eq 1 ]]; then
                    SELECTED[idx]=0
                elif [[ $LIMIT -gt 0 && $selected_count -ge $LIMIT ]]; then
                    tput bel
                else
                    SELECTED[idx]=1
                fi
                _draw_menu
            fi
            ;;
        "/")
            FILTER_MODE=1
            _draw_menu
            ;;
        "") # Enter
            stty sane
            printf "\033[u"
            for ((i = 0; i < ${#ORIG_OPTIONS[@]} + COUNT_LINE + 1; i++)); do
                printf "\033[2K\r"
                ((i < ${#ORIG_OPTIONS[@]} + COUNT_LINE)) && printf "\033[1B"
            done
            printf "\033[u"
            if ((HEADER_LINES > 0)); then
                for ((i = 0; i < HEADER_LINES; i++)); do printf "\033[1A"; done
                for ((i = 0; i < HEADER_LINES; i++)); do
                    printf "\033[2K\r"
                    ((i < HEADER_LINES - 1)) && printf "\033[1B"
                done
            fi
            printf "\033[?25h"
            local out=()
            if [[ $MULTI -eq 1 ]]; then
                for i in "${!ORIG_OPTIONS[@]}"; do [[ ${SELECTED[i]} -eq 1 ]] && out+=("${ORIG_OPTIONS[i]}"); done
            else
                out=("${FILTERED[$CURSOR]}")
            fi
            if [[ ${#RAW_OPTIONS[@]} -gt 0 && $STRICT -eq 0 ]]; then
                local final=()
                for sel in "${out[@]}"; do for j in "${!LABELS[@]}"; do [[ "${LABELS[j]}" == "$sel" ]] && final+=("${VALUES[j]}"); done; done
                echo "${final[*]}"
            else echo "${out[*]}"; fi
            return 0
            ;;
        esac
    done

    stty sane
    __tty_leave

    printf "\033[?25h"
    return 0
}
