"""Bounded subprocess checks; engine errors can occur even with exit status zero."""
import argparse
import os
from pathlib import Path
import re
import subprocess
import sys

parser = argparse.ArgumentParser()
parser.add_argument("--log", type=Path, required=True)
parser.add_argument("--marker", default="")
parser.add_argument("--timeout", type=int, default=120)
parser.add_argument("command", nargs=argparse.REMAINDER)
args = parser.parse_args()
command = args.command[1:] if args.command[:1] == ["--"] else args.command
args.log.parent.mkdir(parents=True, exist_ok=True)
try:
    result = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                              encoding="utf-8", errors="replace")
    output, _ = result.communicate(timeout=args.timeout)
except subprocess.TimeoutExpired as error:
    # Godot's Windows console relay spawns the actual engine. Kill both on timeout.
    if os.name == "nt":
        subprocess.run(["taskkill", "/PID", str(result.pid), "/T", "/F"],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
    result.kill()
    output, _ = result.communicate(timeout=10)
    output += "\nPROCESS_TIMEOUT\n"
    result = None
args.log.write_text(output, encoding="utf-8")
print(output, end="")
bad_log = re.search(r"(?im)(SCRIPT ERROR:|(^|\s)ERROR:|FATAL|PROCESS_TIMEOUT)", output)
if result is None or result.returncode != 0 or bad_log or args.marker not in output:
    print(f"Check failed; see {args.log}", file=sys.stderr)
    sys.exit(1)
