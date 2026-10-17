# Проверка выполнения требований

| Шаг | Требование | Результат и доказательство |
|---|---|---|
| 1 | Пять типов дефектов через kubectl JSONPath | [Privileged, ConfigMap, env, default SA, wildcard RBAC](screenshots/evidence/03-jsonpath-before.txt) |
| 1 | Kubescape NSA baseline и таблица рисков | [Baseline JSON](screenshots/evidence/kubescape-before.json), [таблица в отчёте](REPORT.md#1-диагностика-и-аудит) |
| 2 | frontend-sa, Role/RoleBinding с get/list pods/services | [Проверка прав](screenshots/evidence/05-rbac-after.txt) |
| 2 | Отказ create/delete, чтения Secret и доступа в backend | [can-i с группами ServiceAccount](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 2 | Небезопасные ClusterRoleBinding/ClusterRole удалены | [Проверка отсутствия объектов и wildcard-доступа](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 3 | Opaque Secret отдельно в frontend/backend, secretKeyRef | [Миграция и проверка env](screenshots/evidence/06-secrets.txt) |
| 3 | ConfigMap удалён; значения credentials не выводятся | [Проверка Secret и Pod](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 4 | PSA baseline, безопасный SecurityContext, non-root | [Параметры и UID](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 4 | Admission отклоняет privileged Pod | [Forbidden: violates PodSecurity](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 5 | Default-deny в обоих namespace, DNS и TCP 5432 | [NetworkPolicy](manifests/secure/30-network.yaml) |
| 5 | frontend→backend разрешён; outsider→backend запрещён | [До/после политик](screenshots/evidence/08-network.txt), [повторные TCP-пробы](screenshots/evidence/19-review-final-verification.txt) |
| 5 | backend→frontend запрещён при работающем listener | [Контроль listener и отказ TCP](screenshots/evidence/19-review-final-verification.txt) |
| 6 | Повторный NSA JSON и сравнение FAIL/OK | [After JSON](screenshots/evidence/kubescape-after.json), [сравнение](screenshots/evidence/comparison.md) |
| 6 | Ручные исправления и автоматическое предотвращение | [RBAC, Secrets, Pod Security, NetworkPolicy](REPORT.md), [PSA deny](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 6 | Falco/Falcosidekick | [Новое событие и совпадающий payload](screenshots/evidence/18-review-falco.txt) |
| Сдача | Применимые манифесты и инструкция воспроизведения | [Server-side dry-run](screenshots/evidence/19-review-final-verification.txt), [README](README.md) |

Ограничения Kubescape и Falco приведены в [REPORT.md](REPORT.md#ограничения).

Повторная проверка:

```bash
scripts/review-live.sh
scripts/verify-final.sh
scripts/08-falco.sh
```
