#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-

function pluggable_bashrc_sourcer () {
  local CATEG="$1"; shift
  case "$CATEG" in
    p | r ) ;;
    profile | rc ) CATEG="${CATEG:0:1}";;
    * )
      echo "E: unsupported category '$CATEG', expected 'p' or 'r'" >&2
      return 3;;
  esac

  local ROOT_DIRS=(
    /etc/
    "$HOME"/.config/
    )
  local SUBDIRS=(
    bash/
    )
  local ROOT_DIR= SUBDIR= ITEM= BFN=
  local FILES=()
  for ROOT_DIR in "${ROOT_DIRS[@]}"; do
    for SUBDIR in "${SUBDIRS[@]}"; do
      ITEM="$ROOT_DIR$SUBDIR"
      for ITEM in "$ITEM"*.rcd/"$CATEG"[0-9]*.sh; do
        [ -f "$ITEM" ] || continue
        BFN="$(basename -- "$ITEM")"
        FILES+=( "$BFN"$'\t'"$ITEM" )
      done
    done
  done

  readarray -t FILES < <(printf '%s\n' "${FILES[@]}" \
    | sort --version-sort | cut -sf 2)

  local NICK=
  for ITEM in "${FILES[@]}"; do case "$ITEM" in
    *.inline.sh )
      NICK="$ITEM"
      [[ "$NICK" == "$HOME/"* ]] && NICK="~${NICK:${#HOME}}"
      echo
      echo "# ==---BEGIN---== $NICK ==---== #"
      cat -- "$ITEM"
      echo
      echo "# ==---ENDOF---== $NICK ==---== #"
      echo
      ;;
    * )
      [[ "$ITEM" == "$HOME/"* ]] && ITEM='$HOME'"${ITEM:${#HOME}}"
      echo 'source -- "'"$ITEM"'" --bashrc || return $?'
      ;;
  esac; done
}




pluggable_bashrc_sourcer "$@"; exit $?
