# Реальное сравнение Kubescape NSA

Kubescape 4.0.16; до 2026-10-17T12:51:53Z, после 2026-10-17T12:53:21Z (UTC).

| Метрика | До | После |
|---|---:|---:|
| FAIL | 13 | 11 |
| OK | 8 | 10 |
| Пропущено / Action Required | 5 | 5 |
| Compliance score | 54.77% | 68.01% |

FAIL/OK — статусы controls всего локального кластера, а не число отдельных дефектов. Набор NSA содержит одинаковые 26 control ID. После появился тестовый outsider Pod; системные ресурсы включены в оба снимка.

| Control | Статус до → после | Failed resources до → после |
|---|---|---|
| C-0002: Prevent containers from allowing command execution | failed → failed | 2 → 1 |
| C-0005: API server insecure port is enabled | passed → passed | 0 → 0 |
| C-0012: Applications credentials in configuration files | failed → passed | 2 → 0 |
| C-0013: Non-root containers | failed → failed | 4 → 3 |
| C-0016: Allow privilege escalation | failed → failed | 3 → 1 |
| C-0017: Immutable container filesystem | failed → failed | 3 → 2 |
| C-0030: Ingress and Egress blocked | failed → failed | 4 → 3 |
| C-0034: Automatic mapping of service account | failed → failed | 4 → 2 |
| C-0035: Administrative Roles | failed → failed | 2 → 1 |
| C-0038: Host PID/IPC privileges | passed → passed | 0 → 0 |
| C-0041: HostNetwork access | passed → passed | 0 → 0 |
| C-0044: Container hostPort | passed → passed | 0 → 0 |
| C-0046: Insecure capabilities | passed → passed | 0 → 0 |
| C-0054: Cluster internal networking | failed → failed | 7 → 5 |
| C-0055: Linux hardening | failed → failed | 4 → 2 |
| C-0057: Privileged container | failed → passed | 1 → 0 |
| C-0058: CVE-2021-25741 - Using symlink for arbitrary host file system access. | passed → passed | 0 → 0 |
| C-0059: CVE-2021-25742-nginx-ingress-snippet-annotation-vulnerability | passed → passed | 0 → 0 |
| C-0066: Secret/etcd encryption enabled | skipped → skipped | 0 → 0 |
| C-0067: Audit logs enabled | skipped → skipped | 0 → 0 |
| C-0068: PSP enabled | skipped → skipped | 0 → 0 |
| C-0069: Disable anonymous access to Kubelet service | skipped → skipped | 0 → 0 |
| C-0070: Enforce Kubelet client TLS authentication | skipped → skipped | 0 → 0 |
| C-0270: Ensure CPU limits are set | failed → failed | 2 → 2 |
| C-0271: Ensure memory limits are set | failed → failed | 1 → 1 |
| C-0292: Nginx Ingress Controller End of Life | passed → passed | 0 → 0 |

Ограничения: host-scan отключён; C-0069/C-0070 не оценены без operator KubeletInfo; облачный provider отсутствует. В повторном запуске --use-from использует исходный nsa.json; exceptions/controlInputs взяты из bundled defaults из-за отсутствия локальных файлов (см. лог). Поэтому сравнение отражает наблюдение, но не является строгим сертификационным измерением при полностью зафиксированных inputs.

JSON сохранён с редактированием Secret data и last-applied annotation; статусы/счётчики не менялись. Исходные JSON доступны только в игнорируемой .local/.
