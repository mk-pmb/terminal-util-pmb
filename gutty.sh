#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function gutty () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly
  local SELFFILE="$(readlink -m -- "$BASH_SOURCE")"
  # local SELFPATH="$(dirname -- "$SELFFILE")"
  cd / || return $?   # avoid locking the orig cwd
  local GUTTY_APPNAME='GuTTY'
  local GUTTY_CONFIGS=(
    /etc/ssh/gutty.conf
    /etc/gutty.conf
    "$HOME"/.ssh/gutty.conf
    "$HOME"/.config/gutty.conf
    )
  local GUTTY_PORT_FINDER=''
  local GUTTY_TERM_OPTS=()
  local GUTTY_TERM_PROFILE_FINDER='host_title_case'
  local GUTTY_TERM_PROFILE_PREFIX='SSH on '
  local GUTTY_TERM_PROFILE_SUFFIX=''
  local GUTTY_SSH_MIN_DURATION=5

  # check unitialized config variables:
  # grep -oPe '\$GUTTY\w+' $(which gutty) | sort | uniq -c

  local CFG=
  for CFG in "${GUTTY_CONFIGS[@]}"; do
    [ -f "$CFG" ] && source "$CFG"
  done

  if [ "$1" == "--ssh-wrapper" ]; then
    echo "D: Waiting for TTY to adapt itself to the terminal window size…"
    sleep 1s
    echo "D: Gonna SSH now."
    ssh_wrapper "${@:2}"
    return $?
  fi

  local DEST_HOST="$1"
  [ -n "$DEST_HOST" ] || DEST_HOST="$(sel_dest_menu)"
  [ -n "$DEST_HOST" ] || return 0

  local SSH_USER="$( <<<"$DEST_HOST" sed -nre 's!^([^@]+)@.*$!\1!p' )"
  [ -n "$SSH_USER" ] && DEST_HOST="$( <<<"$DEST_HOST" cut -d '@' -f 2- )"

  local HOST_ALIAS="$( cfg_list_dict hostalias | grep -F "#${DEST_HOST}#" )"
  # jetzt ggf. vertauschen: HOST_ALIAS soll sein, wie der Benutzer den
  # Host nennt, und DEST_HOST soll sein, wie der Host im DNS heißt.
  if [ -z "$HOST_ALIAS" ]; then
    HOST_ALIAS="$DEST_HOST"
  else
    DEST_HOST="$( <<<"$HOST_ALIAS" cut -d '#' -f 3)"
    HOST_ALIAS="$( <<<"$HOST_ALIAS" cut -d '#' -f 2)"
    if <<<"$DEST_HOST" grep -qF '@'; then
      [ -z "$SSH_USER" ] && SSH_USER="$( <<<"$DEST_HOST" cut -d '@' -f 1 )"
      DEST_HOST="$( <<<"$DEST_HOST" cut -d '@' -f 2- )"
    fi
  fi
  # echo "[$HOST_ALIAS] = [$DEST_HOST]:[$DEST_PORT]" ; return 0

  local DEST_PORT="$2"
  if [ -z "$DEST_PORT" ]; then
    DEST_PORT="$( <<<"$DEST_HOST" grep -oPe ':\d+$' | tr -cd '0-9' )"
    [ -n "$DEST_PORT" ] && DEST_HOST="${DEST_HOST%:*}"
  fi
  if [ -z "$DEST_PORT" -a -n "$GUTTY_PORT_FINDER" ]; then
    DEST_PORT=$( $GUTTY_PORT_FINDER "$DEST_HOST" )
  fi
  # [ -n "$DEST_PORT" ] || DEST_PORT=22

  local TERM_PROFILE="$HOST_ALIAS"
  if [ -n "$GUTTY_TERM_PROFILE_FINDER" ]; then
    TERM_PROFILE=$(
      $GUTTY_TERM_PROFILE_FINDER "$HOST_ALIAS" "$DEST_HOST" "$DEST_PORT" )
  fi
  TERM_PROFILE="${GUTTY_TERM_PROFILE_PREFIX}${TERM_PROFILE}"
  TERM_PROFILE+="${GUTTY_TERM_PROFILE_SUFFIX}"

  local TERM_BIN="$(which \
    gnome-terminal \
    2>&1 | tail -n 1)"
  if [ ! -x "$TERM_BIN" ]; then
    <<<'E: cannot find any supported terminal emulator!' \
      tee /dev/stderr | xmessage -title "$GUTTY_APPNAME" -center -file -
    return 1
  fi

  local INNER_CMD="'$SELFFILE' --ssh-wrapper $(
    )'$SSH_USER' '$DEST_HOST' '$DEST_PORT' -X"
  local TERM_CMD=( "$TERM_BIN" )
  export GUTTY_WINTITLE="$TERM_PROFILE"
  TERM_CMD+=( --title="$GUTTY_WINTITLE" )
  TERM_CMD+=( --window-with-profile="$TERM_PROFILE" )
  TERM_CMD+=( "${GUTTY_TERM_OPTS[@]}" )
  TERM_CMD+=( --command="$INNER_CMD" )
  [ "${DEBUGLEVEL:-0}" -gt 2 ] && dump_args term: "${TERM_CMD[@]}"
  exec &>/dev/null
  "${TERM_CMD[@]}" &
}


