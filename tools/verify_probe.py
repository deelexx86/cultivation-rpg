"""Pinned Blender: verify committed source -> fresh GLB without modifying source."""
import hashlib
import json
from pathlib import Path
import bpy

root = Path(__file__).resolve().parents[1]
manifest = json.loads((root / "art/p0-probe.json").read_text(encoding="utf-8"))
for kind in ("source", "prepared"):
    path = root / manifest[kind]
    if hashlib.sha256(path.read_bytes()).hexdigest() != manifest[kind + "_sha256"]:
        raise RuntimeError(f"{kind} asset checksum mismatch")
bpy.ops.wm.open_mainfile(filepath=str(root / manifest["source"]))
if bpy.app.version != tuple(map(int, manifest["blender_version"].split("."))):
    raise RuntimeError("Unexpected Blender version")
output = root / ".artifacts/rebuilt-probe.glb"
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB",
                          export_yup=True, export_animations=True,
                          export_frame_range=True, export_force_sampling=True)
if hashlib.sha256(output.read_bytes()).hexdigest() != manifest["prepared_sha256"]:
    raise RuntimeError("Fresh GLB differs from committed prepared asset")
print("P0_ASSET_REBUILD_PASS", flush=True)
