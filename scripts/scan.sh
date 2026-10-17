#!/bin/bash
source "$(dirname "$0")/env.sh"
stage="${1:?Usage: scan.sh before|after}"
[[ "$stage" == before || "$stage" == after ]] || exit 2
mkdir -p .local/kubescape-cache
if [[ ! -s "$PWD/.local/kubescape-cache/nsa.json" && -s screenshots/evidence/nsa-policy.json ]]; then
 cp screenshots/evidence/nsa-policy.json .local/kubescape-cache/nsa.json
fi
policy_args=()
if [[ -s "$PWD/.local/kubescape-cache/nsa.json" ]]; then policy_args=(--use-from "$PWD/.local/kubescape-cache/nsa.json"); fi
kubescape scan framework nsa --kube-context "$KUBECTL_CONTEXT" --keep-local --host-scan=false --cache-dir "$PWD/.local/kubescape-cache" "${policy_args[@]}" --format json --output "$PWD/.local/kubescape-$stage.raw.json" > "screenshots/evidence/kubescape-$stage.log" 2>&1
# Only fictitious lab secrets exist in this dedicated cluster. Redact Secret payloads before evidence export.
python3 scripts/redact-scan.py "$stage"