function cfg_list_dict () {
  local CFG=
  for CFG in "${GUTTY_CONFIGS[@]}"; do
    [ -f "$CFG" ] || continue
    sed -nre 's![\t ]+! !;s!^ *# *'"$1"' +([^ ]+) +!#\1#!p' "$CFG" \
      | cut -d '#' -f 1-3 | sed -re 's! *\r*$!!'
  done
}


function host_title_case () {
  local HSN="$1" # HSN = host short name
  case "$HSN" in
    *.local | *.lan ) HSN="${HSN%.*}";;
  esac
  case "$HSN" in
    *.* )
      # has a dot in it -> internet name
      ;;
    * )
      # no dot -> local name
      HSN="${HSN^}"
      ;;
  esac
  echo "$HSN"
}


function sel_dest_menu () {
  local GUTTY_HOSTS="$( <<<"${GUTTY_HOSTS[*]}" \
    tr -cs 'a-zA-Z0-9\_\.\-\&\(\)@:' '\n' | grep . )"
  local BUTTONS="GTK_STOCK_CONNECT:2,$( <<<"$GUTTY_HOSTS" \
    sed -re 's!\([^\(\)]+\)!!g;s!_!__!g;s!\&!_!g' | nl -v 10 -n ln \
    | sed -nre 's!^([0-9]+)[ \t]+(.+)$!\2:\1!p')"
  BUTTONS="${BUTTONS//$'\n'/,}"
  local DEST_HOST=
  DEST_HOST="$( gxmessage -title "$GUTTY_APPNAME" \
    'destination host?' -buttons "$BUTTONS" -entry )"
  local HOST_SEL=$?
  [ $HOST_SEL == 2 ] && echo "$DEST_HOST"
  if [ $HOST_SEL -ge 10 ]; then
    <<<"$GUTTY_HOSTS" head -n $(( $HOST_SEL - 9 )) | tail -n 1 | tr -d '&()'
  fi
  return 0
}


function dump_args () {
  local PFX="$1"; shift
  local ARG=
  for ARG in "$@"; do echo "$PFX [$ARG]"; done
}


function ssh_wrapper () {
  [ "${DEBUGLEVEL:-0}" -gt 2 ] && dump_args wrapper: "$@"
  local SSH_USER="$1"; shift
  local DEST_HOST="$1"; shift
  local DEST_PORT="$1"; shift
  local SSH_LOGIN="$DEST_HOST"
  [ -n "$SSH_USER" ] && SSH_LOGIN="${SSH_USER}@${SSH_LOGIN}"
  local SSH_CMD=( ssh "$SSH_LOGIN" )
  [ -n "$DEST_PORT" ] && SSH_CMD+=( -p "$DEST_PORT" )
  local CFG="$(ssh -G "$DEST_HOST" | sed -nre 's~^setenv gutty_~~p')"
  local DEST_ICON="$(<<<"$CFG" sed -nre 's~^icon=~~p')"

  # SSHW_PID="$$" debian_chroot=ssh:debug bash -i || return $?
  local WIN_ID='s~\t~ ~g; s~^(\S+)\s+\S+\s+\S+\s+~\1\n\t~'
  WIN_ID="$(wmctrl -l | sed -re "$WIN_ID" |
    grep -B 1 -xFe $'\t'"$GUTTY_WINTITLE" | grep -oPe '^0x\w+')$"
  case "$DEST_ICON" in
    '*'*) DEST_ICON="/usr/share/icons/${DEST_ICON:1}";;
  esac
  [ -z "$DEST_ICON" ] || for WIN_ID in $WIN_ID; do
    xseticon-pmb "$WIN_ID" png "$DEST_ICON" || true
  done

  SSH_CMD+=( "$@" )
  local SSH_RTV=
  echo "${SSH_CMD[@]}"
  SECONDS=0    # bash timer magic
  "${SSH_CMD[@]}"
  SSH_RTV=$?
  local SSH_DURATION_SECS=$SECONDS
  if [ "$SSH_DURATION_SECS" -lt "$GUTTY_SSH_MIN_DURATION" ]; then
    echo
    echo
    echo "$(date -R): SSH finished unexpectedly quickly, rv=$SSH_RTV."
    echo -n "Press Enter to close."
    read -rs SSH_DURATION_SECS
  fi
  return 0
}










gutty "$@"; exit $?
