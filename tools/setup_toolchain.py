"""Portable, hash-pinned Windows tools; Python standard library only."""
import concurrent.futures
import hashlib
import json
from pathlib import Path
import shutil
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
TOOLS = ROOT / ".tools"
LOCK = json.loads((ROOT / "tools/toolchain.json").read_text())


def digest(path, algorithm):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, algorithm).hexdigest()


def install(item):
    name, spec = item
    archive = TOOLS / "downloads" / spec["url"].rsplit("/", 1)[1]
    archive.parent.mkdir(parents=True, exist_ok=True)
    if not archive.exists() or digest(archive, spec["algorithm"]) != spec["hash"]:
        partial = archive.with_suffix(".partial")
        print(f"Downloading {name} {spec['version']}", flush=True)
        with urllib.request.urlopen(spec["url"], timeout=60) as response, partial.open("wb") as output:
            shutil.copyfileobj(response, output)
        if digest(partial, spec["algorithm"]) != spec["hash"]:
            raise RuntimeError(f"Checksum mismatch: {name}")
        partial.replace(archive)
    target = TOOLS / name
    # Re-extract verified bytes, including on repeated setup; no trust in old binaries.
    with zipfile.ZipFile(archive) as bundle:
        if name == "templates":
            for member in ("templates/version.txt", "templates/windows_debug_x86_64.exe",
                           "templates/windows_release_x86_64.exe"):
                bundle.extract(member, target)
        else:
            bundle.extractall(target)
    print(f"Verified and installed {name} {spec['version']}", flush=True)


if __name__ == "__main__":
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        list(executor.map(install, LOCK.items()))
