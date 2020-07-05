#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function screen_usbtty () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  cd / || return $?

  local TTY_BASE='/dev/ttyUSB'
  local TTY_DEV=
  local BAUDRATE=
  local ARG=
  while [ "$#" -ge 1 ]; do
    ARG="$1"; shift
    case "$ARG" in
      [0-9]* )
        if [ "$ARG" -ge 96 ]; then
          BAUDRATE="$ARG"
        else
          TTY_DEV="$ARG"
        fi;;
      * ) echo "E: unsupported option: '$ARG'" >&2; return 3;;
    esac
  done

  [ -n "$TTY_DEV" ] || TTY_DEV="$(guess_tty)"
  [ -n "$TTY_DEV" ] || TTY_DEV=1
  [ "${TTY_DEV:0:1}" == / ] || TTY_DEV="$TTY_BASE$TTY_DEV"
  [ -c "$TTY_DEV" ] || return 4$(
    echo "E: not a character device: $TTY_DEV" >&2)
  [ "${BAUDRATE:-0}" -ge 1 ] || BAUDRATE=115200
  exec screen "$TTY_DEV" "$BAUDRATE" || return $?
}


function guess_tty () {
  local MAYBE=
  for MAYBE in "$TTY_BASE"*; do
    [ -c "$MAYBE" ] || continue
    [ -w "$MAYBE" ] || continue
    echo "$MAYBE"
    return 0
  done
  echo "E: Failed to find a writable $TTY_BASE*" >&2
  return 4
}



screen_usbtty "$@"; exit $?
