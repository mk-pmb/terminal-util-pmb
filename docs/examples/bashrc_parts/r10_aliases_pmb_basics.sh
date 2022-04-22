# -*- coding: utf-8, tab-width: 2 -*-

if ls --help |& grep -qFe '--format='; then
  # We have a proper ls that supports long options
  alias l="ls$(echo '
    --color=auto
    --file-type
    --format=across
    --human-readable
    --group-directories-first
    ' | tr -s ' \n' ' ')"
  alias l1='l -1'
  alias ll='l --format=long'
  alias la='l --almost-all'
else
  # Probably busybox
  alias l="ls$(echo '
    --color=auto
    -F
    -h
    --group-directories-first
    ' | tr -s ' \n' ' ')"
  alias l1='l -1'
  alias ll='l -l'
  alias la='l -A'
fi

alias grep='grep --color=auto'

alias Q=exit

alias less='less --tilde --RAW-CONTROL-CHARS --chop-long-lines'
alias nano='nano --nowrap'
alias ssh='TERM=xterm-color ssh'

alias cronedit='crontab -e'     # <-- never again mistype -r
alias cronlist='crontab -l'
