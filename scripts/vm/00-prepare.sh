#!/usr/bin/env bash
# Run on the course master after connecting with the portal's SSH command.
set -euo pipefail
umask 077
source "$(dirname "$0")/env.sh"
[[ "$(uname -s)" == Linux && "$(uname -m)" == x86_64 ]]
command -v kubectl >/dev/null
k get namespaces frontend backend >/dev/null
mkdir -p bin private policies
chmod 700 private
k get namespace kube-system -o jsonpath='{.metadata.uid}' > private/cluster-uid
if [[ ! -x bin/kubescape ]]; then
 curl -fLsS --max-time 120 https://github.com/kubescape/kubescape/releases/download/v4.0.16/kubescape_4.0.16_linux_amd64 -o bin/kubescape
fi
echo 'fcf172f0d1fb5683379586bcf8875091da4d0d815bd304f8098d58be65ecab0d  bin/kubescape' | sha256sum -c -
chmod 700 bin/kubescape
[[ -s policies/nsa-policy.json ]] || cp screenshots/evidence/nsa-policy.json policies/nsa-policy.json
[[ -s policies/controls-inputs.json ]] || bin/kubescape download controls-inputs --output policies/controls-inputs.json --cache-dir private/cache
[[ -s policies/exceptions.json ]] || bin/kubescape download exceptions --output policies/exceptions.json --cache-dir private/cache
sha256sum policies/nsa-policy.json policies/controls-inputs.json policies/exceptions.json
bin/kubescape version
