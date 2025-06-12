# -*- coding: utf-8, tab-width: 2 -*-

PS1='\u@\h:\w\$ '

case "$TERM" in
  xterm-color | \
  screen | screen.* | \
  __color-capable__ )
    PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    ;;
esac

[ -z "$debian_chroot" ] || PS1="$($debian_chroot)$PS1"

if dircolors --version &>/dev/null; then
  eval "$(dircolors -b)"
  [ ! -r ~/.dircolors ] || eval "$(dircolors -b ~/.dircolors)"
fi
