#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function haxxterm_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  local PKGNAME='terminal-util-pmb'

  local APPNAME="${HAXXTERM_SESS:-${FUNCNAME%%_*}}"
  export HAXXTERM_SESS="$APPNAME"
  local SCREENS_LIST="$HOME/.config/Terminal/screen_lists/$APPNAME.htsl"
  local RUNMODE="$1"; shift
  [ -n "$RUNMODE" ] || RUNMODE='spawn'

  local CACHE_DIR="$HOME/.cache/$PKGNAME/$APPNAME"
  mkdir --parents --mode=a=,u=rwx -- "$CACHE_DIR" || true
  # ^-- Failure is ok in preparation. If something really needs it,
  #     it will fail later.

  local BEST_SHELL='bash'
  local HAS_COLORDIFF=
  </dev/null colordiff &>/dev/null && HAS_COLORDIFF='colordiff'
  local DBGLV="${DEBUGLEVEL:-0}"

  "${FUNCNAME%%_*}_$RUNMODE" "$@"
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

    # screen command (will only run if the screen session does not yet exist):
    "$SELFFILE" welcome
    )
  [ "$DBGLV" -lt 2 ] || echo "D: $FUNCNAME: ${SPAWN[*]}" >&2
  "${SPAWN[@]}"
}


function haxxterm_spawn_unloaded_sessions () {
  local SLDIR="$(dirname -- "$SCREENS_LIST")"
  local FEXT=".${SCREENS_LIST##*.}"

  local WANT=(
    "$SLDIR"/
    -mindepth 1
    -maxdepth 1
    -type f
    -name '*.htsl'
    -printf '%f\n'
    )
  readarray -t WANT < <(find "${WANT[@]}" | sed -re 's~\.[a-z]*$~~')
  [ "${#WANT[@]}" -ge 1 ] || WANT+=( "$APPNAME" )

  local HAVE='s~^0x\S+ +\S+ +(gnome-terminal-server.)(\S+) .*$~\2~p'
  HAVE=$'\n'"$(wmctrl -xl | sed -nre "$HAVE")"$'\n'

  local HAD=/
  local SESS=
  for SESS in "${WANT[@]}"; do
    echo -n "· '$SESS': "
    if [[ "$HAVE" == *$'\n'"$SESS"$'\n'* ]]; then
      echo 'found.'
    else
      echo 'spawn!'
      HAXXTERM_SESS="$SESS" haxxterm spawn
    fi
  done
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
  #
  # For visual diff, see "meld" below.
  #
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


function haxxterm_meld () {
  local BEST_MELD='
    meld
    diffuse
    '
  BEST_MELD="$(which $BEST_MELD 2>/dev/null | grep -m 1 -Pe '^/')"
  [ -x "$BEST_MELD" ] || return 3$(echo "E: Cannot find the meld program." >&2)
  local TMP_FILE="$CACHE_DIR"/screens.tmp
  # ^-- We could use `mktemp --tmpdir=… -- …` but then we'd have to wait for
  #     the meld to close and then clean it up. Easier to use just a default
  #     fixed path to at least limit our littering. Anyone worried about
  #     access permissions can pre-create $CACHE_DIR safely.

  local PATHS_LIST="$(haxxterm_guess_active_shell_paths_keep_unknown)"
  haxxterm_diff__maybe_merge_first_two_lines || return $?

  # Meld on default settings doesn't scroll below end of file,
  # so let's add lots of padding:
  local PAD=
  printf -v PAD '\n%05d\n\r%040d' 0 0
  PAD="${PAD//0/$'\n#'}"
  PAD="${PAD/$'\r'/'# padding for easier scrolling in meld:'}"

  echo "$PATHS_LIST$PAD" >"$TMP_FILE"
  "$BEST_MELD" "$SCREENS_LIST" "$TMP_FILE" &
  return $?
}


function haxxterm_parse_screenlist_cfg () {
  sed -nrf <(echo '
    s~^##:term:([A-Za-z0-9_-]+):\s+~\1\n~
    /\n/!b
    s~\x27+~\x27"&"\x27~g
    s~$~\x27~
    s~^(\S+)\n~[\1]=\x27~
    p
    ') -- "$@"
}


function haxxterm_welcome () {
  clear
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local TERM_PATHS=()
  readarray -t TERM_PATHS < <(sed -nrf <(echo '
    s~^\s+~~
    \:^\~?/:!b
    s!\s+¶\s+!\n!g
    p
    ') -- "$SCREENS_LIST")

  # local -A TERM_CFG=()
  # eval "TERM_CFG=( $(haxxterm_parse_screenlist_cfg "$SCREENS_LIST") )"

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










haxxterm_main "$@"; exit $?
