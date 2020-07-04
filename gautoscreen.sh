#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function gautoscreen () {
  cd / || return $?

  export AS_SESS=gautoscreen
  local AS_CMD=( autoscreen )
  local TERM_OPTS=()
  local OPT=
  while [ "$#" -gt 0 ]; do
    OPT="$1"; shift
    case "$OPT" in
      -- ) break;;
      --T* )
        echo "E: $0, CLI: unsupported option: $OPT, try ${OPT:1}" >&2
        return 3;;
      --sessname=* ) export AS_SESS="${OPT#*=}";;
      --winclass=* | \
      --winname=* | \
      -T* )
        OPT="${OPT#-T}"
        TERM_OPTS+=( "$OPT" );;
      -* )
        echo "E: $0, CLI: unsupported option: $OPT" >&2
        return 3;;
      * )
        echo "E: $0, CLI: unexpected positional argument." >&2
        return 3;;
    esac
  done

  TERM_OPTS+=(
    --forkoff
    --title="$AS_SESS ~${USER}@${HOSTNAME}"
    --geom='max,122x33'
    --emus='gnome-terminal,+'
    )
  exec terminal-emu-best-pmb "${TERM_OPTS[@]}" --exec "${AS_CMD[@]}" "$@"
  return $?
}










gautoscreen "$@"; exit $?
