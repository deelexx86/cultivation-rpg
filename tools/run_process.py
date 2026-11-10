"""Bounded subprocess checks; engine errors can occur even with exit status zero."""
import argparse
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
    result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                            timeout=args.timeout, encoding="utf-8", errors="replace")
    output = result.stdout
except subprocess.TimeoutExpired as error:
    output = (error.stdout or b"").decode("utf-8", errors="replace") + "\nPROCESS_TIMEOUT\n"
    result = None
args.log.write_text(output, encoding="utf-8")
print(output, end="")
bad_log = re.search(r"(?im)(SCRIPT ERROR:|(^|\s)ERROR:|FATAL|PROCESS_TIMEOUT)", output)
if result is None or result.returncode != 0 or bad_log or args.marker not in output:
    print(f"Check failed; see {args.log}", file=sys.stderr)
    sys.exit(1)
