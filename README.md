# Практическая работа: безопасность Kubernetes

Реальная лаборатория на macOS Apple Silicon / Docker Desktop, выполнена 17.10.2026. Все шесть шагов и runtime-событие Falco подтверждены выводами в [screenshots/evidence](screenshots/evidence/). Основной отчёт — [REPORT.md](REPORT.md), машинное сравнение — [comparison.md](screenshots/evidence/comparison.md).

## Стенд

Одноузловой **k3d 5.9.0 / K3s v1.34.5-k3s1**, имя `devsecops-lab`. Узел ограничен 3 GiB RAM; Docker Desktop имеет около 8 GiB, Mac — 32 GiB / 10 CPU. Traefik, ServiceLB и metrics-server отключены. Порты приложений на Mac не публикуются; API доступен через локальный Docker mapping. Другие контейнеры пользователя не останавливались.

Flannel обеспечивает сеть, **встроенный K3s network policy controller на основе kube-router** — исполнение стандартных NetworkPolicy. Это не установка Calico: работа фильтрации доказана изменением доступности TCP и наличием iptables KUBE-NWPLCY. [Документация K3s](https://docs.k3s.io/networking/networking-services/), [kube-router](https://www.kube-router.io/docs/user-guide/).

Frontend и backend — BusyBox 1.37.0, реальные TCP listeners на 8080 и 5432. Backend возвращает `lab-backend`; это учебный TCP-сервис, не PostgreSQL. Все credentials с `DEMO_ONLY` вымышлены. Kubernetes Secret base64 не является шифрованием; KMS/encryption at rest в этой лаборатории не настраивались.

## Подготовка

Рабочий каталог: `/Users/alexandrvafin/PycharmProjects/KubernetesSec`. Исходный `origin`: `https://github.com/FFinn/KubernetesSec` (на момент начала remote без refs). Существовавшие `.idea/` и `.venv/` сохранены и исключены из Git. Первоначальная подготовка и ревью выполнялись без push. После ревью пользователь разрешил отправку в этот GitHub-репозиторий.

Нужны Docker Desktop, Python 3, bash, Git, curl и Homebrew. Установленные версии: Helm 4.2.3, Kubescape 4.0.16. При отсутствии: `brew install k3d kubescape helm`. Для воспроизводимости используйте указанные версии; новые версии сканера могут изменить оценки.

Системный kubectl 1.36.3 отличается от Kubernetes 1.34 на две minor версии. Для дальнейших проверок скачан **kubectl 1.34.5** с официального dl.k8s.io, checksum проверен. Он лежит только в `.local/bin`, системный бинарник не заменён.

```bash
cd /Users/alexandrvafin/PycharmProjects/KubernetesSec
scripts/00-kubectl.sh
scripts/01-cluster.sh
```

Kubeconfig хранится в `.local/kubeconfig` (0600), каталог `.local` — 0700. Скрипты явно выбирают контекст `k3d-devsecops-lab` и отдельный kubeconfig; пользовательский текущий контекст не переключается. Скрипты запускайте как файлы или из **bash**; не выполняйте `source scripts/env.sh` из zsh.

## Воспроизведение шести шагов

Для повторения полного цикла нужен свежий выделенный кластер без secure state. Существующее защищённое состояние скрипт baseline не понижает. Скрипты не удаляют кластер автоматически.

```bash
# 1. Намеренно уязвимый исходный стенд и аудит
scripts/02-baseline.sh
scripts/audit-jsonpath.sh
scripts/scan.sh before
# 2. Минимальные права и удаление wildcard binding
scripts/03-rbac.sh
# 3. Отдельные Secret в каждом namespace, удаление ConfigMap
scripts/04-secrets.sh
# 4. Non-root / SecurityContext, PSA baseline, отрицательная проба
scripts/05-pod-security.sh
# 5. Default deny, DNS и взаимные разрешения TCP 5432
scripts/06-network.sh
# 6. Удаление только неактивных лабораторных ReplicaSet и повторный аудит
scripts/07-final-audit.sh
scripts/scan.sh after
python3 scripts/compare-scans.py
# Дополнительно: Falco + Falcosidekick
scripts/08-falco.sh
```

Скрипты возвращают ненулевой код при нарушении проверок. `scan.sh` сохраняет raw JSON в `.local/`, редактированную копию — в evidence. Остальные выводы для нового запуска сохраняйте через `> новый-файл.txt 2>&1`; имеющиеся evidence относятся к фактическому первому выполнению и автоматически не обновляются всеми скриптами. `scan.sh before/after` и `compare-scans.py` перезаписывают одноимённые результаты, поэтому перед новым циклом сохраните нужный набор.

## Манифесты

`manifests/baseline/` — намеренно уязвимое состояние, только для изолированной лаборатории. `manifests/secure/` — итоговое. Не применять оба набора одновременно и не выполнять `kubectl apply -R -f manifests/`: тестовый privileged Pod должен быть отклонён.

Для чистого кластера итоговая конфигурация применяется так:

```bash
bash
source scripts/env.sh
k apply -f manifests/secure/00-namespaces.yaml
k apply -f manifests/secure/10-rbac.yaml
k apply -f manifests/secure/20-workloads.yaml
k apply -f manifests/secure/30-network.yaml
```

При переходе с baseline используйте этапные скрипты: `apply` secure-файлов сам не удаляет прежний ClusterRoleBinding, ConfigMap и старые ReplicaSet. Скрипты делают это явно. Отрицательные тесты и outsider Pod находятся в `manifests/tests/`.

Разрешён frontend `app=frontend` в namespace frontend → backend `app=backend` в namespace backend, TCP 5432; DNS frontend → CoreDNS в kube-system, UDP/TCP 53. Остальные ingress/egress frontend/backend блокируются. Ответы на разрешённые соединения пропускаются conntrack; отдельный backend egress для ответа не нужен. Backend DNS не требуется и не разрешён.

## Мониторинг и ограничения

[Falco Helm chart 9.2.0](https://github.com/falcosecurity/charts/tree/master/charts/falco), Falco 0.45.0, Falcosidekick 2.32.0. `monitoring/falco-values.yaml` включает только специально помеченное лабораторное syscall-правило; общего production ruleset нет. Контейнерные collectors отключены; событие не обогащается Kubernetes metadata. Falcosidekick пишет приём события локально, внешних outputs нет. Команда с уникальным UUID-маркером безопасна и не выводит credentials. Проверка сопоставляет evt.time, PID и команду в обоих компонентах, старые события не засчитываются.

Modern eBPF работает в Linux VM Docker Desktop, а не в ядре macOS. Есть warnings о tracepoints и TOCTOU mitigation; полная видимость всех syscall не заявляется. См. реальное событие и диагностику в `10-falco.txt`/`11-falco-startup.txt`. API audit source не подключён: PSA rejection подтверждается kubectl, не Falco. [Официальное описание eBPF](https://falco.org/docs/concepts/event-sources/kernel/).

Kubescape NSA сканировался до установки Falco, без host-scan. Его JSON не является доказательством шифрования etcd или настройки kubelet. В `comparison.md` подробно указаны пропущенные controls и различие загрузки input defaults. Не считать итоговый балл сертификатом безопасности.

## Завершение и публикация

Стенд оставлен работающим. После просмотра можно остановить **только его** командой `k3d cluster stop devsecops-lab`; возобновление — `k3d cluster start devsecops-lab`. Удаление не выполнялось. Документы, учебные манифесты и evidence готовы для проверки пользователем. По последующему указанию пользователя GitHub настроен как `origin`: [FFinn/KubernetesSec](https://github.com/FFinn/KubernetesSec), основная ветка `main`. GitLab URL ожидается отдельно; отправка в GitLab не выполнялась.

## Ревью готовности к сдаче

Все требования сопоставлены с конкретными доказательствами в [REVIEW.md](REVIEW.md). При ревью устранены ложные положительные результаты сетевого и Falco-тестов. Новые проверки: [сеть и dry-run](screenshots/evidence/19-review-final-verification.txt), [RBAC/Secrets/PSA](screenshots/evidence/20-review-rbac-secrets-psa.txt), [новое коррелированное Falco-событие](screenshots/evidence/18-review-falco.txt). Исходные снимки Kubescape сохранены.
