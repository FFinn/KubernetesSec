#!/usr/bin/env bash
# Read-only inventory of the course VM and its existing cluster.
source "$(dirname "$0")/env.sh"
printf 'UTC: '; date -u +%FT%TZ
printf '\nOS and resources\n'
uname -srmo
cat /etc/os-release
free -h
df -h /
printf '\nAvailable tools\n'
for tool in kubectl helm kubescape docker k3s; do command -v "$tool" || true; done
if ! command -v kubectl >/dev/null; then
 echo 'kubectl not found; inspect VM bootstrap before making changes.' >&2
 exit 3
fi
printf '\nCluster version and context\n'
printf '%s\n' "$KUBECTL_CONTEXT"
k version
printf '\nNodes\n'
k get nodes -o wide
printf '\nNamespaces\n'
k get namespaces --show-labels
printf '\nPods\n'
k get pods -A -o wide
printf '\nNetworkPolicy and CNI\n'
k get networkpolicy -A
k get pods -n kube-system --show-labels
for ns in frontend backend; do
 printf '\nResources in %s\n' "$ns"
 k get deployments,services,serviceaccounts,rolebindings -n "$ns"
 printf '\nImages and SA in %s\n' "$ns"
 k get deployments -n "$ns" -o jsonpath='{range .items[*]}{.metadata.name}{" SA="}{.spec.template.spec.serviceAccountName}{" images="}{.spec.template.spec.containers[*].image}{"\n"}{end}'
done
printf '\nClusterRoleBindings\n'
k get clusterrolebindings
