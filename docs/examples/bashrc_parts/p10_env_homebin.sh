# -*- coding: utf-8, tab-width: 2 -*-
local SUB='
  .local/bin
  bin
  '
PATH=":${PATH//:/::}:"
for SUB in $SUB; do
  SUB="$HOME/$SUB"
  [ -d "$SUB" ] || continue
  PATH=":$SUB:${PATH//:$SUB:/}"
done
PATH="${PATH//::/:}"
PATH="${PATH#:}"
PATH="${PATH%:}"
export PATH
