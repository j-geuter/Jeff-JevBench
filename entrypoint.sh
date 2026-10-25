#!/bin/sh
# Jeff 1.1 for JevBench: jeff-serve with the settings we submit. The JevBench settings are always added last, so they
# win over any other value given; the arguments only choose the model (folder or repo id), host and port.
#   ./entrypoint.sh /model --host 0.0.0.0 --port 8013
# Reasoning when unsure, with the JevBench limits (every decision within 8.5 s); the reasoning settings chosen for
# JevBench for this model (settings/<model name>.json) when there is a file for it; the reasoning step compiled
# (--fast-reasoning auto: a second copy of the base weights when the GPU has room, else the adapter removed inside the
# compiled step); one request at a time.
#   JEFF_FAST_REASONING=off: no compilation (serves about a minute after loading; slower reasoning, so fewer
#   reasonings finish within the 8.5 s).
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
# The compilers (Triton, TorchInductor) write caches and temporary files: use the first writable folder (a container
# may have a read-only root and one scratch folder); cache folders the caller set are kept.
for d in "$TMPDIR" /tmp /scratch "$HOME" /dev/shm; do
  if [ -n "$d" ] && [ -d "$d" ] && [ -w "$d" ] && mkdir -p "$d/jeff-cache" 2>/dev/null; then
    export TMPDIR="$d/jeff-cache" TRITON_CACHE_DIR="${TRITON_CACHE_DIR:-$d/jeff-cache/triton}" \
           TORCHINDUCTOR_CACHE_DIR="${TORCHINDUCTOR_CACHE_DIR:-$d/jeff-cache/inductor}"
    break
  fi
done
exec jeff-serve "$@" --reasoning on --jevbench-limits on --fast-reasoning "${JEFF_FAST_REASONING:-auto}" \
  --reasoning-engine transformers --batching off $config
