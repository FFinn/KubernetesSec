#!/bin/bash
source "$(dirname "$0")/env.sh"
python3 scripts/review-sprint.py
printf '\nNEGATIVE PSA admission test (actual create request)\n'
set +e
rejection=$(k create -f manifests/tests/denied-privileged-pod.yaml 2>&1)
rc=$?
set -e
printf '%s\n' "$rejection"
[[ "$rc" -ne 0 && "$rejection" == *Forbidden* && "$rejection" == *'violates PodSecurity'* && "$rejection" == *privileged* ]]
[[ -z "$(k get pod psa-privileged-probe -n backend --ignore-not-found -o name)" ]]
echo 'PASS: admission denied; privileged test Pod does not exist'
