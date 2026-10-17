# Отчёт о выполнении практики Kubernetes Security

Дата: 17 октября 2026, часовой пояс Asia/Yekaterinburg (UTC+5). Выполнено непосредственно на Mac в `/Users/alexandrvafin/PycharmProjects/KubernetesSec`. Результаты относятся к выделенному Docker/K3s-кластеру `devsecops-lab`, не к недоступным ВМ курса.

## 1. Исходный аудит

Работали frontend/backend Deployments и backend Service TCP 5432. Начальная конфигурация содержала намеренные учебные дефекты. Полный аудит: [JSONPath](screenshots/evidence/03-jsonpath-before.txt), [wildcard и TCP до изменений](screenshots/evidence/04-access-before.txt), [Kubescape до](screenshots/evidence/kubescape-before.json).

| Тип | Namespace | Ресурс | Риск | Приоритет |
|---|---|---|---|---|
| Privileged container | backend | Deployment/backend, Pod backend-686f678c4-wr2mj | Расширенный доступ к ядру Linux VM, возможность выхода из контейнера | Критический |
| Пароль в ConfigMap | backend | ConfigMap/db-config, ключ password | Чувствительные данные доступны читателям обычной конфигурации | Высокий |
| Plaintext env | frontend | Deployment/frontend, DB_PASSWORD | Пароль раскрывается при чтении Deployment/Pod и истории ревизий | Высокий |
| Default ServiceAccount | frontend | Deployment/frontend, Pod frontend-867bdc8454-pklsc | Общая идентичность, в сочетании с binding — полномочия на весь кластер | Высокий |
| Wildcard RBAC | frontend / cluster-scoped | ClusterRole/lab-unsafe-wildcard + ClusterRoleBinding/lab-unsafe-default → frontend/default | Все verbs/resources/apiGroups во всём кластере | Критический |

Само имя default SA не означает административных прав; опасность здесь доказана конкретным binding и `kubectl auth can-i '*' '*'` → **yes**. В baseline все значения credentials демонстрационные.

JSONPath использован для Pod SA/privileged, ConfigMap data, Deployment env sources, ClusterRole rules и binding subjects. В evidence демонстрационное значение заменено `[REDACTED_DEMO]`.

## 2. Исправление RBAC

Созданы frontend/frontend-sa, Role/frontend-reader и RoleBinding/frontend-reader. Роль разрешает только `get/list` для core pods/services в frontend. Deployment использует frontend-sa, автоматическое монтирование токена отключено, поскольку приложение не вызывает Kubernetes API. Роль проверена impersonation-командами, а не использованием токена приложения.

Исходные ClusterRoleBinding и ClusterRole **удалены**. [Полный вывод](screenshots/evidence/05-rbac-after.txt):

| Проверка для frontend-sa | Результат |
|---|---|
| get/list pods в frontend | yes / yes |
| get/list services в frontend | yes / yes |
| create/delete pods в frontend | no / no |
| get secrets в frontend | no |
| get pods в backend | no |
| default SA: wildcard на весь кластер | no |
| default SA: get secrets в backend | no |

Системные встроенные ClusterRole не изменялись: удалены только два специально созданных лабораторных объекта.

## 3. Миграция секретов

В frontend и backend созданы отдельные Secret/db-secret типа Opaque с ключами `username` и `password`, представленными в YAML как `data` base64. Pod не может ссылаться через `secretKeyRef` на Secret другого namespace. Оба Deployment используют DB_USERNAME/DB_PASSWORD через локальный Secret.

После rollout выполнен `test -n` внутри каждого рабочего контейнера: оба ключа доступны. Значения не печатались. ConfigMap/backend/db-config удалён; прежние last-applied annotations убраны, неактивные ReplicaSet с прежними Pod templates удалены перед финальным аудитом. [Доказательство](screenshots/evidence/06-secrets.txt), [финальный аудит](screenshots/evidence/09-final-audit.txt).

