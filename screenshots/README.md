# Результаты проверок

| Проверка | Файл в evidence/ |
|---|---|
| Исходный аудит JSONPath | `03-jsonpath-before.txt` |
| RBAC после исправления | `05-rbac-after.txt` |
| Миграция Secret | `06-secrets.txt` |
| PSA rejection | `07-psa.txt` |
| Сеть до/после NetworkPolicy | `08-network.txt` |
| Falco и Falcosidekick | `18-review-falco.txt` |
| Применимость secure-манифестов и повторные сетевые пробы | `19-review-final-verification.txt` |
| Проверка RBAC, Secrets, UID и PSA | `20-review-rbac-secrets-psa.txt` |
| Kubescape NSA | `kubescape-before.json`, `kubescape-after.json` и соответствующие `.log` |
| Сравнение всех controls | `comparison.md` |

Значения Secret и last-applied annotations в JSON скрыты. Сканирование after выполнено до установки Falco.
