#!/usr/bin/env python3
"""Build apply-ready manifests for the course Kubernetes 1.31 lab."""
import base64
import json
from pathlib import Path

root = Path(__file__).resolve().parents[2] / 'manifests' / 'vm'
def resource(kind, name, namespace=None, api='v1', **fields):
    item = {'apiVersion': api, 'kind': kind, 'metadata': {'name': name}, **fields}
    if namespace: item['metadata']['namespace'] = namespace
    return item

def write(stage, name, items):
    folder = root / stage
    folder.mkdir(parents=True, exist_ok=True)
    (folder / name).write_text(json.dumps({'apiVersion': 'v1', 'kind': 'List', 'items': items}, indent=2) + '\n')

namespaces = [resource('Namespace', ns) for ns in ['frontend', 'backend']]
write('baseline', '00-namespaces.yaml', namespaces)
write('secure', '00-namespaces.yaml', [
    namespaces[0],
    resource('Namespace', 'backend'),
])
# PSA is separate so compatible Pods are rolled out before enforcement.
psa = resource('Namespace', 'backend')
psa['metadata']['labels'] = {'pod-security.kubernetes.io/enforce': 'baseline', 'pod-security.kubernetes.io/enforce-version': 'v1.31'}
write('secure', '40-psa.yaml', [psa])

service = lambda name, port: resource('Service', name, name, spec={'selector': {'app': name}, 'ports': [{'port': 80 if name == 'frontend' else 5432, 'targetPort': port, 'protocol': 'TCP'}]})

def deployment(name, secure=False):
    frontend = name == 'frontend'
    container = {'name': name, 'image': 'nginx:1.25' if frontend else 'postgres:15', 'ports': [{'containerPort': 8080 if frontend and secure else 80 if frontend else 5432}], 'resources': {}}
    spec = {'containers': [container]}
    if secure:
        uid = 101 if frontend else 999
        spec.update({'serviceAccountName': name + '-sa', 'automountServiceAccountToken': False, 'securityContext': {'runAsNonRoot': True, 'runAsUser': uid, 'runAsGroup': uid, 'fsGroup': uid, 'seccompProfile': {'type': 'RuntimeDefault'}}})
        container['securityContext'] = {'privileged': False, 'allowPrivilegeEscalation': False, 'readOnlyRootFilesystem': True, 'capabilities': {'drop': ['ALL']}}
        container['resources'] = {'requests': {'cpu': '50m', 'memory': '64Mi' if frontend else '128Mi'}, 'limits': {'cpu': '500m', 'memory': '128Mi' if frontend else '512Mi'}}
    if frontend:
        container['env'] = [{'name': 'DB_HOST', 'value': 'backend.backend.svc.cluster.local'}, {'name': 'DB_PASSWORD', **({'valueFrom': {'secretKeyRef': {'name': 'db-secret', 'key': 'password'}}} if secure else {'value': 'DEMO_ONLY_VM_password_20261103'})}]
        if secure:
            container['env'].append({'name': 'DB_USERNAME', 'valueFrom': {'secretKeyRef': {'name': 'db-secret', 'key': 'username'}}})
            container.update({'command': ['nginx'], 'args': ['-g', 'daemon off;', '-c', '/etc/nginx/lab/nginx.conf'], 'readinessProbe': {'httpGet': {'path': '/', 'port': 8080}, 'initialDelaySeconds': 2, 'periodSeconds': 3}, 'volumeMounts': [{'name': 'nginx-config', 'mountPath': '/etc/nginx/lab', 'readOnly': True}, {'name': 'tmp', 'mountPath': '/tmp'}]})
            spec['volumes'] = [{'name': 'nginx-config', 'configMap': {'name': 'frontend-config'}}, {'name': 'tmp', 'emptyDir': {}}]
    else:
        container['env'] = [{'name': 'POSTGRES_PASSWORD', 'valueFrom': {'secretKeyRef' if secure else 'configMapKeyRef': {'name': 'db-secret' if secure else 'db-config', 'key': 'password'}}}]
        if secure:
            container['env'] += [{'name': 'POSTGRES_USER', 'valueFrom': {'secretKeyRef': {'name': 'db-secret', 'key': 'username'}}}, {'name': 'PGDATA', 'value': '/var/lib/postgresql/data/pgdata'}]
            container['readinessProbe'] = {'exec': {'command': ['sh', '-c', 'pg_isready -U "$POSTGRES_USER" -d postgres']}, 'initialDelaySeconds': 3, 'periodSeconds': 3}
            container['volumeMounts'] = [{'name': 'pgdata', 'mountPath': '/var/lib/postgresql/data'}, {'name': 'pgsocket', 'mountPath': '/var/run/postgresql'}, {'name': 'tmp', 'mountPath': '/tmp'}]
            spec['volumes'] = [{'name': name, 'emptyDir': {}} for name in ['pgdata', 'pgsocket', 'tmp']]
        else: container['securityContext'] = {'privileged': True}
    return resource('Deployment', name, name, api='apps/v1', spec={'replicas': 1, 'revisionHistoryLimit': 2, 'selector': {'matchLabels': {'app': name}}, 'template': {'metadata': {'labels': {'app': name}}, 'spec': spec}})

