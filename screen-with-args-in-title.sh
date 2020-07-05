#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
# launch a screen with not only the cmd but also its args
# (and initial working directory) in the title.


function screen_args_title () {
  local PROG="$1"; shift
  local DIR="$PWD"

  case "$PROG" in
    / | /*/ ) DIR="$PROG"; PROG="$1"; shift;;
    */ ) DIR+="/$PROG"; PROG="$1"; shift;;
  esac
  case "$PROG" in
    '' )
      PROG='cdscreen'
      exec "$PROG"
      echo "E: $0: no command given and $PROG is not available." >&2
      return 1;;
    man )
      DIR=.;;
  esac

  local S_TITLE="$USER@$HOSTNAME $PROG"
  local ARGS_PREVIEW="$*"
  if [ -n "$ARGS_PREVIEW" ]; then
    [ -n "$COLUMNS" ] || COLUMNS="$(stty size | grep -oPe ' \d+$')"
    [ -n "$COLUMNS" ] || COLUMNS=80
    let HALFCOLS="$COLUMNS/ 2"
    S_TITLE+=" ${ARGS_PREVIEW:0:$HALFCOLS}"
  fi
  [ "$DIR" != . ] && S_TITLE+=" @ ${DIR/$HOME/~}"

  cd /
  exec screen -t "$S_TITLE" sh -c 'cd "$0" && exec "$@"' "$DIR" "$PROG" "$@"
  return $?
}











screen_args_title "$@"; exit $?
