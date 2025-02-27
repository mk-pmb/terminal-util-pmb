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
  local ARG= CHILD=
  while [ "$#" -ge 1 ]; do
    case "$1" in
      -x )
        echo 'H: Did you mean -xN (--tabs=N) or -e (--exec)?' >&2
        echo "E: $0: invalid option: $1" >&2
        return 1;;
      -e | --exec ) shift; exec < <(exec "$@" 2>&1); CHILD=$!; set --;;
      -[A-Za-z]* | \
      +* ) LESS_OPTS+=( "$1" ); shift;;
      * ) break;;
    esac
  done
  less "${LESS_OPTS[@]}" "$@" && wait $CHILD
  return $?
}











[ "$1" == --lib ] && return 0; smart_less_pmb "$@"; exit $?
