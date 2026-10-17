#!/bin/bash
source "$(dirname "$0")/env.sh"
# Initial deployment only: refuse to downgrade an already secured namespace.
if [[ -n "$(k get sa frontend-sa -n frontend --ignore-not-found -o name 2>/dev/null)" ]]; then
 echo "RBAC fixes already present; refusing to restore vulnerable baseline." >&2; exit 1
fi
if k get ns backend -o jsonpath='{.metadata.labels.pod-security\.kubernetes\.io/enforce}' 2>/dev/null | grep -Eq "baseline|restricted"; then
 echo 'Secure state already present; use a fresh dedicated lab cluster for baseline.' >&2; exit 1
fi
k apply -f manifests/baseline/00-namespaces.yaml
k apply -f manifests/baseline/10-workloads.yaml
k apply -f manifests/baseline/20-unsafe-rbac.yaml
for ns in frontend backend; do k rollout status deployment/$ns -n "$ns" --timeout=180s; done
k get pods -A -o wide
