#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
# Output format: 'wn ' $win_num \t 'fl ' $win_flags \t 'wt ' $win_title


function screen_windowlist () {
  local SESSNAME="$1"; shift
  local DBGLV="${DEBUGLEVEL:-0}"
  case "$SESSNAME" in
    --func:* ) "${SESSNAME#*:}" "$@"; return $?;;
    --parse-dump ) parse_screen_list_dump "$@"; return $?;;
  esac

  local SESSLIST='1{/^[A-Za-z ]+:$/d}; $s~^([0-9]+) [Ssocket].*$~\t\1~'
  SESSLIST="$(LANG=C screen -list |
    grep -Pe '\S' | # <- On Ubuntu focal, screen prints a trailing blank line.
    sed -re "$SESSLIST" | cut -sf 2)"
  local SESS_CNT="${SESSLIST##*$'\n'}"
  SESSLIST="${SESSLIST%$'\n'*}"
  case "$SESS_CNT" in
    *[^0-9]* ) SESS_CNT=;;
    1 )
      SESSLIST="${SESSLIST#[0-9]*.}"
      [ -z "$SESSNAME" ] || [ "$SESSNAME" == "$SESSLIST" ] || return 4$(
        echo E: "No such screen session '$SESSNAME', only '$SESSLIST'." >&2);;
    [1-9]* )
      if [ -z "$SESSNAME" ]; then
        SESSLIST="$(echo "$SESSLIST" | sort -V)"
        SESSLIST="${SESSLIST//$'\n'/ }"
        echo E: "Multiple screen sessions, you need to choose: $SESSLIST" >&2
        return 4
      fi;;
  esac
  [ -n "$SESS_CNT" ] || return 4$(
    echo E: 'Failed to count screen sessions!' >&2)

  local PTY_ROWS=16005
  # You need a few (about five) more lines of pty height than
  # the number of open windows you want to scan.
  # A really high number shouldn't impact performance, because
  # (a) screen jumps to absolute coordinates instead of printing
  #     lots of blank lines, and
  # (b) the scan stops reading as soon as the first list is printed.
  # I have no idea why screen prints the list multiple times anyway.

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
    ) | parse_screen_list_dump)"
  SCAN_DURA+=" + $(date +%s%N)" # nanoseconds / 1e6 = milliseconds
  let SCAN_DURA="( $SCAN_DURA ) / 1"000'000'

  [ "$DBGLV" -ge 4 ] && echo "D: $FUNCNAME: scan took $SCAN_DURA ms" >&2

  case "$SCAN_DATA" in
    $'\v<start_list>\n'*$'\n\v<list_complete>' )
      SCAN_DATA="${SCAN_DATA#*$'\n'}"
      SCAN_DATA="${SCAN_DATA%$'\n'*}"
      echo "$SCAN_DATA"
      return 0;;
  esac
  echo "E: incomplete data:" >&2
  echo "$SCAN_DATA" | LANG=C sed -re '
    s~\v~¡~g
    s~^[0-9]+\t\$\t.*$~000\t…\tdummy~
    ' | uniq --count | LANG=C sed -re '
    s~\t~»\t~g
    s~$~¶~
    s~^\s+1\s~~
    s~^\s+([0-9]+)\s(.*)$~\2   × \1~
    s~^~E:    ~
    ' >&2
  echo "H: Set SCREEN_WINLIST_DUMP_RAW to a filename to dumo raw input." >&2
  return 4
}


function parse_screen_list_dump () {
  local DUMP="$SCREEN_WINLIST_DUMP_RAW:"
  [ "$DUMP" != : ] || DUMP='/dev/null'
  tee -- "${DUMP/%:/.raw}" |
    parse_screen_list_dump_stage1 | tee -- "${DUMP/%:/.st1}" |
    parse_screen_list_dump_stage2 | tee -- "${DUMP/%:/.st2}"
}


function sedcmd_socat_errors () {
  echo '
  /E read\(1, 0x\S+, \S+\): Bad file descriptor$/d
  '
}


function parse_screen_list_dump_stage1 () {
  uniq -c -- "$@" | LANG=C sed -rf <(echo '
    s~\t~ ~g
    s~\a|\f|\v~~g
    s~\x1B\[~\v~g

    s~\v[0-9;]*m+~~g  # strip color codes
    s~\v[0-9]*A~\v<up>~g
    s~\vH~\v<jump_to_origin>~g
    s~\v[0-9;]+H~\v<jump>~g
    s~\v[0-9]*J~\v<erase>~g
    s!(\v<jump>\r)+!\n!g  # window list line terminator
    s~\r~\v<cr>~g

    s~^ *[1-9][0-9]{2,} \v0?K$|$\
      ^-- i.e. at least 100 blank lines, usually a few less than $PTY_ROWS \
      ~\v<clear_screen>~
    s~^ +1 +([0-9]+) ~\v<win \1 > ~
    s~^ +1 ($|\v)~\1~
    s~\v0?K~\v<clear_right>~g

    1{
      s~\v1;[1-9][0-9]{2,}r(\v<jump_to_origin>\v<erase>|$\
        )~\v<-clear_very_many_lines>\n\v<clear_very_many_lines->~
    }
    : col_heads
      s~(\v<\S+>) +Num +Name {100,}Flags($|\n)~\1\v<col_heads>~g
    t col_heads
    s!(\v<col_heads>)+!\1!g
    s~(\v<jump_to_origin>\v<erase>|\v<clear_right>|$\
      )+(\v<col_heads>)~\2~g
    s~ {50,}~\v<wide_space>~g
    ') | LANG=C sed -re '/^$/d;1{/<-clear_very_many_lines>$/d}' |
    sed -re '/^\v<win /s~$~\v</win>~' |
    sed -zre 's~(\v</win>)\n~\n\1~g;s~\n\v</win>(\v<win )~\n\1~g'
}


function parse_screen_list_dump_stage2 () {
  LANG=C sed -zrf <(echo '
    # Remove noise before and after clear_screen:
    s!(\n|\v<erase>|\v<clear_right>|\v<jump_to_origin>|$\
      )*(\v<clear_screen>)(\v<clear_screen>|$\
      |\n|\v<erase>|\v<clear_right>|\v<jump_to_origin>)*!\n\2\n!g

    # Detect list start:
    s!^\v<clear_very_many_lines->\n?(\v<clear_screen>|$\
      |)\n?\v<col_heads>!\v<start_list>!
    s!\n\v</win>\n?(\v<clear_screen>|$\
      |)\n?\v<col_heads>\n!\n\v<list_complete>\n!
    ') | LANG=C sed -rf <(echo '
    s~^[^\v]~unsupported\t&~
    /^\v<win /{
      s~\v<wide_space>+(\S*)$~\n\1~
      s~^\v<win (\S+) > ([^\v\n]*)\n(\S*)$~wn \1\tfl \3\twt \2~
    }
    /^\v<maybe_repeat_list>$/N
    s!^\v<maybe_repeat_list>\n\v<(start_list>)$!\v<re\1!
    /^\v<restart_list>$/q
    /^\v<list_complete>$/q
    ')
}


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











screen_windowlist "$@"; exit $?