Удаление исторических шаблонов не является ротацией настоящего пароля. Для production нужны ротация, защищённое хранилище, encryption at rest/KMS и отдельные credentials по назначению. Здесь в обоих namespace используются только фиктивные учебные значения; реальных credentials нет.

## 4. SecurityContext и PSA

В обоих Deployment: runAsNonRoot, UID/GID 10001, RuntimeDefault seccomp, drop ALL capabilities, allowPrivilegeEscalation=false, readOnlyRootFilesystem=true, privileged=false. BusyBox listeners совместимы с этими настройками; TCP-порты выше 1024. `id` внутри обоих контейнеров показал uid=10001.

В backend включён `pod-security.kubernetes.io/enforce=baseline`, версия v1.34. Безопасные шаблоны применены до включения enforce. В момент установки метки API предупредил об ещё завершающихся старых privileged Pod; они не уничтожаются PSA автоматически и были дожданы/удалены вместе с неактивными ревизиями до финального аудита. В финале остался только backend Pod с privileged=false.

[Отрицательная проба](screenshots/evidence/07-psa.txt): API отклонил создание psa-privileged-probe с `Forbidden`, `violates PodSecurity "baseline:v1.34": privileged`. Проверено, что Pod отсутствует. Это **автоматическое предотвращение**, а не автоматическое исправление манифеста. ReadOnlyRootFilesystem — отдельное ужесточение, не требование baseline или Restricted.

## 5. Сетевая изоляция

В обоих namespace установлены default-deny Ingress/Egress. Дополнительные политики разрешают только frontend→backend TCP 5432 и frontend→CoreDNS UDP/TCP 53. Namespace selector и pod selector заданы в одном peer и работают как AND.

Проверка стороннего Pod сделана с меткой `app=frontend`, но в namespace outsider: одной подделки метки приложения недостаточно. До NetworkPolicy тот же Pod достигал backend listener. Это контроль против ложного вывода «порт закрыт из-за неработающего приложения».

| Реальная проверка | Результат |
|---|---|
| outsider → backend:5432 до политик | Получен lab-backend |
| outsider → backend:5432 после политик | TCP отказ / exit 1 |
| frontend DNS lookup backend.backend.svc.cluster.local | Успешно, Service IP получен |
| frontend → backend Service:5432 после политик | Получен lab-backend |
| frontend → собственный listener:8080 | Получен lab-frontend |
| backend → frontend Pod IP:8080 | TCP отказ / exit 1 |

[Вывод проверок](screenshots/evidence/08-network.txt), [правила KUBE-NWPLCY](screenshots/evidence/12-network-enforcement.txt). Фильтрация обеспечивается kube-router network policy controller K3s. Ответы backend на разрешённый TCP сеанс допускаются stateful conntrack даже при default-deny egress; инициативное backend→frontend не разрешено. Сеть не шифруется автоматически.

## 6. Повторный Kubescape и runtime-мониторинг

Команда в обоих случаях: `kubescape scan framework nsa --format json --output ...`, с явным lab context, `--keep-local`, `--host-scan=false`. Второй запуск использовал сохранённый исходный nsa.json. Версия 4.0.16, формат v2. Сканировался весь выделенный кластер; другие Docker-проекты в него не входят. После snapshot сделан **до установки Falco**, чтобы мониторинг со специальными полномочиями не менял сравнение приложений.

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

Полные [До](screenshots/evidence/kubescape-before.json), [После](screenshots/evidence/kubescape-after.json), [сравнение всех 26 controls](screenshots/evidence/comparison.md), исходные логи рядом. Критерий «минимум два исправления» выполнен вручную (RBAC, Secrets, SecurityContext, NetworkPolicy), автоматический admission deny доказан отдельно.

