#! /usr/bin/env bash

# _spin: Animate a spinner while running a command.
# flags: --title str, --spinner type, --show-output
# use: _spin --spinner dots --title "Waiting" do_thing
_spin() {
  __tty_enter

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

  # Spinner frames
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

  # Spinner loop
  start_spinner() {
    local title="$1"
    spinner_running=true
    local i=0

    (
      while [ "$spinner_running" = true ]; do
        set -- $frames
        eval "frame=\${$(($i + 1))}"
        printf "\r\033[K${C_MAGENTA}%s${C_NC} %s" "$frame" "$title"
        i=$(((i + 1) % $#))
        sleep "$fps"
      done
    ) &
    SPINNER_PID=$!
    disown "$SPINNER_PID"
  }

  stop_spinner() {
    spinner_running=false
    kill "$SPINNER_PID" 2>/dev/null
    printf "\r\033[K"
  }

  _spin_print() {
    while IFS= read -r line; do
      printf "\r\033[K"
      printf "%b\n" "${C_GRAY}│${C_NC} $line"
    done
  }

  start_spinner "$title"

  if [ "$show_output" = true ]; then
    tmp_fifo=$(mktemp -u)
    mkfifo "$tmp_fifo"
    _spin_print <"$tmp_fifo" &
    spin_pid=$!

    line_count=$(
      "$func" 2>&1 |
        tee "$tmp_fifo" |
        wc -l
    )

    wait "$spin_pid"
    rm -f "$tmp_fifo"
  else
    "$func" >/dev/null 2>&1
    line_count=0
  fi

  stop_spinner

  # Done message (with alignment if prior output shown)
  if [ "$line_count" -gt 0 ]; then
    printf "%b\n" "\r\033[K${C_GRAY}╰─ ${C_GREEN}✓${C_NC} $title"
  else
    printf "%b\n" "\r\033[K     ${C_GREEN}✓${C_NC} $title"
  fi

  printf "\033[?25h" # show cursor
  set -m             # restore job control
  __tty_leave
}
