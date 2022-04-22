#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
# For weird embedded systems where setting the default shell has no effect.

tmpfunc_tupmb_bash_plz () {
  # ^-- Assuming a bad shell means we can't use nice function syntax.

  local ABS_SHELL="$(readlink -f -- "$(which -- "$SHELL" 2>/dev/null)")"
  case "$ABS_SHELL" in
    */ash | \
    */sh | \
    */busybox | \
    . ) ;;
    * ) return 0;;
  esac

  [ "$#" == 0 ] || return 0
  tty -s || return 0
  # ^-- short option for busybox compatibility

  # Warn & delay: Damage control in case we somehow become recursive.
  echo 'D: bash fix triggered via <<$plug:src$>>' >&2
  SHELL='/bin/bash'
  export SHELL
  sleep 1s && exec "$SHELL" -i
}
tmpfunc_tupmb_bash_plz; unset tmpfunc_tupmb_bash_plz
