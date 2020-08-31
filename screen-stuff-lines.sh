#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function screen_stuff_lines () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SC_NUM="$1"; shift
  local DELAY="${1:-0.1s}"; shift
  local LN=

  if [ "$#" != 0 ]; then
    "$@" | "$FUNCNAME" "$SC_NUM" "$DELAY"
    LN="${PIPESTATUS[*]}"
    let LN="${LN// /+}"
    return "$LN"
  fi

  local LN=
  while IFS= read -r LN; do
    screen -p "$SC_NUM" -X stuff "$LN"$'\n' || return $?
    sleep "$DELAY"
  done
}



screen_stuff_lines "$@"; exit $?
