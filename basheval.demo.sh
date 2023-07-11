#!./basheval.sh false | grep --color=always -HnFe "$KW" -- "$@"; echo W: See the length limit warning in basheval.sh! >&2 0123456789

This is a demo script for `sheval.sh`.
It's meant to be run with the environment variable KW set to
some keyword from this file so grep would search for that.

Example: KW=ample ./basheval.demo.sh
