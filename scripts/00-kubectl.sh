#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
umask 077
mkdir -p .local/bin
chmod 700 .local
platform=$(uname -s | tr '[:upper:]' '[:lower:]')
arch=$(uname -m)
case "$arch" in arm64|aarch64) arch=arm64;; x86_64) arch=amd64;; *) exit 2;; esac
base="https://dl.k8s.io/release/v1.34.5/bin/$platform/$arch"
curl -fLsS --max-time 120 "$base/kubectl" -o .local/bin/kubectl.download
curl -fLsS --max-time 30 "$base/kubectl.sha256" -o .local/bin/kubectl.sha256
python3 - <<'PY'
import hashlib,pathlib
p=pathlib.Path('.local/bin/kubectl.download')
assert hashlib.sha256(p.read_bytes()).hexdigest()==pathlib.Path('.local/bin/kubectl.sha256').read_text().strip()
p.chmod(0o700)
p.replace('.local/bin/kubectl')
PY
.local/bin/kubectl version --client
