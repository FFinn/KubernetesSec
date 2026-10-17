import json,pathlib,base64
root=pathlib.Path(__file__).resolve().parents[1]
def obj(kind,name,ns=None,**kw):
 d={'apiVersion':'v1','kind':kind,'metadata':{'name':name},**kw}
 if ns:d['metadata']['namespace']=ns
 return d
def write(stage,name,items):
 (root/'manifests'/stage/name).write_text('\n---\n'.join(json.dumps(i,indent=2) for i in items)+'\n')
nss=[obj('Namespace',n) for n in ['frontend','backend','outsider']]
write('baseline','00-namespaces.yaml',nss)
write('secure','00-namespaces.yaml',[{**x,'metadata':{**x['metadata'],**({'labels':{'pod-security.kubernetes.io/enforce':'baseline','pod-security.kubernetes.io/enforce-version':'v1.34'}} if x['metadata']['name']=='backend' else {})}} for x in nss])
def deploy(ns,secure):
 c={'name':ns,'image':'busybox:1.37.0','command':['sh','-c', 'while true; do nc -l -p 5432 -e echo lab-backend; done' if ns=='backend' else 'while true; do nc -l -p 8080 -e echo lab-frontend; done'],'resources':{'requests':{'cpu':'10m','memory':'16Mi'},'limits':{'cpu':'200m','memory':'64Mi'}}}
 c['env']=[{'name':'DB_PASSWORD',**({'valueFrom':{'secretKeyRef':{'name':'db-secret','key':'password'}}} if secure else ({'valueFrom':{'configMapKeyRef':{'name':'db-config','key':'password'}}} if ns=='backend' else {'value':'DEMO_ONLY_password_2026'}))}]

 if secure:c['env'].append({'name':'DB_USERNAME','valueFrom':{'secretKeyRef':{'name':'db-secret','key':'username'}}})
 spec={'containers':[c]}
 if secure:
  spec.update({'automountServiceAccountToken':False,'securityContext':{'runAsNonRoot':True,'runAsUser':10001,'runAsGroup':10001,'seccompProfile':{'type':'RuntimeDefault'}}})
  c['securityContext']={'privileged':False,'allowPrivilegeEscalation':False,'readOnlyRootFilesystem':True,'capabilities':{'drop':['ALL']}}
  if ns=='frontend':spec['serviceAccountName']='frontend-sa'
 elif ns=='backend':c['securityContext']={'privileged':True}
 d=obj('Deployment',ns,ns,spec={'replicas':1,'selector':{'matchLabels':{'app':ns}},'template':{'metadata':{'labels':{'app':ns}},'spec':spec}});d['apiVersion']='apps/v1';return d
svc=obj('Service','backend','backend',spec={'selector':{'app':'backend'},'ports':[{'port':5432,'targetPort':5432}]})
write('baseline','10-workloads.yaml',[obj('ConfigMap','db-config','backend',data={'password':'DEMO_ONLY_password_2026'}),deploy('frontend',False),deploy('backend',False),svc])
role=obj('ClusterRole','lab-unsafe-wildcard',rules=[{'apiGroups':['*'],'resources':['*'],'verbs':['*']}]);role['apiVersion']='rbac.authorization.k8s.io/v1'
bind=obj('ClusterRoleBinding','lab-unsafe-default',roleRef={'apiGroup':'rbac.authorization.k8s.io','kind':'ClusterRole','name':'lab-unsafe-wildcard'},subjects=[{'kind':'ServiceAccount','name':'default','namespace':'frontend'}]);bind['apiVersion']=role['apiVersion']
write('baseline','20-unsafe-rbac.yaml',[role,bind])
r=obj('Role','frontend-reader','frontend',rules=[{'apiGroups':[''],'resources':['pods','services'],'verbs':['get','list']}]);r['apiVersion']=role['apiVersion']
b=obj('RoleBinding','frontend-reader','frontend',roleRef={'apiGroup':'rbac.authorization.k8s.io','kind':'Role','name':'frontend-reader'},subjects=[{'kind':'ServiceAccount','name':'frontend-sa','namespace':'frontend'}]);b['apiVersion']=role['apiVersion']
write('secure','10-rbac.yaml',[obj('ServiceAccount','frontend-sa','frontend',automountServiceAccountToken=False),r,b])
write('secure','20-workloads.yaml',[*[obj('Secret','db-secret',n,type='Opaque',data={k:base64.b64encode(v.encode()).decode() for k,v in {'username':'demo_user','password':'DEMO_ONLY_password_2026'}.items()}) for n in ['frontend','backend']],deploy('frontend',True),deploy('backend',True),svc])
def np(name,ns,spec):
 d=obj('NetworkPolicy',name,ns,spec=spec);d['apiVersion']='networking.k8s.io/v1';return d
pol=[np('default-deny',n,{'podSelector':{},'policyTypes':['Ingress','Egress']}) for n in ['frontend','backend']]
peer={'namespaceSelector':{'matchLabels':{'kubernetes.io/metadata.name':'backend'}},'podSelector':{'matchLabels':{'app':'backend'}}}
pol.append(np('frontend-egress','frontend',{'podSelector':{'matchLabels':{'app':'frontend'}},'policyTypes':['Egress'],'egress':[{'to':[peer],'ports':[{'protocol':'TCP','port':5432}]},{'to':[{'namespaceSelector':{'matchLabels':{'kubernetes.io/metadata.name':'kube-system'}},'podSelector':{'matchLabels':{'k8s-app':'kube-dns'}}}],'ports':[{'protocol':p,'port':53} for p in ['UDP','TCP']]}]}))
pol.append(np('backend-ingress','backend',{'podSelector':{'matchLabels':{'app':'backend'}},'policyTypes':['Ingress'],'ingress':[{'from':[{'namespaceSelector':{'matchLabels':{'kubernetes.io/metadata.name':'frontend'}},'podSelector':{'matchLabels':{'app':'frontend'}}}],'ports':[{'protocol':'TCP','port':5432}]}]}))
write('secure','30-network.yaml',pol)
