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

  local SHORT_TERM="$(shorten_termprog_name "${TERM_CMD[0]}")"
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
  cfg_window_name; cfg_window_class
    # ^-- wmctrl displays them as name.class, e.g.
    # Navigator.Firefox
    # IEXPLORE.EXE.Wine
    # see https://tronche.com/gui/x/icccm/sec-4.html#WM_CLASS
  cfg_icon
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


function shorten_termprog_name () {
  local TP="$1"
  TP="${TP##*/}"
  TP="${TP%-terminal}"
  echo "$TP"
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
      --cwd=* | \
      --emus=* | \
      --geom=* | \
      --icon=* | \
      --winclass=* | \
      --winname=* | \
      --title=* )
        OPT="${OPT#--}"
        [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME: [${OPT%%=*}]=${OPT#*=}" >&2
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


function cfg_icon () {
  local ICON="${CFG[icon]}"

  case "$SHORT_TERM" in
    xfce4 )
      TERM_CMD+=( --icon="$ICON" ); return 0;;
  esac

  cfg_unsup_opt =
  return 0
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
        cfg_unsup_opt -gnome
        # "There's no bug here; this option is simply not supported anymore."
        # https://bugzilla.gnome.org/show_bug.cgi?id=707899#c1
        INNER_HELPER+=( _unreliable_parent )
      fi;;
    sakura ) ;;
    * ) cfg_unsup_opt;;
  esac
}


function cfg_menubar () {
  local MBAR="${CFG[menubar]:--}"
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME: '$MBAR'" >&2
  case "$SHORT_TERM:${MBAR:0:1}" in
    xfce4:- | gnome:- ) TERM_CMD+=( --hide-menubar );;
    xfce4:+ | gnome:+ ) TERM_CMD+=( --show-menubar );;
    sakura:- ) ;;
    sakura:+ | \
    * ) cfg_unsup_opt;;
  esac
}


function cfg_window_class () {
  local WINCLS="${CFG[winclass]}"
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME: '$WINCLS'" >&2
  [ -z "$WINCLS" ] && return 0
  case "$SHORT_TERM" in
    gnome )
      # --class is deprecated: GNOME Bug #775383, WONTFIX
      INNER_HELPER+=( _xdo_setwin class="$WINCLS" );;
    sakura )  TERM_CMD+=( --class="$WINCLS" );;
    * ) cfg_unsup_opt;;
  esac
}


function cfg_window_name () {
  local WINNAME="${CFG[winname]}"
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME: '$WINNAME'" >&2
  [ -z "$WINNAME" ] && return 0
  case "$SHORT_TERM" in
    gnome )
      # --name is deprecated: GNOME Bug #775383, WONTFIX
      INNER_HELPER+=( _xdo_setwin classname="$WINNAME" );;
    sakura )  TERM_CMD+=( --name="$WINNAME" );;
    * ) cfg_unsup_opt;;
  esac
}


function array_shift () {
  local A="$1"; shift     # name of source array
  local V=    # name of each target variable
  local I=0
  for V in "$@"; do
    [ "$V" == - ] || eval "$V"'="${'"$A[$I]"'}"'
    # echo D: eval "$V"'="${'"$A[$I]"'}"' >&2
    let I="$I+1"
  done
  eval "$A"'=( "${'"$A"'[@]:'"$#"'}" )'
}


function inner_helper () {
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME args: $(dump_args "$@")" >&2
  local -A IH_CFG
  local IH_TRACE=()
  local OPTS=( "$@" )
  inner_helper_dare && return 0
  local DARE_RV=$?
  ( echo -n "E: inner helper failed: "
    printf '%s » ' "${IH_TRACE[@]}"
    echo -n "rv=$DARE_RV, remaining opts: "
    dump_args "${OPTS[@]}"
    echo 'press any key to close/exit'
  ) >&2
  local KEY=
  read -rs -N 1 KEY
  return $DARE_RV
}


function inner_helper_dare () {
  # local TERM_PROG="$(LANG=C ps wwch -o cmd "$PPID")"
  # TERM_PROG="${TERM_PROG%-}"
  # local SHORT_TERM="$(shorten_termprog_name "$TERM_PROG")"
  # [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME: terminal progam:" \
  #   "'$SHORT_TERM' ('$TERM_PROG')" >&2

  local XDO_SETWIN=(
    # name=N:       WM_NAME = title, usually
    # icon-name=N:  WM_ICON_NAME = title when minimized, usually
    # role=N, classname=N, class=N
    )
  local RV=
  local OPT=
  while [ "${#OPTS[@]}" -gt 0 ]; do
    array_shift OPTS OPT
    [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME: '$OPT' <${OPTS[*]}>" >&2
    case "$OPT" in
      _unreliable_parent )
        IH_CFG["${OPT#_}"]=+;;
      _xdo_setwin )
        array_shift OPTS OPT
        XDO_SETWIN+=( "$OPT" );;
      _title | _strip )
        inner_helper_"$OPT" || return $?;;
      _hold | _exec )
        [ "${#XDO_SETWIN[@]}" == 0 ] || inner_helper_xdo_setwin || return $?
        inner_helper_"$OPT" || return $?;;
      * )
        IH_TRACE+=( "$FUNCNAME: unsupported option" "$OPT" )
        return 4;;
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


