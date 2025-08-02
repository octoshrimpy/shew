#! /usr/bin/env bash

# converts given text to pixelart 3x3 figlet font
# _fig "sphynx of black quartz, hear my vow - 12345678 and 9"
# shellcheck disable=SC2120
# shellcheck disable=SC2034
function lib::_fig() {
  lib::__tty_enter

  local T_a=" ▄▄\033[1B\033[3D▀▄█\033[1A\033[1C" # a
  local T_b="▄  \033[1B\033[3D███\033[1A\033[1C" # b
  local T_c="▄▄▄\033[1B\033[3D█▄▄\033[1A\033[1C" # c
  local T_d="  ▄\033[1B\033[3D███\033[1A\033[1C" # d
  local T_e=" ▄▄\033[1B\033[3D▀█▄\033[1A\033[1C" # e
  local T_f="▄▄▄\033[1B\033[3D█▀ \033[1A\033[1C" # f
  local T_g="▄▄▄\033[1B\033[3D▀▄█\033[1A\033[1C" # g
  local T_h="▄ ▄\033[1B\033[3D█▀█\033[1A\033[1C" # h
  local T_i="▄▄▄\033[1B\033[3D▄█▄\033[1A\033[1C" # i
  local T_j="  ▄\033[1B\033[3D█▄█\033[1A\033[1C" # j
  local T_k="▄ ▄\033[1B\033[3D█▀▄\033[1A\033[1C" # k
  local T_l="▄  \033[1B\033[3D█▄▄\033[1A\033[1C" # l
  local T_m="▄▄▄\033[1B\033[3D█▀█\033[1A\033[1C" # m
  local T_n="▄▄ \033[1B\033[3D█ █\033[1A\033[1C" # n
  local T_o="▄▄▄\033[1B\033[3D█▄█\033[1A\033[1C" # o
  local T_p="▄▄▄\033[1B\033[3D█▀▀\033[1A\033[1C" # p
  local T_q="▄▄▄\033[1B\033[3D▀▀█\033[1A\033[1C" # q
  local T_r=" ▄▄\033[1B\033[3D█ ▀\033[1A\033[1C" # r
  local T_s=" ▄▄\033[1B\033[3D▄█ \033[1A\033[1C" # s
  local T_t="▄▄▄\033[1B\033[3D █ \033[1A\033[1C" # t
  local T_u="▄ ▄\033[1B\033[3D█▄█\033[1A\033[1C" # u
  local T_v="▄ ▄\033[1B\033[3D▀▄▀\033[1A\033[1C" # v
  local T_w="▄ ▄\033[1B\033[3D██▀\033[1A\033[1C" # w
  local T_x="▄ ▄\033[1B\033[3D▄▀▄\033[1A\033[1C" # x
  local T_y="▄ ▄\033[1B\033[3D▀█▀\033[1A\033[1C" # y
  local T_z="▄▄ \033[1B\033[3D █▄\033[1A\033[1C" # z

  local T_space="\033[2C" # ` `

  local T_1="▄▄ \033[1B\033[3D▄█▄\033[1A\033[1C" # 1
  local T_2="▄  \033[1B\033[3D █▄\033[1A\033[1C" # 2
  local T_3="▄▄▄\033[1B\033[3D▄█▀\033[1A\033[1C" # 3
  local T_4="▄ ▄\033[1B\033[3D▀▀█\033[1A\033[1C" # 4
  local T_5=" ▄▄\033[1B\033[3D▄▀ \033[1A\033[1C" # 5
  local T_6="▄  \033[1B\033[3D███\033[1A\033[1C" # 6
  local T_7="▄▄▄\033[1B\033[3D  █\033[1A\033[1C" # 7
  local T_8=" ▄▄\033[1B\033[3D██▀\033[1A\033[1C" # 8
  local T_9="▄▄▄\033[1B\033[3D▀▀█\033[1A\033[1C" # 9
  local T_0=" ▄▄\033[1B\033[3D█▄▀\033[1A\033[1C" # 0

  local T_dash="   \033[1B\033[3D▀▀▀\033[1A\033[1C"   # -
  local T_comma="   \033[1B\033[3D▄▀ \033[1A\033[1C"  # ,
  local T_period="   \033[1B\033[3D▄  \033[1A\033[1C" # ,

  local string="$*"
  processing="$string"
  result=

  # TODO: first letter losing top row
  for ((i = 0; i < ${#processing}; i++)); do
    letter="${processing:$i:1}"

    case "$letter" in
    ' ') varname="T_space" ;;
    -) varname="T_dash" ;;
    ,) varname="T_comma" ;;
    .) varname="T_period" ;;
    *) varname="T_$letter" ;;
    esac

    value="${!varname}"
    result+="$value"
  done

  lib::__tty_leave

  # not -e on purpose, so user can handle it later
  # make space for the text, and then move up 3, 
  # and only then print result
  echo "\n\n\n\033[3A$result"
}