Остаточные FAIL включают системные CoreDNS/local-path-provisioner, системные RBAC и тестовый outsider. Некоторые controls имеют глобальный охват или устаревшие ожидания, например PSP; их нельзя объявлять пройденными на основании PSA. C-0066/C-0067/C-0068 имеют skipped; C-0069/C-0070 не оценены без operator KubeletInfo. Провайдер AWS/Azure/GKE отсутствует. Host-scan не включён. Coverage degraded в обоих запусках; во втором дополнительно отсутствовали локальные exceptions/controlInputs, использованы bundled defaults. Совпадение 26 control IDs подтверждено, но полная идентичность всех policy inputs не доказана. Числа отражают реальные результаты, а не строгое измерение при всех равных условиях. После добавлен outsider Pod.

**Falco/Falcosidekick реально работают:** Helm chart 9.2.0, Falco 0.45.0, modern eBPF, Falcosidekick 2.32.0. В 12:54:25 UTC (17:54:25 UTC+5) зарегистрирован syscall-event правила `DevSecOps Lab Shell Marker`, затем тот же payload принят Falcosidekick. [Событие и приём](screenshots/evidence/10-falco.txt), [диагностика запуска](screenshots/evidence/11-falco-startup.txt).

Использована безопасная команда `sh -c 'echo DEVSECOPS_LAB_EVENT >/dev/null; sleep 1'`. Правило специально ограничено маркером: это демонстрация runtime pipeline, не полноценный production ruleset. Container collectors отключены; Kubernetes enrichment и API audit source не подключены. Внешние outputs Falcosidekick не настроены. Modern eBPF работает в Linux VM, с предупреждениями о недоступных syscall tracepoints и ограничении TOCTOU mitigation. Нельзя делать вывод о полной видимости macOS/всех syscall. Скриншоты и события не имитировались.

## Итоговое До/После

| Область | До | После |
|---|---|---|
| Backend privilege | privileged=true | non-root UID 10001, privileged=false |
| Пароль в ConfigMap | backend/db-config | ConfigMap удалён, Secret в каждом namespace |
| Frontend env | plaintext value | secretKeyRef |
| Frontend identity | default SA | frontend-sa, get/list pods/services |
| Default SA wildcard | yes | no, небезопасный binding удалён |
| Admission | privileged Pod разрешался | PSA baseline отклоняет новый privileged Pod |
| Сеть outsider→backend | доступна | заблокирована |
| Сеть frontend→backend | доступна | доступна только по нужному порту |
| Runtime evidence | отсутствовало | реальное syscall событие и приём Falcosidekick |

Манифесты, скрипты и evidence находятся локально. Kubeconfig/raw артефакты исключены из Git. `.idea`/`.venv` сохранены. На момент выполнения и ревью коммиты и push не выполнялись. После ревью пользователь разрешил отправить работу в GitHub через origin `https://github.com/FFinn/KubernetesSec`; GitLab URL ожидается отдельно. Инструкция воспроизведения — [README.md](README.md).

## Заключительная проверка

`verify-final.sh` прошёл: API server dry-run принял весь secure-набор, проверены действующие Secret references и отсутствие plaintext env в Pod, удаление ConfigMap/binding, PSA labels и четыре NetworkPolicy. Повторные сетевые проверки успешны. [Вывод](screenshots/evidence/14-final-verification.txt). Повторно получено syscall-событие и его приём Falcosidekick: [проверка](screenshots/evidence/15-falco-verification.txt).

В сохранённом Kubescape after JSON ни один ресурс frontend/backend не имеет failed control; остаточные failures относятся к системным ресурсам, другим namespace и outsider. Это утверждение относится к снимку до установки Falco. Проверены исключения Git и права `.local`/kubeconfig: [результат](screenshots/evidence/16-artifact-verification.txt).

## Ревью готовности к сдаче

Все требования сопоставлены с конкретными доказательствами в [REVIEW.md](REVIEW.md). При ревью устранены ложные положительные результаты сетевого и Falco-тестов. Новые проверки: [сеть и dry-run](screenshots/evidence/19-review-final-verification.txt), [RBAC/Secrets/PSA](screenshots/evidence/20-review-rbac-secrets-psa.txt), [новое коррелированное Falco-событие](screenshots/evidence/18-review-falco.txt). Исходные снимки Kubescape сохранены.
