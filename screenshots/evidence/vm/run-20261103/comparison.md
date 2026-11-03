# Сравнение Kubescape NSA

Kubescape v4.0.16. До: 2026-11-03T02:55:48Z; после: 2026-11-03T03:05:25Z (UTC).

| Метрика | До | После |
|---|---:|---:|
| FAIL controls | 19 | 19 |
| OK controls | 5 | 5 |
| Пропущено controls | 2 | 2 |
| Compliance score | 53.88% | 56.92% |

Набор из 26 control ID и версия сканера совпадают. FAIL/OK обозначают статусы controls, а не количество отдельных дефектов.

| Control | До → после | Failed resources до → после |
|---|---|---:|
| C-0002: Prevent containers from allowing command execution | failed → failed | 4 → 2 |
| C-0005: API server insecure port is enabled | passed → passed | 0 → 0 |
| C-0012: Applications credentials in configuration files | failed → failed | 5 → 3 |
| C-0013: Non-root containers | failed → failed | 25 → 23 |
| C-0016: Allow privilege escalation | failed → failed | 15 → 13 |
| C-0017: Immutable container filesystem | failed → failed | 19 → 17 |
| C-0030: Ingress and Egress blocked | failed → failed | 30 → 28 |
| C-0034: Automatic mapping of service account | failed → failed | 31 → 29 |
| C-0035: Administrative Roles | failed → failed | 4 → 2 |
| C-0038: Host PID/IPC privileges | passed → passed | 0 → 0 |
| C-0041: HostNetwork access | failed → failed | 9 → 9 |
| C-0044: Container hostPort | passed → passed | 0 → 0 |
| C-0046: Insecure capabilities | failed → failed | 1 → 1 |
| C-0054: Cluster internal networking | failed → failed | 15 → 13 |
| C-0055: Linux hardening | failed → failed | 13 → 11 |
| C-0057: Privileged container | failed → failed | 5 → 4 |
| C-0058: CVE-2021-25741 - Using symlink for arbitrary host file system access. | passed → passed | 0 → 0 |
| C-0059: CVE-2021-25742-nginx-ingress-snippet-annotation-vulnerability | passed → passed | 0 → 0 |
| C-0066: Secret/etcd encryption enabled | failed → failed | 1 → 1 |
| C-0067: Audit logs enabled | failed → failed | 1 → 1 |
| C-0068: PSP enabled | failed → failed | 1 → 1 |
| C-0069: Disable anonymous access to Kubelet service | skipped → skipped | 0 → 0 |
| C-0070: Enforce Kubelet client TLS authentication | skipped → skipped | 0 → 0 |
| C-0270: Ensure CPU limits are set | failed → failed | 31 → 29 |
| C-0271: Ensure memory limits are set | failed → failed | 26 → 24 |
| C-0292: Nginx Ingress Controller End of Life | failed → failed | 1 → 1 |

## Ресурсы frontend/backend

| Namespace | Ресурс | Control | До | После |
|---|---|---|---|---|
| backend | /backend/ServiceAccount/default/rbac.authorization.k8s.io/v1//ClusterRole/unsafe-role/rbac.authorization.k8s.io/v1//ClusterRoleBinding/unsafe-binding-backend | C-0002 | FAIL | Нет FAIL |
| backend | /backend/ServiceAccount/default/rbac.authorization.k8s.io/v1//ClusterRole/unsafe-role/rbac.authorization.k8s.io/v1//ClusterRoleBinding/unsafe-binding-backend | C-0035 | FAIL | Нет FAIL |
| backend | /v1/backend/ConfigMap/db-config | C-0012 | FAIL | Нет FAIL |
| backend | apps/v1/backend/Deployment/backend | C-0013 | FAIL | Нет FAIL |
| backend | apps/v1/backend/Deployment/backend | C-0016 | FAIL | Нет FAIL |
| backend | apps/v1/backend/Deployment/backend | C-0017 | FAIL | Нет FAIL |
| backend | apps/v1/backend/Deployment/backend | C-0030 | FAIL | Нет FAIL |
| backend | apps/v1/backend/Deployment/backend | C-0034 | FAIL | Нет FAIL |
| backend | apps/v1/backend/Deployment/backend | C-0055 | FAIL | Нет FAIL |
| backend | apps/v1/backend/Deployment/backend | C-0057 | FAIL | Нет FAIL |
| backend | apps/v1/backend/Deployment/backend | C-0270 | FAIL | Нет FAIL |
| backend | apps/v1/backend/Deployment/backend | C-0271 | FAIL | Нет FAIL |
| frontend | /frontend/ServiceAccount/default/rbac.authorization.k8s.io/v1//ClusterRole/unsafe-role/rbac.authorization.k8s.io/v1//ClusterRoleBinding/unsafe-binding-frontend | C-0002 | FAIL | Нет FAIL |
| frontend | /frontend/ServiceAccount/default/rbac.authorization.k8s.io/v1//ClusterRole/unsafe-role/rbac.authorization.k8s.io/v1//ClusterRoleBinding/unsafe-binding-frontend | C-0035 | FAIL | Нет FAIL |
| frontend | apps/v1/frontend/Deployment/frontend | C-0012 | FAIL | Нет FAIL |
| frontend | apps/v1/frontend/Deployment/frontend | C-0013 | FAIL | Нет FAIL |
| frontend | apps/v1/frontend/Deployment/frontend | C-0016 | FAIL | Нет FAIL |
| frontend | apps/v1/frontend/Deployment/frontend | C-0017 | FAIL | Нет FAIL |
| frontend | apps/v1/frontend/Deployment/frontend | C-0030 | FAIL | Нет FAIL |
| frontend | apps/v1/frontend/Deployment/frontend | C-0034 | FAIL | Нет FAIL |
| frontend | apps/v1/frontend/Deployment/frontend | C-0055 | FAIL | Нет FAIL |
| frontend | apps/v1/frontend/Deployment/frontend | C-0270 | FAIL | Нет FAIL |
| frontend | apps/v1/frontend/Deployment/frontend | C-0271 | FAIL | Нет FAIL |

«Нет FAIL» означает отсутствие failed-записи для этой пары ресурс/control; ресурс мог быть изменён или удалён. Это не заменяет статус проверки в JSON.

Остаточные failed-записи frontend/backend: **0**.

## Охват сканирования

| Снимок | Coverage score | Не оценены |
|---|---:|---|
| До | 83.31% | C-0069, C-0070 |
| После | 83.31% | C-0069, C-0070 |

Причины неполного охвата и пропущенных проверок указаны в логах сканирования и scanCoverage соответствующих JSON.
