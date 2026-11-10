extends RefCounted
## P0 import boundary: metres, Y-up, applied scale, materials and animated track.

static func problems(probe: Node) -> PackedStringArray:
	var errors := PackedStringArray()
	var meshes := probe.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != 2:
		errors.append("Expected two imported meshes")
	for child: Node in meshes:
		var mesh_node := child as MeshInstance3D
		if mesh_node.mesh == null or mesh_node.mesh.get_surface_count() == 0:
			errors.append("Missing mesh surfaces")
			continue
		if not mesh_node.scale.is_equal_approx(Vector3.ONE):
			errors.append("Unapplied scale")
		if not mesh_node.basis.is_equal_approx(Basis.IDENTITY):
			errors.append("Unexpected rotation or scale")
		if mesh_node.mesh.surface_get_material(0) == null:
			errors.append("Missing material")
		var arrays := mesh_node.mesh.surface_get_arrays(0)
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.size() != 36 or normals.is_empty():
			errors.append("Cube topology/normals changed")
		for normal: Vector3 in normals:
			if not normal.is_finite() or not is_equal_approx(normal.length(), 1.0):
				errors.append("Invalid normal")
	var base := probe.find_child("Base", true, false) as MeshInstance3D
	if base == null or not base.position.is_equal_approx(Vector3(0, 0.1, 0)):
		errors.append("Base transform changed")
	var bob := probe.find_child("Bob", true, false) as MeshInstance3D
	if bob == null:
		errors.append("Missing animated Bob mesh")
	else:
		if not bob.position.is_equal_approx(Vector3(0, 1.2, 0)):
			errors.append("Metres/Y-up translation was not preserved")
		if not bob.mesh.get_aabb().size.is_equal_approx(Vector3(0.8, 0.6, 0.8)):
			errors.append("Geometry dimensions changed")
		var material := bob.mesh.surface_get_material(0) as StandardMaterial3D
		if material == null or not material.albedo_color.is_equal_approx(Color(0.12, 0.75, 0.57, 1).linear_to_srgb()):
			errors.append("GLB material color changed")
	var player := probe.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null or pulse_name(player).is_empty():
		errors.append("Missing Pulse animation")
	else:
		var clip := player.get_animation(pulse_name(player))
		print("P0_CLIP name=", pulse_name(player), " length=", clip.length, " tracks=", clip.get_track_count())
		if not is_equal_approx(clip.length, 2.0) or clip.get_track_count() == 0:
			errors.append("Animation duration/tracks changed")
	return errors

static func pulse_name(player: AnimationPlayer) -> StringName:
	for clip: StringName in player.get_animation_list():
		if "Pulse" in String(clip):
			return clip
	return &""
