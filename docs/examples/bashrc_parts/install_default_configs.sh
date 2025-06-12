#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function install_main () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFPATH="$(readlink -m -- "$BASH_SOURCE"/..)"
  cd -- "$SELFPATH" || return $?
  local REPO_DIR="${SELFPATH%/*/*/*}"

  exec </dev/null
  local TUP_HSUB="/lib/terminal-util-pmb"
  local PLUGBS_MAIN='pluggable-bashrc-sourcer.sh'
  local HTUP="$HOME$TUP_HSUB"
  [ "$REPO_DIR" -ef "$HTUP" ] || return 3$(
    echo "E: Expected '$REPO_DIR' and '$HTUP' to be the same directory." >&2)

  local SAFE_MV='mv --verbose --no-clobber --no-target-directory --'
  local BACKUP_SUF="orig-$(printf '%(%y%m%d-%H%M)T' -1)-$$"

  local IMPL_PRE= IMPL_SUF=
  case "$HOSTNAME" in
    *.uberspace.de ) install_snowflake_uberspace; return $?;;
  esac

  install_rc_file .profile p || return $?
  install_rc_file .bashrc  r || return $?
  install_default_rcd || return $?
}


function install_rc_file () {
  local DEST="$HOME/$1"
  local IMPL='eval "$("$HOME"'"$TUP_HSUB/$PLUGBS_MAIN $2"')"'
  [ -z "$IMPL_PRE" ] || IMPL="$IMPL_PRE"$'\n'"$IMPL"
  [ -z "$IMPL_SUF" ] || IMPL="$IMPL"$'\n'"$IMPL_SUF"
  [ -f "$DEST" ] || echo "$IMPL" >"$DEST" || return $?
  local ACTUAL="$(head --lines=2; echo .)"
  diff -sU 4 --label "expected/$1" -- <(echo "$IMPL") "$DEST" || return $?$(
    echo "E: Unexpected text in $DEST. Please move that file away, e.g." \
      $SAFE_MV "$DEST"'{,.'"$BACKUP_SUF"'}' >&2)
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


function install_snowflake_uberspace () {
  local BACKUP_SUF="uberspace-$BACKUP_SUF"
  install_rc_file .bash_profile p || return $?
  IMPL_PRE='source -- /etc/bashrc' install_rc_file .bashrc  r || return $?
  install_default_rcd || return $?
  $SAFE_MV "$HOME"/.profile{,."$BACKUP_SUF"}
}










install_main "$@"; exit $?
