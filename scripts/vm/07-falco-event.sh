#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
marker="${1:?Provide a unique alphanumeric marker}"
[[ "$marker" =~ ^DSO06_SPRINT_[a-f0-9]+$ ]]
echo "UTC=$(date -u +%FT%TZ) marker=$marker"
k exec -it -n frontend deploy/frontend -- sh -c "echo $marker >/dev/null; id; sleep 2"
echo 'Harmless terminal shell completed; inspect Falco and Falcosidekick UI for this marker.'
