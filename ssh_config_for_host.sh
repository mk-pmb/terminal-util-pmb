#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
# Originally written for GuTTY. The idea was to reuse the SetEnv config
# option to configure custom extra features in the SSH config file.
# It should have been this easy:
#     ssh -G "$DEST_HOST" | sed -nre 's~^setenv gutty_~~p'
# … but unfortunately, `ssh -G` reports only the first matching SetEnv.
# This also means our reuse of SetEnv would probably conflict with users'
# actual SetEnv if they need it. Thus, we'll have to roll our own parsing.


function ssh_config_for_host () {
  local DEST_HOST="$1"; shift
  local LN= PAT= APPLICABLE=
  local SED='s~^\s+~~; s~^Host\s~EndOfHost\n&~; /^Host\s/s~\s+~ ~g'
  LANG=C sed -re "$SED" -- "$HOME"/.ssh/config |
  while IFS= read -r LN; do
    case "$LN" in
      'Host '* )
        APPLICABLE="${LN#* } "
        # echo "?? <$APPLICABLE> ??"
        while [ -n "$APPLICABLE" ]; do
          PAT="${APPLICABLE%% *}"
          APPLICABLE="${APPLICABLE#* }"
          [[ "$DEST_HOST" == $PAT ]] || continue
          APPLICABLE='*'
          break
        done
        [ "$APPLICABLE" == '*' ] || APPLICABLE=
        # echo "applicable? <$APPLICABLE>"
        ;;
      EndOfHost ) APPLICABLE=;;
    esac
    [ -n "$LN" ] || continue
    [ -z "$APPLICABLE" ] || echo "$LN"
  done
}


ssh_config_for_host "$@"; exit $?
