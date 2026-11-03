#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
echo "UTC=$(date -u +%FT%TZ) Context=$KUBECTL_CONTEXT"
k apply -f manifests/vm/secure/30-workloads.yaml
for ns in frontend backend; do k rollout status deploy/"$ns" -n "$ns" --timeout=150s; done
k apply -f manifests/vm/secure/40-psa.yaml
k get ns backend --show-labels
for ns in frontend backend; do
 k exec -n "$ns" deploy/"$ns" -- id
 k exec -n "$ns" deploy/"$ns" -- sh -c 'test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token && echo "PASS no mounted SA token"'
done
k exec -n backend deploy/backend -- sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U "$POSTGRES_USER" -d postgres -Atc "SELECT 1"'
set +e
rejection=$(k create -f manifests/vm/tests/privileged.yaml 2>&1)
rc=$?
set -e
printf '%s\n' "$rejection"
[[ "$rc" -ne 0 && "$rejection" == *Forbidden* && "$rejection" == *'violates PodSecurity'* && "$rejection" == *privileged* ]]
[[ -z "$(k get pod psa-privileged-probe -n backend --ignore-not-found -o name)" ]]
echo 'PASS PSA denied privileged Pod and no test Pod exists'
