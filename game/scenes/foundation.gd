extends Node3D

const AssetContract = preload("res://tests/asset_contract.gd")

func _ready() -> void:
	if "--p4" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://scenes/combat_stand.tscn")
		return
	if "--p2" in OS.get_cmdline_user_args() or "--p3" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://scenes/sedge.tscn")
		return
	if "--p1-demo" in OS.get_cmdline_user_args() or "--p1-demo-smoke" in OS.get_cmdline_user_args():
		get_tree().change_scene_to_file.call_deferred("res://scenes/p1_demo.tscn")
		return
	if "--smoke" not in OS.get_cmdline_user_args() and "--p0" not in OS.get_cmdline_user_args():
		$Probe.hide()
		campaign_menu()
		return
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

func campaign_menu() -> void:
	var id := "white-sedge"
	var seed_key := "vs_smooth_no_overload"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--campaign="): id = arg.trim_prefix("--campaign=")
		if arg.begins_with("--seed="): seed_key = arg.trim_prefix("--seed=")
	var slot := SliceSession.storage(id)
	var exists := FileAccess.file_exists(slot.path("current.json")) or FileAccess.file_exists(slot.path("previous.json"))
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	center.add_child(box)
	var title := Label.new()
	title.text = "Долина Белой Осоки"
	title.add_theme_font_size_override("font_size",32)
	box.add_child(title)
	var button := Button.new()
	button.text = "Продолжить кампанию" if exists else "Начать кампанию"
	box.add_child(button)
	button.pressed.connect(func() -> void:
		var session := SliceSession.open(id,seed_key)
		if session.error != "":
			title.text = session.error
			return
		SliceSession.current = session
		get_tree().change_scene_to_file(SliceSession.RAVINE if session.state.slice.area == "ravine" else SliceSession.VILLAGE))
	button.grab_focus()
	if "--p5-tour" in OS.get_cmdline_user_args():
		await get_tree().process_frame
		button.pressed.emit()
