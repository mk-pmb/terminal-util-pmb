#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function repeatedly () {
  local INTV='10s'
  case "$1" in
    [0-9]* ) INTV="$1"; shift;;
    -- ) shift;;
  esac
  while true; do
    printf '%(%a %d %T)T ' -1
    "$@"
    sleep "$INTV" || return $?
  done
}

[ "$1" == --lib ] && return 0; repeatedly "$@"; exit $?
