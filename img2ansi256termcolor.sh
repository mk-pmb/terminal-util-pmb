#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function img2ansi256_cli_init () {
  export LANG{,UAGE}=en_US.UTF-8  # make error messages search engine-friendly

  local -A CFG=(
    [bgcolor]='black'
    [dither]='FloydSteinberg'
    [renderer]='double_space'
    )

  local KEY= VAL=
  while [ "$#" -ge 1 ]; do
    case "$1" in
      '' ) continue;;
      - ) break;; # read from stdin
      -* ) ;;
      * ) break;;
    esac
    VAL="$1"; shift
    KEY=
    case "$VAL" in
      -B ) KEY='bgcolor';;
    esac
    if [ -n "$KEY" ]; then CFG["$KEY"]="$1"; shift; continue; fi
    case "$VAL" in
      -- ) break;;

      --numbers | \
      --half-block | \
      --double-space | \
      -- ) VAL="${VAL#--}"; VAL="--renderer=${VAL//-/_}";;
    esac
    case "$VAL" in
      --example )
        exec <'/usr/share/icons/gnome/22x22/categories/package_graphics.png';;

      --bgcolor=* | \
      --renderer=* | \
      - ) VAL="${VAL#--}"; CFG["${VAL%%=*}"]="${VAL#*=}";;

      -* ) echo E: $FUNCNAME: "Unsupported CLI option: $VAL" >&2; return 4;;
    esac
  done

  [ "$#" -ge 1 ] || set -- -
  [ "$1" == - ] || exec <"$1" || return $?$(
    echo E: $FUNCNAME: "Unable to open input image: $1" >&2)
  shift
  [ "$#" == 0 ] || return 4$(
    echo E: $FUNCNAME: "Unexpected superfluous argument: $1" >&2)

  # The original idea was to generate the ANSI 256 terminal color palette
  # as a 256x1 pixel PPM, have ImageMagick map the input image to palette
  # index numbers, then generate color control codes based on the indexes.
  #
  # The first 16 colors would be affected by the user's color theme,
  # thus unreliable, but we can just black them out; that way, ImageMagick
  # will always map black as index 0, which we can later remap to the
  # real RGB black at index 16.

  local ANSI_256_PAL_CSV="$(
    yes 0,0,0 | head --lines=16
    # Next up, the 6x6 RGB color cube, starting with the real black.
    printf -- '%s\n' {0,{95..255..40}},{0,{95..255..40}},{0,{95..255..40}}
    # Now the grey ramp.
    printf -- '%s,%s,%s\n' {8..238..10}{,,} # GNOME Terminal uses 238 as max.
    )"
  local ANSI_256_PAL_PPM=$'P3\n256 1\n255\n'"${ANSI_256_PAL_CSV//,/ }"

  exec < <(convert - -background "${CFG[bgcolor]}" -alpha remove -flatten \
    -dither "${CFG[dither]}" -remap <(echo "$ANSI_256_PAL_PPM") \
    -compress none ppm:-)

  # Unfortunately, Ubuntu focal's old ImageMagick v6 cannot preserve palette
  # entry order, so we can't just map index numbers to ANSI color numbers.
  # At least it can pick the correct colors and dither, but we then have to
  # convert those RGB pixels, so we better build a reverse dictionary:

  eval local -A ANSI_256_PAL_REV=( $( echo "$ANSI_256_PAL_CSV" |
    nl -ba -v0 -w1 | sed -nre 's!^(\S+)\t(\S+)$![\2]=\1!p'
    ) )

  exec < <(img2ansi256_read_matrix)
  img2ansi256_"${CFG[renderer]}"
}


function img2ansi256_read_matrix () {
  set -- $(grep -Pe '^\w' | tr -cd 'A-Za-z0-9 \n')
  [ "$1:$4" == P3:255 ] || return 4$(
    echo E: 'Expected P3 ascii PPM format with 8-bit RGB pixels!' >&2)
  local W="$2" H="$3" X=0 Y=0 PIXEL= COLOR=
  shift 4
  while [ "$#" -ge 3 ]; do
    PIXEL="$1,$2,$3"; shift 3
    COLOR="${ANSI_256_PAL_REV[$PIXEL]}"
    [ -n "$COLOR" ] || return 4$(
      echo E: "Unexpected color $PIXEL @ $X:$Y!" >&2)
    (( X += 1 ))
    echo -n "$COLOR "
    [ "$X" -ge "$W" ] || continue
    X=0
    (( Y += 1 ))
    echo
  done
}


function img2ansi256_numbers () { cat; }


function img2ansi256_double_space () {
  LANG=C sed -re 's!\S+!\x1B[48;5;&m !g;s!$!\x1B[0m!'
}


function img2ansi256_half_height_pairs () {
  local UPPER= LOWER= FGC= BGC=
  while IFS= read -r UPPER; do
    LOWER=
    IFS= read -r LOWER || true
    LOWER+=' '
    for FGC in $UPPER; do
      BGC="${LOWER%% *}"
      LOWER="${LOWER#* }"
      echo -n "$FGC,$BGC "
    done
    echo
  done
}


function img2ansi256_half_block () {
  img2ansi256_half_height_pairs | tr , ' ' |
    LANG=C sed -re 's!(\S+) (\S+) !\x1B[38;5;\1;48;5;\2m▀!g;s!$!\x1B[0m!'
}










img2ansi256_cli_init "$@"; exit $?
