#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function terminal_colors () {
  echo
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

  draw_basic_colors_chart

  echo
  echo '256 color (8 bit) palette: [38;5;…m = text, [48;5;…m = background'
  draw_8bit_palette
}


function draw_basic_colors_chart () {
  local TX_DF= BG_DF= TX_CC= BG_CC=
  local COLWIDTH=8 HUE= MARKED_HUE= LABEL=
  set -- $(echo '
    3%  40
    9%  40
    97  4%
    30  10%
    ')
  while [ "$#" -ge 1 ]; do
    TX_DF="$1"; shift
    BG_DF="$1"; shift
    for HUE in {0..7}; do
      # MARKED_HUE="$HUE"
      # MARKED_HUE="$(unicode_circled_digit "$HUE") "
      MARKED_HUE="$(unicode_parenthesized_digit "$HUE") "
      TX_CC="$TX_DF"
      BG_CC="$BG_DF"
      case "$TX_CC,$BG_CC,$HUE" in
        # Improve readability in edge cases:
        [39]%,40,0 )  BG_CC=47;;
        30,10%,[01] ) TX_CC=97;;
        97,4%,7 )     TX_CC=30;;
      esac
      LABEL="$(printf -- '% 3s×%- 3s' "$TX_CC" "$BG_CC")"
      TX_CC="$TX_CC;$BG_CC"
      TX_CC="${TX_CC//%/$HUE}"
      rcell "$TX_CC" "${LABEL//%/$MARKED_HUE}"
    done
  echo
  done
}


function esc_seq_cell () { echo -ne "\x1b$1"; }


function rcell () {
  local COLORS="$1"; shift
  local TEXT="${1:-$COLORS}"; shift
  TEXT="${TEXT//%/$COLORS}"
  echo -n '  '
  [ -n "$COLORS" ] && printf '\x1b[%sm' "$COLORS"
  echo -n "                         $TEXT" | LANG=C sed -re '
    s~^.*(([\x00-\x7F]|[\x80-\xFF]{2,3}){'"$COLWIDTH"'})$~\1~
    #s~(×)10(\S+)~\1\xE2\x8F\xA8\2 ~g
    '
  [ -n "$COLORS" ] && printf '\x1b[%sm' 0
}


function unicode_small_digit () {
  # U+2080  subscript zero          = E2 82 80
  # U+2089  subscript nine          = E2 82 89
  # U+23e8  decimal exponent symbol = E2 8F A8   # a small subscript 10
  echo -ne '\xE2\x82\x8'"$1"
}


function unicode_circled_digit () {
  # U+24ea  circled digit zero  = E2 93 AA
  # U+2460  circled digit one   = E2 91 A0
  # U+2468  circled digit nine  = E2 91 A8
  case "$1" in
    0 ) echo -ne '\xE2\x93\xAA';;
    [1-9] ) echo -ne '\xE2\x91\xA'$(( "$1" - 1 ));;
  esac
}


function unicode_parenthesized_digit () {
  # U+24AA  parenthesized latin small letter o    = E2 92 AA
  # U+2474  parenthesized digit one               = E2 91 B4
  # U+247c  parenthesized digit nine              = E2 91 BC
  case "$1" in
    0 ) echo -ne '\xE2\x92\xAA';;
    [1-6] ) echo -ne '\xE2\x91\xB'$(( "$1" + 3 ));;
    7 ) echo -ne '\xE2\x91\xBA';;
    8 ) echo -ne '\xE2\x91\xBB';;
    9 ) echo -ne '\xE2\x91\xBC';;
  esac
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
