#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-


function set_xterm_title () {
  if ! tty --silent; then
    echo "E: $FUNCNAME: expected stdin to be a TTY" >&2
    return 3
  fi

  printf '\x1b]0;%s\x07' "$*" >&0
  # ^-- If this seems to fail, it's usually because the title is (re)set
  #     very soon after we set it.
}


function inner_helper_guess_winid () {
  local PFX_W="W: $FUNCNAME: "
  local WIN_ID=
  [ "$DBGLV" -ge 2 ] && echo "${PFX_W}(@$0) guessing by ppid $PPID" >&2
  if [ -n "${IH_CFG[unreliable_parent]}" ]; then
    [ "$DBGLV" -ge 2 ] && echo "${PFX_W}skip: unreliable parent" >&2
  else
    WIN_ID="$(xdotool search --all --onlyvisible --pid "$PPID" --class .)"
    inner_helper_validate_winid "$WIN_ID" && return 0
  fi

  echo "${PFX_W}falling back to title guessing work-around" >&2
  local TITLE_TAG="==:$$:$UID:$RANDOM:== $(LANG=C ps wwch -o cmd "$PPID")"
  # LANG=C ps wwch -o cmd,pid,uid "$PPID" | tr -s ' \t' :
  set_xterm_title "$TITLE_TAG"
  WIN_ID="$(find_window_id_by_title "$TITLE_TAG")"
  inner_helper_validate_winid "$WIN_ID" && return 0

  echo "${PFX_W}exhausted all known strategies. giving up." >&2
  return 2
}


function find_window_id_by_title () {
  local W_TITLE="$1"
  local W_ID=

  W_ID="$(xwininfo -name "$W_TITLE" \
    | grep -oPe '^xwininfo: Window id: 0x\S+' -m 1)"
  W_ID="${W_ID##* }"
  [ -n "$W_ID" ] && inner_helper_validate_winid "$W_ID" && return 0

  if xdotool version &>/dev/null; then
    W_ID="$(timeout 2s xdotool search --sync --all --onlyvisible
      --name "$W_TITLE")"
    [ -n "$W_ID" ] && inner_helper_validate_winid "$W_ID" && return 0
  fi

  echo "W: $FUNCNAME: exhausted all known strategies. giving up." \
    "maybe there just is no window named '$W_TITLE'." >&2
  return 2
}


function inner_helper_validate_winid () {
  local W_ID="$1"
  case "$W_ID" in
    *$'\n'* )
      [ "$DBGLV" -ge 2 ] && echo "${PFX_W}too many window IDs" >&2;;
    '' )
      [ "$DBGLV" -ge 2 ] && echo "${PFX_W}no window ID" >&2;;
    0x[0-9a-fA-F]* ) echo "$W_ID"; return 0;;
    [0-9]* ) printf '0x%x\n' "$W_ID"; return 0;;
    * )
      echo "${PFX_W}strange window ID '$W_ID' for process $PPID" >&2;;
  esac
  return 2
}










[ "$1" == --lib ] && return 0; "$@"; exit $?
