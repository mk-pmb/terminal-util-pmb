#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function repeatedly () {
  local INTV='10s'
  local PREPARE=
  local DATE_CR=
  local PRESLEEP=
  while [ "$#" -ge 1 ]; do case "$1" in
    --clear ) PREPARE+='clear; '; shift;;
    --pad ) PRESLEEP+='echo; echo; echo; '; shift;;
    -r | --date-cr ) DATE_CR='\r'; shift;;
    [0-9]* ) INTV="$1"; shift;;
    -- ) shift; break;;
    * ) break;;
  esac; done
  while true; do
    eval "$PREPARE"
    printf "$DATE_CR"'%(%a %d %T)T ' -1
    "$@"
    eval "$PRESLEEP"
    sleep "$INTV" || return $?
  done
}

repeatedly "$@"; exit $?
