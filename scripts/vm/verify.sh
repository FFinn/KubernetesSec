#!/usr/bin/env bash
source "$(dirname "$0")/env.sh"
python3 - <<'PY'
import base64,json,os,subprocess
base=['kubectl','--context',os.environ['KUBECTL_CONTEXT']]
def get(*args):return json.loads(subprocess.check_output(base+['get',*args,'-o','json']))
def check(value,message):
 if not value:raise SystemExit('FAIL: '+message)
 print('PASS: '+message)
role=get('role','frontend-reader','-n','frontend')
check(role['rules']==[{'apiGroups':[''],'resources':['pods','services'],'verbs':['get','list']}], 'Role: exactly get/list pods/services')
check(not get('clusterrolebinding','--field-selector=metadata.name=unsafe-binding-frontend')['items'], 'unsafe frontend binding absent')
check(not get('clusterrolebinding','--field-selector=metadata.name=unsafe-binding-backend')['items'], 'unsafe backend binding absent')
check(not get('clusterrole','--field-selector=metadata.name=unsafe-role')['items'], 'unsafe wildcard role absent')
check(not get('cm','-n','backend','--field-selector=metadata.name=db-config')['items'], 'db-config absent')
for ns,uid in [('frontend',101),('backend',999)]:
 d=get('deployment',ns,'-n',ns); s=d['spec']['template']['spec']; c=s['containers'][0];sc=c['securityContext']
 check(s['serviceAccountName']==ns+'-sa' and not s['automountServiceAccountToken'],ns+': dedicated SA, no automount')
 check(s['securityContext']['runAsNonRoot'] and s['securityContext']['runAsUser']==uid,ns+': non-root UID')
 check(not sc.get('privileged',False) and not sc['allowPrivilegeEscalation'] and sc['readOnlyRootFilesystem'] and sc['capabilities']['drop']==['ALL'],ns+': hardened container')
 sec=get('secret','db-secret','-n',ns)
 check(sec['type']=='Opaque' and set(sec['data'])=={'username','password'} and all(base64.b64decode(v,validate=True) for v in sec['data'].values()),ns+': Opaque Secret keys present; values suppressed')
 names={'DB_USERNAME','DB_PASSWORD'} if ns=='frontend' else {'POSTGRES_USER','POSTGRES_PASSWORD'}
 env=[e for e in c['env'] if e['name'] in names]
 check(len(env)==2 and all('value' not in e and e['valueFrom']['secretKeyRef']['name']=='db-secret' for e in env),ns+': secretKeyRef for credentials')
 pods=get('pods','-n',ns,'-l','app='+ns)['items']
 check(len(pods)==1 and all(any(x['type']=='Ready' and x['status']=='True' for x in p['status']['conditions']) for p in pods),ns+': one Ready Pod')
 actual=subprocess.check_output(base+['exec','-n',ns,'deploy/'+ns,'--','id','-u'],text=True).strip()
 check(actual==str(uid),ns+': live uid='+actual)
 for sa in [ns+'-sa','default']:
  for verb,res,target,expected in [('get','secrets',ns,'no'),('*','*',ns,'no')]:
   r=subprocess.run(base+['auth','can-i',verb,res,'-n',target,'--as=system:serviceaccount:'+ns+':'+sa,'--as-group=system:authenticated','--as-group=system:serviceaccounts','--as-group=system:serviceaccounts:'+ns],text=True,capture_output=True)
   check(r.stdout.strip()==expected,ns+'/'+sa+': '+verb+' '+res+'='+expected)
 check(len(get('networkpolicy','-n',ns)['items'])==2,ns+': default deny plus explicit allow')
check(get('namespace','backend')['metadata']['labels']['pod-security.kubernetes.io/enforce']=='baseline','backend PSA baseline')
check(not get('pod','-n','backend','--field-selector=metadata.name=psa-privileged-probe')['items'],'rejected probe Pod absent')
print('PASS: final course VM verification completed')
PY
k apply --dry-run=server -f manifests/vm/secure/
