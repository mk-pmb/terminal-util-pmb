#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function terminal_colors () {
  local COLWIDTH=10
  rcell '1'   '[%m = bold'
  rcell '2'   '[%m = dim '
  COLWIDTH=20
  rcell '7'   ' [%m = reverse   '
  rcell '1;7' ' [%m = rev+bold  '
  rcell '2;7' ' [%m = rev+dim   '
  echo
  echo '   30+ = text color, +40 = background,' \
    '90+ = slim bright, 100+ = bright background:'

  COLWIDTH=8
  local ROWS=(
    # :
    3%x40
    9%x40
    97x4%
    30x10%
    )
  local ROW= HUE=
  local BGC= FGC=
  local MARKED_HUE=
  local LABEL=
  for ROW in "${ROWS[@]}"; do
    case "$ROW" in
    : ) FGC=0; BGC=7; LABEL='___________________%_';;
    *x* )
      FGC="${ROW%%x*}"; BGC="${ROW##*x}"
      LABEL="$(printf '% 3s×%- 3s' "$FGC" "$BGC")";;
    * ) FGC=0; BGC=0; LABEL="$ROW";;
    esac
    for HUE in {0..7}; do
      case "$ROW" in
      : ) MARKED_HUE="$HUE";;
      * )
        # MARKED_HUE="$HUE"
        # MARKED_HUE="$(echo -n "$HUE" | circled_numbers) "
        MARKED_HUE="$(echo -n "$HUE" | parenthesized_numbers) "
        ;;
      esac
      rcell "${FGC//%/$HUE};${BGC//%/$HUE}" "${LABEL//%/$MARKED_HUE}"
    done
    echo
  done

  echo
  echo '256 color (8 bit) palette: [38;5;…m = text, [48;5;…m = background'
  COLWIDTH= draw_8bit_palette
}


function esc_seq_cell () { echo -ne "\x1b$1"; }


function rcell () {
  local COLORS="$1"; shift
  local TEXT="${1:-$COLORS}"; shift
  TEXT="${TEXT//%/$COLORS}"
  echo -n '  '
  [ -n "$COLORS" ] && printf '\x1b[%sm' "$COLORS"
  <<<"                         $TEXT" tr -d '\n' | LANG=C sed -re '
    s~^.*(([\x00-\x7F]|[\x80-\xFF]{2,3}){'"$COLWIDTH"'})$~\1~
    #s~(×)10(\S+)~\1\xE2\x8F\xA8\2 ~g
    '
  [ -n "$COLORS" ] && printf '\x1b[%sm' 0
}


function small_numbers () {
  # subscript zero          = U+2080 = C-hex: E2 82 80 = oct: 342 202 200
  # subscript nine          = U+2089 = C-hex: E2 82 89 = oct: 342 202 211
  # decimal exponent symbol = U+23e8 = C-hex: E2 8F A8 = oct: 342 217 250
  #   ^-- a small subscript 10
  LANG=C tr '0-9' '\200-\211' | LANG=C sed -re 's~[\x80-\x89]~\xE2\x82&~g'
}


function circled_numbers () {
  # circled digit zero = U+24ea = C-hex: E2 93 AA = oct: 342 223 252
  # circled digit one  = U+2460 = C-hex: E2 91 A0 = oct: 342 221 240
  # circled digit nine = U+2468 = C-hex: E2 91 A8 = oct: 342 221 250
  LANG=C tr '1-9' '\240-\250' | LANG=C sed -re '
    s~[\xA0-\xA8]~\xE2\x91&~g; s~0~\xE2\x93\xAA~g'
}


function parenthesized_numbers () {
  # circled latin small o    = U+24de = C-hex: E2 93 9E = oct: 342 223 236
  # parenthesized digit one  = U+2474 = C-hex: E2 91 B4 = oct: 342 221 264
  # parenthesized digit nine = U+247c = C-hex: E2 91 BC = oct: 342 221 274
  LANG=C tr '1-9' '\264-\274' | LANG=C sed -re '
    s~[\xB4-\xBC]~\xE2\x91&~g; s~0~\xE2\x93\x9E~g'
}


function draw_8bit_palette () {
  local COLS="${1:-32}"
  local COLOR= FMT='%- 4s'
  echo -n '      '
  for COLOR in $(seq 0 $(( COLS - 1 )) ); do
    printf "$FMT" "+$COLOR"
  done
  for COLOR in $(seq 0 255); do
    if [ $(( COLOR % 32 )) == 0 ]; then
      [ "$COLOR" == 0 ] || echo -n $'\x1b[0m'
      echo
      printf "% 3u+… " "$COLOR"
    fi
    printf "\x1b[48;5;%sm$FMT" "$COLOR" ''
  done
  echo $'\x1b[0m'
}

















terminal_colors "$@"; exit $?
