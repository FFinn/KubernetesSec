#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
printf 'UTC='; date -u +%FT%TZ
printf 'Context=%s\n' "$KUBECTL_CONTEXT"
for ns in frontend backend; do
 echo "== $ns: Pod / ServiceAccount / privileged =="
 k get pods -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{" SA="}{.spec.serviceAccountName}{range .spec.containers[*]}{" container="}{.name}{" privileged="}{.securityContext.privileged}{end}{"\n"}{end}'
 echo "== $ns: env.value names (values suppressed) =="
 k get deploy -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.spec.containers[*].env[?(@.value)]}{.name}{" source=env.value\n"}{end}{end}'
 echo "== $ns: ConfigMaps containing password key =="
 k get cm -n "$ns" -o jsonpath='{range .items[?(@.data.password)]}{.metadata.name}{" password key present (value suppressed)\n"}{end}'
 echo "== $ns: ConfigMap/Secret env references =="
 k get deploy -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.spec.containers[*].env[*]}{.name}{" configMap="}{.valueFrom.configMapKeyRef.name}{" secret="}{.valueFrom.secretKeyRef.name}{" key="}{.valueFrom.secretKeyRef.key}{"\n"}{end}{end}'
done
echo '== Unsafe wildcard role and subjects =='
k get clusterrole unsafe-role --ignore-not-found -o jsonpath='{.metadata.name}{"\n"}{range .rules[*]}{.apiGroups}{" "}{.resources}{" "}{.verbs}{"\n"}{end}'
k get clusterrolebindings -o jsonpath='{range .items[?(@.roleRef.name=="unsafe-role")]}{.metadata.name}{" "}{.subjects}{"\n"}{end}'
