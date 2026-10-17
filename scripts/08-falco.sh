#!/bin/bash
source "$(dirname "$0")/env.sh"
helm upgrade --install devsecops-falco falco --repo https://falcosecurity.github.io/charts --version 9.2.0 --namespace falco --create-namespace --kube-context "$KUBECTL_CONTEXT" -f monitoring/falco-values.yaml --wait --timeout 180s
k get pods -n falco -o wide
marker="DEVSECOPS_LAB_EVENT_$(python3 -c 'import uuid; print(uuid.uuid4().hex)')"
printf 'Context=%s UTC=%s marker=%s\n' "$KUBECTL_CONTEXT" "$(date -u +%FT%TZ)" "$marker"
k exec -n frontend deploy/frontend -- sh -c "echo $marker >/dev/null; sleep 1"
python3 scripts/verify-falco-event.py "$marker"
