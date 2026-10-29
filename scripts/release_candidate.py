"""Run reproducible local release-candidate gates without exposing secrets."""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(name: str, command: list[str], report: dict[str, object]) -> None:
    started = datetime.now(timezone.utc).isoformat()
    try:
        completed = subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            capture_output=True,
            check=False,
        )
    except OSError as error:
        report[name] = {
            "status": "BLOCKED",
            "command": command[0],
            "error": str(error),
            "started_at": started,
        }
        return
    report[name] = {
        "status": "PASS" if completed.returncode == 0 else "FAIL",
        "command": command[0],
        "exit_code": completed.returncode,
        "stdout_tail": completed.stdout[-2000:],
        "stderr_tail": completed.stderr[-2000:],
        "started_at": started,
    }


def config_safety(report: dict[str, object]) -> None:
    unsafe = []
    for path in ROOT.glob("config/*.json"):
        if path.name in {"example.json", "web.example.json"}:
            continue
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except OSError:
            continue
        if "sb_secret_" in text or "service_role" in text:
            unsafe.append(path.name)
    report["config_safety"] = {
        "status": "FAIL" if unsafe else "PASS",
        "unsafe_files": unsafe,
        "checked": "config/*.json",
    }


def acceptance_status() -> dict[str, object]:
    return {
        "status": "BLOCKED",
        "reason": "Hosted accounts, provider credentials, and native devices are not available in this environment.",
        "required_external_evidence": [
            "AT01-AT24 with independent customer and baker accounts",
            "Hosted RLS/storage and concurrency checks",
            "Apple/Google sandbox billing verification",
            "Android and iOS device acceptance",
            "Deletion worker and backup/restore recovery rehearsal",
        ],
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--build-web", action="store_true")
    parser.add_argument("--build-apk", action="store_true")
    parser.add_argument("--output", type=Path, default=Path("release-candidate-report.json"))
    args = parser.parse_args()

    report: dict[str, object] = {
        "generated_at": datetime.now(timezone.utc).isoformat(),
        "repository": str(ROOT),
        "release_status": "NOT_APPROVED",
        "gates": {},
    }
    gates = report["gates"]
    assert isinstance(gates, dict)

    config_safety(gates)
    dart = shutil.which("dart.exe") or shutil.which("dart") or "dart"
    flutter = (
        shutil.which("flutter.bat")
        or shutil.which("flutter.exe")
        or shutil.which("flutter")
        or "flutter"
    )
    run(
        "dart_format",
        [dart, "format", "--output=none", "--set-exit-if-changed", "lib", "test"],
        gates,
    )
    run("flutter_analyze", [flutter, "analyze"], gates)
    run("flutter_test", [flutter, "test"], gates)
    run("sql_validation", [sys.executable, "scripts/validate_sql.py"], gates)
    if args.build_web:
        run("flutter_web_build", [flutter, "build", "web", "--release"], gates)
    if args.build_apk:
        run("flutter_android_build", [flutter, "build", "apk", "--debug"], gates)

    report["acceptance"] = acceptance_status()
    failures = [
        value
        for value in gates.values()
        if isinstance(value, dict) and value.get("status") in {"FAIL", "BLOCKED"}
    ]
    report["local_gates_pass"] = not failures
    report["release_status"] = (
        "NOT_APPROVED"
        if failures or report["acceptance"]["status"] != "PASS"
        else "APPROVED"
    )

    output = args.output if args.output.is_absolute() else ROOT / args.output
    output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({
        "release_status": report["release_status"],
        "local_gates_pass": report["local_gates_pass"],
        "report": str(output),
    }))
    return 0 if report["local_gates_pass"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
