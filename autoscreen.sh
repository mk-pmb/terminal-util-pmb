#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function autoscreen () {
  cd / || return $?

  local OPT
  while [ "$#" -ge 1 ]; do
    OPT="$1"; shift
    case "$OPT" in
      -- ) break;;
      -ls ) sesslist; return $?;;
      * ) echo "E: $FUNCNAME: Unsupported option '$OPT'." >&2; return 3;;
    esac
  done

  local S_CMD=(
    screen
    -U      # UTF-8 moe
    -O      # auto-detect terminal type and optimize for it
    -h 0    # no scrollback history
    )

  local OPT="${AS_CHDIR:-$HOME}"; unset AS_CHDIR
  cd -- "$OPT" || echo "W: unable to chdir to: $OPT" >&2

  local SESS="${AS_SESS:-$FUNCNAME}"; unset AS_SESS
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






autoscreen "$@"; exit $?
