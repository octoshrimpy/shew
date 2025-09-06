#!/usr/bin/env bash

# _spin: Animate a spinner while running a command.
# flags: --title str, --spinner type, --show-output
# use: _spin --spinner dots --title "Waiting" do_thing
shew__spin() {
  shew__tty_enter

  printf "\033[?25l" # hide cursor
  set +m             # disable job control

  local func=""
  local spinner="dots"
  local title=""
  local has_title=false
  local show_output=false
  local fps=0.1
  local frames

  # Parse flags
  while [ "$#" -gt 0 ]; do
    case "$1" in
    --title)
      shift
      title=$1
      has_title=true
      ;;
    --spinner)
      shift
      spinner=$1
      ;;
    --show-output) show_output=true ;;
    *)
      func=$1
      break
      ;;
    esac
    shift
  done

  # Default title from func name
  if [ "$has_title" != true ]; then
    title=$(printf "%s" "$func" | tr '_-' ' ')
    title="$(printf "%s" "${title^}") "
  fi
  
  
  if [[ "$title" == *__* ]]; then
    
    # Extract the last segment after the last '__'
    last_segment="${title##*__}"

    # Remove the last segment from the title to get the path base
    path_base="${title%__*}"

    # Replace all '__' with '/' to form a clean path
    path="${path_base//__//}"

    # Format the final title
    title="$last_segment${C_CYAN}● ${C_GRAY}${C_ITALIC}$path${C_NC}"
  fi




  # Spinner frames
  # shellcheck disable=SC1003
  case "$spinner" in
  line) frames='| / - \' ;;
  dots) frames='⣾ ⣽ ⣻ ⢿ ⡿ ⣟ ⣯ ⣷' ;;
  minidots) frames='⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏' ;;
  jump) frames='⢄ ⢂ ⢁ ⡁ ⡈ ⡐ ⡠' ;;
  pulse) frames='█ ▓ ▒ ░' ;;
  points) frames='∙∙∙ ●∙∙ ∙●∙ ∙∙●' ;;
  globe) frames='🌍 🌎 🌏' ;;
  moon) frames='🌑 🌒 🌓 🌔 🌕 🌖 🌗 🌘' ;;
  monkey) frames='🙈 🙉 🙊' ;;
  meter) frames='▱▱▱ ▰▱▱ ▰▰▱ ▰▰▰ ▰▰▱ ▰▱▱ ▱▱▱' ;;
  hamburger) frames='☱ ☲ ☴ ☲' ;;
  ellipsis) frames='   .  .. ... .. .   ' ;;
  *) frames='| / - \' ;;
  esac


  shew__spin__on_interrupt() {
    spinner_running=false
    kill "$SPINNER_PID" 2>/dev/null
    printf "\r\033[K"
    printf "\033[?25h" # show cursor
    set -m             # restore job control
    shew__tty_leave
    echo -e "\n${C_RED}✗${C_NC} Interrupted"
    exit 1
  }

  # Spinner loop
  shew__spin__start_spinner() {
    local title="$1"
    spinner_running=true
    local i=0

    (
      while [ "$spinner_running" = true ]; do
        set -- $frames
        eval "frame=\${$((i + 1))}"
        printf "\r\033[K${C_MAGENTA}%s${C_NC} %s" "$frame" "$title"
        i=$(((i + 1) % $#))
        sleep "$fps"
      done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID"
  }

  shew__spin__stop_spinner() {
    spinner_running=false
    kill "$SPINNER_PID" 2>/dev/null
    printf "\r\033[K"
  }

  shew__spin__spin_print() {
    while IFS= read -r line; do
      printf "\r\033[K"
      printf "%b\n" "${C_GRAY}│${C_NC} $line"
    done
  }

  trap shew__spin__on_interrupt SIGINT

  shew__spin__start_spinner "$title"

  if [ "$show_output" = true ]; then
    tmp_fifo=$(mktemp -u)
    mkfifo "$tmp_fifo"

    # Start background reader and line counter
    # TODO: use _spin_print
      line_count=0
      {
        while IFS= read -r line; do
          printf "\r\033[K"
          printf "%b\n" "${C_GRAY}│${C_NC} $line"
          line_count=$((line_count + 1))
        done < "$tmp_fifo"
      } &
      spin_pid=$!

  # Redirect stdout and stderr to the FIFO, run in current shell
    exec 3>"$tmp_fifo"
    {
      "$func"
    } 2>&1 >&3
    exec 3>&-

    wait "$spin_pid"
    rm -f "$tmp_fifo"
  else
    "$func" >/dev/null 2>&1
    line_count=0
  fi

  shew__spin__stop_spinner

  # Done message (with alignment if prior output shown)
  if [ "$line_count" -gt 0 ]; then
    printf "%b\n" "\r\033[K${C_GRAY}╰─ ${C_GREEN}✓${C_NC} $title \n"
  else
    printf "%b\n" "\r\033[K     ${C_GREEN}✓${C_NC} $title"
  fi
  
  printf "\033[?25h" # show cursor
  set -m             # restore job control
  shew__tty_leave
}
