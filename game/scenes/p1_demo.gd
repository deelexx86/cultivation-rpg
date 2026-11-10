extends Control
## Debug-only P1 UI; P0 remains the default technical scene.
var session: CampaignSession
var plan: Dictionary = {}
var output: RichTextLabel
var status: Label
var automated: bool = false
var fatal_dialog: ConfirmationDialog

func _ready() -> void:
	automated = "--p1-demo-smoke" in OS.get_cmdline_user_args()
	get_tree().auto_accept_quit = false
	var id := "p1-demo"
	if automated:
		id = "smoke-" + str(Time.get_unix_time_from_system()).replace(".", "-") + "-" + str(OS.get_process_id())
	session = CampaignSession.new(P1Fixture.demo(id), SnapshotStore.new("user://campaigns", id))
	if FileAccess.file_exists(session.store.path("current.json")) or FileAccess.file_exists(session.store.path("previous.json")):
		if not session.reload():
			push_error("P1 demo cannot restore: " + session.error)
			get_tree().quit(1)
			return
	elif not session.save():
		push_error("P1 demo cannot create: " + session.error)
		get_tree().quit(1)
		return
	build_ui()
	refresh()
	if automated:
		call_deferred("smoke")

func build_ui() -> void:
	var debug_theme := Theme.new()
	debug_theme.default_font_size = 24
	# Measured diagnostic-font workaround on the available AMD driver:
	# bitmap glyphs for Forward+, existing MSDF fallback for Compatibility.
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		var debug_font := ThemeDB.fallback_font.duplicate() as FontFile
		debug_font.multichannel_signed_distance_field = false
		debug_theme.default_font = debug_font
	theme = debug_theme
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	margin.add_child(column)
	var title := Label.new()
	title.text = "Cultivation RPG / P1 simulation laboratory"
	title.add_theme_font_size_override("font_size", 24)
	column.add_child(title)
	var note := Label.new()
	note.text = "Technical fixtures only. Calendar advances through confirmed actions.\nOne current continuation; backups are used only for recovery."
	column.add_child(note)
	status = Label.new()
	column.add_child(status)
	var controls := HFlowContainer.new()
	column.add_child(controls)
	for entry: Array in [["Preview 20 years", preview_action], ["Confirm practice", confirm_action], ["Advance / continue", advance_action], ["Acknowledge & resume", resume_action], ["Save / retry", save_action], ["Load current", load_action], ["Save & exit", exit_action]]:
		var button := Button.new()
		button.text = entry[0]
		button.pressed.connect(entry[1])
		controls.add_child(button)
	fatal_dialog = ConfirmationDialog.new()
	fatal_dialog.title = "Confirm known life expiry"
	fatal_dialog.confirmed.connect(func() -> void:
		session.confirm(plan, "practice-" + str(session.state.actions.size() + 1), true)
		refresh())
	add_child(fatal_dialog)
	output = RichTextLabel.new()
	output.size_flags_vertical = Control.SIZE_EXPAND_FILL
	output.add_theme_font_size_override("normal_font_size", 24)
	column.add_child(output)

func refresh(message: String = "") -> void:
	var state := session.state
	status.text = "World %s | Soul %d / %d years | Body %d / %d years\nSupplies %d | Spent %d | %s | snapshot %d" % [WorldCalendar.label(state.day), WorldCalendar.age_years(state.soul.born, state.day), state.soul.limit_years, WorldCalendar.age_years(state.body().born, state.day), state.body().limit_years, state.supplies, state.spent, state.mode, session.store.sequence]
	var lines: Array[String] = []
	if not message.is_empty():
		lines.append(message)
	if not session.error.is_empty():
		lines.append("Operation failed: " + session.error + (". Use Save / retry." if session.dirty else ""))
	for action: CampaignState.Action in state.actions:
		lines.append("%s: %s, %d / %d days, unresolved channel: %s" % [action.id, action.status, action.progress, action.duration, action.blocker])
	# This is explicitly a diagnostic view of resolved world facts, not hero knowledge.
	lines.append("Resolved world facts (debug):")
	for person: CampaignState.Person in state.people:
		lines.append("%s: %s" % [person.id, "alive" if person.alive else "died " + WorldCalendar.label(person.died)])
	for obligation: CampaignState.Obligation in state.obligations:
		lines.append("%s: %s" % [obligation.id, "active" if obligation.active else "ended " + WorldCalendar.label(obligation.ended)])
	lines.append("History:")
	lines.append_array(state.history)
	output.text = "\n".join(lines)

