# Отчёт о выполнении практики Kubernetes Security

При создании учебной виртуальной машины постоянно возникает ошибка: «Произошла ошибка при создании ресурса. Пожалуйста, повторите запрос позже или обратитесь к куратору». Поэтому работа выполнена на локальном Docker вместо выделенных для задания ВМ. Стенд — одноузловой K3s в k3d с поддержкой NetworkPolicy через kube-router.

## 1. Диагностика и аудит

Развёрнуты frontend/backend Deployments и backend Service на TCP 5432. В исходной конфигурации выявлены пять типов проблем:

| Тип | Namespace | Ресурс | Риск | Приоритет |
|---|---|---|---|---|
| Привилегированный контейнер | backend | Deployment/backend | Расширенный доступ к ядру узла, возможность выхода из контейнера | Критический |
| Пароль в ConfigMap | backend | ConfigMap/db-config, ключ password | Раскрытие credentials при чтении конфигурации | Высокий |
| Пароль в plaintext env | frontend | Deployment/frontend, DB_PASSWORD | Раскрытие пароля в манифестах Pod/Deployment и истории ревизий | Высокий |
| Использование default ServiceAccount | frontend | Deployment/frontend | Общая идентичность с избыточными правами через binding | Высокий |
| Wildcard RBAC | frontend / cluster-scoped | ClusterRole/lab-unsafe-wildcard, ClusterRoleBinding/lab-unsafe-default | Все действия над всеми ресурсами кластера | Критический |

JSONPath-запросы показали privileged, ServiceAccount, источники переменных окружения, данные ConfigMap, wildcard-правила и binding. `kubectl auth can-i '*' '*' --as=system:serviceaccount:frontend:default` вернул **yes**.

Доказательства: [JSONPath](screenshots/evidence/03-jsonpath-before.txt), [исходные проверки доступа](screenshots/evidence/04-access-before.txt), [Kubescape baseline JSON](screenshots/evidence/kubescape-before.json), [лог сканирования](screenshots/evidence/kubescape-before.log).

## 2. Исправление RBAC

Созданы ServiceAccount/frontend-sa, Role/frontend-reader и RoleBinding/frontend-reader в namespace frontend. Роль разрешает только `get/list` для pods/services. Deployment/frontend переведён на frontend-sa; монтирование SA token отключено, поскольку приложение не использует Kubernetes API.

ClusterRoleBinding/lab-unsafe-default и ClusterRole/lab-unsafe-wildcard удалены.

| Проверка | Результат |
|---|---|
| frontend-sa: get/list pods в frontend | yes / yes |
| frontend-sa: get/list services в frontend | yes / yes |
| frontend-sa: create/delete pods в frontend | no / no |
| frontend-sa: get secrets в frontend | no |
| frontend-sa: get pods в backend | no |
| default SA: wildcard-доступ | no |
| default SA: get secrets в backend | no |

Доказательства: [проверка can-i](screenshots/evidence/05-rbac-after.txt), [проверка с группами ServiceAccount](screenshots/evidence/20-review-rbac-secrets-psa.txt).

## 3. Миграция секретов

В каждом namespace создан отдельный Secret/db-secret типа Opaque с ключами `username` и `password` в `data` base64. Оба Deployment используют DB_USERNAME и DB_PASSWORD через `secretKeyRef` на Secret своего namespace.

Наличие переменных проверено внутри контейнеров через `test -n`, без вывода значений. ConfigMap/backend/db-config удалён. Прежние last-applied annotations и неактивные ReplicaSet с plaintext credentials удалены.

Все credentials вымышленные. Base64 не является шифрованием; encryption at rest в стенде не настраивалось.

Доказательства: [миграция и проверка env](screenshots/evidence/06-secrets.txt), [проверка Secret и Pod](screenshots/evidence/20-review-rbac-secrets-psa.txt).

## 4. Pod Security

В обоих Deployment настроены:

- `runAsNonRoot: true`, UID/GID 10001;
- `seccompProfile.type: RuntimeDefault`;
- `privileged: false`, `allowPrivilegeEscalation: false`;
- `readOnlyRootFilesystem: true`, `capabilities.drop: [ALL]`.

В backend включён `pod-security.kubernetes.io/enforce=baseline`, версия v1.34. Рабочие контейнеры запускаются с UID 10001. Старые privileged Pod удалены после rollout; PSA не завершает существующие Pod автоматически.

Попытка создать privileged Pod получила `Forbidden: violates PodSecurity "baseline:v1.34": privileged`. Проверено, что тестовый Pod не создан. Это автоматическая блокировка опасной конфигурации на Admission.

Доказательства: [SecurityContext и PSA rejection](screenshots/evidence/07-psa.txt), [повторная admission-проба](screenshots/evidence/20-review-rbac-secrets-psa.txt).

## 5. NetworkPolicy

В frontend и backend применены default-deny для Ingress/Egress. Разрешены:

