#!/bin/bash
source "$(dirname "$0")/env.sh"
k apply -f manifests/secure/10-rbac.yaml
k patch deployment frontend -n frontend --type merge -p '{"spec":{"template":{"spec":{"serviceAccountName":"frontend-sa","automountServiceAccountToken":false}}}}'
k rollout status deployment/frontend -n frontend --timeout=120s
k delete clusterrolebinding lab-unsafe-default --ignore-not-found
k delete clusterrole lab-unsafe-wildcard --ignore-not-found
for spec in 'get pods frontend yes' 'list pods frontend yes' 'get services frontend yes' 'list services frontend yes' 'create pods frontend no' 'delete pods frontend no' 'get secrets frontend no' 'get pods backend no'; do
 read -r verb resource ns expected <<< "$spec"
 actual=$(k auth can-i "$verb" "$resource" -n "$ns" --as=system:serviceaccount:frontend:frontend-sa || true)
 echo "frontend-sa: $verb $resource namespace=$ns => $actual (expected $expected)"
 [[ "$actual" == "$expected" ]]
done
for args in 'get secrets -n backend' '* *'; do
 read -r -a words <<< "$args"
 actual=$(k auth can-i "${words[@]}" --as=system:serviceaccount:frontend:default || true)
 echo "default SA: $args => $actual (expected no)"
 [[ "$actual" == no ]]
done
k get deployment frontend -n frontend -o jsonpath='{.spec.template.spec.serviceAccountName}{"\n"}'
