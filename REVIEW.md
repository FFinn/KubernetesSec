# Ревью готовности к сдаче

Проверено 17.10.2026. Источник требований: предоставленный пользователем `KubernetesSec_DevSecOps_chat_handoff.md`, раздел 4, и прямое задание в этом чате. Проверены все текущие файлы (на момент ревью репозиторий был без коммитов), сохранённые evidence и действующий кластер. Подход: отдельные проверки требований и реализации, затем исправления и реальные повторные проверки.

**Вердикт:** все шесть шагов выполнены; блокирующих недочётов для сдачи по переданному заданию не осталось. На момент ревью публикация не выполнялась. Полного соответствия NSA и полной runtime-видимости стенд не заявляет. Отдельный прогон создания второго кластера с нуля не выполнялся: проверены фактический первый запуск, текущий API dry-run и повторяемые проверки действующего стенда.

## Standards — реализация

1. Исправлен P2: отрицательный сетевой тест раньше считал любой ненулевой `kubectl exec` доказательством изоляции. Теперь внутри контейнера проверяется наличие nc, исполняется TCP-проба, печатаются маркер завершения, код nc и elapsed. Ошибка API/exec или отсутствие утилиты не засчитываются. Положительные контроли проверяют оба listener. Новый результат: [19-review-final-verification.txt](screenshots/evidence/19-review-final-verification.txt).
2. Усилена подготовка `.local`: создание и 0700 выполняются и в setup-cluster, и в установке локального kubectl. Это устраняет зависимость от существовавшей папки первого запуска.
3. Baseline-скрипт теперь отказывается восстанавливать уязвимости не только при PSA baseline, но и при Restricted либо уже созданном frontend-sa. Имена исходных ресурсов и пользовательские файлы сохранены.

Стилевые упрощения генератора не нужны для выполнения спринта; изменения ограничены работоспособностью проверок и защитой воспроизведения. Публичные копии evidence не содержат kubeconfig/приватных ключей; учебные credentials намеренно обозначены как фиктивные.

## Spec — соответствие заданию

1. Исправлен P2: Falco-тест мог принять старый постоянный маркер. Теперь для каждого запуска используется UUID-маркер; Python-проверка требует **новое** syscall-событие и идентичные evt.time, proc.pid, proc.cmdline в Falco и Falcosidekick. [18-review-falco.txt](screenshots/evidence/18-review-falco.txt) подтверждает новый запуск.
2. Уточнена формулировка сетевых результатов: kube-router может REJECT-ить TCP до истечения nc timeout. Отказ соединения подтверждён, но именно истечение полного тайм-аута не заявляется. Черновая проверка с завышенным порогом времени оставлена в `17-review-final-verification.txt` для прозрачности; она заменена успешной проверкой 19. Это не дефект сетевой политики.
3. Добавлены повторная RBAC-проверка с реальными группами ServiceAccount, проверка точного состава Role, Secret keys, non-root UID, отсутствия смонтированного SA token, удаления небезопасных объектов и новая admission-проба. Все прошли: [20-review-rbac-secrets-psa.txt](screenshots/evidence/20-review-rbac-secrets-psa.txt).

## Матрица требований и доказательств

