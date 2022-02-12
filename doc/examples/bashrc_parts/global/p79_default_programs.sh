# -*- coding: utf-8, tab-width: 2 -*-
eval "$(echo '

EDITOR=nano
VISUAL=nano
GIT_SSH=gitutil-ssh-helper
GIT_PROXY_COMMAND=gitutil-proxy-helper

' | sed -nre '

s~^ *([^=]+)=(\S+)$~[ -n "\$\1" ] || \\\
  [ ! -x "$(which \2 2>/dev/null)" ] || \\\
  export \1=\2~p

')"
