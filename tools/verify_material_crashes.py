"""Hard-kill actual Windows writers, then inspect and continue each P3 transaction."""
import argparse
from pathlib import Path
import re
import subprocess
import time

STAGES = ("before_write", "partial_write", "after_flush", "after_verify",
          "partial_backup", "after_backup_write", "after_backup_replace", "after_main_replace")
KINDS = ("buy", "extract", "order", "active", "finish", "claim", "choose", "sell")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--game", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    destination = args.output.resolve() / f"material-crashes-{time.time_ns()}"
    destination.mkdir(parents=True)
    engine = args.godot.resolve()
    if engine.name.endswith("_console.exe"):
        engine = engine.with_name(engine.name.replace("_console.exe", ".exe"))
    command = [str(engine), "--headless", "--path", str(args.game.resolve()),
               "--script", "res://tests/material_crash_worker.gd", "--"]
    for kind in KINDS:
        for stage in STAGES:
            slot = destination / f"{kind}-{stage}"
            log = destination / f"{kind}-{stage}-writer.log"
            with log.open("wb") as output:
                process = subprocess.Popen(command + [str(slot), "write", stage, kind],
                                           stdout=output, stderr=subprocess.STDOUT)
                try:
                    deadline = time.monotonic() + 20
                    while f"P1_CRASH_READY:{stage}" not in log.read_text(encoding="utf-8", errors="replace"):
                        if process.poll() is not None or time.monotonic() >= deadline:
                            raise RuntimeError(f"Writer did not reach {kind}/{stage}: {log.read_text()}")
                        time.sleep(0.03)
                finally:
                    process.kill()
                    process.wait(timeout=5)
            result = subprocess.run(command + [str(slot), "recover", stage, kind],
                                    capture_output=True, text=True, encoding="utf-8", timeout=20)
            content = result.stdout + result.stderr
            (destination / f"{kind}-{stage}-recovery.log").write_text(content, encoding="utf-8")
            if result.returncode or "P3_CRASH_RECOVERY_PASS:" not in content or re.search(r"SCRIPT ERROR:|ERROR:", content):
                raise RuntimeError(f"Recovery failed at {kind}/{stage}: {content}")
        print(f"P3_CRASH_KIND_PASS {kind} stages={len(STAGES)}", flush=True)
    print(f"P3_CRASH_PASS terminations={len(KINDS)*len(STAGES)} evidence={destination}")


if __name__ == "__main__":
    main()
