#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
stage="${1:?Usage: 06-scan.sh before|after}"
[[ "$stage" == before || "$stage" == after ]]
mkdir -p private
if [[ "$stage" == after ]]; then
 for ns in frontend backend; do
  k rollout status deployment/"$ns" -n "$ns" --timeout=120s
  for rs in $(k get rs -n "$ns" -l app="$ns" -o json | python3 -c 'import json,sys;print(" ".join(r["metadata"]["name"] for r in json.load(sys.stdin)["items"] if r["spec"].get("replicas",0)==0 and r.get("status",{}).get("replicas",0)==0 and any(o["kind"]=="Deployment" and o["name"]==sys.argv[1] for o in r["metadata"].get("ownerReferences",[]))))' "$ns"); do
   k delete rs "$rs" -n "$ns" --wait=true --timeout=90s
  done
 done
 k apply --dry-run=server -f manifests/vm/secure/
fi
echo "UTC=$(date -u +%FT%TZ) Context=$KUBECTL_CONTEXT"
sha256sum policies/nsa-policy.json policies/controls-inputs.json policies/exceptions.json
bin/kubescape scan framework nsa --kube-context "$KUBECTL_CONTEXT" --keep-local --host-scan=false --use-from policies/nsa-policy.json --controls-config policies/controls-inputs.json --exceptions policies/exceptions.json --fail-on-degraded-config --cache-dir private/cache --format json --output "private/kubescape-$stage.json"
