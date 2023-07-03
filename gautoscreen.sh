#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function gautoscreen () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  cd / || return $?

  local AS_PROG='autoscreen'
  export AS_SESS="$AS_PROG"
  local AS_CMD=( "$AS_PROG" )
  local TERM_OPTS=()
  local WRAP_CMD=()
  local OPT=
  while [ "$#" -gt 0 ]; do
    OPT="$1"; shift
    case "$OPT" in
      -- ) break;;

      -T* ) OPT="${OPT:2}"; TERM_OPTS+=( "$OPT" );;
      -W* ) OPT="${OPT:2}"; WRAP_CMD+=( "$OPT" );;
      --[TW]* )
        # ^-- ATTN: Using [A-Z] here matches lowercase letters in older
        #     Ubuntus even with shopt nocaseglob off and nocasematch off.
        echo "E: $0, CLI: unsupported option: $OPT," \
          "try ${OPT:1} if that's a screen option." >&2
        return 3;;

      --sessname=* ) export AS_SESS="${OPT#*=}";;
      --winclass=* | \
      --winname=* | \
      -- ) TERM_OPTS+=( "$OPT" );;

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

  exec terminal-emu-best-pmb "${TERM_OPTS[@]}" \
    --exec "${WRAP_CMD[@]}" "${AS_CMD[@]}" "$@"
  return $?
}










gautoscreen "$@"; exit $?
