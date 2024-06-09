#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function smart_less_pmb () {
  local LESS_OPTS=(
    --quit-if-one-screen
    --no-init
      # ^-- avoid xfce4-terminal blanking at less start and hiding less'
      #     text after quit, esp. instant --quit-if-one-screen.
    --RAW-CONTROL-CHARS
    )
  while [ "${1:0:1}" == '+' ]; do LESS_OPTS+=( "$1" ); shift; done
  local CHILD=
  case "$1" in
    -x )
      echo 'H: Did you mean -xN (--tabs=N) or -e (--exec)?' >&2
      echo "E: $0: invalid option: $1" >&2
      return 1;;
    -e | --exec ) shift; exec < <(exec "$@" 2>&1); CHILD=$!; set --;;
  esac
  less "${LESS_OPTS[@]}" "$@" && wait $CHILD
  return $?
}











[ "$1" == --lib ] && return 0; smart_less_pmb "$@"; exit $?
