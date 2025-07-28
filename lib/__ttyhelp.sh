#! /usr/bin/env bash

# Call at the top of any function that needs real‑TTY I/O
__tty_enter() {
  # stash the caller’s stdin (0) and stdout (1)
  exec {TTY_IN_SAVE}<&0 {TTY_OUT_SAVE}>&1
  # rebind 0 and 1 to the real terminal
  exec </dev/tty >/dev/tty
}

# Call at the bottom (just before producing your final stdout result)
__tty_leave() {
  # restore the caller’s stdin/stdout
  exec 0<&${TTY_IN_SAVE} 1>&${TTY_OUT_SAVE}
  # close the temporary fds
  exec {TTY_IN_SAVE}<&- {TTY_OUT_SAVE}>&-
}