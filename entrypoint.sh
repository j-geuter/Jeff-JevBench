#!/bin/sh
# Jeff 1.1 for JevBench: jeff-serve with the settings we submit. The JevBench settings are always added last, so they
# win over any other value given; the arguments only choose the model (folder or repo id), host and port.
#   ./entrypoint.sh /model --host 0.0.0.0 --port 8013
# Reasoning when unsure, with the JevBench limits (every decision within 9 s); the reasoning settings chosen for
# JevBench for this model (settings/<model name>.json) when there is a file for it; a second copy of the base weights
# for faster reasoning when the GPU has room for it (--fast-reasoning); one request at a time.
set -e
if [ "$#" -eq 0 ]; then
  set -- /model --host 0.0.0.0 --port 8013
fi
if [ -f "$1/jeff_config.json" ]; then
  name=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1])).get("name", ""))' "$1/jeff_config.json")
else
  name=$(basename "$1")
fi
settings="$(dirname "$0")/settings/$name.json"
config=""
if [ -n "$name" ] && [ -f "$settings" ]; then
  config="--reasoning-config $settings"
fi
exec jeff-serve "$@" --reasoning on --jevbench-limits on --fast-reasoning --reasoning-engine transformers --batching off $config
