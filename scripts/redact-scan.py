import json,sys,pathlib
stage=sys.argv[1]; root=pathlib.Path(__file__).resolve().parents[1]
p=root/'.local'/f'kubescape-{stage}.raw.json'
d=json.loads(p.read_text())
def clean(x):
 if isinstance(x,dict):
  if x.get('kind')=='Secret':
   for k in ('data','stringData'):
    if k in x: x[k]={key:'[REDACTED]' for key in x[k]}
  for k,v in list(x.items()):
   if k=='kubectl.kubernetes.io/last-applied-configuration':x[k]='[REDACTED]'
   else:clean(v)
 elif isinstance(x,list):
  for v in x:clean(v)
clean(d)
s=json.dumps(d,ensure_ascii=False,indent=2).replace('DEMO_ONLY_password_2026','[REDACTED_DEMO]').replace('REVNT19PTkxZX3Bhc3N3b3JkXzIwMjY=','[REDACTED_DEMO]')
(root/'screenshots/evidence'/f'kubescape-{stage}.json').write_text(s+'\n')
