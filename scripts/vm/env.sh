#!/usr/bin/env bash
set -euo pipefail
umask 077
cd "$(dirname "${BASH_SOURCE[0]}")/../.."
export KUBECTL_CONTEXT="${VM_KUBECTL_CONTEXT:-kubernetes-admin@kubernetes}"
k() { kubectl --context "$KUBECTL_CONTEXT" "$@"; }
if [[ -f private/cluster-uid ]]; then
 [[ "$(k get ns kube-system -o jsonpath='{.metadata.uid}')" == "$(cat private/cluster-uid)" ]] || { echo 'Cluster UID mismatch' >&2; exit 1; }
fi
