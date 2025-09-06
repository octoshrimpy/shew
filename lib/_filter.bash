#!/usr/bin/env bash

# TODO: overflow cleanly.
# brew list | _filter --multi

# _filter: Interactive single/multi-choice selector with header, prompt, fuzzy filtering, and keyboard navigation.
# flags: --header str, --prompt str, --multi, --strict, --reverse, --limit int, --selected str, --label/--labels str
# use: _filter --header "Choose your favorite:" --prompt "Pick one:" --multi --limit 3 --label "Apple|a Banana|b Cherry|c"
shew__filter() {

    # If running under zsh, emulate bash semantics locally (no global shell changes)
    if [ -n "${ZSH_VERSION-}" ]; then
        emulate -L bash
        setopt ksharrays # make arrays 0-indexed like bash
    fi

    # --- helpers -------------------------------------------------------------

    # portable lowercase (avoid ${var,,})
    _shew__lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

    # portable "read N chars [with optional timeout]" into named var
    # usage: _shew__read_n 1 "" key        # read 1 char, no timeout
    #        _shew__read_n 2 0.01 key2     # read 2 chars, 0.01s timeout
    _shew__read_n() {
        local __n="$1" __t="$2" __var="$3" __buf __rc
        local IFS=

        if [ -n "${ZSH_VERSION-}" ]; then
            emulate -L bash
            if [ -n "$__t" ]; then
                read -rsk "$__n" -t "$__t" __buf
            else
                read -rsk "$__n" __buf
            fi
            __rc=$?
        else
            if [ -n "$__t" ]; then
                read -rsn"$__n" -t "$__t" __buf
            else
                read -rsn"$__n" __buf
            fi
            __rc=$?
        fi

        # Assign the buffer to the named variable
        printf -v "$__var" '%s' "$__buf"
        return "$__rc"
    }

    # --- args & state --------------------------------------------------------

    local HEADER="" PROMPT="" MULTI=0 STRICT=0 REVERSE=0 LIMIT=0
    typeset -a OPTIONS RAW_OPTIONS LABELS VALUES SELECTED_ITEMS SELECTED
    local SELECTED_STR=""
    local POINTER=">" SELECTABLE="●" UNSELECTABLE="᳃" CHECKED="✔"
    local MAX_LINES=10 # default page height
    local PAGE=0 NPAGES=0

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
            # Read space-separated "Label|Value" items into RAW_OPTIONS (zsh/bash compatible)
            if [ -n "${ZSH_VERSION-}" ]; then
                IFS=' ' read -rA RAW_OPTIONS <<<"$2"
            else
                IFS=' ' read -r -a RAW_OPTIONS <<<"$2"
            fi
            # Remove completely empty entries from RAW_OPTIONS
            TMP=()
            for item in "${RAW_OPTIONS[@]}"; do
                [[ -n "$item" ]] && TMP+=("$item")
            done
            RAW_OPTIONS=("${TMP[@]}")
            shift 2
            ;;
        --max)
            MAX_LINES="$2"
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

    # if we have no positional OPTIONS and stdin is coming from a pipe, read all of it
    if ((${#OPTIONS[@]} == 0)) && ! tty -s; then
        if [ -n "${BASH_VERSION-}" ]; then
            mapfile -t OPTIONS
        else
            OPTIONS=()
            while IFS= read -r __line; do OPTIONS+=("$__line"); done
        fi
    fi

    shew__tty_enter

    if [[ ${#RAW_OPTIONS[@]} -gt 0 ]]; then
        for item in "${RAW_OPTIONS[@]}"; do
            LABELS+=("${item%%|*}")
            VALUES+=("${item#*|}")
        done
        OPTIONS=("${LABELS[@]}")
    fi

    # Reverse arrays without relying on mapfile/process substitution
    if [[ $REVERSE -eq 1 ]]; then
        __rev=()
        for ((ri = ${#OPTIONS[@]} - 1; ri >= 0; ri--)); do __rev+=("${OPTIONS[ri]}"); done
        OPTIONS=("${__rev[@]}")
        if [[ ${#RAW_OPTIONS[@]} -gt 0 ]]; then
            __rev=()
            for ((ri = ${#VALUES[@]} - 1; ri >= 0; ri--)); do __rev+=("${VALUES[ri]}"); done
            VALUES=("${__rev[@]}")
        fi
    fi

    if [[ -n $SELECTED_STR ]]; then
        if [ -n "${ZSH_VERSION-}" ]; then
            IFS=' ' read -rA SELECTED_ITEMS <<<"$SELECTED_STR"
        else
            IFS=' ' read -r -a SELECTED_ITEMS <<<"$SELECTED_STR"
        fi
    fi

    for ((i = 0; i < ${#OPTIONS[@]}; i++)); do
        opt="${OPTIONS[$i]}"
        [[ -n "$opt" ]] || continue
        SELECTED[i]=0
        for sel in "${SELECTED_ITEMS[@]}"; do
            [[ "$opt" == "$sel" ]] && SELECTED[i]=1 && break
        done
    done

    local -a ORIG_OPTIONS=("${OPTIONS[@]}")
    local -a FILTERED=("${ORIG_OPTIONS[@]}")
    local -a FILTERED_IDX=()
    for ((i = 0; i < ${#ORIG_OPTIONS[@]}; i++)); do FILTERED_IDX+=("$i"); done

    local FILTER="" FILTER_MODE=0 CURSOR=0 HEADER_LINES=0
    local COUNT_LINE=$((MULTI && LIMIT > 0 ? 1 : 0))
    local VISIBLE=$MAX_LINES

    # TODO: rethink prompt logic
    printf "\033[?25l"
    [[ -n "$PROMPT" ]] && echo -ne "${PROMPT} " && ((HEADER_LINES++))
    printf "\033[s"

    # _move_to_line
    # Restore the cursor to the saved position (via ESC[s]), then move it down by N lines.
    # Arguments:
    #   $1  Number of lines to move the cursor down from the saved point.
    shew__filter__move_to_line() {
        printf "\033[u"
        (($1 > 0)) && printf "\033[%dB" "$1"
    }

    # _draw_header
    shew__filter__draw_header() {
        shew__filter__move_to_line 0
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
    shew__filter__draw_count() {
        local filter="/ to filter"
        if ((FILTER_MODE)); then
            filter=" [enter] to apply, [esc] to cancel"
        fi
        if [[ $MULTI -eq 1 && $LIMIT -gt 0 ]]; then
            local selected_count=0
            for n in "${SELECTED[@]}"; do ((selected_count += n)); done
            shew__filter__move_to_line 1
            printf "\033[2K\r"
            echo -e "${C_ITALIC}${C_B_BLACK}${selected_count}/${LIMIT} selected. $filter${C_NC}"
        fi
    }

    # _highlight_match
    shew__filter__highlight_match() {
        local text="$1" pat="$2" iscursor="${3:-false}"
        if [[ -z "$pat" ]]; then
            if [[ -n "$iscursor" && "$iscursor" != "0" ]]; then
                echo -ne "${C_BOLD}${text}${C_UNBOLD}"
            else
                echo -ne "$text"
            fi
            return
        fi
        local lc_text="$(_shew__lc "$text")" lc_pat="$(_shew__lc "$pat")" idx
        idx=$(awk -v a="$lc_text" -v b="$lc_pat" 'BEGIN{print index(a,b)}')
        if ((idx > 0)); then
            local pre="${text:0:$((idx - 1))}"
            local match="${text:$((idx - 1)):$((${#pat}))}"
            local post="${text:$((idx - 1 + ${#pat}))}"
            if [[ -n "$iscursor" && "$iscursor" != "0" ]]; then
                echo -ne "${C_BOLD}${pre}${C_CYAN}${match}${C_RESET_FG}${C_BOLD}${post}${C_UNBOLD}"
            else
                echo -ne "$pre${C_CYAN}${C_BOLD}$match${C_NC}${C_UNBOLD}$post"
            fi
        else
            if [[ -n "$iscursor" && "$iscursor" != "0" ]]; then
                echo -ne "${C_BOLD}${text}${C_UNBOLD}"
            else
                echo -ne "$text"
            fi
        fi
    }

    # _fuzzy_filter
    shew__filter__fuzzy_filter() {
        FILTERED=()
        FILTERED_IDX=()
        if [[ -z "$FILTER" ]]; then
            FILTERED=("${ORIG_OPTIONS[@]}")
            for ((i = 0; i < ${#ORIG_OPTIONS[@]}; i++)); do FILTERED_IDX+=($i); done
        else
            local __f_lc="$(_shew__lc "$FILTER")"
            for ((i = 0; i < ${#ORIG_OPTIONS[@]}; i++)); do
                __o_lc="$(_shew__lc "${ORIG_OPTIONS[i]}")"
                [[ "$__o_lc" == *"$__f_lc"* ]] && {
                    FILTERED+=("${ORIG_OPTIONS[i]}")
                    FILTERED_IDX+=("$i")
                }
            done
        fi
        # recalc pages
        NPAGES=$(((${#FILTERED[@]} + VISIBLE - 1) / VISIBLE))
        ((CURSOR >= ${#FILTERED[@]})) && CURSOR=0
        ((PAGE >= NPAGES)) && PAGE=0
    }

    # _draw_option
    shew__filter__draw_option() {
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
            shew__filter__highlight_match "$opt" "$FILTER" "true"
            echo -e "${C_UNBOLD}${C_NC}"
        else
            printf "\033[2K\r"
            echo -ne "  $prefix "
            shew__filter__highlight_match "$opt" "$FILTER"
            echo -e "${C_NC}"
        fi
    }

    # _draw_menu
    shew__filter__draw_menu() {
        # clear area
        local total=$((1 + COUNT_LINE + VISIBLE + 1)) # +footer
        shew__filter__move_to_line 0
        for ((i = 0; i < total; i++)); do
            printf "\033[2K\r"
            ((i < total - 1)) && printf "\033[1B"
        done
        shew__filter__move_to_line 0

        # header + count
        shew__filter__draw_header
        ((MULTI == 1 && LIMIT > 0)) && shew__filter__draw_count

        # show page window
        local start=$((PAGE * VISIBLE))
        local end=$((start + VISIBLE))
        ((end > ${#FILTERED[@]})) && end=${#FILTERED[@]}
        local y=$((1 + COUNT_LINE))
        for ((fidx = start; fidx < end; fidx++)); do
            shew__filter__move_to_line $y
            shew__filter__draw_option $fidx
            ((y++))
        done

        # footer: page bullets
        shew__filter__move_to_line $y
        for ((p = 0; p < NPAGES; p++)); do
            if ((p == PAGE)); then printf "%s " "$SELECTABLE"; else printf "%s " "$UNSELECTABLE"; fi
        done
        printf "\n"

        # cursor visibility
        if ((FILTER_MODE)); then printf "\033[?25h"; else printf "\033[?25l"; fi
    }

    shew__filter__fuzzy_filter
    shew__filter__draw_menu

    trap 'stty sane; shew__tty_leave; printf "\033[?25h"; return 130' INT
    stty -echo -icanon time 0 min 1

    local key key2 old_PAGE old_CURSOR rel_old rel_new old_line new_line
    while _shew__read_n 1 "" key; do
        if ((FILTER_MODE)); then
            if [[ $key == $'\x1b' ]]; then
                # try to read an arrow‐sequence suffix
                key2=""
                _shew__read_n 2 0.01 key2
                if [[ -z "$key2" ]]; then
                    # plain Esc → cancel filter
                    FILTER=""
                    FILTER_MODE=0
                    shew__filter__fuzzy_filter
                    shew__filter__draw_menu
                else
                    # actual CSI: handle arrows
                    case "$key2" in
                    "[A")
                        if ((CURSOR > 0)); then
                            ((CURSOR--))
                            PAGE=$((CURSOR / VISIBLE))
                        fi
                        shew__filter__draw_menu
                        ;;
                    "[B")
                        if ((CURSOR < ${#FILTERED[@]} - 1)); then
                            ((CURSOR++))
                            PAGE=$((CURSOR / VISIBLE))
                        fi
                        shew__filter__draw_menu
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
                    shew__filter__draw_menu
                fi
                ;;
            $'\177' | $'\010') # Backspace
                if [[ -n "$FILTER" ]]; then
                    FILTER="${FILTER:0:-1}"
                    shew__filter__fuzzy_filter
                    shew__filter__draw_menu
                fi
                ;;
            "" | $'\r' | $'\n') # Enter: leave filter mode
                FILTER_MODE=0
                shew__filter__draw_menu
                ;;
            $'\x1b') # Esc: leave filter mode
                FILTER=""
                FILTER_MODE=0
                shew__filter__fuzzy_filter
                shew__filter__draw_menu
                ;;
            *)
                FILTER="$FILTER$key"
                shew__filter__fuzzy_filter
                shew__filter__draw_menu
                ;;
            esac
            continue
        fi

        if [[ $key == $'\x1b' ]]; then
            # read a CSI sequence (e.g. [A, [B, [C, [D])
            key2=""
            _shew__read_n 2 0.01 key2
            old_PAGE=$PAGE
            old_CURSOR=$CURSOR
            case "$key2" in
            "[A") # Up arrow: move up 
                ((CURSOR > 0)) && ((CURSOR--))
                ;;
            "[B") # Down arrow: move down
                ((CURSOR < ${#FILTERED[@]} - 1)) && ((CURSOR++))
                ;;
            "[C") # Right arrow: next page
                if ((PAGE < NPAGES - 1)); then
                    ((PAGE++))
                    CURSOR=$((PAGE * VISIBLE))
                fi
                ;;
            "[D") # Left arrow: previous page
                if ((PAGE > 0)); then
                    ((PAGE--))
                    # place cursor at last item of the new page
                    CURSOR=$((PAGE * VISIBLE + VISIBLE - 1))
                    ((CURSOR >= ${#FILTERED[@]})) && CURSOR=$((${#FILTERED[@]} - 1))
                fi
                ;;
            esac
            # re-sync page
            PAGE=$((CURSOR / VISIBLE))
            if ((PAGE != old_PAGE)); then
                # full redraw on page change
                shew__filter__draw_menu
            else
                # same page → just repaint the two cursor lines
                rel_old=$((old_CURSOR % VISIBLE))
                rel_new=$((CURSOR % VISIBLE))
                # line numbers offset by header/count
                old_line=$((rel_old + 1 + COUNT_LINE))
                new_line=$((rel_new + 1 + COUNT_LINE))

                # redraw old cursor slot without pointer (use absolute index)
                shew__filter__move_to_line $old_line
                shew__filter__draw_option $old_CURSOR

                # redraw new cursor slot with pointer (use absolute index)
                shew__filter__move_to_line $new_line
                shew__filter__draw_option $CURSOR

                # keep cursor hidden in normal mode
                printf "\033[?25l"
            fi
            continue
        fi
        case "$key" in
        $'\t' | $' ') # outside filter mode, space can also toggle
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
                shew__filter__draw_menu
            fi
            ;;
        "/")
            FILTER_MODE=1
            shew__filter__draw_menu
            ;;
        "" | $'\r' | $'\n') # Enter
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
            shew__tty_leave

            local out=()
            if [[ $MULTI -eq 1 ]]; then
                for i in "${!ORIG_OPTIONS[@]}"; do [[ ${SELECTED[i]} -eq 1 ]] && out+=("${ORIG_OPTIONS[i]}"); done
            else
                out=("${FILTERED[$CURSOR]}")
            fi
            if [[ ${#RAW_OPTIONS[@]} -gt 0 && $STRICT -eq 0 ]]; then
                final=()
                for sel in "${out[@]}"; do
                    for ((j = 0; j < ${#LABELS[@]}; j++)); do
                        [[ "${LABELS[j]}" == "$sel" ]] && final+=("${VALUES[j]}")
                    done
                done
                echo "${final[*]}"
            else echo "${out[*]}"; fi
            return 0
            ;;
        esac
    done

    stty sane
    shew__tty_leave

    printf "\033[?25h"
    return 0
}
