#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function smart_less_pmb () {
  # page if overflow
  case "$1" in
    -x )
      echo 'H: Did you mean -xN (--tabs=N) or -e (--exec)?' >&2
      echo "E: $0: invalid option: $1" >&2
      return 1;;
    -e | --exec ) shift; "$@" 2>&1 | smart_less_pmb; return $?;;
  esac
  local LESS_OPTS=(
    --quit-if-one-screen
    --no-init
      # ^-- avoid xfce4-terminal blanking at less start and hiding less'
      #     text after quit, esp. instant --quit-if-one-screen.
    --RAW-CONTROL-CHARS
    )
  less "${LESS_OPTS[@]}" "$@"
  return $?
}











[ "$1" == --lib ] && return 0; smart_less_pmb "$@"; exit $?