function inner_helper_guess_winid () {
  local PFX_W="W: $FUNCNAME: "
  local WIN_ID=
  [ "$DBGLV" -ge 2 ] && echo "${PFX_W}(@$0) guessing by ppid $PPID" >&2
  if [ -n "${IH_CFG[unreliable_parent]}" ]; then
    [ "$DBGLV" -ge 2 ] && echo "${PFX_W}skip: unreliable parent" >&2
  else
    WIN_ID="$(xdotool search --all --onlyvisible --pid "$PPID" --class .)"
    inner_helper_validate_winid "$WIN_ID" && return 0
  fi

  echo "${PFX_W}falling back to title guessing work-around" >&2
  local TITLE_TAG="==:$$:$UID:$RANDOM:== $(LANG=C ps wwch -o cmd "$PPID")"
  # LANG=C ps wwch -o cmd,pid,uid "$PPID" | tr -s ' \t' :
  set_xterm_title "$TITLE_TAG"
  WIN_ID="$(find_window_id_by_title "$TITLE_TAG")"
  inner_helper_validate_winid "$WIN_ID" && return 0

  echo "${PFX_W}exhausted all known strategies. giving up." >&2
  return 2
}


function find_window_id_by_title () {
  local W_TITLE="$1"
  local W_ID=

  W_ID="$(xwininfo -name "$W_TITLE" \
    | grep -oPe '^xwininfo: Window id: 0x\S+' -m 1)"
  W_ID="${W_ID##* }"
  [ -n "$W_ID" ] && inner_helper_validate_winid "$W_ID" && return 0

  if xdotool version &>/dev/null; then
    W_ID="$(timeout 2s xdotool search --sync --all --onlyvisible
      --name "$W_TITLE")"
    [ -n "$W_ID" ] && inner_helper_validate_winid "$W_ID" && return 0
  fi

  echo "W: $FUNCNAME: exhausted all known strategies. giving up." \
    "maybe there just is no window named '$W_TITLE'." >&2
  return 2
}


function inner_helper_validate_winid () {
  local W_ID="$1"
  case "$W_ID" in
    *$'\n'* )
      [ "$DBGLV" -ge 2 ] && echo "${PFX_W}too many window IDs" >&2;;
    '' )
      [ "$DBGLV" -ge 2 ] && echo "${PFX_W}no window ID" >&2;;
    0x[0-9a-fA-F]* ) echo "$W_ID"; return 0;;
    [0-9]* ) printf '0x%x\n' "$W_ID"; return 0;;
    * )
      echo "${PFX_W}strange window ID '$W_ID' for process $PPID" >&2;;
  esac
  return 2
}


function inner_helper_xdo_setwin () {
  local WIN_ID="$(inner_helper_guess_winid)"
  [ -n "$WIN_ID" ] || return 5$(
    echo "E: unable to identify terminal window," \
      "thus cannot set these window properties: ${XDO_SETWIN[*]}" >&2)

  local XDO_CMD=( xdotool set_window )
  local ARG=
  for ARG in "${XDO_SETWIN[@]}"; do
    XDO_CMD+=( "--${ARG%%=*}" "${ARG#*=}" )
  done
  XDO_CMD+=( "$WIN_ID" )
  [ "$DBGLV" -ge 2 ] && echo "D: $FUNCNAME: $(dump_args "${XDO_CMD[@]}")" >&2
  "${XDO_CMD[@]}"
  ARG="$?"
  if [ "$ARG" != 0 ]; then
    IH_TRACE=( "$FUNCNAME" "${XDO_CMD[@]}" )
    return "$ARG"
  fi

  ( sleep 0.2s; "${XDO_CMD[@]}" ) &
  disown $!
  return 0
}


function set_xterm_title () {
  if ! tty --silent; then
    echo "E: $FUNCNAME: expected stdin to be a TTY" >&2
    return 3
  fi

  printf '\x1b]0;%s\x07' "$*" >&0
  # ^-- If this seems to fail, it's usually because the title is (re)set
  #     very soon after we set it.
}


function inner_helper__title () {
  local TERM_TITLE=
  array_shift OPTS TERM_TITLE
  set_xterm_title "$TERM_TITLE"
  XDO_SETWIN+=( {,icon-}name="$TERM_TITLE" )
  return 0
}


function inner_helper__exec () {
  local ALIAS_OPT=
  if [ -n "${OPTS[0]}" ]; then
    ALIAS_OPT='-a'
  else
    array_shift OPTS -
  fi
  [ -n "${OPTS[*]}" ] || OPTS=( "$SHELL" -i )
  IH_TRACE+=( "_exec[alias=$ALIAS_OPT]" )
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
      [a-z0-9/]* ) ;;
      * ) PAD="$ARG_WRAP_PRFX"; break;;
    esac; done
  fi
  [ -z "$PAD" ] && return 0
  local ORIG_ARGS=( "${EXEC_APP[@]}" )
  EXEC_APP=()
  for ARG in "${ORIG_ARGS[@]}"; do EXEC_APP+=( "$PAD$ARG" ); done
  ORIG_ARGS=( "${INNER_HELPER[@]}" )
  INNER_HELPER=( _strip )
  local OPT_EXEC_NO_ALIAS=
  [ -n "${ORIG_ARGS[*]}" ] || ORIG_ARGS+=( _exec "$OPT_EXEC_NO_ALIAS" )
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