func preview_action() -> void:
	plan = Simulation.preview(session.state, WorldCalendar.add_years(session.state.day, 20) - session.state.day)
	var warning := "Known life expiry on %s prevents completion; a second confirmation is required." % WorldCalendar.label(plan.life_boundary) if plan.fatal else "Positive life margin at projected completion."
	refresh("Practice forecast: %d days, finish %s; cost %d supply. Soul age %d days; body age %d days.\n%s\nKnown obligations: %s\n%s\n%s" % [plan.duration, WorldCalendar.label(plan.finish), plan.cost, plan.soul_age_days, plan.body_age_days, warning, ", ".join(plan.known_obligations), plan.reason, plan.risk])

func confirm_action() -> void:
	if plan.is_empty():
		refresh("Preview the action before confirming.")
		return
	if plan.fatal:
		fatal_dialog.dialog_text = "Life expires on %s before this action can finish.\nThe new limit cannot save an expired life.\nSoul expiry ends the campaign; body expiry leaves a death checkpoint.\nProceed with this known outcome?" % WorldCalendar.label(plan.life_boundary)
		fatal_dialog.popup_centered()
		return
	session.confirm(plan, "practice-" + str(session.state.actions.size() + 1))
	refresh()

func advance_action() -> void:
	session.advance(36525)
	refresh()

func resume_action() -> void:
	for action: CampaignState.Action in session.state.actions:
		if action.status == "paused":
			session.resume(action.id, "resume-" + str(session.state.revision))
			refresh()
			return
	refresh("No interrupted action.")

func save_action() -> void:
	session.save()
	refresh()

func load_action() -> void:
	session.reload()
	plan.clear()
	refresh()

func exit_action() -> void:
	if session.save():
		get_tree().quit(0)
	else:
		refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and session != null:
		exit_action()

func smoke() -> void:
	await get_tree().create_timer(0.1).timeout
	var before := session.state.fingerprint()
	preview_action()
	await get_tree().create_timer(0.1).timeout
	if before != session.state.fingerprint():
		fail("Preview mutated state")
		return
	confirm_action()
	await get_tree().create_timer(0.1).timeout
	advance_action()
	await get_tree().create_timer(0.1).timeout
	var stopped := session.state.fingerprint()
	if session.state.day != WorldCalendar.ordinal(9) or session.state.actions[0].status != "paused" or session.state.obligations[0].active:
		fail("Event/obligation interruption incorrect: " + session.error)
		return
	load_action()
	await get_tree().create_timer(0.1).timeout
	if session.state.fingerprint() != stopped:
		fail("Interrupted snapshot changed on load")
		return
	resume_action()
	await get_tree().create_timer(0.1).timeout
	advance_action()
	await get_tree().create_timer(0.1).timeout
	load_action()
	if session.state.day != WorldCalendar.ordinal(20) or session.state.actions[0].status != "complete" or session.state.spent != 1 or not session.error.is_empty():
		fail("Continuation incorrect: " + session.error)
		return
	await get_tree().create_timer(0.25).timeout
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture=") and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			if get_viewport().get_texture().get_image().save_png(argument.trim_prefix("--capture=")) != OK:
				fail("Capture failed")
				return
	print("P1_DEMO_PASS date=", WorldCalendar.label(session.state.day), " progress=", session.state.actions[0].progress, " spent=", session.state.spent, " engine=", Engine.get_version_info().string, " display=", DisplayServer.get_name())
	exit_action()

func fail(message: String) -> void:
	push_error("P1 demo: " + message)
	get_tree().quit(1)
