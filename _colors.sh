#!/usr/bin/env bash

# Terminal color and style definitions
# Author: Roman Ožana <roman@ozana.cz>
# Modified by: octoshrimpy <shew@octo.sh>
# License: MIT

# 🎨 16-color Foreground Palette
export C_BLACK='\033[0;30m'
export C_RED='\033[0;31m'
export C_GREEN='\033[0;32m'
export C_YELLOW='\033[0;33m'
export C_BLUE='\033[0;34m'
export C_MAGENTA='\033[0;35m'
export C_CYAN='\033[0;36m'
export C_WHITE='\033[0;37m'

# 🌈 Bright Foreground Colors
export C_B_BLACK='\033[0;90m'   # often used as gray
export C_B_RED='\033[0;91m'
export C_B_GREEN='\033[0;92m'
export C_B_YELLOW='\033[0;93m'
export C_B_BLUE='\033[0;94m'
export C_B_MAGENTA='\033[0;95m'
export C_B_CYAN='\033[0;96m'
export C_B_WHITE='\033[0;97m'

# 🔲 Background Colors (standard)
export C_BG_BLACK='\033[40m'
export C_BG_RED='\033[41m'
export C_BG_GREEN='\033[42m'
export C_BG_YELLOW='\033[43m'
export C_BG_BLUE='\033[44m'
export C_BG_MAGENTA='\033[45m'
export C_BG_CYAN='\033[46m'
export C_BG_WHITE='\033[47m'

# 🌈 Bright Backgrounds (some terminals only)
export C_BG_B_BLACK='\033[100m'
export C_BG_B_RED='\033[101m'
export C_BG_B_GREEN='\033[102m'
export C_BG_B_YELLOW='\033[103m'
export C_BG_B_BLUE='\033[104m'
export C_BG_B_MAGENTA='\033[105m'
export C_BG_B_CYAN='\033[106m'
export C_BG_B_WHITE='\033[107m'

# ✨ Styles
export C_BOLD='\033[1m'
export C_DIM='\033[2m'       # aka faint
export C_ITALIC='\033[3m'    # not widely supported
export C_UNDER='\033[4m'
export C_BLINK='\033[5m'
export C_REVERSE='\033[7m'
export C_HIDDEN='\033[8m'
export C_STRIKE='\033[9m'

# 🔄 Undo Styles
export C_UNBOLD='\033[21m'
export C_UNDIM='\033[22m'
export C_UNITALIC='\033[23m'
export C_UNUNDER='\033[24m'
export C_UNBLINK='\033[25m'
export C_UNREVERSE='\033[27m'
export C_UNHIDDEN='\033[28m'
export C_UNSTRIKE='\033[29m'

# 🧼 Reset Colors
export C_RESET_FG='\033[39m'
export C_RESET_BG='\033[49m'
export C_NC='\033[0m' # reset all (colors + styles)
