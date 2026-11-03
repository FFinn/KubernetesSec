# Практическая работа по безопасности Kubernetes

Работа выполнена на учебной ВМ DSO-06. Результаты всех шести шагов — в [REPORT.md](REPORT.md), проверка требований — в [REVIEW.md](REVIEW.md).

Стенд: Ubuntu 22.04.5, Kubernetes 1.31.2, Calico, frontend `nginx:1.25`, backend `postgres:15`. Использованы исходные приложения учебного окружения. Kubescape — 4.0.16; Falco — 0.45.2.

## Результаты

- Выявлены пять типов дефектов; исправлены RBAC, хранение credentials, SecurityContext и NetworkPolicy.
- PSA baseline блокирует создание privileged Pod.
- frontend подключается к backend на TCP 5432; Pod из стороннего namespace получает timeout.
- Failed-пары «ресурс/control» в frontend/backend: **23 → 0**. Общие FAIL controls кластера: **19 → 19**, OK: **5 → 5**; оставшиеся нарушения относятся к инфраструктуре.
- [Сравнение Kubescape](screenshots/evidence/vm/run-20261103/comparison.md), [скриншот Falco UI](screenshots/evidence/vm/run-20261103/falco-ui-event.png), [итоговая проверка](screenshots/evidence/vm/run-20261103/09-final-verification.txt).

## Манифесты

| Каталог | Назначение |
|---|---|
| `manifests/vm/baseline/` | Воспроизведение исходных пяти дефектов с вымышленными credentials |
| `manifests/vm/secure/` | ServiceAccount, Role/RoleBinding, Secret, Deployment, PSA и NetworkPolicy для ВМ |
| `manifests/vm/tests/` | Отрицательная проба PSA и сторонний сетевой Pod |
| `scripts/vm/` | Последовательное исправление и проверки учебного кластера |
| `screenshots/evidence/vm/run-20261103/` | Выводы команд, JSON сканирования, сравнение и Falco UI |

Итоговую конфигурацию можно применить на подготовленном Kubernetes 1.31 с Calico:

```bash
kubectl apply -f manifests/vm/secure/
```

При переходе с уязвимого состояния используйте этапные скрипты ниже: `apply` не удаляет старые ClusterRoleBinding, ClusterRole, ConfigMap и ReplicaSet. Baseline предназначен только для отдельного учебного стенда; не применяйте его поверх исправленного состояния. Тестовый privileged Pod должен быть отклонён.

## Выполнение на учебной ВМ

Подключитесь к master способом, указанным сервисом учебных окружений, и скопируйте репозиторий на ВМ. Требуются bash, Python 3, curl, kubectl и права администратора кластера. Команды выполняются из корня репозитория. Контекст по умолчанию — `kubernetes-admin@kubernetes`; `VM_KUBECTL_CONTEXT` позволяет задать другой явно. Скрипты сохраняют UID кластера и проверяют его при повторных запусках.

На свежем DSO-06 уязвимые приложения уже существуют. Если их нет, на отдельном учебном кластере сначала примените `manifests/vm/baseline/`.

```bash
set -euo pipefail
umask 077
evidence="screenshots/evidence/vm/run-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$evidence"

# 1. Подготовка, JSONPath-аудит, NSA baseline
scripts/vm/00-prepare.sh | tee "$evidence/00-prepare.txt"
scripts/vm/inventory.sh | tee "$evidence/00-inventory.txt"
scripts/vm/audit.sh | tee "$evidence/01-audit-before.txt"
scripts/vm/06-scan.sh before 2>&1 | tee "$evidence/kubescape-before.log"
python3 scripts/vm/redact.py private/kubescape-before.json "$evidence/kubescape-before.json"

# 2–5. RBAC, Secret, SecurityContext/PSA, сеть
scripts/vm/02-rbac.sh 2>&1 | tee "$evidence/02-rbac.txt"
scripts/vm/03-secrets.sh 2>&1 | tee "$evidence/03-secrets.txt"
scripts/vm/04-pod-security.sh 2>&1 | tee "$evidence/04-pod-security.txt"
scripts/vm/05-network.sh 2>&1 | tee "$evidence/05-network.txt"

# 6. Повторный NSA, сравнение, итоговая проверка
scripts/vm/06-scan.sh after 2>&1 | tee "$evidence/kubescape-after.log"
python3 scripts/vm/redact.py private/kubescape-after.json "$evidence/kubescape-after.json"
python3 scripts/vm/compare.py "$evidence"
scripts/vm/audit.sh | tee "$evidence/08-audit-after.txt"
scripts/vm/verify.sh 2>&1 | tee "$evidence/09-final-verification.txt"
```

`00-prepare.sh` проверяет SHA-256 закреплённого Kubescape. Для обоих сканирований используются одни и те же файлы NSA, control inputs и exceptions. `06-scan.sh after` также удаляет неактивные ревизии приложений и выполняет server-side dry-run манифестов.

Для Falco выполните из терминала с TTY:

```bash
marker="DSO06_SPRINT_$(python3 -c 'import uuid; print(uuid.uuid4().hex)')"
scripts/vm/07-falco-event.sh "$marker"
```

В Falcosidekick UI найдите событие по маркеру и сохраните скриншот с правилом, namespace и командой. Используются установленные в DSO-06 Falco/Falcosidekick; событие вызывает обычное правило `Terminal shell in container`. Доступ к UI организуется через SSH-туннель и port-forward на `svc/falco-falcosidekick-ui:2802`, привязанные к `127.0.0.1`; учётные данные берутся из окружения ВМ и не сохраняются в репозитории.

## Данные и ограничения

В манифестах только демонстрационные credentials. Значения переменных проверяются внутри Pod без вывода. Base64 не шифрует Secret; encryption at rest не настраивалось. PostgreSQL использует учебное хранилище `emptyDir`, которое не сохраняет БД при пересоздании Pod.

Исходные JSON сканера, кеш, SSH-настройки и kubeconfig исключены из Git. Публикуемые JSON обработаны `redact.py`: скрыты Secret, значения ConfigMap/env и annotations; статусы проверок сохранены. Полный охват узла Kubescape без host scan/operator не обеспечивается; ограничения и остаточные FAIL указаны в отчёте.

Предыдущий вариант на Docker сохранён отдельно: [инструкция](README-DOCKER.md), [отчёт](REPORT-DOCKER.md), [проверки](REVIEW-DOCKER.md). Основные результаты этой работы относятся к ВМ и находятся в `manifests/vm/`, `scripts/vm/`, `screenshots/evidence/vm/run-20261103/`.
