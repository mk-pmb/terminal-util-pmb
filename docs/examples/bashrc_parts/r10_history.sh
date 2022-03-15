# -*- coding: utf-8, tab-width: 2 -*-

# append to the history file, don't overwrite it
shopt -s histappend
HISTCONTROL=ignorespace:erasedups
HISTSIZE=20

# disable exclamation mark magic
set +o histexpand
