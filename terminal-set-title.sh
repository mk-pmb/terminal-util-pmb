#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
#  set_terminal_title - Set the title for xterm or compatible terminals.
#  Copyright (C) 2016  mk-pmb,  License: ISC
#


function set_terminal_title () {
  # FAQ "How to change the title of an xterm":
  # http://www.faqs.org/docs/Linux-mini/Xterm-Title.html

  # [removed:] attempts to warn about PS1 and PROMPT_COMMAND,
  # but they aren't exported to programs running in the shell.

  local TTY_FD=
  for TTY_FD in 0 1 2 ''; do
    tty --silent <&$TTY_FD && break
  done
  [ -z "$TTY_FD" ] || printf '\x1b]0;%s\x07' "$*" >&"$TTY_FD"; exit $?
}


[ "$1" == --lib ] && return 0; set_terminal_title "$@"; exit $?
