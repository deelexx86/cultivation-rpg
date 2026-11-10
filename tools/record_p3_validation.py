"""Verify completed clean-checkout evidence and produce a portable review record.

Standard library only. This records observations; it does not run or replace tests.
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import struct
import subprocess
import zipfile


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def git(root, *args):
    return subprocess.check_output(["git", "-C", str(root), *args], text=True).strip()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--checkout", type=Path, required=True)
    parser.add_argument("--clean-log", type=Path, required=True)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[1]
    checkout = args.checkout.resolve()
    artifacts = checkout / ".artifacts"
    evidence = root / "docs/technical/evidence"
    clean_text = args.clean_log.read_text(encoding="utf-8-sig")
    if "P3_CLEAN_CHECKOUT_PASS" not in clean_text or git(checkout, "status", "--porcelain"):
        raise RuntimeError("A completed, clean verification checkout is required")
    expected = {
        "asset-rebuild": "P0_ASSET_REBUILD_PASS", "tests": "P0_TEST_PASS",
        "headless-startup": "P0_SMOKE_PASS", "design": "Errors: 0",
        "import": "", "export": "", "p1-tests": "P1_TEST_PASS",
        "p1-crashes": "P1_CRASH_PASS", "p1-demo-headless": "P1_DEMO_PASS",
        "p2-assets": "P2_ASSETS_PASS", "p2-rules": "P2_RULE_PASS",
        "p3-rules": "P3_RULE_PASS", "p3-crashes": "P3_CRASH_PASS",
    }
    for renderer in ("forward_plus", "gl_compatibility"):
        for mode in ("project", "export"):
            expected[f"{mode}-{renderer}"] = "P0_SMOKE_PASS"
            expected[f"p1-{mode}-{renderer}"] = "P1_DEMO_PASS"
            expected[f"p2-{mode}-{renderer}"] = "P2_SCENE_PASS"
        expected[f"p2-resume-{renderer}"] = "P2_RESUME_PASS"
        for mode, marker in (("project", "SCENE"), ("resume", "RESUME"),
                             ("export", "SCENE"), ("export-resume", "RESUME"),
                             ("condense", "CONDENSE"), ("property", "PROPERTY"),
                             ("mortality", "MORTALITY")):
            expected[f"p3-{mode}-{renderer}"] = f"P3_{marker}_PASS"
    record = {
        "source_commit": git(checkout, "rev-parse", "HEAD"),
        "base_commit": "ecdd3be645f34bd61a8953d479623af2e675580d",
        "date": "2026-11-11", "platform": "Windows 11 x86-64, AMD RX 580 2048SP",
        "godot": "4.8.beta3.official.c51ff06e8", "clean_checkout": "P3_CLEAN_CHECKOUT_PASS",
        "commands": ["pwsh -NoProfile -File tools/p3.ps1 -Task Verify",
                     "pwsh -NoProfile -File tools/verify_clean_checkout.ps1 -Phase P3",
                     "python tools/validate_design.py"],
        "logs": {}, "runtime_files": {}, "crash_cases": [], "screenshots": {},
        "normal_ui_check": {"entry": "tools/p3.ps1 -Task Demo -Campaign p3-input-review",
                            "observed": ["Mouse scroll reached lower help choices",
                                         "Clicked comparison opened from its beginning",
                                         "Relaunch continued the same campaign",
                                         "Normal window close: exit 0; sequence 2 -> 3; day 0, wallet 80 unchanged"],
                            "scope": "Agent-controlled Windows UI check; not independent owner acceptance"},
        "limits": ["No actual breakthrough or life-limit grant", "No reincarnation rights / combat / flight",
                   "No production balance, second GPU, dense-scene performance or power-loss proof",
                   "Schema 3 uses a separate slot; P2-to-P3 migration is not provided"],
    }
    archive_entries = {}
    for name, marker in expected.items():
        path = artifacts / f"{name}.log"
        text = path.read_text(encoding="utf-8")
        if marker not in text or re.search(r"SCRIPT ERROR:|(?:^|\s)ERROR:|PROCESS_TIMEOUT", text):
            raise RuntimeError(f"Missing or failed evidence: {path.name}")
        markers = [line.strip().split(" evidence=")[0] for line in text.splitlines()
                   if re.search(r"P[0-3]_[A-Z_]+PASS|Errors: 0|checks=", line)]
        record["logs"][path.name] = {"sha256": digest(path), "markers": markers}
        archive_entries[f"logs/{path.name}"] = text.replace(str(checkout), "<checkout>")
    # Ensure later report-only commits have not changed any tested runtime files.
    for relative in git(checkout, "ls-files", "game").splitlines():
        if digest(root / relative) != digest(checkout / relative):
            raise RuntimeError(f"Runtime changed after verification: {relative}")
        record["runtime_files"][relative] = digest(checkout / relative)
    crash_log = (artifacts / "p3-crashes.log").read_text(encoding="utf-8")
    match = re.search(r"evidence=(.+)", crash_log)
    crash_dir = Path(match.group(1).strip()).resolve() if match else Path()
    if not crash_dir.is_relative_to(artifacts.resolve()):
        raise RuntimeError("Crash evidence must stay within the validated checkout")
    recovery_logs = sorted(crash_dir.glob("*-recovery.log"))
    if len(recovery_logs) != 64:
        raise RuntimeError("Expected 64 independently killed and recovered writers")
    for recovery in recovery_logs:
        writer = recovery.with_name(recovery.name.replace("-recovery.log", "-writer.log"))
        text = recovery.read_text(encoding="utf-8")
        if "P3_CRASH_RECOVERY_PASS:" not in text:
            raise RuntimeError("Missing crash recovery confirmation")
        record["crash_cases"].append({"case": recovery.stem.removesuffix("-recovery"),
                                      "writer_sha256": digest(writer), "recovery_sha256": digest(recovery),
                                      "result": next(line for line in text.splitlines() if "P3_CRASH_RECOVERY_PASS:" in line)})
        for path in (writer, recovery):
            archive_entries[f"crashes/{path.name}"] = path.read_text(encoding="utf-8").replace(str(checkout), "<checkout>")
    executable = artifacts / "windows/CultivationRPG.exe"
    binary = executable.read_bytes()
    pe_offset = struct.unpack_from("<I", binary, 0x3C)[0]
    machine = struct.unpack_from("<H", binary, pe_offset + 4)[0]
    if binary[pe_offset:pe_offset+4] != b"PE\0\0" or machine != 0x8664:
        raise RuntimeError("Export is not a Windows x86-64 PE")
    record["pe_machine"] = hex(machine)
    record["export"] = {name: digest(artifacts / "windows" / name)
                        for name in ("CultivationRPG.exe", "CultivationRPG.pck")}
    for frame in sorted(artifacts.glob("p3-*.png")):
        record["screenshots"][frame.name] = digest(frame)
    selections = {
        "p3-root-forward_plus.png": "p3-project-forward_plus-extraction.png",
        "p3-contract-forward_plus.png": "p3-project-forward_plus-contract.png",
        "p3-prepared-forward_plus.png": "p3-resume-forward_plus-prepared.png",
        "p3-condensation-forward_plus.png": "p3-condense-forward_plus-condensation.png",
        "p3-prepared-gl_compatibility.png": "p3-resume-gl_compatibility-prepared.png",
    }
    record["committed_frames"] = selections
    evidence.mkdir(parents=True, exist_ok=True)
    for destination, source in selections.items():
        shutil.copyfile(artifacts / source, evidence / destination)
    report = evidence / "p3-validation.json"
    report.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n", encoding="utf-8", newline="\n")
    archive = root / ".artifacts/p3-review-evidence.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED) as bundle:
        bundle.write(report, "p3-validation.json")
        for name, text in archive_entries.items(): bundle.writestr(name, text)
        for source in selections.values(): bundle.write(artifacts / source, f"frames/{source}")
        bundle.writestr("clean-checkout.log", clean_text.replace(str(checkout), "<checkout>"))
    print(f"P3_EVIDENCE_PASS logs={len(expected)} crash_cases=64 runtime_files={len(record['runtime_files'])}")


if __name__ == "__main__":
    main()
