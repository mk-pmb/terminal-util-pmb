#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function repeatedly () {
  local INTV='10s'
  local PREPARE=
  local PRESLEEP=
  while [ "$#" -ge 1 ]; do case "$1" in
    --clear ) PREPARE+='clear; '; shift;;
    --pad ) PRESLEEP+='echo; echo; echo; '; shift;;
    [0-9]* ) INTV="$1"; shift;;
    -- ) shift; break;;
    * ) break;;
  esac; done
  while true; do
    eval "$PREPARE"
    printf '%(%a %d %T)T ' -1
    "$@"
    eval "$PRESLEEP"
    sleep "$INTV" || return $?
  done
}

repeatedly "$@"; exit $?
