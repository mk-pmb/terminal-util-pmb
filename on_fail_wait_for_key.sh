#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function on_fail_wait_for_key () {
  "$@" && return 0
  local RV=$?
  echo -n "D: failed (rv=$RV):"
  printf ' ‹%s›' "$@"
  echo -n ' — Type any character to continue: '
  local KEY=
  read -rn 1 KEY
  echo
  return "$RV"
}

[ "$1" == --lib ] && return 0; on_fail_wait_for_key "$@"; exit $?
