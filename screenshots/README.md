# Результаты проверок

Основные доказательства выполнения на учебной ВМ находятся в [evidence/vm/run-20261103/](evidence/vm/run-20261103/).

| Проверка | Файл в каталоге запуска |
|---|---|
| Исходный стенд | `00-inventory.txt` |
| JSONPath до/после | `01-audit-before.txt`, `08-audit-after.txt` |
| RBAC и can-i | `02-rbac.txt` |
| Secret references, env и SQL | `03-secrets.txt` |
| SecurityContext, UID и PSA rejection | `04-pod-security.txt` |
| Сеть до/после политик и повторная проба | `05-network.txt`, `05-network-repeat.txt` |
| Kubescape NSA | `kubescape-before.json`, `kubescape-after.json`, соответствующие `.log` |
| До/После всех controls и frontend/backend | `comparison.md` |
| Falco | `07-falco-trigger.txt`, `07-falco-events.json`, `falco-ui-event.png` |
| Итог и server-side dry-run | `09-final-verification.txt` |
| Спецификации приложений до/после | `frontend-before.json`, `backend-before.json`, `frontend-after.json`, `backend-after.json` |

В публикуемых JSON скрыты значения Secret, ConfigMap/env и annotations. Статусы, счётчики, ссылки Secret и SecurityContext сохранены. Сопоставление времени Falco: JSON — UTC, UI — UTC+5.

Файлы непосредственно в `evidence/` относятся к предыдущему запуску на Docker; их результаты описаны в [REPORT-DOCKER.md](../REPORT-DOCKER.md).
