#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function haxxterm_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -f -- "$BASH_SOURCE")"
  local SELFPATH="$(dirname -- "$SELFFILE")"
  local PKGNAME='terminal-util-pmb'

  local APPNAME="${HAXXTERM_SESS:-${FUNCNAME%%_*}}"
  export HAXXTERM_SESS="$APPNAME"
  local SCREENS_LIST="$HOME/.config/Terminal/screen_lists/$APPNAME.htsl"
  local -A CFG=()
  eval "CFG=( $(haxxterm_parse_config_dict) )"
  local RUNMODE="$1"; shift
  [ -n "$RUNMODE" ] || RUNMODE='spawn'

  local CACHE_DIR="$HOME/.cache/$PKGNAME/$APPNAME"
  mkdir --parents --mode=a=,u=rwx -- "$CACHE_DIR" || true
  # ^-- Failure is ok in preparation. If something really needs it,
  #     it will fail later.

  local TTY_SIZE=( $(stty size) )
  local BEST_SHELL='bash'
  local HAS_COLORDIFF=
  </dev/null colordiff &>/dev/null && HAS_COLORDIFF='colordiff'
  local DBGLV="${DEBUGLEVEL:-0}"

  "${FUNCNAME%%_*}_$RUNMODE" "$@"
  return $?
}


function vdo_terse () { echo "X: $*"; "$@"; }


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
    -W"$SELFFILE"
    -W'inner'
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

  local HAVE='s~^0x\S+ +\S+ +(gnome-terminal(-server|).\S+) .*$~\1~p'
  HAVE=$'\n'"$(wmctrl -xl | sed -nre "$HAVE" | cut -d . -sf 2-)"$'\n'

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
  haxxterm_set_icon || true

  if [ "$#" == 0 -o "$#:$1" == 1: ]; then
    echo "E: $FUNCNAME: Expected a command to exec in this shell." >&2
    sleep 10s
    return 3
  fi

  exec "$@" || return $?
}


function haxxterm_scrl () {
  ( [ -n "$DISPLAY" ] && default-x-text-editor "$SCREENS_LIST"
    ) || "$VISUAL" "$SCREENS_LIST" || return $?
  local SCRL_ABS="$(readlink -f -- "$SCREENS_LIST")"
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
  local HOME_RGX="${HOME//[^A-Za-z0-9_/-]/}"
  # ^-- Proper quotemeta woul be overkill here. Let's just discard characters
  #   that don't belong in a $HOME path in the first place.

  screen-windowlist "$APPNAME" | sed -rf <(echo '
    s~^[0-9]+\t[^A-Za-z0-9]*\t~~
    s~^[a-z0-9_-]+@[a-z0-9_-]+ '"$(basename -- "$BEST_SHELL"
      )"' (\?{2} |)(\~?/|'"$HOME_RGX"'/)~\2~
    s!^'"$HOME_RGX"'(/|$)!\~\1!
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
    [ -z "$debian_chroot" ] || DEBCH+=": $debian_chroot"
    debian_chroot="$DEBCH" exec bash -i || echo "W: $DEBCG: rv=$?" >&2
  fi

  exec "$BEST_SHELL"
  return $?$(echo "E: exec $BEST_SHELL failed: rv=$?" >&2; sleep 5s)
}


function haxxterm_screen_eval_debug () {
  zenity --question --title "$FUNCNAME" --text "$*" || return 0
  screen -X eval "$@"
}


function haxxterm_welcome_prepare () {
  [ "$WINDOW" == 0 ] || return 4$(
    echo "E: panic: expected WINDOW=0, not '$WINDOW'" >&2)
  cd / || return $?

  local HAVE_ROWS="${TTY_SIZE[0]:-0}"
  local HAVE_COLS="${TTY_SIZE[1]:-0}"
  yes '' | head -n 90
  local MIN_ROWS="${CFG[panel_min_rows]:-26}"
  local MIN_COLS="${CFG[panel_min_cols]:-121}"
  local HBAR_SPLIT=$(( ( HAVE_ROWS / MIN_ROWS ) - 1 ))
  [ "${HBAR_SPLIT:-0}" -ge 1 ] || HBAR_SPLIT=0
  local VBAR_SPLIT=$(( ( HAVE_COLS / MIN_COLS ) - 1 ))
  [ "${VBAR_SPLIT:-0}" -ge 1 ] || VBAR_SPLIT=0
  local SCE='screen -X eval'
  # SCE='vdo_terse screen -X eval'
  # SCE='haxxterm_screen_eval_debug'
  # not eval-able --> $SCE 'defcaption always'
  # not eval-able --> $SCE 'defvbell on'

  local DUMMY=
  for DUMMY in $(seq 1 $HBAR_SPLIT); do $SCE split; done
  for DUMMY in $(seq 0 $HBAR_SPLIT); do
    for DUMMY in $(seq 1 $VBAR_SPLIT); do $SCE 'split -v'; done
    for DUMMY in $(seq 0 $VBAR_SPLIT); do
      $SCE fit
      $SCE 'focus next'
    done
  done

  $SCE 'focus next'
  $SCE 'windowlist -b'
  $SCE 'focus prev'

  cdscreen "${TERM_PATHS[@]:1}" & wait
  # ^-- Fork + wait makes the top-left pane stay at window 0.

  return 0
}


function haxxterm_parse_config_dict () {
  sed -nre 's~^##:term:([^: \t\r\f=#]+)\s*=\s*~[\1\t~p' -- "$SCREENS_LIST" \
    | sed -re 's~\x27+~\x27\x22&\x22\x27~g; s~\t~]=\x27~; s~$~\x27~'
}


function haxxterm_set_icon () {
  # This should be run outside of "welcome", because we want to set/update
  # the icon even if the screen session already exists.

  local WIN_ID="$(haxxterm_guess_xwinid)"
  [ -n "$WIN_ID" ] || return 5$(
    echo "E: $FUNCNAME: Failed to guess window ID for session '$APPNAME'." >&2)

  local CANDIDATES=()
  readarray -t CANDIDATES < <(
    sed -nre 's~^##:term:icon:\s+~~p' -- "$SCREENS_LIST")
  local N_CANDI="${#CANDIDATES[@]}"
  [ "$N_CANDI" -ge 1 ] || return 0
  [ "$N_CANDI:${CANDIDATES[0]}" != 1: ] || return 0

  local ORIG= ICON=
  for ORIG in "${CANDIDATES[@]}"; do
    ICON="$ORIG"

    if [ "${ICON:0:1}" == '*' ]; then
      ICON="$(haxxterm_find_icon "${ICON:1}")"
      [ -f "$ICON" ] || continue$(
        echo "W: $FUNCNAME: Unable to find icon for pattern '$ORIG'" >&2)
    fi

    xseticon-pmb "$WIN_ID" GUESS "$ICON" && return 0
    echo "E: $FUNCNAME: Failed to set icon '$ICON' for session" \
      "'$APPNAME' (window ID $WIN_ID)." >&2
    continue
  done

  echo "E: $FUNCNAME: Failed to set icon ($N_CANDI candidates)." >&2
  return 4
}


function haxxterm_find_icon () {
  local PAT="$1"
  local D='/usr/share/icons/'
  # ^-- Trailing slash is to make find ignore whether "icons" is a symlink.
  local FOUND="$(find "$D" -mindepth 1 -xdev -type f -path "$D$PAT" \
    | sort --version-sort --reverse | head --lines=1)"
    # ^-- reverse version-sort usually picks the largest variant.
  [ -n "$FOUND" ] || return 2
  echo "$FOUND"
}





















haxxterm_main "$@"; exit $?
