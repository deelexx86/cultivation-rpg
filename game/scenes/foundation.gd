extends Node3D

const AssetContract = preload("res://tests/asset_contract.gd")

func _ready() -> void:
	var probe := $Probe
	var errors: PackedStringArray = AssetContract.problems(probe)
	if not errors.is_empty():
		push_error("P0 contract: " + "; ".join(errors))
		get_tree().quit(1)
		return
	var player := probe.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var clip: StringName = AssetContract.pulse_name(player)
	player.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
	player.play(clip)
	print("P0_READY version=", ProjectSettings.get_setting("application/config/version"),
		" engine=", Engine.get_version_info().string,
		" display=", DisplayServer.get_name(),
		" renderer=", RenderingServer.get_current_rendering_method())
	if "--smoke" in OS.get_cmdline_user_args():
		await _smoke(probe, player)

func _smoke(probe: Node, player: AnimationPlayer) -> void:
	var bob := probe.find_child("Bob", true, false) as Node3D
	var initial := bob.position
	await get_tree().create_timer(0.4).timeout
	if not player.is_playing() or bob.position.distance_to(initial) < 0.05:
		push_error("P0 smoke: imported animation did not advance")
		get_tree().quit(1)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var result := get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--capture="))
			if result != OK:
				push_error("P0 capture failed")
				get_tree().quit(1)
				return
	await get_tree().create_timer(1.6).timeout
	print("P0_SMOKE_PASS animation_advanced=true")
	get_tree().quit(0)
