#!/bin/bash
source "$(dirname "$0")/env.sh"
umask 077
mkdir -p .local
chmod 700 .local
if ! k3d cluster list -o json | python3 -c 'import json,sys;sys.exit(not any(c["name"]=="devsecops-lab" for c in json.load(sys.stdin)))'; then
 k3d cluster create devsecops-lab --servers 1 --agents 0 --servers-memory 3g --image rancher/k3s:v1.34.5-k3s1 --kubeconfig-update-default=false --kubeconfig-switch-context=false --no-lb --k3s-arg '--disable=traefik,servicelb,metrics-server@server:0'
fi
k3d kubeconfig get devsecops-lab > "$KUBECONFIG"
chmod 600 "$KUBECONFIG"
k wait --for=condition=Ready nodes --all --timeout=180s
k get nodes -o wide
