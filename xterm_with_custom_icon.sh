#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function xterm_with_custom_icon () {
  local SELFPATH="$(readlink -f -- "$BASH_SOURCE"/..)"
  local PROGNAME="$FUNCNAME"
  local XT=()
  local WRAP_EXEC=()

  local DBGLV="${DEBUGLEVEL:-0}"
  # [ "$DBGLV" -ge 2 ] || XT+=( gtame )

  XT+=(
    xterm
    -u8     # UTF-8 mode
    -lc     # use locale from env
    -b 2    # inner window padding = 2px
    +bc     # steady text cursor (i.e. not blinking)
    -fs 15  # font size
    -mesg   # disable write access to terminal (local user chat)
    -sb     # enable scrollbar
    -rightbar   # scrollbar should be on the right side
    -s      # allow async/lazy screen updates while scrolling
    -si     # do NOT auto-scroll on new output.
    -sk     # scroll to bottom on key press.
    -sl 512 # scroll buffer length in lines
    +uc     # cursor is a full block.
    -vb     # prefer visual bell over audible
    -wf     # start child process only after window is positioned
    -bg black     # background color
    -fg grey      # text color
    )

  local OPT=
  while [ "$#" -ge 1 ]; do
    OPT="$1"; shift
    case "$OPT" in
      -- ) break;;

      --icon-file=* ) opt_icon_file "${OPT#*=}" || return $?;;
      --wrap-exec+=* ) WRAP_EXEC+=( "${OPT#*=}" );;

      -hold | \
      -iconic | \
      -- )
        XT+=( "$OPT" );;

      --write-pid-file=* )
        echo "$$" >"${OPT#*=}" || return $?;;

      --title-and-class=* )
        OPT="${OPT#*=}"
        XT+=(
          -title "$OPT"
          -class "${OPT//[^A-Za-z0-9_.]/-}"
        );;

      -class | \
      -fs | \
      -geometry | \
      -name | \
      -title | \
      -- )
        XT+=( "$OPT" "$1" )
        shift;;

      -e )
        XT+=( "$OPT" "${WRAP_EXEC[@]}" )
        WRAP_EXEC=()
        break;;

      * | \
      -- )
        XT+=( "$OPT" )
        break;;
    esac
  done

  [ "$DBGLV" -lt 2 ] || echo "D: $PROGNAME: run:$(
    printf -- ' ‹%s›' "${XT[@]}")" >&2
  exec "${XT[@]}" "$@" || return $?
}


function opt_icon_file () {
  local IMG="$1"
  local XPM=

  case "$IMG" in
    *.xpm | *.xbm ) XPM="$IMG";;

    * )
      local CKS="$(sha1sum --binary -- "$IMG")"
      CKS="${CKS%%[ \*]*}"
      [ -n "$CKS" ] || return 3$(
        echo "E: $PROGNAME: Failed to calculate checksum" >&2)
      XPM="$HOME/.cache/img2xpm/${CKS:0:2}"
      mkdir --parents -- "$XPM"
      XPM+="/${CKS:2}.xpm"
      local CONV=( convert "$IMG" xpm:"$XPM" )
      [ -f "$XPM" ] || "${CONV[@]}" || return $?$(
        echo "E: $PROGNAME: Failed (rv=$?) to ${CONV[*]}" >&2)
      ;;

  esac

  [ -f "$XPM" ] || return $?$(
    echo "E: $PROGNAME: Icon file does not exist: $XPM" >&2)
  XT+=( -xrm "xterm*iconHint: $XPM" )
}











xterm_with_custom_icon "$@"; exit $?
