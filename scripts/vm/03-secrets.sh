#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
echo "UTC=$(date -u +%FT%TZ) Context=$KUBECTL_CONTEXT"
k apply -f manifests/vm/secure/20-secrets.yaml
k patch deployment frontend -n frontend --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env","value":[{"name":"DB_HOST","value":"backend.backend.svc.cluster.local"},{"name":"DB_USERNAME","valueFrom":{"secretKeyRef":{"name":"db-secret","key":"username"}}},{"name":"DB_PASSWORD","valueFrom":{"secretKeyRef":{"name":"db-secret","key":"password"}}}]}]'
k rollout status deployment/frontend -n frontend --timeout=120s
k patch deployment backend -n backend --type=json -p '[{"op":"replace","path":"/spec/template/spec/containers/0/env","value":[{"name":"POSTGRES_USER","valueFrom":{"secretKeyRef":{"name":"db-secret","key":"username"}}},{"name":"POSTGRES_PASSWORD","valueFrom":{"secretKeyRef":{"name":"db-secret","key":"password"}}}]}]'
k rollout status deployment/backend -n backend --timeout=120s
for ns in frontend backend; do
 k get secret db-secret -n "$ns" -o jsonpath='{.metadata.namespace}{"/"}{.metadata.name}{" type="}{.type}{"\n"}'
 k get deploy "$ns" -n "$ns" -o jsonpath='{range .spec.template.spec.containers[*].env[*]}{.name}{" secret="}{.valueFrom.secretKeyRef.name}{" key="}{.valueFrom.secretKeyRef.key}{"\n"}{end}'
 if k get deploy "$ns" -n "$ns" -o json | python3 -c 'import json,sys;sys.exit("kubectl.kubernetes.io/last-applied-configuration" not in json.load(sys.stdin)["metadata"].get("annotations",{}))'; then
  k annotate deploy "$ns" -n "$ns" kubectl.kubernetes.io/last-applied-configuration- >/dev/null
 fi
done
k exec -n frontend deploy/frontend -- sh -c 'test -n "$DB_USERNAME" && test -n "$DB_PASSWORD" && echo "PASS frontend Secret env present; values suppressed"'
k exec -n backend deploy/backend -- sh -c 'test -n "$POSTGRES_USER" && test -n "$POSTGRES_PASSWORD" && echo "PASS backend Secret env present; values suppressed"'
ready=false
for attempt in {1..30}; do
 if k exec -n backend deploy/backend -- pg_isready -h 127.0.0.1 -p 5432; then ready=true; break; fi
 sleep 1
done
[[ "$ready" == true ]]
k exec -n backend deploy/backend -- sh -c 'PGPASSWORD="$POSTGRES_PASSWORD" psql -h 127.0.0.1 -U "$POSTGRES_USER" -d postgres -Atc "SELECT 1"'
k delete configmap db-config -n backend --ignore-not-found
