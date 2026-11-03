#!/usr/bin/env python3
"""Compare preserved Kubescape v2 JSON snapshots in an evidence directory."""

import argparse
from collections import Counter
import json
from pathlib import Path
import re


STATUSES = {"failed": "FAIL", "passed": "OK", "skipped": "Пропущено"}


def status(value):
    if isinstance(value, dict):
        value = value.get("status", "unknown")
    return str(value)


def cell(value):
    return str(value).replace("|", "\\|").replace("\n", " ")


def scoped_failures(report):
    failures = set()
    for result in report.get("results", []):
        resource_id = result.get("resourceID", "")
        match = re.search(r"/(frontend|backend)/", resource_id)
        if not match:
            continue
        for control in result.get("controls", []):
            if status(control.get("status")) == "failed":
                failures.add((match.group(1), resource_id, control["controlID"]))
    return failures


def generate(before, after):
    controls_before = before["summaryDetails"]["controls"]
    controls_after = after["summaryDetails"]["controls"]
    versions = [report["metadata"]["scanMetadata"]["kubescapeVersion"] for report in (before, after)]
    if versions[0] != versions[1]:
        raise ValueError("Версии Kubescape различаются; сравнение не сформировано")
    if set(controls_before) != set(controls_after):
        raise ValueError("Наборы control ID различаются; сравнение не сформировано")

    counters = [Counter(status(control.get("status")) for control in controls.values())
                for controls in (controls_before, controls_after)]
    lines = [
        "# Сравнение Kubescape NSA", "",
        f"Kubescape {cell(versions[0])}. До: {cell(before['generationTime'])}; "
        f"после: {cell(after['generationTime'])} (UTC).", "",
        "| Метрика | До | После |", "|---|---:|---:|",
    ]
    for key, title in STATUSES.items():
        lines.append(f"| {title} controls | {counters[0][key]} | {counters[1][key]} |")
    other = set(counters[0]) | set(counters[1])
    for key in sorted(other - set(STATUSES)):
        lines.append(f"| {cell(key)} controls | {counters[0][key]} | {counters[1][key]} |")
    scores = [report["summaryDetails"]["complianceScore"] for report in (before, after)]
    lines.append(f"| Compliance score | {scores[0]:.2f}% | {scores[1]:.2f}% |")
    lines.extend([
        "", f"Набор из {len(controls_before)} control ID и версия сканера совпадают. "
        "FAIL/OK обозначают статусы controls, а не количество отдельных дефектов.", "",
        "| Control | До → после | Failed resources до → после |", "|---|---|---:|",
    ])
    for control_id in sorted(controls_before):
        old, new = controls_before[control_id], controls_after[control_id]
        old_count = old["ResourceCounters"]["failedResources"]
        new_count = new["ResourceCounters"]["failedResources"]
        old_status, new_status = status(old.get("status")), status(new.get("status"))
        lines.append(f"| {cell(control_id)}: {cell(new['name'])} | "
                     f"{cell(old_status)} → {cell(new_status)} | {old_count} → {new_count} |")

    before_failures, after_failures = [scoped_failures(report) for report in (before, after)]
    lines.extend([
        "", "## Ресурсы frontend/backend", "",
        "| Namespace | Ресурс | Control | До | После |", "|---|---|---|---|---|",
    ])
    for namespace, resource_id, control_id in sorted(before_failures | after_failures):
        key = (namespace, resource_id, control_id)
        old = "FAIL" if key in before_failures else "Нет FAIL"
        new = "FAIL" if key in after_failures else "Нет FAIL"
        lines.append(f"| {namespace} | {cell(resource_id)} | {cell(control_id)} | {old} | {new} |")
    if not (before_failures | after_failures):
        lines.append("| frontend/backend | Все оценённые ресурсы | — | Нет FAIL | Нет FAIL |")
    lines.extend([
        "", "«Нет FAIL» означает отсутствие failed-записи для этой пары ресурс/control; "
        "ресурс мог быть изменён или удалён. Это не заменяет статус проверки в JSON.",
        "", f"Остаточные failed-записи frontend/backend: **{len(after_failures)}**.",
    ])

    if any(report.get("scanCoverage") for report in (before, after)):
        lines.extend(["", "## Охват сканирования", "",
                      "| Снимок | Coverage score | Не оценены |", "|---|---:|---|"])
        for label, report in [("До", before), ("После", after)]:
            coverage = report.get("scanCoverage") or {}
            score = coverage.get("coverageScore")
            score_text = f"{score:.2f}%" if isinstance(score, (int, float)) else "—"
            pending = coverage.get("notEvaluatedControls", [])
            if isinstance(pending, dict):
                pending = list(pending)
            ids = []
            for control in pending:
                ids.append(control.get("controlID", control.get("id", "unknown"))
                           if isinstance(control, dict) else str(control))
            lines.append(f"| {label} | {score_text} | {cell(', '.join(ids) or '—')} |")
        lines.extend(["", "Причины неполного охвата и пропущенных проверок указаны в логах "
                      "сканирования и scanCoverage соответствующих JSON."])
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path, help="Каталог с kubescape-before.json и kubescape-after.json")
    args = parser.parse_args()
    try:
        before, after = [json.loads((args.directory / f"kubescape-{stage}.json").read_text())
                         for stage in ("before", "after")]
        result = generate(before, after)
    except (OSError, ValueError, KeyError, TypeError) as error:
        parser.exit(1, f"Не удалось сформировать сравнение: {error}\n")
    (args.directory / "comparison.md").write_text(result, encoding="utf-8")
    print("Сравнение сохранено в comparison.md")


if __name__ == "__main__":
    main()
