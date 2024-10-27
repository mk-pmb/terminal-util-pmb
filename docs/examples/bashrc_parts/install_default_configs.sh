#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function install_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -f -- "$BASH_SOURCE"/..)"
  cd -- "$SELFPATH" || return $?
  local REPO_DIR="${SELFPATH%/*/*/*}"

  exec </dev/null
  local TUP_HSUB="/lib/terminal-util-pmb"
  local PLUGBS_MAIN='pluggable-bashrc-sourcer.sh'
  local HTUP="$HOME/lib/terminal-util-pmb"
  [ "$REPO_DIR" -ef "$HTUP" ] || return 3$(
    echo "E: Expected '$REPO_DIR' and '$HTUP' to be the same directory." >&2)

  install_rc_file .profile p || return $?
  install_rc_file .bashrc  r || return $?
  install_default_rcd || return $?
}


function install_rc_file () {
  local DEST="$HOME/$1"
  local IMPL='eval "$("$HOME"'"$TUP_HSUB/$PLUGBS_MAIN $2"')"'
  [ -f "$DEST" ] || echo "$IMPL" >"$DEST" || return $?
  local ACTUAL="$(head --lines=2; echo .)"
  diff -sU 4 --label "expected/$1" -- <(echo "$IMPL") "$DEST" || return $?$(
    echo "E: Unexpected text in $DEST. Please move that file away." >&2)
}


function install_default_rcd () {
  echo -n 'Install default config: '
  local HCB="$HOME/.config/bash"
  mkdir --parents -- "$HCB"
  local ITEM=
  for ITEM in "$HCB"/*.rcd/; do
    [ -d "$ITEM" ] || continue
    echo "Skip: Found a $HCB/*.rcd/ directory."
    return 0
  done
  echo "Create symlinks:"
  local LNS='ln --symbolic --no-target-directory --verbose --'
  $LNS "../..$TUP_HSUB/docs/examples/bashrc_parts" "$HCB"/tu.core.rcd \
    || return $?$(echo "E: Failed to create symlink: $HCB/tu.core.rcd" >&2)
  local ITEM=
  for ITEM in global extra; do
    $LNS tu.core.rcd/$ITEM $HCB/tu.$ITEM.rcd || return $?$(
      echo "E: Failed to create symlink: $HCB/tu.$ITEM.rcd" >&2)
  done
}










install_main "$@"; exit $?
