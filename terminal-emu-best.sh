#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
#  terminal-emu-best - Abstraction layer for available terminal emulators.
#  Copyright (C) 2016  mk-pmb
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program.  If not, see <http://www.gnu.org/licenses/>.
#
#
SELFFILE="$(readlink -m "$BASH_SOURCE")"; SELFPATH="$(dirname "$SELFFILE")"
SELFNAME="$(basename "$SELFFILE" .sh)"; INVOKED_AS="$(basename "$0" .sh)"


function terminal_emu_best () {
  local DBGLV="${DEBUGLEVEL:-0}"
  local ARG_WRAP_PRFX='_'
  [ "$DBGLV" -ge 4 ] && echo "D: $FUNCNAME args: $(dump_args "$@")" >&2
  if [ "$1" == "${ARG_WRAP_PRFX}WRAP" ]; then
    shift
    inner_helper "$@"
    return $?
  fi

  local -A CFG
  local EXEC_APP=()
  local UNSUP_OPTS=()
  local INNER_HELPER=()
  parse_cli_opts "$@" || return $?
  [ -n "${CFG[no-op]}" ] && return 0


  local TERM_CMD=( "$(guess_best_termemu)" )
  [ -x "${TERM_CMD[0]}" ] || return 4$(
    echo "E: $0: cannot find any supported terminal emulator!" >&2)

  local SHORT_TERM="$(basename "${TERM_CMD[0]}")"
  SHORT_TERM="${SHORT_TERM%-terminal}"
  local TERM_VER=
  case "$SHORT_TERM" in
    gnome )
      TERM_VER="$(LANG=C gnome-terminal --version | sed -nre '
        s~^GNOME Terminal ([0-9]+)\.([0-9]+)(\.\S+|)$~\1³0000\2~p')";;
  esac
  [ -n "$TERM_VER" ] && TERM_VER="$(<<<"$TERM_VER" sed -re '
    s~³0*([0-9]{3})( |$)~\1~g')"
  [ -n "$TERM_VER" ] || TERM_VER=0
  [ "$DBGLV" -ge 2 ] && echo "D: Terminal: $SHORT_TERM v_ser=$TERM_VER" >&2

  cfg_ensure_new_window
  cfg_geom
  cfg_menubar
  cfg_hold
  cfg_title
  cfg_cwd

  [ -n "${UNSUP_OPTS[*]}" ] && echo "W: $0: cannot control these aspects of" \
      "${TERM_CMD[0]##*/} v_ser=$TERM_VER: ${UNSUP_OPTS[*]}" >&2

  [ "${CFG[hold]}" == inner ] && INNER_HELPER+=( _hold )
  [ -n "${CFG[exec-alias]}" -o -n "${INNER_HELPER[*]}" ] \
    && INNER_HELPER+=( _exec "${CFG[exec-alias]}" )

  ##-----## Check how to encapsulate command arguments: ##-----##
  if [ -n "${INNER_HELPER[*]}" -o -n "${EXEC_APP[*]}" ]; then
    case "$SHORT_TERM" in
      xfce4 | gnome ) TERM_CMD+=( --execute );;
      sakura ) TERM_CMD+=( --xterm-execute ); check_wrap_app_args;;
    esac
  fi
  ##-----## Command arguments below this line won't be encapsulated! ##-----##

  [ -n "${INNER_HELPER[*]}" ] && EXEC_APP=(
    "$SELFFILE" "${ARG_WRAP_PRFX}WRAP" "${INNER_HELPER[@]}" "${EXEC_APP[@]}" )
  INNER_HELPER=()
  [ "${EXEC_APP[0]}" == "$SELFFILE" ] && shorten_self_exec

  [ -n "${CFG[forkoff]}" ] && TERM_CMD=( forkoff "${TERM_CMD[@]}" )
  [ "$DBGLV" -ge 2 ] && echo "D: term cmd: $(dump_args "${TERM_CMD[@]}"
    ) app: $(dump_args "${EXEC_APP[@]}")" >&2

  case "$SHORT_TERM" in
    gnome ) exec 2>/dev/null;;    # ignore its GIO-CRITICAL debug warnings
  esac
  "${TERM_CMD[@]}" "${EXEC_APP[@]}"
  return $?
}


function guess_best_termemu () {
  local DEFAULT_TOPLIST=(
    xfce4-terminal
    sakura
    gnome-terminal
    )

  local EMUS="${CFG[emus]:-+}"
  EMUS=" $(<<<"$EMUS" tr -s ':, \n' ' ') "
  EMUS="${EMUS// + / ${DEFAULT_TOPLIST[*]} }"
  local TOPS=()
  readarray -t TOPS < <(<<<"${EMUS// /$'\n'}" grep -Pe '\S')
  which "${TOPS[@]}" 2>/dev/null | grep -Pe '^/' -m 1
  return $?
}


function dump_args () {
  printf '‹%s› ' "$@"; echo "($#)"
}


