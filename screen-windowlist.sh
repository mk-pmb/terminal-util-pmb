#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function screen_windowlist () {
  local SESSNAME="$1"; shift
  local DBGLV="${DEBUGLEVEL:-0}"
  case "$SESSNAME" in
    --func:* ) "${SESSNAME#*:}" "$@"; return $?;;
    --parse-dump ) parse_screen_list_dump "$@"; return $?;;
  esac

  local PTY_ROWS=16005
  # You need a few (about five) more lines of pty height than
  # the number of open windows you want to scan.
  # A really high number shouldn't impact performance, because
  # (a) screen jumps to absolute coordinates instead of printing
  #     lots of blank lines, and
  # (b) the scan stops reading as soon as the first list is printed,
  # I've no idea why screen prints the list multiple times anyway.

  local PTY_COLS=767  # sed seems to be limited to (3*256)-1 bytes
  PTY_COLS=256  # should be enough for most users -> prefer performance.

  local IDLE_TIMEOUT_SEC=3
  # The timeout guards against situations in which we won't encounter
  # the end of the first list, or not in the style we expect it.
  # The primary reason for why this could happen is having too small
  # a number of terminal lines (ws_row) above.

  local EXEC="screen -U -p ="
  case "$SESSNAME" in
    --test-pty-size ) EXEC='stty size';;
    '' )  EXEC+=" -xR $*";;
    * )   EXEC+=" -xr $SESSNAME $*";;
  esac
  EXEC="${EXEC//\\/\\\\\\\\}"
  EXEC="${EXEC//,/\\,}"
  EXEC="${EXEC//:/\\:}"
  EXEC+=,pty      # run in PTY
  EXEC+=,ctty     # make it the controlling TTY
  EXEC+=,setsid   # bug? if missing, at least one of the other connected
                  # screens exits (crashes?) as soon as our PTY closes.
  EXEC+=,rawer    # gratuitous PTY option: sounds cool
  EXEC+=,cs8      # gratuitous PTY option: use 8bit characters

  local ENDIAN="$(LANG=C lscpu | sed -nre '
    /^[Bb]yte [Oo]rder:/{s~^[^:]+:\s+([a-z]+) Endian~\L\1\E~ip;q}')"
  case "$ENDIAN" in
    little | big ) ;;
    * ) echo "E: unable to detect your CPU's endianess!" >&2; return 8;;
  esac

  local TIOCSWINSZ=$(( 0x5414 ))  # from /usr/include/asm-generic/ioctls.h
  EXEC+=,ioctl-bin=$TIOCSWINSZ:x
  # data for TIOCSWINSZ:
  EXEC+="$(ushort_hex_le "$PTY_ROWS")"  # ws_row
  EXEC+="$(ushort_hex_le "$PTY_COLS")"  # ws_col
  EXEC+=DEAD    # ws_xpixel, unused
  EXEC+=BEEF    # ws_ypixel, unused

  local SCAN_DURA="-$(date +%s%N)" # bash printf doesn't %N
  local SOCAT_CMD=(
    env --ignore-environment
    TERM=xterm
    LANG=C
    socat
    -T"$IDLE_TIMEOUT_SEC"
    STDOUT
    "EXEC:$EXEC"
    )
  local SCAN_DATA="$(LANG=C "${SOCAT_CMD[@]}" 2> >(
    LANG=C sed -urf <(sedcmd_socat_errors) >&2
    ) | tee -- "${SCREEN_WINLIST_DUMP_RAW:-/dev/null}" \
    | parse_screen_list_dump)"
  SCAN_DURA+=" + $(date +%s%N)"
  let SCAN_DURA="( $SCAN_DURA ) / 1"000'000'

  [ "$DBGLV" -ge 4 ] && echo "D: $FUNCNAME: scan took $SCAN_DURA ms" >&2

  case "$SCAN_DATA" in
    *$'\n\v<list_complete>' )
      echo "${SCAN_DATA%$'\n\v<list_complete>'}"
      return 0;;
  esac
  echo "E: incomplete data:" >&2
  <<<"$SCAN_DATA" LANG=C sed -re '
    s~\v~¡~g
    s~^[0-9]+\t\$\t.*$~000\t…\tdummy~
    ' | uniq --count | LANG=C sed -re '
    s~\t~»\t~g
    s~$~¶~
    s~^\s+1\s~~
    s~^\s+([0-9]+)\s(.*)$~\2   × \1~
    s~^~E:    ~
    ' >&2
  return 4
}


function parse_screen_list_dump () { LANG=C sed -urf <(sedcmd_scan) -- "$@"; }

function ushort_hex_le () {
  local NUM="${1:-0}"
  if [ "$NUM" -ge $(( 0xFFFF )) ]; then
    echo FFFF
  elif [ "$NUM" -ge 1 ]; then
    # convert to hex (big endian, the sane notation):
    printf -v NUM '%04X' "$NUM"
    [ "$ENDIAN" == little ] && NUM="${NUM:2}${NUM:0:2}"
    echo "$NUM"
  else
    echo 0000
  fi
}


function sedcmd_socat_errors () {
  echo '
  /E read\(1, 0x\S+, \S+\): Bad file descriptor$/d
  '
}


function sedcmd_scan () {
  echo '
  1{
    /^[0-9]+\s+[0-9]+\s*$/{
      # First line has nothing but two integers => probably pty size test.
      s~\s+~ lines × ~;s~$~ columns~;q
    }
    d
  }
  /^$/d
  s~\a|\f|\v~~g
  s~\t~ ~g
  s~\x1B\[~\v~g     # https://en.wikipedia.org/wiki/CSI_sequence

  s~\v[0-9;]*m+~~g  # strip color codes
  s~\v[0-9]*A~\v<up>~g
  s~\vH~\v<jump_to_origin>~g
  s~\v[0-9;]+H~\v<jump>~g
  s~\v[0-9]*J~\v<erase>~g

  s~\v<jump>\r~\n~  # window list line terminator
  s~\n$~~ # discard line terminator if there is nothing else.

  s~(\v<jump_to_origin>\v<erase>){2}( +[A-Za-z]+)+~\v<end_of_list>~
  s~^\v<end_of_list>$~W: \
    List is probably incomplete, \
    usually because the scanner pty was too small. \
    Try increase ws_row to add some more lines.~

  s~^ *([0-9]+) ([^\n\v\r]*)     (\S*)(\n|$)~\1\t\3\t\2\4~
  /^[0-9]*\t/s~ +($|\n)~\1~
  s~\n(\v<up>|)\v<end_of_list>\v<jump>\r?$~\n\v<list_complete>~
  s~\v<end_of_list>~\n&~

  s~ {8,}~… …~g
  /\n/{
    s~\s+$~~
    /^W: /s~\n +~~g
    q
  }
  '
}











screen_windowlist "$@"; exit $?
