extends SceneTree

const AssetContract = preload("res://tests/asset_contract.gd")

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://assets/p0_probe.glb") as PackedScene
	if packed == null:
		push_error("P0: GLB could not load")
		quit(1)
		return
	var probe := packed.instantiate()
	root.add_child(probe)
	var errors: PackedStringArray = AssetContract.problems(probe)
	var player := probe.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var bob := probe.find_child("Bob", true, false) as Node3D
	if errors.is_empty():
		player.play(AssetContract.pulse_name(player))
		player.seek(0.5, true)
		if not bob.position.is_equal_approx(Vector3(0, 1.5, 0)):
			errors.append("Animation quarter-cycle transform changed")
		player.seek(1.5, true)
		if not bob.position.is_equal_approx(Vector3(0, 0.9, 0)):
			errors.append("Animation three-quarter-cycle transform changed")
	probe.free()
	if not errors.is_empty():
		for problem: String in errors:
			push_error(problem)
		quit(1)
		return
	print("P0_TEST_PASS geometry transforms materials animation_samples")
	quit(0)
