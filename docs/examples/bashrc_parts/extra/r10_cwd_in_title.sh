# -*- coding: utf-8, tab-width: 2 -*-

function tmpfunc_bashrc_cwd_in_title () {
  # enhance in interactive sessions only
  [ -n "$PS1" ] || return 0
  [ -n "$TERM" ] || return 0

  # only apply from inside a screen session.
  case "$TERM" in
    screen | screen.* ) ;;
    * ) return 0;;
  esac
  local ENV_WARN=
  [ -n "$STY" ] || ENV_WARN+=', STY'
  [ -n "$WINDOW" ] || ENV_WARN+=', WINDOW'
  if [ -n "$ENV_WARN" ]; then
    ENV_WARN="env var(s) [${ENV_WARN#* }] is/are empty!"
    ENV_WARN="W: Found TERM='$TERM' but $ENV_WARN"
    [ -z "$SUDO_USER" ] || ENV_WARN+=' Did you forget -E in sudo?'
    echo "$ENV_WARN" >&2
    return 2
  fi

  function cd () {
    local CD_ARGS=( "$@" )
    if [ "$#" == 0 ]; then
      [ "$PWD" == "$HOME" ] || echo -n "I: $PWD -> $HOME " >&2
      # ^-- help discern ":/" from ":~/"
      CD_ARGS=( "$HOME" )
    fi
    command cd "${CD_ARGS[@]}"
    local CD_RV=$?
    case "$PWD" in
      "$HOME" )     HSUB='.';;
      "$HOME"/* )   HSUB="${PWD#$HOME/}";;
      * )           HSUB=;;
    esac

    local SET_TITLE=( screen -p "$WINDOW" -X title )
    # ^-- w/o -p, "cd" in a background window would rename the active window.
    [ -n "$SUDO_USER" ] && SET_TITLE=(
      sudo -u "$SUDO_USER" -E "${SET_TITLE[@]}" )
    local SHORT_PWD="$PWD"
    case "$SHORT_PWD" in
      "$HOME" ) SHORT_PWD='~/';;
      "$HOME"/* ) SHORT_PWD="~${SHORT_PWD#$HOME}";;
    esac
    local NEW_TITLE="$USER@${HOSTNAME%%\.*} ${SHELL##*/} $SHORT_PWD"
    [ -n "$debian_chroot" ] && NEW_TITLE="($debian_chroot)$NEW_TITLE"
    # echo "$(date +'%F %T') $$@$WINDOW: $NEW_TITLE" >>"$HOME"/.cdtitle.txt
    [ "${DEBUGLEVEL:-0}" -ge 3 ] && SET_TITLE=( echo "${SET_TITLE[@]}" )
    "${SET_TITLE[@]}" "$NEW_TITLE" 2>/dev/null
    printf '\x1b]0;%s\x07' "$NEW_TITLE"
    return $CD_RV
  }
  cd .
}
tmpfunc_bashrc_cwd_in_title; unset tmpfunc_bashrc_cwd_in_title
