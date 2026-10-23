#!/bin/sh
# Jeff 1.1 for JevBench: jeff-serve with the settings we submit. The JevBench settings are always added last, so they
# win over any other value given; the arguments only choose the model (folder or repo id), host and port.
#   ./entrypoint.sh /model --host 0.0.0.0 --port 8013
set -e
if [ "$#" -eq 0 ]; then
  set -- /model --host 0.0.0.0 --port 8013
fi
exec jeff-serve "$@" --reasoning on --jevbench-limits on