- frontend `app=frontend` → backend `app=backend`, TCP 5432;
- frontend → CoreDNS в kube-system, UDP/TCP 53.

Для TCP 5432 настроены обе стороны: frontend Egress и backend Ingress. Namespace selector и Pod selector объединены в одном peer. Ответный трафик разрешённого соединения допускается conntrack.

| Проверка | Результат |
|---|---|
| outsider → backend:5432 до политик | Получен `lab-backend` |
| outsider → backend:5432 после политик | TCP отказ, nc exit 1 |
| frontend → backend Service:5432 после политик | Получен `lab-backend` |
| DNS lookup backend.backend.svc.cluster.local из frontend | Успешно |
| frontend → собственный listener:8080 | Получен `lab-frontend` |
| backend → frontend:8080 | TCP отказ, nc exit 1 |

У стороннего Pod также стоит `app=frontend`, но namespace outsider не соответствует разрешающей политике. Перед отрицательной пробой проверяется доступность контейнера и nc; тест фиксирует завершение nc и его код, поэтому ошибка `kubectl exec` не считается блокировкой трафика.

Доказательства: [проверки до/после политик](screenshots/evidence/08-network.txt), [повторные TCP-пробы](screenshots/evidence/19-review-final-verification.txt), [правила kube-router](screenshots/evidence/12-network-enforcement.txt).

## 6. Повторное сканирование и мониторинг

Выполнены два сканирования `kubescape scan framework nsa --format json --output ...` с `--keep-local` и `--host-scan=false`. Версия Kubescape — 4.0.16. Повторный запуск использовал сохранённый набор NSA. Оба сканирования выполнены до установки Falco.

| Метрика | До | После |
|---|---:|---:|
| FAIL controls | 13 | 11 |
| OK controls | 8 | 10 |
| Skipped / Action Required | 5 | 5 |
| Compliance score | 54,77% | 68,01% |
| C-0012: credentials in configuration, failed resources | 2 | 0 |
| C-0057: privileged container, failed resources | 1 | 0 |
| C-0016: privilege escalation, failed resources | 3 | 1 |
| C-0034: automatic SA mapping, failed resources | 4 | 2 |

Вручную исправлены RBAC, Secrets, SecurityContext и NetworkPolicy. Автоматическое предотвращение повторной опасной конфигурации подтверждено отказом PSA.

Доказательства: [before JSON](screenshots/evidence/kubescape-before.json), [after JSON](screenshots/evidence/kubescape-after.json), [сравнение всех controls](screenshots/evidence/comparison.md).

Falco 0.45.0 с modern eBPF и Falcosidekick 2.32.0 установлены через Helm chart 9.2.0. Выполнение shell-команды с уникальным маркером зарегистрировано правилом `DevSecOps Lab Shell Marker`. В Falcosidekick получен payload с совпадающими `evt.time`, `proc.pid` и `proc.cmdline`.

Доказательства: [событие и доставка](screenshots/evidence/18-review-falco.txt), [диагностика eBPF](screenshots/evidence/11-falco-startup.txt).

### Ограничения

Оставшиеся FAIL относятся к системным компонентам, системным RBAC, другим namespace и тестовому outsider. В сохранённом after JSON ресурсы frontend/backend не имеют failed controls.

C-0066/C-0067/C-0068 пропущены; C-0069/C-0070 не оценены без operator KubeletInfo. Host-scan отключён, облачный provider отсутствует. При повторном сканировании exceptions/controlInputs загружены из bundled defaults; после также добавлен outsider Pod. Сравнение охватывает одинаковые 26 control ID, но полная идентичность дополнительных policy inputs не обеспечена.

Falco использует лабораторное правило, без Kubernetes enrichment и API audit source. eBPF сообщает о недоступности части tracepoints и ограничении TOCTOU mitigation. Внешние outputs Falcosidekick не настроены.

## До/После

| Область | До | После |
|---|---|---|
| Backend privilege | privileged=true | non-root UID 10001, privileged=false |
| Пароль в ConfigMap | backend/db-config | ConfigMap удалён, Secret в каждом namespace |
| Frontend env | plaintext value | secretKeyRef |
| Frontend identity | default SA | frontend-sa с get/list pods/services |
| Default SA wildcard | yes | no, небезопасный binding удалён |
| Admission | Privileged Pod разрешался | PSA baseline отклоняет новый privileged Pod |
| outsider → backend | Доступен | Заблокирован |
| frontend → backend | Доступен | Разрешён TCP 5432 |
| Runtime-мониторинг | Отсутствовал | Falco фиксирует событие, Falcosidekick принимает payload |

Secure-манифесты прошли server-side dry-run; повторные проверки RBAC, Secrets, PSA и сети выполнены успешно. Инструкция запуска — в [README.md](README.md), список проверок — в [REVIEW.md](REVIEW.md).
