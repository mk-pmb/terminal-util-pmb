#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function screen_set_own_window_title () {
  local SELFFILE="$(readlink -f -- "$BASH_SOURCE")"
  case "$1" in
    --resolve-self ) echo "$SELFFILE"; return $?;;
  esac

  [ -n "$STY" ] || return 2
  [ -n "$WINDOW" ] || return 2
  [ "${TERM%%.*}" == screen ] || return 2

  local SELFPATH="$(dirname -- "$SELFFILE")"
  local USE_SUDO=()
  [ -z "$SUDO_USER" ] || USE_SUDO=( sudo -u "$SUDO_USER" -E )

  local TITLE="$*"
  case "$1" in
    --printf ) shift; TITLE="$(printf "$@")";;
    --and-term )
      shift
      TITLE="$*"
      "$SELFPATH"/terminal-set-title.sh "$TITLE";;
    -- ) shift; TITLE="$*";;
  esac

  # Unfortunately Ubuntu focal's "screen" seems to not have proper
  # UTF-8 support for titles.
  TITLE="${TITLE//…/...}"

  case "$BASH_VERSION" in
    [1-4].* ) TITLE="${TITLE//[^ -z\{\}~]/?}";; # <- No idea why [^ -~] fails.
    * ) TITLE="${TITLE//[^ -~]/?}";;
  esac

  "${USE_SUDO[@]}" screen -p "$WINDOW" -X title "$TITLE"
  return 0
}


[ "$1" == --lib ] || screen_set_own_window_title "$@" || exit $?
