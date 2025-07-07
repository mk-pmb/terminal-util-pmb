#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gnetcat_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local TEB_OPT=(
    --forkoff
    )
  local DEST_GEOM='120x25'
  local DEST_ICON='tsclient'
  case "$1" in
    -k | --hold ) TEB_OPT+=( --hold ); shift;;
    --geom=* ) DEST_GEOM="${1#*=}"; shift;;
    --icon=* ) DEST_ICON="${1#*=}"; shift;;
  esac

  local DEST_HOST="$1"; shift
  local MUST='Destination host must'
  [[ "$DEST_HOST" == [a-z0-9]* ]] || return 4$(
    echo E: "$MUST start with a letter or digit!" >&2)

  local DEST_PORT="$1"; shift
  MUST='Destination port must'
  [ -z "${DEST_PORT//[0-9]/}" ] || return 4$(
    echo E: "$MUST consist of only digits!" >&2)
  [ "${DEST_PORT:-0}" -ge 1 ] || return 4$(
    echo E: "$MUST be a positive number!" >&2)

  TEB_OPT+=(
    --icon="$DEST_ICON"
    --geom="$DEST_GEOM"
    --winname=gnetcat
    --title="gnetcat: $DEST_HOST:$DEST_PORT"
    --exec
    rlwrap
    netcat
    "$@"
    "$DEST_HOST" "$DEST_PORT"
    )
  terminal-emu-best-pmb "${TEB_OPT[@]}"
}










gnetcat_cli_init "$@"; exit $?
