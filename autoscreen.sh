#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function autoscreen () {
  cd / || return $?

  local OPT=
  while [ "$#" -ge 1 ]; do
    OPT="$1"; shift
    case "$OPT" in
      -- ) break;;
      -ls ) sesslist; return $?;;
      --bashrc ) decide_bashrc_startup; return $?;;
      * ) echo "E: $FUNCNAME: Unsupported option '$OPT'." >&2; return 3;;
    esac
  done

  local S_CMD=(
    screen
    -U      # UTF-8 moe
    -O      # auto-detect terminal type and optimize for it
    -h 0    # no scrollback history
    )

  OPT="${AS_CHDIR:-$HOME}"; unset AS_CHDIR
  cd -- "$OPT" || echo "W: unable to chdir to: $OPT" >&2

  local SESS="$AS_SESS"; unset AS_SESS
  case "$SESS" in
    *'?'* ) SESS="$(find_preferred_session "$SESS")" || return $?;;
  esac
  [ -n "$SESS" ] || SESS="$FUNCNAME"
  S_CMD+=( -S "$SESS" )

  sesslist | grep -qxFe "$SESS" && S_CMD+=(
    -RR     # try eagerly to reattach,
    -x      # … but don't detach other sides.
    )

  setsid "${S_CMD[@]}" -- "$@" || return $?$(
    echo "W: screen exited with rv=$?" >&2)
}


function sesslist () {
  # Problem with scanning the default ${SCREENDIR}s: The decision which one
  # screen will attempt to use, is rather complex.
  #   find {/var,}/run/screen/S-"$USER"/ \
  #     -maxdepth 1 -type p -name '[0-9]*.*' \
  #     -printf '%f\n' | cut -d . -sf 2 | sort -u | grep .
  # Thus, parsing -ls output is probably more failsafe in this case:
  LANG=C screen -ls | sed -rf <(echo '
    s~^\t[0-9]+\.~\n~
    /\n/!d
    s~^\n~~
    s~(\t\([^()]+\))+$~~
    ') | grep .
}


function find_preferred_session () {
  local WANT="$1"
  local SESS=
  local HAVE=$'\n'"$(sesslist)"$'\n'
  while [[ "$WANT" == *'?'* ]]; do
    SESS="${WANT%%\?*}"
    WANT="${WANT#*\?}"
    WANT="${WANT# }"
    [ -n "$SESS" ] || continue
    [[ "$HAVE" == *$'\n'"$SESS"$'\n'* ]] || continue
    echo "$SESS"
    break
  done
  [ -z "$WANT" ] || echo "$WANT"
}


function tmpfunc_bashrc_maybe_autoscreen () {
  # Don't start an autoscreen if shell is not interactive,
  # (which might be the case in e.g. an X11 start script.)
  [ -n "$PS1" ] || return 0
  [ -n "$TERM" ] || return 0

  case "$(tty)" in
    /dev/ttyS[0-9]* | \
    /dev/ttyUSB[0-9]* | \
    __serial__ ) return 0;;
  esac

  # Don't start an autoscreen inside another one.
  [ -z "$STY" ] || return 0
  case "$TERM" in
    screen | screen.* ) return 0;;
  esac

  if [ -n "$SSH_CONNECTION" ]; then
    export SSH_CONN_DISPLAY="$DISPLAY"
    export DISPLAY=:0
  fi

  export AS_SESS='haxxterm?'

  autoscreen || return $?

  # Should we end the session automatically if autoscreen succeded?
  [ -n "$SSH_CONNECTION" ] && exit 0
  # ^-- If it is an SSH connection, then yes, quit.
  # Emergency repairs can still be done by specifying a shell
  # other than bash as the SSH command, or some command that
  # disables this auto-exit.
}


function decide_bashrc_startup () {
  local FUN='tmpfunc_bashrc_maybe_autoscreen'
  local -fp "$FUN"
  echo "$FUN; unset $FUN"
}






autoscreen "$@"; exit $?
