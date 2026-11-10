"""Verify the complete distributable asset subset against the checked-in register."""
import hashlib
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
packs = json.loads((root / "art/sedge-assets.json").read_text(encoding="utf-8"))
models = 0
for pack in packs:
    directory = root / "game/assets/sedge" / pack["directory"]
    license_text = (directory / "License.txt").read_text(encoding="utf-8")
    if "CC0" not in license_text or pack["pack"] not in license_text:
        raise ValueError(f"License or release mismatch in {directory}")
    files = {p.relative_to(directory).as_posix() for p in directory.rglob("*")
             if p.is_file() and not p.name.endswith(".import") and p.name != "License.txt"}
    if files != set(pack["sha256"]):
        raise ValueError(f"Asset subset mismatch in {directory}")
    for name, digest in pack["sha256"].items():
        if hashlib.sha256((directory / name).read_bytes()).hexdigest() != digest:
            raise ValueError(f"Checksum mismatch for {directory / name}")
        models += name.endswith(".glb")
print(f"P2_ASSETS_PASS packs={len(packs)} models={models}")
