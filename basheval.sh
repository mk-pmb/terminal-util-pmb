#!/bin/bash
# -*- coding: utf-8, tab-width: 2 -*-
#
#   In shebang scripts, all interpreter arguments in the shebang line are
#   passed to the interpreter as one single argument. However, sometimes
#   you'd prefer to pass multiple arguments, or even be able to use
#   environment variables. This script helps make it happen.
#
#   !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !!
#   !!                                                                !!
#   !!  Warning: Maximum length limit!                                !!
#   !!                                                                !!
#   !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !! !!
#
#   * There seems to be a limit of 127 bytes for the entire line.
#     The remainder will be silently discarded. This cut-off affects
#     the part that, as described above, will be passed as the first
#     argument that is passed to the interpreter. Potential additional
#     arguments, i.e. CLI arguments to the shebang file invocation,
#     are not affected.
#
#
eval "shift; $*"; exit $?
