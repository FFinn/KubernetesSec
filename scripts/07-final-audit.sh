#!/bin/bash
source "$(dirname "$0")/env.sh"
# Delete only inactive revisions owned by this lab's Deployments.
for ns in frontend backend; do
 for rs in $(k get rs -n "$ns" -l "app=$ns" -o json | python3 -c 'import json,sys;print(" ".join(x["metadata"]["name"] for x in json.load(sys.stdin)["items"] if x["spec"].get("replicas",0)==0 and any(o["kind"]=="Deployment" and o["name"]==sys.argv[1] for o in x["metadata"].get("ownerReferences",[]))))' "$ns"); do
  k delete rs "$rs" -n "$ns" --wait=true --timeout=120s
 done
 for pod in $(k get pods -n "$ns" -l "app=$ns" -o json | python3 -c 'import json,sys;print(" ".join(x["metadata"]["name"] for x in json.load(sys.stdin)["items"] if x["metadata"].get("deletionTimestamp")))'); do
  k wait -n "$ns" --for=delete pod/"$pod" --timeout=120s
 done
done
scripts/audit-jsonpath.sh
for ns in frontend backend; do
 k exec -n "$ns" deploy/"$ns" -- sh -c 'test -n "$DB_USERNAME" && test -n "$DB_PASSWORD" && echo "Secret env present; values suppressed"'
done
k get pods -A -o wide
