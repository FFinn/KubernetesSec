#!/bin/bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
export PATH="$PWD/.local/bin:$PATH"
export KUBECONFIG="$PWD/.local/kubeconfig"
export KUBECTL_CONTEXT=k3d-devsecops-lab
k() { kubectl --context "$KUBECTL_CONTEXT" "$@"; }
