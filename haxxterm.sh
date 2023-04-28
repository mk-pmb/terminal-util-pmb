#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function haxxterm () {
  local RUNMODE="$1"; shift

  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  local APPNAME="$FUNCNAME"
  local SCREENS_LIST="$HOME/.config/Terminal/$APPNAME.screens.txt"
  local BEST_SHELL='bash'
  local HAS_COLORDIFF=
  </dev/null colordiff &>/dev/null && HAS_COLORDIFF='colordiff'
  local DBGLV="${DEBUGLEVEL:-0}"

  "${FUNCNAME}_${RUNMODE:-spawn}" "$@"
  return $?
}


function haxxterm_guess_xwinid () {
  LANG=C wmctrl -xl | LANG=C sed -nrf <(echo '
    s~^(0x\S+)\s+\S+\s+\S+\.'"$APPNAME"'\s.*$~\1~p
    ') | grep -xPe '0x\w+' || return $?
}


function haxxterm_spawn () {
  local SPAWN=(
    gautoscreen

    # terminal launcher options:
    --{sessname,winclass}="$APPNAME"
    # -T--hold
    -- # end of terminal launcher options

    # autoscreen options:
    -- # end of autoscreen options

    # screen command:
    "$SELFFILE" welcome
    )
  [ "$DBGLV" -lt 2 ] || echo "D: $FUNCNAME: ${SPAWN[*]}" >&2
  "${SPAWN[@]}"
}


function haxxterm_inner () {
  AS_SESS="$APPNAME" autoscreen -- "$SELFFILE" welcome
}


function haxxterm_scrl () {
  ( [ -n "$DISPLAY" ] && default-x-text-editor "$SCREENS_LIST"
    ) || "$VISUAL" "$SCREENS_LIST" || return $?
  local SCRL_ABS="$(readlink -m -- "$SCREENS_LIST")"
  sed -re 's~\s+$~~' -i -- "$SCRL_ABS" || return $?
  # ^-- rel b/c otherwise sed would replace a potential symlink with
  #     a regular text file.
}


function haxxterm_diff () {
  if [ -n "$HAS_COLORDIFF" ] && tty --silent <&1; then
    "$FUNCNAME" | "$HAS_COLORDIFF" | less -rS
    return 0
  fi
  local PATHS_LIST="$(haxxterm_guess_active_shell_paths_keep_unknown)"
  haxxterm_diff__maybe_merge_first_two_lines || return $?
  diff -sU 9009009 -- "$SCREENS_LIST" <(echo "$PATHS_LIST")
}


function haxxterm_guess_active_shell_paths_keep_unknown () {
  screen-windowlist "$APPNAME" | sed -rf <(echo '
    s~^[0-9]+\t[^A-Za-z0-9]*\t~~
    s~^[a-z0-9_-]+@[a-z0-9_-]+ '"$(basename -- "$BEST_SHELL")"' (\~?/)~\1~
    ')
}


function haxxterm_diff__maybe_merge_first_two_lines () {
  local SL1="$(head --lines=1 -- "$SCREENS_LIST")"
  local DIR1="${SL1%% ¶ *}"
  [ "$DIR1" != "$SL1" ] || return 0
  local PL1="${PATHS_LIST%%$'\n'*}"
  [ "$PL1" == "$DIR1" ] || return 0
  PATHS_LIST="${PATHS_LIST/$'\n'/ ¶ }"
}


function haxxterm_welcome () {
  clear
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local TERM_PATHS=()
  readarray -t TERM_PATHS < <(sed -nre '
    s~^\s+~~
    \:^\~?/:!b
    s!\s+¶\s+!\n!g
    p
    ' -- "$SCREENS_LIST")

  local SC0_DIR="${TERM_PATHS[0]}"
  case "$SC0_DIR" in
    '~/'* ) SC0_DIR="$HOME/${SC0_DIR:1}";;
  esac

  "${FUNCNAME}_prepare" || echo "W: ${FUNCNAME}_prepare rv=$?" >&2

  cd -- "$SC0_DIR" || cd -- "$HOME" || cd -- / || return $?

  if [ "$DBGLV" -ge 2 ]; then
    echo "D: $FUNCNAME: local -p:" >&2
    local -p >&2
    echo "D: $FUNCNAME: starting a plain bash rather than BEST_SHELL='"$(
      )"$BEST_SHELL'" >&2
    local DEBCH='haxxterm debug'
    [ -z debian_chroot ] || DEBCH+=": $debian_chroot"
    debian_chroot="$DEBCH" exec bash -i || echo "W: $DEBCG: rv=$?" >&2
  fi

  exec "$BEST_SHELL"
  return $?$(echo "E: exec $BEST_SHELL failed: rv=$?" >&2; sleep 5s)
}


function haxxterm_welcome_prepare () {
  [ "$WINDOW" == 0 ] || return 4$(
    echo "E: panic: expected WINDOW=0, not '$WINDOW'" >&2)
  cd / || return $?

  xargs screen -X eval < <(sed -nre 's~^\s*([a-z])~\1~p' <<<'
    defcaption always
    defvbell on
    split
    fit
    focus next
    fit
    windowlist -b
    focus prev
    ')

  ( sleep 1s; cdscreen "${TERM_PATHS[@]:1}" ) &
  return 0
}










haxxterm "$@"; exit $?
