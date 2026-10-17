#!/bin/bash
source "$(dirname "$0")/env.sh"
python3 - <<'PY' | k apply -f -
import json
from pathlib import Path
items=[json.loads(s) for s in Path('manifests/secure/20-workloads.yaml').read_text().split('\n---\n')]
print(json.dumps({'apiVersion':'v1','kind':'List','items':[x for x in items if x['kind']=='Secret']}))
PY
for ns in frontend backend; do
 k patch deployment "$ns" -n "$ns" --type=json -p "[{\"op\":\"replace\",\"path\":\"/spec/template/spec/containers/0/env\",\"value\":[{\"name\":\"DB_USERNAME\",\"valueFrom\":{\"secretKeyRef\":{\"name\":\"db-secret\",\"key\":\"username\"}}},{\"name\":\"DB_PASSWORD\",\"valueFrom\":{\"secretKeyRef\":{\"name\":\"db-secret\",\"key\":\"password\"}}}]}]"
 k rollout status deployment/"$ns" -n "$ns" --timeout=120s
 k exec -n "$ns" deployment/"$ns" -- sh -c 'test -n "$DB_USERNAME" && test -n "$DB_PASSWORD" && echo "Secret env: username/password present (values suppressed)"'
 k get secret db-secret -n "$ns" -o jsonpath='{.metadata.namespace}{"/"}{.metadata.name}{" type="}{.type}{"\n"}'
 k get deploy "$ns" -n "$ns" -o jsonpath='{range .spec.template.spec.containers[*].env[*]}{.name}{" => "}{.valueFrom.secretKeyRef.name}{"/"}{.valueFrom.secretKeyRef.key}{"\n"}{end}'
done
k delete configmap db-config -n backend --ignore-not-found
# Replace annotations that retained the old baseline plaintext.
for ns in frontend backend; do
 k annotate deployment "$ns" -n "$ns" kubectl.kubernetes.io/last-applied-configuration- || true
done
