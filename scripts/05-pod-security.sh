#!/bin/bash
source "$(dirname "$0")/env.sh"
k apply -f manifests/secure/20-workloads.yaml
for ns in frontend backend; do k rollout status deployment/"$ns" -n "$ns" --timeout=120s; done
k apply -f manifests/secure/00-namespaces.yaml
k get ns backend --show-labels
for ns in frontend backend; do k exec -n "$ns" deploy/"$ns" -- id; done
set +e
rejection=$(k apply -f manifests/tests/denied-privileged-pod.yaml 2>&1)
rc=$?
set -e
printf '%s\n' "$rejection"
[[ $rc -ne 0 ]]
[[ "$rejection" == *'violates PodSecurity'* ]]
[[ "$rejection" == *'privileged'* ]]
[[ -z "$(k get pod psa-privileged-probe -n backend --ignore-not-found -o name)" ]]
echo 'PASS: admission rejected privileged Pod; no Pod created.'
