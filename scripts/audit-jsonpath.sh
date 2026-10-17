#!/bin/bash
source "$(dirname "$0")/env.sh"
for ns in frontend backend; do
 echo "=== $ns: pod / SA / container / privileged ==="
 k get pods -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.serviceAccountName}{"\t"}{range .spec.containers[*]}{.name}{" privileged="}{.securityContext.privileged}{"\n"}{end}{end}'
 echo "=== $ns: ConfigMap names and keys (values suppressed) ==="
 k get configmaps -n "$ns" --field-selector=metadata.name=db-config -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.data}{"\n"}{end}' | sed -E 's/DEMO_ONLY_password_2026/[REDACTED_DEMO]/g'
 echo "=== $ns: deployment env sources (values suppressed) ==="
 k get deployments -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .spec.template.spec.containers[*].env[*]}{.name}{" plaintext="}{.value}{" secret="}{.valueFrom.secretKeyRef.name}{" configmap="}{.valueFrom.configMapKeyRef.name}{"\n"}{end}{end}' | sed -E 's/DEMO_ONLY_password_2026/[REDACTED_DEMO]/g'
done
echo '=== Lab ClusterRole rules ==='
k get clusterrole lab-unsafe-wildcard --ignore-not-found -o jsonpath='{.metadata.name}{"\n"}{range .rules[*]}{.apiGroups}{"\t"}{.resources}{"\t"}{.verbs}{"\n"}{end}'
echo '=== Lab binding subjects ==='
k get clusterrolebinding lab-unsafe-default --ignore-not-found -o jsonpath='{.metadata.name}{"\t"}{.roleRef.name}{"\t"}{.subjects}{"\n"}'