write('baseline', '10-workloads.yaml', [resource('ConfigMap', 'db-config', 'backend', data={'host': 'backend', 'port': '5432', 'username': 'demo_user', 'password': 'DEMO_ONLY_VM_password_20261103'}), deployment('frontend'), deployment('backend'), service('frontend', 80), service('backend', 5432)])
role = resource('ClusterRole', 'unsafe-role', api='rbac.authorization.k8s.io/v1', rules=[{'apiGroups': ['*'], 'resources': ['*'], 'verbs': ['*']}])
bindings = [resource('ClusterRoleBinding', 'unsafe-binding-' + ns, api='rbac.authorization.k8s.io/v1', roleRef={'apiGroup': 'rbac.authorization.k8s.io', 'kind': 'ClusterRole', 'name': 'unsafe-role'}, subjects=[{'kind': 'ServiceAccount', 'name': 'default', 'namespace': ns}]) for ns in ['frontend', 'backend']]
write('baseline', '20-rbac.yaml', [role, *bindings])
write('secure', '10-rbac.yaml', [*[resource('ServiceAccount', name + '-sa', name, automountServiceAccountToken=False) for name in ['frontend', 'backend']], resource('Role', 'frontend-reader', 'frontend', api='rbac.authorization.k8s.io/v1', rules=[{'apiGroups': [''], 'resources': ['pods', 'services'], 'verbs': ['get', 'list']}]), resource('RoleBinding', 'frontend-reader', 'frontend', api='rbac.authorization.k8s.io/v1', roleRef={'apiGroup': 'rbac.authorization.k8s.io', 'kind': 'Role', 'name': 'frontend-reader'}, subjects=[{'kind': 'ServiceAccount', 'name': 'frontend-sa', 'namespace': 'frontend'}])])
write('secure', '20-secrets.yaml', [resource('Secret', 'db-secret', ns, type='Opaque', data={key: base64.b64encode(value.encode()).decode() for key, value in {'username': 'demo_user', 'password': 'DEMO_ONLY_VM_password_20261103'}.items()}) for ns in ['frontend', 'backend']])
nginx_config = '''pid /tmp/nginx.pid;
events { worker_connections 256; }
http {
  include /etc/nginx/mime.types;
  default_type application/octet-stream;
  access_log /dev/stdout;
  error_log /dev/stderr warn;
  client_body_temp_path /tmp/client_temp;
  proxy_temp_path /tmp/proxy_temp;
  fastcgi_temp_path /tmp/fastcgi_temp;
  uwsgi_temp_path /tmp/uwsgi_temp;
  scgi_temp_path /tmp/scgi_temp;
  server { listen 8080; root /usr/share/nginx/html; location / { index index.html; } }
}
'''
write('secure', '30-workloads.yaml', [resource('ConfigMap', 'frontend-config', 'frontend', data={'nginx.conf': nginx_config}), deployment('frontend', True), deployment('backend', True), service('frontend', 8080), service('backend', 5432)])
# Reuse the same standard NetworkPolicy semantics, but apply on the course Calico CNI.
policies = [json.loads(part) for part in (root.parents[0]/'secure'/'30-network.yaml').read_text().split('\n---\n')]
write('secure', '50-network.yaml', policies)
write('tests', 'privileged.yaml', [resource('Pod', 'psa-privileged-probe', 'backend', spec={'containers': [{'name': 'probe', 'image': 'postgres:15', 'command': ['sleep', '60'], 'securityContext': {'privileged': True}}]})])
probe = resource('Pod', 'outsider-probe', 'attacker-test', spec={'automountServiceAccountToken': False, 'securityContext': {'runAsNonRoot': True, 'runAsUser': 999, 'runAsGroup': 999, 'seccompProfile': {'type': 'RuntimeDefault'}}, 'containers': [{'name': 'probe', 'image': 'postgres:15', 'command': ['sleep', '86400'], 'securityContext': {'allowPrivilegeEscalation': False, 'readOnlyRootFilesystem': True, 'capabilities': {'drop': ['ALL']}}, 'resources': {'requests': {'cpu': '10m', 'memory': '16Mi'}, 'limits': {'cpu': '100m', 'memory': '64Mi'}}}]})
probe['metadata']['labels'] = {'app': 'frontend'}
write('tests', 'outsider.yaml', [resource('Namespace', 'attacker-test'), probe])
