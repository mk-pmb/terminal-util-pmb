#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function screen_set_own_window_title () {
  [ -n "$STY" ] || return 2
  [ -n "$WINDOW" ] || return 2
  [ "${TERM%%.*}" == screen ] || return 2
  local TITLE="$*"
  case "$1" in
    --printf ) shift; TITLE="$(printf "$@")";;
    --and-term )
      shift
      TITLE="$*"
      terminal-set-title "$TITLE";;
    -- ) shift; TITLE="$*";;
  esac

  # Unfortunately Ubuntu focal's "screen" seems to not have proper
  # UTF-8 support for titles.
  TITLE="${TITLE//…/...}"
  TITLE="${TITLE//[^ -~]/?}"

  screen -p "$WINDOW" -X title "$TITLE"
  return 0
}


[ "$1" == --lib ] || screen_set_own_window_title "$@" || exit $?
