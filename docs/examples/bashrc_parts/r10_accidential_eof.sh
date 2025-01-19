# -*- coding: utf-8, tab-width: 2 -*-

IGNOREEOF=15
# Number of consecutive EOF (Ctrl+d) characters that bash can receive and
# ignore before the next one makes it give up reading stdin and quit.
# Thus, you have to type Ctrl+d $(( IGNOREEOF + 1 )) times to quit the shell
# this way. This helps avoid the shell closing by accident when you actually
# just wanted to end the command's input.