function parse_cli_opts () {
  local OPT=
  while [ "$#" -gt 0 ]; do
    OPT="$1"; shift
    case "$OPT" in
      '' ) continue;;
      -x | --exec | -- ) EXEC_APP+=( "$@" ); break;;
      --exec-alias )
        CFG[exec-alias]="$1"; shift
        EXEC_APP+=( "$@" ); break;;
      -c | --cmdarg ) EXEC_APP+=( "$OPT" );;
      --forkoff | \
      --menubar | \
      --hold ) CFG["${OPT#--}"]=+;;
      --emus=* | \
      --cwd=* | \
      --geom=* | \
      --title=* )
        OPT="${OPT#--}"
        CFG["${OPT%%=*}"]="${OPT#*=}";;
      --help | \
      -* )
        local -fp "${FUNCNAME[0]}" | guess_bash_script_config_opts-pmb
        if [ "${OPT//-/}" == help ]; then CFG[no-op]=help; return 0; fi
        echo "E: $0: unsupported option: $OPT" >&2; return 1;;
      * )
        echo "E: unexpected positional argument, forgot '-x'?: $OPT" >&2
        return 1;;
    esac
  done

  return 0
}


function cfg_unsup_opt () {
  UNSUP_OPTS+=( "${FUNCNAME[1]#cfg_}$1" )
}



function cfg_title () {
  [ -n "${CFG[title]}" ] || return 0
  case "$SHORT_TERM" in
    xfce4 | sakura ) TERM_CMD+=( --title "${CFG[title]}" );;
    gnome ) INNER_HELPER+=( _title "${CFG[title]}" );;
    * ) cfg_unsup_opt;;
  esac
}


function cfg_cwd () {
  [ -n "${CFG[cwd]}" ] || return 0
  case "$SHORT_TERM" in
    xfce4 | gnome ) TERM_CMD+=( --working-directory="${CFG[cwd]}" );;
    sakura ) TERM_CMD+=( --working-directory "${CFG[cwd]}" );;
    * ) cfg_unsup_opt;;
  esac
}


function cfg_hold () {
  local HOLD="${CFG[hold]:--}"
  case "$SHORT_TERM:$HOLD" in
    xfce4:- | gnome:- | sakura:- ) ;;
    xfce4:+ | sakura:+ ) TERM_CMD+=( --hold );;
    gnome:+ ) CFG[hold]=inner;;
    * ) cfg_unsup_opt;;
  esac
}


function cfg_geom () {
  local GEOM="${CFG[geom]}"

  if [ "${GEOM%%,*}" == max ]; then
    case "$SHORT_TERM" in
      xfce4 | gnome | sakura )
        TERM_CMD+=( --maximize );;
      * ) TERM_CMD+=( --maximize ); cfg_unsup_opt =max;;
    esac
    GEOM="${GEOM#max,}"
    [ "$GEOM" == max ] && GEOM=
  fi
  [ -n "$GEOM" ] || return 0

  local NUMS='
    s~^¹x¹$~WxH \1 \2~p
    s~^¹x¹±±$~WxH@xy \1 \2 \3 \4~p
    '
  NUMS="${NUMS//¹/([0-9]+)}"
  NUMS="${NUMS//±/([+-][0-9]+)}"
  NUMS=( $(<<<"$GEOM" sed -nre "$NUMS") )
  case "$SHORT_TERM:${NUMS[0]}" in
    gnome:* ) cfg_geom_gnome "${NUMS[@]:1}"; return $?;;
    xfce4:WxH )
      TERM_CMD+=( --geometry="$GEOM" ); return 0;;
    sakura:WxH )
      TERM_CMD+=( -c "${NUMS[1]}" -r "${NUMS[2]}" ); return 0;;
  esac

  cfg_unsup_opt =
  return 2
}


function cfg_geom_gnome () {
  local T_COLS="$1"; shift
  local T_ROWS="$1"; shift
  local T_LEFT="$1"; shift
  local T_TOP="$1"; shift
  # Xenial, GT 3.18.3, Compiz: no adjustments required
  # Trusty, GT 3.6.2, Xfce 4.10: rows += 1 :TODO:
  TERM_CMD+=( --geometry="${T_COLS}x${T_ROWS}${T_LEFT}${T_TOP}" )
  return 0
}


function cfg_ensure_new_window () {
  case "$SHORT_TERM" in
    xfce4 ) TERM_CMD+=( --disable-server );;
    gnome )
      if [ "$TERM_VER" -lt 3008 ]; then
        TERM_CMD+=( --disable-factory )
      else
        # https://mail.gnome.org/archives/commits-list/2013-
        # September/msg05584.html
        cfg_unsup_opt -gnome
      fi;;
    sakura ) ;;
    * ) cfg_unsup_opt;;
  esac
}


function cfg_menubar () {
  local MBAR="${CFG[menubar]:--}"
  case "$SHORT_TERM:${MBAR:0:1}" in
    xfce4:- | gnome:- ) TERM_CMD+=( --hide-menubar );;
    xfce4:+ | gnome:+ ) TERM_CMD+=( --show-menubar );;
    sakura:- ) ;;
    sakura:+ | \
    * ) cfg_unsup_opt;;
  esac
}