| Требование | Статус | Доказательство |
|---|---|---|
| Локальный Mac, каталог/Git, Docker/архитектура/инструменты | Выполнено | [00-environment](screenshots/evidence/00-environment.txt), [README](README.md) |
| Реальный Kubernetes на Docker, ограничение памяти | Выполнено | [01-cluster](screenshots/evidence/01-cluster.txt), scripts/01-cluster.sh |
| Действующая NetworkPolicy | Выполнено | [12-network-enforcement](screenshots/evidence/12-network-enforcement.txt), [08-network](screenshots/evidence/08-network.txt), [19-repeat](screenshots/evidence/19-review-final-verification.txt) |
| 1: privileged backend | Выполнено | [03-jsonpath-before](screenshots/evidence/03-jsonpath-before.txt) |
| 1: пароль в backend/db-config | Выполнено | Тот же JSONPath, значение редактировано |
| 1: plaintext env frontend | Выполнено | Тот же JSONPath |
| 1: default SA frontend | Выполнено | Тот же JSONPath |
| 1: wildcard ClusterRole + binding | Выполнено | Тот же JSONPath и [04-access-before](screenshots/evidence/04-access-before.txt) |
| 1: Kubescape NSA baseline JSON/лог | Выполнено | [before JSON](screenshots/evidence/kubescape-before.json), [лог](screenshots/evidence/kubescape-before.log) |
| 1: таблица namespace/resource/risk/priority | Выполнено | REPORT.md, раздел 1 |
| 2: frontend-sa + Role/RoleBinding get/list pods/services | Выполнено | manifests/secure/10-rbac.yaml; [05-rbac](screenshots/evidence/05-rbac-after.txt), [20-current](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 2: Deployment использует frontend-sa; проверки allow/deny | Выполнено | [05-rbac](screenshots/evidence/05-rbac-after.txt), [19-current](screenshots/evidence/19-review-final-verification.txt), [20-current](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 2: default SA больше не имеет wildcard, binding удалён | Выполнено | [05-rbac](screenshots/evidence/05-rbac-after.txt), [20-current](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 3: Secret/db-secret Opaque, username/password data base64 | Выполнено | manifests/secure/20-workloads.yaml; [20-current](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 3: отдельный Secret frontend, secretKeyRef, env внутри Pod | Выполнено | [06-secrets](screenshots/evidence/06-secrets.txt), [20-current](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 3: исходный ConfigMap удалён; значения не выводятся | Выполнено | Те же выводы; scripts/redact-scan.py |
| 4: PSA baseline backend, non-root/без privilege escalation | Выполнено | manifests/secure; [07-psa](screenshots/evidence/07-psa.txt), [20-current](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 4: privileged Pod получает именно Admission rejection | Выполнено | [07-psa](screenshots/evidence/07-psa.txt), [20-current](screenshots/evidence/20-review-rbac-secrets-psa.txt) |
| 5: обе default-deny, frontend egress/backend ingress 5432 | Выполнено | manifests/secure/30-network.yaml, [19-current](screenshots/evidence/19-review-final-verification.txt) |
| 5: DNS UDP/TCP 53 к CoreDNS | Выполнено | Та же политика; DNS lookup в 08 и 19 |
| 5: listener и разрешённый frontend→backend | Выполнено | 04 до, 08 после, 19 повторно |
| 5: отказ outsider→backend, backend→frontend | Выполнено | 08 исторически; 19 усиленная проверка nc rc=1 |
| 6: Kubescape JSON after, сравнение FAIL/OK | Выполнено с ограничениями | [after](screenshots/evidence/kubescape-after.json), [comparison](screenshots/evidence/comparison.md) |
| 6: минимум два ручных исправления и автоматический PSA deny | Выполнено | Исправлены RBAC, Secrets, SecurityContext и сеть; 07/20 — deny |
| 6: Falco/Falcosidekick при возможности | Выполнено | [10-event](screenshots/evidence/10-falco.txt), [18-new-correlated-event](screenshots/evidence/18-review-falco.txt) |
| Apply-ready baseline/secure, автоматизация и русские документы | Выполнено | manifests/, scripts/, README/REPORT; 19 server dry-run |
| Реальные выводы и понятное До/После | Выполнено | screenshots/evidence/, REPORT, comparison |
| Нет реальных секретов/kubeconfig в составе сдачи; нет push | Выполнено | .gitignore, [16-permissions](screenshots/evidence/16-artifact-verification.txt), [21-review-integrity](screenshots/evidence/21-review-integrity.txt) |

## Ограничения, которые нужно оставить в сдаче

- Kubescape after: FAIL 11, OK 10, skipped 5, score 68,01%; это не сертификат полного соответствия NSA. Системные компоненты, outsider и неоценённые host/cloud controls объяснены в REPORT.
- Baseline/after — настоящие снимки разных состояний. Набор 26 controls совпадает и сохранён nsa-policy.json, но загрузка дополнительных policy inputs различалась, после появился outsider. Не представлять разницу балла как строго контролируемый эксперимент. Это не заменяет конкретные доказательства RBAC/Secrets/PSA/NetworkPolicy, которые проверены отдельно.
- After JSON отражает состояние до установки Falco. Новый скан всего кластера теперь включал бы мониторинг с особыми полномочиями и не был бы сопоставим без пояснения; старый снимок не перезаписывался.
- Falco использует специально помеченное лабораторное правило, без API audit source и Kubernetes enrichment; eBPF tracepoint warnings сохранены. Это доказательство работающей доставки события, не полный набор production detections.
- Старый `04-access-before.txt` содержит только два результата. Их происхождение — фактический запуск `kubectl auth can-i '*' '*' --as=system:serviceaccount:frontend:default` и TCP nc из frontend в backend под отдельным lab kubeconfig (scripts/env.sh). Сам файл исторический и не дополнен выдуманным timestamp. Wildcard независимо виден в исходном JSONPath и baseline Kubescape.
- Формат задания допускает реальные выводы в evidence. Отдельные изображения терминала не требуются по переданному конспекту; имитированных скриншотов нет.

Для проверки перед сдачей: `scripts/review-live.sh`, `scripts/verify-final.sh`, `scripts/08-falco.sh`. Последний выполняет повторное применение существующего Helm release и вызывает только безопасную команду с маркером. Не запускать baseline поверх secure. После ревью пользователь дал отдельное указание отправить работу в GitHub `FFinn/KubernetesSec` через origin; это не меняет зафиксированные результаты ревью.
