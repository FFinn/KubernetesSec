# Практическая работа по безопасности Kubernetes

При создании учебной виртуальной машины постоянно возникает ошибка: «Произошла ошибка при создании ресурса. Пожалуйста, повторите запрос позже или обратитесь к куратору». Поэтому работа выполнена на локальном Docker вместо выделенных для задания ВМ.

## Стенд

- k3d 5.9.0, K3s v1.34.5-k3s1, один узел с лимитом памяти 3 GiB.
- Flannel и встроенный контроллер NetworkPolicy kube-router.
- frontend и backend на BusyBox 1.37.0: TCP-порты 8080 и 5432. Backend — учебный TCP-сервис, возвращающий `lab-backend`.
- kubectl 1.34.5, Helm 4.2.3, Kubescape 4.0.16.

Результаты шести этапов — в [REPORT.md](REPORT.md), соответствие требованиям — в [REVIEW.md](REVIEW.md), сравнение сканирований — в [comparison.md](screenshots/evidence/comparison.md).

## Запуск

Требуются Docker Desktop, Python 3, bash, curl, k3d, Helm и Kubescape. На macOS инструменты можно установить через Homebrew:

```bash
brew install k3d kubescape helm
```

Из корня репозитория:

```bash
scripts/00-kubectl.sh
scripts/01-cluster.sh

# 1. Исходная уязвимая конфигурация и аудит
scripts/02-baseline.sh
scripts/audit-jsonpath.sh
scripts/scan.sh before

# 2–5. RBAC, Secrets, Pod Security и NetworkPolicy
scripts/03-rbac.sh
scripts/04-secrets.sh
scripts/05-pod-security.sh
scripts/06-network.sh

# 6. Повторный аудит и сравнение
scripts/07-final-audit.sh
scripts/scan.sh after
python3 scripts/compare-scans.py

# Runtime-мониторинг
scripts/08-falco.sh
```

Полный цикл выполняется на свежем кластере `devsecops-lab`. Baseline-скрипт отказывается применять уязвимую конфигурацию поверх исправленного состояния. Скрипты используют отдельный kubeconfig `.local/kubeconfig` и контекст `k3d-devsecops-lab`.

Повторный `scan.sh before/after` перезаписывает одноимённые отчёты. Перед новым циклом сохраните нужные результаты. Исходные JSON находятся в `.local/`, копии со скрытыми значениями Secret — в `screenshots/evidence/`.

## Манифесты

| Каталог | Назначение |
|---|---|
| `manifests/baseline/` | Исходные пять типов уязвимостей |
| `manifests/secure/` | Исправленные RBAC, Secrets, Deployment, PSA и NetworkPolicy |
| `manifests/tests/` | Privileged Pod для отрицательной пробы PSA и сторонний сетевой Pod |
| `monitoring/` | Конфигурация Falco/Falcosidekick |

Итоговую конфигурацию на чистом кластере можно применить отдельно:

```bash
bash
source scripts/env.sh
k apply -f manifests/secure/00-namespaces.yaml
k apply -f manifests/secure/10-rbac.yaml
k apply -f manifests/secure/20-workloads.yaml
k apply -f manifests/secure/30-network.yaml
```

Для перехода с baseline используйте этапные скрипты: они также удаляют небезопасные ClusterRoleBinding, ClusterRole, ConfigMap и неактивные ReplicaSet. Наборы baseline и secure не применяются одновременно; тестовый privileged Pod должен быть отклонён.

В Secret используются только вымышленные учебные credentials. Base64 не шифрует данные; encryption at rest не настраивалось. Kubeconfig и исходные выгрузки исключены из Git.

## Проверка результата

```bash
scripts/review-live.sh
scripts/verify-final.sh
scripts/08-falco.sh
```

Проверяются права ServiceAccount, Secret references, UID, SecurityContext, отказ PSA, разрешённые и запрещённые TCP-соединения. Falco-тест использует уникальный маркер и сопоставляет время события, PID и команду с payload Falcosidekick.

Ограничения Kubescape и eBPF описаны в [REPORT.md](REPORT.md). Для остановки стенда: `k3d cluster stop devsecops-lab`; для запуска: `k3d cluster start devsecops-lab`.
