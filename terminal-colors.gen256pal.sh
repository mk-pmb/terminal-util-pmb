#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function pal_cli_main () {
  local TASK="$1"; shift
  [ -n "$TASK" ] || TASK='first_steps'
  local DEFAULT_ZOOM=25
  pal_"$TASK" "$@" || return $?$(
    echo E: "$0: Task failed (rv=$?): $TASK" >&2)

  # In case we had outfx filters, close stdout explicitly and wait for
  # them to print their output:
  exec 1<&-
  wait
}


function pal_first_steps () {
  echo 'No task given. Maybe try:'
  echo "  $0 ansi_16 view"
  echo "  ZOOM=10 $0 ansi_16 view     # default zoom is $DEFAULT_ZOOM"
  echo "  $0 ansi_256 view"
  echo "  $0 ansi_256 ppm >ansi256.ppm"
  echo "  $0 ansi_6x6_rgb_cube view"
  echo "  $0 ansi_6x6_rgb_cube view prove_greys"
}


function pal_outfx_ () { true; }
function pal_outfx_nofx () { true; }
function pal_outfx_index () { exec > >(nl -ba -v0); }


function pal_outfx_ppm () {
  echo P3
  echo "${PPM_SIZE:-0 0}"
  echo 255
  exec > >(tr , ' ')
}



function pal_outfx_view () {
  exec > >(display -resize "${ZOOM:-$DEFAULT_ZOOM}00%" -filter point ppm:-)
  pal_outfx_ppm
}



function pal_ansi_256 () {
  PPM_SIZE='32 8' pal_outfx_"$1"; shift
  pal_ansi_16
  pal_ansi_6x6_rgb_cube
  pal_greyscale_for_ansi_256
}


function pal_ansi_16 () {
  PPM_SIZE='8 2' pal_outfx_"$1"; shift

  # Unfortunately the ANSI bit flip order is BGR, not RGB, so we cannot just
  # printf -- '%s\n' {0,128},{0,128},{0,128} |
  # … but we can copy strings:
  local ANSI=' '
  ANSI="${ANSI// /0, }${ANSI// /r, }"
  ANSI="${ANSI// /0, }${ANSI// /g, }"
  ANSI="${ANSI// /0 }${ANSI// /b }"
  # Now add the intense versions:
  ANSI+="${ANSI^^}"
  # Drop the 2nd black, move intense black forward by inserting dim white:
  ANSI="${ANSI/ r,g,b 0,0,0 / 192,192,192 r,g,b }"
  ANSI="${ANSI//[rgb]/128}"
  ANSI="${ANSI//[RGB]/255}"
  printf -- '%s\n' $ANSI
}


function pal_ansi_6x6_rgb_cube () {
  # When running as part of pal_ansi_256, black is duplicated here because
  # this is the real RGB black. The black from pal_ansi_16 was "system black"
  # as defined by the user's color theme.

  PPM_SIZE='18 12' pal_outfx_"$1"; shift
  case "$1" in
    prove_greys ) exec > >(sed -re '1~43!s!\S+!255,255,0!');;
  esac
  printf -- '%s\n' {0,{95..255..40}},{0,{95..255..40}},{0,{95..255..40}}
}


function pal_ansi_6x6_rgb_cube__closest_rgb () {
  local C="${FUNCNAME%_*}"_single_channel
  $C "$1"; shift; echo -n ','
  $C "$1"; shift; echo -n ','
  $C "$1"; shift; echo
}


function pal_ansi_6x6_rgb_cube__closest_single_channel () {
  local ORIG="$1"
  local BEST=0 STEP=40 AVAIL= THRESH=
  for AVAIL in $(echo {95..255..$STEP}); do
    (( THRESH = AVAIL - (STEP / 2) ))
    [ "$ORIG" -lt $THRESH ] || BEST=$AVAIL
  done
  echo -n $BEST
}


function pal_greyscale_for_ansi_256 () {
  PPM_SIZE='24 1' pal_outfx_"$1"; shift
  # NB: Some terminal emulators use 231 as the last brightness value.
  #     My GNOME Terminal screenshot says it's 238.
  printf -- '%s,%s,%s\n' {8..238..10}{,,}
}











pal_cli_main "$@"; exit $?
