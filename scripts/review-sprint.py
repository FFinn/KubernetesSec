"""Read-only checks of required live resources, including realistic SA groups."""
import base64
import datetime
import json
import subprocess

base = ['kubectl', '--context', 'k3d-devsecops-lab']
def get(*args):
    return json.loads(subprocess.check_output(base + ['get', *args, '-o', 'json']))

def require(condition, message):
    if not condition:
        raise SystemExit('FAIL: ' + message)
    print('PASS: ' + message)

print('Context=k3d-devsecops-lab UTC=' + datetime.datetime.now(datetime.timezone.utc).isoformat())
role = get('role', 'frontend-reader', '-n', 'frontend')
require(len(role['rules']) == 1 and set(role['rules'][0]['verbs']) == {'get', 'list'}
        and set(role['rules'][0]['resources']) == {'pods', 'services'}
        and role['rules'][0]['apiGroups'] == [''], 'Role exactly get/list pods/services')
for sa in ['frontend-sa', 'default']:
    cases = [('get', 'pods', 'frontend'), ('list', 'services', 'frontend'),
             ('create', 'pods', 'frontend'), ('delete', 'pods', 'frontend'),
             ('get', 'secrets', 'frontend'), ('get', 'pods', 'backend'),
             ('get', 'secrets', 'backend'), ('*', '*', 'frontend')]
    for verb, resource, ns in cases:
        expected = 'yes' if sa == 'frontend-sa' and ns == 'frontend' and verb in ['get', 'list'] and resource in ['pods', 'services'] else 'no'
        cmd = base + ['auth', 'can-i', verb, resource, '-n', ns,
                      '--as=system:serviceaccount:frontend:' + sa,
                      '--as-group=system:authenticated', '--as-group=system:serviceaccounts',
                      '--as-group=system:serviceaccounts:frontend']
        result = subprocess.run(cmd, text=True, capture_output=True, check=False)
        require(result.returncode in (0, 1) and result.stdout.strip() == expected,
                f'{sa}: {verb} {resource} ns={ns} => {expected} (with SA groups)')

for ns in ['frontend', 'backend']:
    secret = get('secret', 'db-secret', '-n', ns)
    require(secret['type'] == 'Opaque' and set(secret['data']) == {'username', 'password'}
            and all(base64.b64decode(value, validate=True) for value in secret['data'].values()),
            f'{ns}/db-secret Opaque, username/password base64 keys; values suppressed')
    deployment = get('deployment', ns, '-n', ns)
    spec = deployment['spec']['template']['spec']
    require(spec['automountServiceAccountToken'] is False, f'{ns}: no automatic SA token')
    security = spec['securityContext']
    require(security['runAsNonRoot'] and security['runAsUser'] == 10001
            and security['seccompProfile']['type'] == 'RuntimeDefault', f'{ns}: UID 10001, non-root, RuntimeDefault')
    container = spec['containers'][0]
    cs = container['securityContext']
    require(cs.get('privileged') is False and cs['allowPrivilegeEscalation'] is False
            and cs['readOnlyRootFilesystem'] and cs['capabilities']['drop'] == ['ALL'], f'{ns}: hardened container SecurityContext')
    require({e['name'] for e in container['env']} == {'DB_USERNAME', 'DB_PASSWORD'}
            and all('value' not in e and e['valueFrom']['secretKeyRef']['name'] == 'db-secret' for e in container['env']),
            f'{ns}: both env vars use local Secret')
    command = base + ['exec', '-n', ns, 'deploy/' + ns, '--', 'sh', '-c',
                      'test -n "$DB_USERNAME" && test -n "$DB_PASSWORD" && test "$(id -u)" = 10001 && test ! -e /var/run/secrets/kubernetes.io/serviceaccount/token']
    subprocess.run(command, check=True)
    print(f'PASS: {ns} live env present, UID nonroot and no mounted SA token; values suppressed')

require(not get('configmaps', '-n', 'backend', '--field-selector=metadata.name=db-config')['items'], 'old ConfigMap absent')
require(not get('clusterrolebindings', '--field-selector=metadata.name=lab-unsafe-default')['items'], 'unsafe binding absent')
require(not get('clusterroles', '--field-selector=metadata.name=lab-unsafe-wildcard')['items'], 'unsafe role absent')
require(get('namespace', 'backend')['metadata']['labels']['pod-security.kubernetes.io/enforce'] == 'baseline', 'backend PSA baseline')
print('PASS: all live sprint review checks completed')
