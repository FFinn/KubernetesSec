# Проверка требований спринта

| Шаг | Требование | Доказательство |
|---|---|---|
| 1 | Пять типов дефектов, kubectl JSONPath, таблица риска/приоритета | [JSONPath](screenshots/evidence/vm/run-20261103/01-audit-before.txt), [отчёт](REPORT.md#1-диагностика-и-аудит) |
| 1 | Kubescape NSA baseline | [JSON](screenshots/evidence/vm/run-20261103/kubescape-before.json), [лог](screenshots/evidence/vm/run-20261103/kubescape-before.log) |
| 2 | frontend-sa, Role/RoleBinding get/list pods/services; нет wildcard | [RBAC-манифест](manifests/vm/secure/10-rbac.yaml), [can-i](screenshots/evidence/vm/run-20261103/02-rbac.txt) |
| 2 | Удалены опасные binding; default SA не имеет wildcard | [Оба namespace, положительные/отрицательные can-i](screenshots/evidence/vm/run-20261103/02-rbac.txt) |
| 3 | Opaque Secret в обоих namespace; data base64; secretKeyRef | [Secret](manifests/vm/secure/20-secrets.yaml), [Deployment](manifests/vm/secure/30-workloads.yaml) |
| 3 | Проверка env внутри Pod; ConfigMap удалён | [Проверки переменных и SQL без вывода credentials](screenshots/evidence/vm/run-20261103/03-secrets.txt) |
| 4 | PSA baseline, SecurityContext, non-root, нет privileged | [UID и параметры](screenshots/evidence/vm/run-20261103/04-pod-security.txt), [финальная проверка](screenshots/evidence/vm/run-20261103/09-final-verification.txt) |
| 4 | PSA автоматически блокирует privileged Pod | [Forbidden и отсутствие Pod](screenshots/evidence/vm/run-20261103/04-pod-security.txt) |
| 5 | Default-deny Ingress/Egress обоих namespace; DNS; TCP 5432 с обеих сторон | [NetworkPolicy](manifests/vm/secure/50-network.yaml) |
| 5 | frontend→backend работает, сторонний Pod блокируется | [До/после](screenshots/evidence/vm/run-20261103/05-network.txt), [повторная проверка](screenshots/evidence/vm/run-20261103/05-network-repeat.txt) |
| 6 | Повторный NSA JSON, сравнение FAIL/OK | [After JSON](screenshots/evidence/vm/run-20261103/kubescape-after.json), [сравнение](screenshots/evidence/vm/run-20261103/comparison.md) |
| 6 | Ручные исправления и автоматическая защита PSA | [Шаги 2–5 отчёта](REPORT.md), [Admission rejection](screenshots/evidence/vm/run-20261103/04-pod-security.txt) |
| 6 | Событие Falco, скриншот UI | [JSON](screenshots/evidence/vm/run-20261103/07-falco-events.json), [UI](screenshots/evidence/vm/run-20261103/falco-ui-event.png) |
| Сдача | Применимые манифесты; отчёт; До/После; проверки | [Server-side dry-run и финальные проверки](screenshots/evidence/vm/run-20261103/09-final-verification.txt), [README](README.md), [REPORT](REPORT.md) |

Все шесть шагов подтверждены. Итог frontend/backend: **0 failed-пар ресурс/control**. Общекластерные FAIL **19 → 19** приведены без исключения инфраструктурных нарушений. Ограничения охвата — в [отчёте](REPORT.md#ограничения).
