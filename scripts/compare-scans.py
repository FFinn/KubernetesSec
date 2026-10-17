import json,pathlib,collections
root=pathlib.Path(__file__).resolve().parents[1];e=root/'screenshots/evidence'
b,a=[json.loads((e/f'kubescape-{s}.json').read_text()) for s in ['before','after']]
bc,ac=[x['summaryDetails']['controls'] for x in [b,a]]
lines=['# Реальное сравнение Kubescape NSA','',f"Kubescape {a['metadata']['scanMetadata']['kubescapeVersion']}; до {b['generationTime']}, после {a['generationTime']} (UTC).",'','| Метрика | До | После |','|---|---:|---:|']
for name,key in [('FAIL','failed'),('OK','passed'),('Пропущено / Action Required','skipped')]:
 lines.append(f"| {name} | {sum(v['status']==key for v in bc.values())} | {sum(v['status']==key for v in ac.values())} |")
lines.append(f"| Compliance score | {b['summaryDetails']['complianceScore']:.2f}% | {a['summaryDetails']['complianceScore']:.2f}% |")
lines.extend(['','FAIL/OK — статусы controls всего локального кластера, а не число отдельных дефектов. Набор NSA содержит одинаковые 26 control ID. После появился тестовый outsider Pod; системные ресурсы включены в оба снимка.','', '| Control | Статус до → после | Failed resources до → после |','|---|---|---|'])
assert set(bc)==set(ac)
for key in sorted(bc):
 x,y=bc[key],ac[key]
 lines.append(f"| {key}: {y['name']} | {x['status']} → {y['status']} | {x['ResourceCounters']['failedResources']} → {y['ResourceCounters']['failedResources']} |")
lines.extend(['','Ограничения: host-scan отключён; C-0069/C-0070 не оценены без operator KubeletInfo; облачный provider отсутствует. В повторном запуске --use-from использует исходный nsa.json; exceptions/controlInputs взяты из bundled defaults из-за отсутствия локальных файлов (см. лог). Поэтому сравнение отражает наблюдение, но не является строгим сертификационным измерением при полностью зафиксированных inputs.','', 'JSON сохранён с редактированием Secret data и last-applied annotation; статусы/счётчики не менялись. Исходные JSON доступны только в игнорируемой .local/.'])
(e/'comparison.md').write_text('\n'.join(lines)+'\n')
print('\n'.join(lines[:16]))
