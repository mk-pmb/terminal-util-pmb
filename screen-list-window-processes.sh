#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function scrl_winprocs () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly

  [ "$SCRLWP_CLI_VER" == 220409 ] || return 4$(
    echo "E: $0 $FUNCNAME: This is still so highly experimental that" \
      "you must specify the latest SCRLWP_CLI_VER." >&2)

  local SESSIONS=()
  readarray -t SESSIONS < <(screen -list | sed -nre '
    s~^\s+([0-9]+)\.(\S+)\s.*$~\1=\2~p')
  local SESS_NAME= SESS_PID=
  for SESS_NAME in "${SESSIONS[@]}"; do
    SESS_PID="${SESS_NAME%%=*}"
    SESS_NAME="${SESS_NAME#*=}"
    echo "* session $SESS_PID: $SESS_NAME"
    scrl_winprocs_found_sess "$SESS_PID" || return $?
  done
}


function scrl_winprocs_found_sess () {
  local S_PID="$1"
  local W_PID=
  for W_PID in $(ps ho pid --ppid "$S_PID"); do
    echo "  * window $(scrl_winprocs_describe_proc $W_PID)"
  done
}


function scrl_winprocs_describe_proc () {
  local P_PID="$1"
  echo -n "pid=$P_PID"
  </proc/"$P_PID"/environ tr -s '\0' '\n' | sed -nre '
    s~^(WINDOW)=~ &~p
    ' | tr -d '\n'

  local P_CWD="$(LANG=C stat -c '%N' -- /proc/"$P_PID"/cwd)"
  P_CWD="${P_CWD#* -\> \'}"
  P_CWD="${P_CWD%\'}"
  echo -n " cwd='$P_CWD'"

  local P_CMD="$(cat -- /proc/"$P_PID"/cmdline)"
  P_CMD="‹${P_CMD//$'\x00'/› ‹}›"
  echo " : $P_CMD"
}











[ "$1" == --lib ] && return 0; scrl_winprocs "$@"; exit $?
