#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
echo "UTC=$(date -u +%FT%TZ) Context=$KUBECTL_CONTEXT"
k apply -f manifests/vm/tests/outsider.yaml
k wait -n attacker-test --for=condition=Ready pod/outsider-probe --timeout=120s
backend_ip=$(k get pod -n backend -l app=backend -o jsonpath='{.items[?(@.status.phase=="Running")].status.podIP}')
[[ -n "$backend_ip" && "$backend_ip" != *' '* ]]
echo 'Backend local PostgreSQL listener control:'
k exec -n backend deploy/backend -- pg_isready -h 127.0.0.1 -p 5432
if [[ $(k get networkpolicy -n backend -o name | wc -l) -eq 0 ]]; then
 echo 'BEFORE NetworkPolicy: outsider -> backend PostgreSQL'
 k exec -n attacker-test outsider-probe -- pg_isready -h "$backend_ip" -p 5432 -t 3
fi
k exec -n frontend deploy/frontend -- sh -c 'command -v bash && command -v curl'
k apply -f manifests/vm/secure/50-network.yaml
blocked=false
for attempt in {1..10}; do
 if result=$(k exec -n attacker-test outsider-probe -- sh -c 'command -v pg_isready >/dev/null || exit 90; pg_isready -h "$1" -p 5432 -t 3; rc=$?; echo "COMPLETED_PG_PROBE rc=$rc"; test "$rc" -eq 2' sh "$backend_ip"); then
  echo "$result"; [[ "$result" == *'COMPLETED_PG_PROBE rc=2'* ]]; blocked=true; break
 fi
 sleep 1
done
[[ "$blocked" == true ]]
echo 'PASS outsider app=frontend in attacker-test -> backend:5432 DENIED'
k exec -n frontend deploy/frontend -- bash -ec 'getent hosts backend.backend.svc.cluster.local; timeout 5 bash -c "exec 3<>/dev/tcp/backend.backend.svc.cluster.local/5432"; echo "PASS frontend -> backend:5432 TCP connected"'
k exec -n frontend deploy/frontend -- curl --fail --silent --output /dev/null http://127.0.0.1:8080/
echo 'PASS frontend HTTP listener serves requests as non-root'
k get networkpolicy -A
# Probe artifacts are removed before after-scan so no test Pod affects totals.
k delete namespace attacker-test --wait=true --timeout=120s