function inner_helper () {
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME args: $(dump_args "$@")" >&2
  local OPTS=( "$@" )
  local OPT=
  while [ "${#OPTS[@]}" -gt 0 ]; do
    OPT="${OPTS[0]}"; OPTS=( "${OPTS[@]:1}" )
    case "$OPT" in
      _strip | _title | _exec | _hold )
        inner_helper_"$OPT" || return $?;;
      * ) echo "E: $FUNCNAME: unsupported option: $OPT" >&2; return 4;;
    esac
  done
  echo "E: $0 [$$], $FUNCNAME: unexpected end of commands, gonna sleep." >&2
  sleep 10s
  return 2
}


function inner_helper__strip () {
  local ORIG_OPTS=( "${OPTS[@]}" )
  OPTS=()
  local ARG=
  for ARG in "${ORIG_OPTS[@]}"; do OPTS+=( "${ARG#$ARG_WRAP_PRFX}" ); done
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME: $(dump_args "${OPTS[@]}")" >&2
  return 0
}


function inner_helper__title () {
  local TERM_TITLE="${OPTS[0]}"; OPTS=( "${OPTS[@]:1}" )
  printf '\x1b]0;%s\x07' "$TERM_TITLE"
  # ^-- If this seems to fail, it's usually because the title is (re)set
  #     very soon after we set it.

  # Since some terminal emulators tend to add their own title to the one
  # set with above method, make assurance double sure:
  local WIN_IDS=( $(wmctrl -pl 2>/dev/null | LANG=C sed -nre '
    s~^(0x[0-9a-fA-F]+)\s+\S+\s+'"$PPID"'\s.*$~\1~p') )
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME: ppid=$PPID win_ids=[$(
    dump_args "${WIN_IDS[@]}")]" >&2
  [ -n "${WIN_IDS[*]}" ] && set_wintitle_by_hnd_soon "${WIN_IDS[@]}"
  return 0
}


function set_wintitle_by_hnd_soon () {
  ( sleep 0.1s
    local WIN_ID=
    for WIN_ID in "$@"; do
      wmctrl -iFr "$WIN_ID" -T "$TERM_TITLE"
    done
  ) &
  disown $!
}


function inner_helper__exec () {
  local ALIAS_OPT=
  if [ -n "${OPTS[0]}" ]; then
    ALIAS_OPT='-a'
  else
    OPTS=( "${OPTS[@]:1}" )
  fi
  [ -n "${OPTS[*]}" ] || OPTS=( "$SHELL" -i )
  exec $ALIAS_OPT "${OPTS[@]}"
  return $?
}


function inner_helper__hold () {
  local EXEC_APP=( "$SELFFILE" "${ARG_WRAP_PRFX}WRAP" )
  shorten_self_exec
  "${EXEC_APP[@]}" "${OPTS[@]}"
  while true; do sleep 90d; done
  echo "E: $0: woke up from --hold's infinite sleep loop." >&2
  return 8
}


function str_is_one_of () {
  local KWD="$1"; shift
  local ARG=
  for ARG in "$@"; do
    [ "$ARG" == "$KWD" ] && return 0
  done
  return 1
}


function check_wrap_app_args () {
  local PAD=
  local ARG=
  if [ "$#" != 0 ]; then
    # only check for some known-bad values:
    for ARG in "$@"; do
      str_is_one_of "$ARG" "${INNER_HELPER[@]}" "${EXEC_APP[@]}" || continue
      PAD="$ARG_WRAP_PRFX"
      break
    done
  else
    # check for prefixes that could confuse the terminal emulator:
    for ARG in "${EXEC_APP[@]}"; do case "$ARG" in
      [a-z0-9_/]* ) ;;
      * ) PAD="$ARG_WRAP_PRFX"; break;;
    esac; done
  fi
  [ -z "$PAD" ] && return 0
  local ORIG_ARGS=( "${EXEC_APP[@]}" )
  EXEC_APP=()
  for ARG in "${ORIG_ARGS[@]}"; do EXEC_APP+=( "$PAD$ARG" ); done
  ORIG_ARGS=( "${INNER_HELPER[@]}" )
  INNER_HELPER=( _strip )
  [ -n "${ORIG_ARGS[*]}" ] || ORIG_ARGS+=( _exec )
  for ARG in "${ORIG_ARGS[@]}"; do INNER_HELPER+=( "$PAD$ARG" ); done
  return 0
}


function shorten_self_exec () {
  [ -n "$SELFFILE" ] || return 3
  local INVO=
  local RSLV=
  for INVO in "$INVOKED_AS"; do
    RSLV="$(which "$INVO" 2>/dev/null)"
    [ -n "$RSLV" ] || continue
    RSLV="$(readlink -m "$RSLV")"
    [ "$RSLV" == "$SELFFILE" ] || continue
    EXEC_APP[0]="$INVOKED_AS"
    return 0
  done
  return 2
}


function forkoff () {
  setsid "$@" &
  disown $!
}















terminal_emu_best "$@"; exit $?
