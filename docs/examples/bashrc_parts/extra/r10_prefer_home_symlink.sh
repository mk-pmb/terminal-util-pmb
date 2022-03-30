# -*- coding: utf-8, tab-width: 2 -*-

function tmpfunc_prefer_home_symlink () {
  local ABS_HOME="$(readlink -m -- "$HOME")"
  [ "$ABS_HOME" == "$HOME" ] && return 0
  [[ "$PWD"/ == "$ABS_HOME"/* ]] || return 0
  local SYM="$HOME${PWD:${#ABS_HOME}}"
  [ "${DEBUGLEVEL:-0}" -le 4 ] || echo "cd: $PWD -> $SYM" >&2
  cd -- "$SYM"
}
tmpfunc_prefer_home_symlink; unset tmpfunc_prefer_home_symlink
