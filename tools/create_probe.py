"""Run with the pinned Blender: --background --factory-startup --python this_file."""
from pathlib import Path
import bpy

ROOT = Path(__file__).resolve().parents[1]
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)
scene = bpy.context.scene
scene.unit_settings.system = "METRIC"
scene.unit_settings.scale_length = 1.0
scene.render.fps = 30
scene.frame_start, scene.frame_end = 0, 60


def block(name, location, dimensions, color):
    bpy.ops.mesh.primitive_cube_add(size=1, location=location)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = dimensions
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    material = bpy.data.materials.new(name + "Material")
    material.diffuse_color = (*color, 1)
    material.use_nodes = True
    material.node_tree.nodes.get("Principled BSDF").inputs["Base Color"].default_value = (*color, 1)
    obj.data.materials.append(material)
    return obj


block("Base", (0, 0, 0.1), (1.8, 1.8, 0.2), (0.12, 0.19, 0.23))
bob = block("Bob", (0, 0, 1.2), (0.8, 0.8, 0.6), (0.12, 0.75, 0.57))
for frame, height in ((0, 1.2), (15, 1.5), (30, 1.2), (45, 0.9), (60, 1.2)):
    bob.location.z = height
    bob.keyframe_insert(data_path="location", frame=frame)
bob.animation_data.action.name = "Pulse"
scene.frame_set(0)
source = ROOT / "art/source/p0_probe.blend"
output = ROOT / "game/assets/p0_probe.glb"
source.parent.mkdir(parents=True, exist_ok=True)
output.parent.mkdir(parents=True, exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=str(source))
bpy.ops.export_scene.gltf(filepath=str(output), export_format="GLB",
                          export_yup=True, export_animations=True,
                          export_frame_range=True, export_force_sampling=True)
print("P0_ASSET_EXPORTED", flush=True)
