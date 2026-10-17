"""Correlate a new uniquely marked syscall event and the Sidekick payload."""
import json
import subprocess
import sys
import time

marker = sys.argv[1]
base = ['kubectl', '--context', 'k3d-devsecops-lab', 'logs', '-n', 'falco']
def logs(component):
    args = base + ['-l', f'app.kubernetes.io/name={component}', '--tail=300']
    if component == 'falco':
        args += ['-c', 'falco']
    return subprocess.check_output(args, text=True)

event = None
for attempt in range(20):
    for line in logs('falco').splitlines():
        if marker not in line or not line.startswith('{'):
            continue
        candidate = json.loads(line)
        if candidate.get('rule') == 'DevSecOps Lab Shell Marker' and candidate.get('source') == 'syscall':
            event = candidate
            break
    if event:
        break
    time.sleep(1)
if not event:
    sys.exit(f'FAIL: new Falco event missing for {marker}')
print(json.dumps(event, ensure_ascii=False))
for attempt in range(20):
    for line in logs('falcosidekick').splitlines():
        if marker not in line or "Falco's payload : " not in line:
            continue
        payload = json.loads(line.split("Falco's payload : ", 1)[1])
        if payload.get('source') == 'syscall' and payload.get('rule') == event['rule'] and all(
            payload.get('output_fields', {}).get(key) == event['output_fields'][key]
            for key in ['evt.time', 'proc.pid', 'proc.cmdline']
        ):
            print(line)
            print('PASS: NEW unique marker; matching evt.time, proc.pid, proc.cmdline in Falco and Falcosidekick')
            sys.exit(0)
    time.sleep(1)
sys.exit('FAIL: matching Sidekick payload missing')
