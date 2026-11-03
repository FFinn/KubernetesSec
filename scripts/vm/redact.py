#!/usr/bin/env python3
"""Create shareable JSON evidence while keeping raw Kubernetes data private.

Usage: python3 scripts/vm/redact.py INPUT.json OUTPUT.json
       python3 scripts/vm/redact.py --self-test
"""

import argparse
import copy
import json
import os
from pathlib import Path
import re
import tempfile


REDACTED = "[REDACTED]"
SENSITIVE_FIELDS = {
    "password", "passwd", "passphrase", "token", "accesstoken",
    "refreshtoken", "idtoken", "bearertoken", "apikey", "accesskey",
    "secretaccesskey", "privatekey", "clientkey", "clientkeydata", "clientsecret",
    "clientcertificatedata", "authorization", "cookie", "setcookie",
    "kubeconfig", "credentials",
}
PRIVATE_KEY = re.compile(r"-----BEGIN (?:[A-Z0-9]+ )*PRIVATE KEY-----")
JWT = re.compile(r"\beyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\b")


def field_name(value):
    return re.sub(r"[^a-z0-9]", "", value.lower())


def hide_values(value):
    """Keep the shape and keys of sensitive maps, but none of their values."""
    if isinstance(value, dict):
        return {key: hide_values(item) for key, item in value.items()}
    if isinstance(value, list):
        return [hide_values(item) for item in value]
    return REDACTED


def redact(value, parent_field=None):
    if isinstance(value, list):
        return [redact(item, parent_field) for item in value]
    if isinstance(value, dict):
        kind = str(value.get("kind", "")).lower()
        result = {}
        for key, item in value.items():
            normalized = field_name(key)
            sensitive = (
                normalized in SENSITIVE_FIELDS
                or normalized == "annotations"
                or key == "kubectl.kubernetes.io/last-applied-configuration"
                or (kind == "secret" and key in {"data", "stringData"})
                or (kind == "configmap" and key in {"data", "binaryData"})
                or (parent_field == "env" and key == "value")
                or (field_name(parent_field or "") == "fixpath" and key == "value")
            )
            result[key] = hide_values(item) if sensitive else redact(item, key)
        return result
    if isinstance(value, str):
        if PRIVATE_KEY.search(value) or JWT.search(value):
            return REDACTED
        # Some exporters store nested resource objects as JSON text.
        if value.lstrip().startswith(("{", "[")):
            try:
                embedded = json.loads(value)
            except json.JSONDecodeError:
                return value
            if isinstance(embedded, (dict, list)):
                cleaned = redact(embedded, parent_field)
                if cleaned != embedded:
                    return json.dumps(cleaned, ensure_ascii=False)
    return value


def self_test():
    fixtures = {
        "apiVersion": "v1",
        "kind": "List",
        "items": [
            {"kind": "Secret", "metadata": {"name": "db-secret", "namespace": "backend"},
             "type": "Opaque", "data": {"password": "SYNTHETIC_BASE64"},
             "stringData": {"username": "SYNTHETIC_USERNAME"}},
            {"kind": "ConfigMap", "metadata": {"name": "db-config"},
             "data": {"ordinary-key": "SYNTHETIC_CONFIG"},
             "binaryData": {"payload": "SYNTHETIC_BINARY"}},
        ],
        "resources": [{"resourceID": "apps/v1/frontend/Deployment/frontend", "object": {
            "kind": "Deployment", "metadata": {"name": "frontend", "annotations": {
                "kubectl.kubernetes.io/last-applied-configuration": "SYNTHETIC_LAST_APPLIED",
                "custom": "SYNTHETIC_ANNOTATION"}},
            "spec": {"template": {"spec": {"automountServiceAccountToken": False,
                "securityContext": {"runAsNonRoot": True, "runAsUser": 10001},
                "containers": [{"env": [
                    {"name": "DB_PASSWORD", "value": "SYNTHETIC_ENV"},
                    {"name": "DB_USERNAME", "valueFrom": {"secretKeyRef": {
                        "name": "db-secret", "key": "username"}}},
                ]}]}}},
        }}],
        "summaryDetails": {"status": "failed", "controls": {"C-0012": {
            "status": "passed", "ResourceCounters": {"failedResources": 0, "passedResources": 2}}}},
        "nested": {"client-key-data": "SYNTHETIC_PRIVATE", "access_token": "SYNTHETIC_TOKEN",
                   "client-secret": "SYNTHETIC_CLIENT_SECRET_DASHED",
                   "clientSecret": "SYNTHETIC_CLIENT_SECRET_CAMEL"},
        "results": [{"controls": [{"status": "failed", "paths": [{
            "fixPath": {"path": "spec.containers[0].env[0].value",
                        "value": "SYNTHETIC_FIX_VALUE"}}]}]}],
        "serialized": json.dumps({"kind": "Secret", "data": {"other": "SYNTHETIC_EMBEDDED"}}),
    }
    original = copy.deepcopy(fixtures)
    result = redact(fixtures)
    assert fixtures == original, "Input must not be modified"
    assert "SYNTHETIC_" not in json.dumps(result), "Sensitive fixture escaped redaction"
    assert result["summaryDetails"] == fixtures["summaryDetails"], "Scan status/counts changed"
    obj = result["resources"][0]["object"]
    spec = obj["spec"]["template"]["spec"]
    assert obj["metadata"]["name"] == "frontend"
    assert spec["securityContext"] == {"runAsNonRoot": True, "runAsUser": 10001}
    assert spec["automountServiceAccountToken"] is False
    assert spec["containers"][0]["env"][1]["valueFrom"]["secretKeyRef"] == {
        "name": "db-secret", "key": "username"}
    assert result["items"][0]["metadata"]["namespace"] == "backend"
    fix_path = result["results"][0]["controls"][0]["paths"][0]["fixPath"]
    assert fix_path == {"path": "spec.containers[0].env[0].value", "value": REDACTED}
    assert result["nested"]["client-secret"] == REDACTED
    assert result["nested"]["clientSecret"] == REDACTED
    assert redact(result) == result, "Redaction must be idempotent"
    print("PASS: nested Secret, ConfigMap, env, annotations and credential fields hidden; references, security and scan counters preserved")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("input", nargs="?", type=Path)
    parser.add_argument("output", nargs="?", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if args.input is None or args.output is None:
        parser.error("input and output JSON paths are required")
    if args.input.resolve() == args.output.resolve():
        parser.error("output must differ from the private raw input")
    # Errors name only files and parse locations; they never print raw JSON.
    try:
        source = json.loads(args.input.read_text(encoding="utf-8"))
    except (OSError, UnicodeError, json.JSONDecodeError) as error:
        parser.exit(1, f"Cannot read JSON input: {type(error).__name__}\n")
    serialized = json.dumps(redact(source), ensure_ascii=False, indent=2) + "\n"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    temporary_path = None
    try:
        with tempfile.NamedTemporaryFile(mode="w", encoding="utf-8", dir=args.output.parent,
                                         prefix=".redacted-", delete=False) as temporary:
            temporary_path = Path(temporary.name)
            temporary.write(serialized)
        os.replace(temporary_path, args.output)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)
    print("Redacted JSON evidence written.")


if __name__ == "__main__":
    main()
