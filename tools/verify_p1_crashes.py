"""Terminate an actual Godot process at each snapshot protocol boundary on Windows."""
import argparse
from pathlib import Path
import re
import subprocess
import time

STAGES = ("before_write", "partial_write", "after_flush", "after_verify",
          "partial_backup", "after_backup_write", "after_backup_replace", "after_main_replace")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--godot", type=Path, required=True)
    parser.add_argument("--game", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    destination = args.output.resolve() / f"crashes-{time.time_ns()}"
    destination.mkdir(parents=True)
    # Use the actual engine, not the console relay, so kill() kills the writer.
    engine = args.godot.resolve()
    if engine.name.endswith("_console.exe"):
        engine = engine.with_name(engine.name.replace("_console.exe", ".exe"))
    command = [str(engine), "--headless", "--path", str(args.game.resolve()),
               "--script", "res://tests/p1_crash_worker.gd", "--"]
    for stage in STAGES:
        slot = destination / stage
        log = destination / f"{stage}-writer.log"
        with log.open("wb") as output:
            process = subprocess.Popen(command + [str(slot), "write", stage],
                                       stdout=output, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + 20
                while f"P1_CRASH_READY:{stage}" not in log.read_text(encoding="utf-8", errors="replace"):
                    if process.poll() is not None or time.monotonic() >= deadline:
                        raise RuntimeError(f"Writer failed to reach {stage}: {log.read_text()}")
                    time.sleep(0.05)
            finally:
                process.kill()
                process.wait(timeout=5)
        result = subprocess.run(command + [str(slot), "recover", stage],
                                capture_output=True, text=True, encoding="utf-8", timeout=20)
        content = result.stdout + result.stderr
        (destination / f"{stage}-recovery.log").write_text(content, encoding="utf-8")
        if result.returncode or "P1_CRASH_RECOVERY_PASS:" not in content or re.search(r"SCRIPT ERROR:|ERROR:", content):
            raise RuntimeError(f"Recovery failed at {stage}: {content}")
        print(content.strip(), flush=True)
    print(f"P1_CRASH_PASS stages={len(STAGES)} evidence={destination}")


if __name__ == "__main__":
    main()
