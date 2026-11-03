#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
echo "UTC=$(date -u +%FT%TZ) Context=$KUBECTL_CONTEXT"
for ns in frontend backend; do
 actual=$(k auth can-i '*' '*' -n "$ns" --as="system:serviceaccount:$ns:default" --as-group=system:authenticated --as-group=system:serviceaccounts --as-group="system:serviceaccounts:$ns" || true)
 echo "BEFORE $ns/default wildcard=$actual"
done
k apply -f manifests/vm/secure/10-rbac.yaml
for ns in frontend backend; do
 k patch deployment "$ns" -n "$ns" --type=merge -p "{\"spec\":{\"template\":{\"spec\":{\"serviceAccountName\":\"$ns-sa\",\"automountServiceAccountToken\":false}}}}"
 k rollout status -n "$ns" deployment/"$ns" --timeout=120s
done
k delete clusterrolebinding unsafe-binding-frontend unsafe-binding-backend --ignore-not-found
k delete clusterrole unsafe-role --ignore-not-found
for line in 'get pods frontend yes' 'list pods frontend yes' 'get services frontend yes' 'list services frontend yes' 'create pods frontend no' 'delete pods frontend no' 'get secrets frontend no' 'get pods backend no'; do
 read -r verb resource namespace expected <<< "$line"
 actual=$(k auth can-i "$verb" "$resource" -n "$namespace" --as=system:serviceaccount:frontend:frontend-sa --as-group=system:authenticated --as-group=system:serviceaccounts --as-group=system:serviceaccounts:frontend || true)
 echo "frontend-sa $verb $resource namespace=$namespace => $actual expected=$expected"
 [[ "$actual" == "$expected" ]]
done
for ns in frontend backend; do
 for args in '* *' 'get secrets'; do
  read -r -a words <<< "$args"
  actual=$(k auth can-i "${words[@]}" -n "$ns" --as="system:serviceaccount:$ns:default" --as-group=system:authenticated --as-group=system:serviceaccounts --as-group="system:serviceaccounts:$ns" || true)
  echo "AFTER $ns/default $args=$actual expected=no"
  [[ "$actual" == no ]]
 done
done
