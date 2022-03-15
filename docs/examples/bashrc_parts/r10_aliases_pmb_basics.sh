# -*- coding: utf-8, tab-width: 2 -*-

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

alias grep='grep --color=auto'

alias Q=exit

alias less='less --tilde --RAW-CONTROL-CHARS --chop-long-lines'
alias nano='nano --nowrap'
alias ssh='TERM=xterm-color ssh'

alias cronedit='crontab -e'     # <-- never again mistype -r
alias cronlist='crontab -l'
