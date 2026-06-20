#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function scrl_winprocs () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly

  [ "$SCRLWP_CLI_VER" == 220409 ] || return 4$(
    echo "E: $0 $FUNCNAME: This is still so highly experimental that" \
      "you must specify the latest SCRLWP_CLI_VER." >&2)

  local SED_HEXESC='s~\\x%s~\\\\x%s~g;'
  SED_HEXESC="$(printf -- "$SED_HEXESC" \
    {5C,0{7..9},0{A..D},1B,20,22,27,7F}{,})"
  SED_HEXESC="${SED_HEXESC/x5C/'\'}" # sed quirk: doesn't accept \x5C

  scrl_"$@" || return $?
}


function scrl_allsess_scan_winprocs () {
  local SESSIONS=()
  readarray -t SESSIONS < <(screen -list |
    sed -nre 's~^\s+([0-9]+)\.(\S+)\s.*$~\1=\2~p')
  local SESS_NAME= SESS_PID=
  for SESS_NAME in "${SESSIONS[@]}"; do
    SESS_PID="${SESS_NAME%%=*}"
    SESS_NAME="${SESS_NAME#*=}"
    scrl_winprocs_found_sess || return $?
  done
}


function scrl_winprocs_found_sess () {
  local WIN_PIDS=( $(ps ho pid --ppid "$SESS_PID" | sort -g) )
  local N_WINS="${#WIN_PIDS[@]}" WIN_PID=
  WIN_PID="${WIN_PIDS[*]}"
  WIN_PID="${WIN_PID// /,}"
  printf -- '%s\t' = sess="$SESS_NAME" spid="$SESS_PID" \
    n_wins="$N_WINS" w_pids="$WIN_PID"
  echo =
  for WIN_PID in "${WIN_PIDS[@]}"; do
    scrl_winprocs_describe_proc
  done
}


function scrl_winprocs_describe_proc () {
  printf -- '%s\t' = sess="$SESS_NAME" spid="$SESS_PID"
  local WIN_ENV='
    s!^(WINDOW)=!wnum=!p
    '
  WIN_ENV="$(sed -znre "$WIN_ENV" -- /proc/"$WIN_PID"/environ |
    tr -s '\0' '\n' | LANG=C sort -V | tr '\n' '\t')"
  echo -n "$WIN_ENV"

  printf -- '%s\t' wpid="$WIN_PID"

  #==BEGIN== Read proc symlinks ===== ===== ===== ===== ===== ===== =====
  local -A SYMLINKS=()
  local KEY= VAL=
  for KEY in exe cwd ; do
    VAL="$(LANG=C stat -c '%N' -- "/proc/$WIN_PID/$KEY")"
    VAL="${VAL#* -\> \'}"
    VAL="${VAL%\'}"
    SYMLINKS["$KEY"]="$VAL"
    printf -- '%s\t' "$KEY=$VAL"
  done
  #==ENDOF== Read proc symlinks ===== ===== ===== ===== ===== ===== =====

  local P_ARGS="$(LANG=C sed -zre "$SED_HEXESC" \
    -- /proc/"$WIN_PID"/cmdline | tr '\0' '\t')"
  P_ARGS="${P_ARGS%$'\t'}"
  local P_ARG0="${P_ARGS%%$'\t'*}"
  P_ARGS="${P_ARGS:${#P_ARG0}}"

  local P_ALIAS="$P_ARG0"
  case "$P_ALIAS" in
    "${SYMLINKS[exe]}" ) P_ALIAS=;;
  esac
  printf -- '%s\t' alias="$P_ALIAS"

  local N_ARGS="${P_ARGS//[^$'\t']/}"
  N_ARGS="${#N_ARGS}"
  printf -- '%s\t' n_args="$N_ARGS"

  echo -n =
  if [ -n "$P_ARGS" ]; then
    P_ARGS='"'"${P_ARGS#$'\t'}"'"'
    P_ARGS="${P_ARGS//$'\t'/$'"\t"'}"
    echo -n $'\t'"$P_ARGS"
  fi

  echo
}











[ "$1" == --lib ] && return 0; scrl_winprocs "$@"; exit $?
