#!/bin/bash
source "$(dirname "$0")/env.sh"
# Server-side validation of the deployable final state; no mutation.
k apply --dry-run=server -f manifests/secure/
python3 - <<'PY'
import json,pathlib,subprocess
base=['kubectl','--context','k3d-devsecops-lab']
def get(*args):return json.loads(subprocess.check_output(base+['get',*args,'-o','json']))
for ns in ['frontend','backend']:
 pods=get('pods','-n',ns)['items']
 assert pods
 for pod in pods:
  s=pod['spec']; assert s['securityContext']['runAsNonRoot']
  for c in s['containers']:
   assert not c['securityContext'].get('privileged',False)
   assert c['securityContext']['allowPrivilegeEscalation'] is False
   assert all('value' not in e and e['valueFrom']['secretKeyRef']['name']=='db-secret' for e in c['env'])
  assert pod['status']['phase']=='Running'
 assert len(get('networkpolicy','-n',ns)['items'])==2
assert not get('clusterrolebindings','--field-selector=metadata.name=lab-unsafe-default')['items']
assert not get('configmaps','-n','backend','--field-selector=metadata.name=db-config')['items']
assert get('deployment','frontend','-n','frontend')['spec']['template']['spec']['serviceAccountName']=='frontend-sa'
assert get('namespace','backend')['metadata']['labels']['pod-security.kubernetes.io/enforce']=='baseline'
print('PASS: running Pods, Secret refs, RBAC cleanup, ConfigMap cleanup, PSA labels, NetworkPolicy objects')
PY
scripts/06-network.sh
scripts/audit-jsonpath.sh
