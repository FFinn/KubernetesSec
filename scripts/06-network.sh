#!/bin/bash
source "$(dirname "$0")/env.sh"
printf 'Context=%s UTC=%s\n' "$KUBECTL_CONTEXT" "$(date -u +%FT%TZ)"
k apply -f manifests/tests/outsider.yaml
k wait -n outsider --for=condition=Ready pod/outsider-probe --timeout=120s
for ns in frontend backend; do k rollout status -n "$ns" deployment/"$ns" --timeout=120s; done
backend_ip=$(k get pod -n backend -l app=backend -o jsonpath='{.items[?(@.status.phase=="Running")].status.podIP}')
frontend_ip=$(k get pod -n frontend -l app=frontend -o jsonpath='{.items[?(@.status.phase=="Running")].status.podIP}')
[[ -n "$backend_ip" && "$backend_ip" != *' '* && -n "$frontend_ip" && "$frontend_ip" != *' '* ]]
# A probe returns kubectl success only after nc completed inside the container.
# Missing nc and transport/API errors are failures; positive controls verify listeners.
expect_denied() {
 local ns=$1 pod=$2 ip=$3 port=$4 result
 result=$(k exec -n "$ns" "$pod" -- sh -c '
  command -v nc >/dev/null || exit 90
  start=$(date +%s)
  nc -w 3 "$1" "$2" >/dev/null 2>&1
  rc=$?
  elapsed=$(($(date +%s)-start))
  printf "COMPLETED_TCP_PROBE rc=%s elapsed=%ss\n" "$rc" "$elapsed"
  test "$rc" -eq 1
 ' sh "$ip" "$port") || { printf 'FAIL probe execution: %s\n' "$result" >&2; return 1; }
 echo "$result"
 [[ "$result" == COMPLETED_TCP_PROBE* ]]
}
for source in 'outsider outsider-probe' 'backend deploy/backend'; do
 read -r ns pod <<< "$source"
 k exec -n "$ns" "$pod" -- sh -c 'command -v nc >/dev/null && echo "PASS source container and nc available"'
done
if [[ $(k get networkpolicy -n backend -o name | wc -l) -eq 0 ]]; then
 echo 'BEFORE policies: outsider -> backend must reach real listener'
 response=$(k exec -n outsider outsider-probe -- nc -w 3 "$backend_ip" 5432)
 echo "$response"; [[ "$response" == *lab-backend* ]]
fi
k apply -f manifests/secure/30-network.yaml
# Bounded retry permits asynchronous policy-controller convergence.
blocked=false
for attempt in {1..10}; do
 if expect_denied outsider outsider-probe "$backend_ip" 5432; then blocked=true; break; fi
 sleep 1
done
[[ "$blocked" == true ]]
echo 'PASS outsider (app=frontend, wrong namespace) -> backend:5432 BLOCKED (completed nc, exit=1)'
echo 'DNS lookup from frontend:'
k exec -n frontend deploy/frontend -- nslookup backend.backend.svc.cluster.local
response=$(k exec -n frontend deploy/frontend -- nc -w 5 backend.backend.svc.cluster.local 5432)
echo "frontend -> backend:5432 = $response"; [[ "$response" == *lab-backend* ]]
response=$(k exec -n frontend deploy/frontend -- nc -w 3 127.0.0.1 8080)
echo "frontend listener control = $response"; [[ "$response" == *lab-frontend* ]]
expect_denied backend deploy/backend "$frontend_ip" 8080
echo 'PASS backend -> frontend:8080 BLOCKED (completed nc, exit=1)'
k get networkpolicy -A
k get ns kube-system --show-labels
k get pods -n kube-system -l k8s-app=kube-dns --show-labels
