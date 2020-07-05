#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function cdscreen () {
  local SELFFILE="$(readlink -m -- "$0")"
  case "$TERM" in
    screen | screen.* ) ;;
    * ) echo "fatal: $0 only works inside a screen." >&2; return 1;;
  esac
  local DEST_DIRS=( "$@" )
  case "$1" in
    '' ) DEST_DIRS=( . );;
    --clip )
      readarray -t DEST_DIRS < <(clipdump | sed -re '
        s!^\s+!!
        s!\s+$!!
        /^(#|$)/d
        ');;
    --inner ) shift; prepare_window "$@"; return $?;;
  esac

  local ORIG_PWD="$PWD"
  cd / || return $?
  local SHBN="$(basename -- "$SHELL")"
  local DEST_DIR=
  local DIR_TITLE=
  for DEST_DIR in "${DEST_DIRS[@]}"; do
    DEST_DIR="${DEST_DIR#\?\? }"
    # ^-- probably copied from window title of a then unreachable path
    case "$DEST_DIR" in
      '~' | '~/'* ) DEST_DIR="$HOME${DEST_DIR#\~}";;
    esac
    DIR_TITLE="$(cd "$ORIG_PWD" && cd "$DEST_DIR" && pwd)"
    case "$DIR_TITLE" in
      '' ) DIR_TITLE="?? $DEST_DIR";;
      "$HOME" ) DIR_TITLE=~/;;
      "$HOME"/* ) DIR_TITLE="~${DIR_TITLE#$HOME}";;
    esac
    screen -t "$USER@$HOSTNAME $SHBN $DIR_TITLE" \
      -- "$SELFFILE" --inner "$ORIG_PWD" "$DEST_DIR" \
      || return $?
  done
}


function prepare_window () {
  local ORIG_PWD="$1"; shift
  local DEST_DIR="$1"; shift
  local MENU=
  while true; do
    cd "$ORIG_PWD" && cd "$DEST_DIR" && break
    echo
    echo "Failed to chdir."
    echo "  orig: $ORIG_PWD"
    echo "  dest: $DEST_DIR"
    echo "  real: $PWD"
    MENU='Press a key:'
    MENU+=' [e]dit dest,'
    MENU+=' [t]emporary shell,'
    MENU+=' [m]kdir,'
    MENU+=' [c]lose screen window,'
    MENU+=' [q]uit to a new shell,'
    MENU+=' any other key: retry'
    read -rs -n 1 -p "$MENU? " MENU
    echo "$MENU"
    case "$MENU" in
      e ) read -er -i "$DEST_DIR" -p '  new dest: ' DEST_DIR;;
      t ) "$SHELL";;
      m ) mkdir --parents --verbose -- "$DEST_DIR";;
      c ) return 4;;
      q ) break;;
    esac
  done
  exec "$SHELL"
}








cdscreen "$@"; exit $?
