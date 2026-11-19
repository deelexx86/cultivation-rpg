extends Node3D

const HERO := P4Content.HERO
const HOTKEYS := {KEY_1:"strike", KEY_2:"bolt", KEY_3:"seek", KEY_4:"ground", KEY_5:"sphere", KEY_T:"ward", KEY_G:"guard", KEY_Q:"dodge"}
const COLORS := {P4Content.YOUNG: Color("#c29972"), P4Content.HORNED: Color("#b76754"), P4Content.AIR: Color("#dda66a"), P4Content.CROSSING: Color("#ccb178")}
var session: SedgeSession
var player: SedgePlayer
var land: SedgeLandscape
var stage := Node3D.new()
var geometry: CombatGeometry
var motion := CombatMotion.new()
var camera_height := 0.0
var target := ""
var selection := ""
var aim := Vector3.INF
var keys: Array[int] = []
var click := false
var pointer := Vector2.ZERO
var held := Vector3.ZERO
var world_meshes := {}
var shot_meshes := {}
var rubble: Node3D
var preview: MeshInstance3D
var volumes := {}
var ward: MeshInstance3D
var board: MeshInstance3D
var hud := Label.new()
var help := Label.new()
var targets := Label.new()
var pause_panel := PanelContainer.new()
var pause_box := VBoxContainer.new()
var book := PanelContainer.new()
var book_box := VBoxContainer.new()
var canvas := Control.new()
var checkpoint_seconds := 0.0
var last_checkpoint_us := 0
var load_usec := 0
var modal := ""
var input_notice := ""
var probe := ""
var probe_elapsed := 0.0
var frames: Array[float] = []
var capture_requested := false
var capture_serial := 0
var step_samples: Array[int] = []
var motion_probe := ""
var motion_samples: Array = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	stage.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stage)
	var args := OS.get_cmdline_user_args()
	var rank := "qi"
	var id := ""
	for arg: String in args:
		if arg.begins_with("--rank="):
			rank = arg.trim_prefix("--rank=")
		elif arg.begins_with("--campaign="):
			id = arg.trim_prefix("--campaign=")
		elif arg.begins_with("--p4-probe="):
			probe = arg.trim_prefix("--p4-probe=")
		elif arg.begins_with("--p4-motion="):
			motion_probe = arg.trim_prefix("--p4-motion=")
	if rank not in P4Content.RANKS:
		push_error("Unknown P4 rank: " + rank)
		get_tree().quit(1)
		return
	if id == "":
		id = "sedge-" + rank
	var base := "user://sedge-combat" if probe == "" else "user://sedge-combat-probe"
	var exists := true
	if SliceSession.current != null:
		session = SliceSession.current
		id = session.state.campaign_id
	else:
		var storage := SnapshotStore.new(base, id, true, true, true)
		session = SedgeSession.new(CombatState.fresh(id, rank), storage)
		exists = FileAccess.file_exists(storage.path("current.json")) or FileAccess.file_exists(storage.path("previous.json"))
		if exists and not session.reload() or not exists and not session.save():
			push_error(session.error)
			get_tree().quit(1)
			return
	if probe != "" and motion_probe != "":
		RenderingServer.frame_post_draw.connect(record_motion)
	DisplayServer.window_set_title(("Белая осока · " if SliceSession.current != null else "Cultivation RPG · P4 · ") + id)
	get_tree().auto_accept_quit = false
	SedgeLandscape.light(stage)
	player = SedgePlayer.new()
	if SliceSession.current != null and session.state.active_body>0: player.appearance = "character-male-f" if session.state.slice.carrier=="cold" else "character-male-b"
	player.external_motion = true
	stage.add_child(player)
	player.collision_layer = 2
	player.collision_mask = 3
	player.arm.spring_length = 5.7
	player.arm.collision_mask = 1
	# The collider is authoritative. Only the model and follow rig move at draw rate.
	camera_height = player.pivot.position.y
	player.actor.reparent(stage, false)
	player.pivot.reparent(stage, false)
	var camera := get_viewport().get_camera_3d()
	camera.position.z = player.arm.spring_length
	build_ui()
	load_scene()
	if exists:
		pause("restore" if session.state.mode == "active" else "death")
	else:
		input_notice = "Камнееды у водосброса. Южная тропа за спиной ведёт к отдыху."
	if SliceSession.current != null and "--p5-tour" in args: SliceTour.combat.call_deferred(self)
	print("P4_READY rank=", session.state.combat.rank, " loaded=", exists, " renderer=", RenderingServer.get_current_rendering_method())

func load_scene() -> void:
	var before := Time.get_ticks_usec()
	if land != null:
		stage.remove_child(land)
		land.queue_free()
	land = SedgeLandscape.new()
	stage.add_child(land)
	land.populate(session.state)
	geometry = CombatGeometry.new(get_world_3d())
	geometry.bodies[HERO] = player
	world_meshes.clear()
	shot_meshes.clear()
	volumes.clear()
	rubble = null
	target = ""
	selection = ""
	var c := session.state.combat
	player.position = CombatWorld.pos(c.actors[HERO])
	for id: String in c.actors:
		if not CombatWorld.present(session.state, id):
			continue
		if id != HERO:
			add_opponent(id, c.actors[id])
		volumes[id] = land.shape(Vector3.ZERO, Vector3.ONE, Color("#ffbf72"), true)
		volumes[id].material_override = translucent(Color(1, 0.43, 0.22, 0.28))
	preview = land.shape(Vector3.ZERO, Vector3.ONE, Color("#fce3ae"), true)
	preview.material_override = translucent(Color(1, 0.9, 0.52, 0.23))
	ward = sphere(land, Color(0.38, 0.89, 0.93, 0.29), 1.13)
	board = land.shape(Vector3.ZERO, Vector3(0.28, 0.12, 2.1), Color("#8bcbd1"))
	if in_court() and not CombatWorld.crossing(session.state):
		land.shape(P4Content.PASSAGE + Vector3.UP * 0.02, Vector3(2.5, 0.04, 3.0), Color("#b2c698"))
		land.shape(Vector3(-6.3, 0.02, P4Content.SHORT_EXIT.z), Vector3(5, 0.04, 1.6), Color("#c5bd8b"))
		for dz: float in [-2.0, 2.0]:
			var edge := Vector3(-6.4, 0.7, P4Content.SHORT_EXIT.z + dz)
			land.shape(edge, Vector3(4.7, 1.45, 0.8), Color("#766350"))
			land.solid(edge, Vector3(4.7, 1.45, 0.8))
		var refuge := Label3D.new()
		refuge.text = "Боковой отход"
		refuge.position = Vector3(-6.6, 1.5, P4Content.SHORT_EXIT.z)
		refuge.font_size = 40
		refuge.pixel_size = 0.004
		refuge.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		land.add_child(refuge)
		var cover := Vector3(5.3, 1.1, -11.0)
		land.shape(cover, Vector3(2.0, 2.2, 1.15), Color("#585d56"))
		land.solid(cover, Vector3(2.0, 2.2, 1.15))
		var access := Label3D.new()
		access.text = "Тропа за водосбросом"
		access.font_size = 42
		access.pixel_size = 0.004
		access.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		access.position = P4Content.PASSAGE + Vector3.UP * 2
		land.add_child(access)
		world_meshes["passage"] = access
		land.solid(P4Content.PASSAGE + Vector3(0, 0.7, -1), Vector3(2.5, 1.5, 0.5), access_marker_block())
	motion.reset(c.tick, c.credit)
	project(true)
	render_motion(0.0)
	load_usec = Time.get_ticks_usec() - before

func access_marker_block() -> Node3D:
	var barrier := Node3D.new()
	land.add_child(barrier)
	land.shape(P4Content.PASSAGE + Vector3(0, 0.7, -1), Vector3(2.5, 1.5, 0.5), Color("#6a6c5a")).reparent(barrier)
	world_meshes["barrier"] = barrier
	return barrier

func add_opponent(id: String, a: Dictionary) -> void:
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 3
	land.add_child(body)
	body.position = CombatWorld.pos(a)
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.42
	capsule.radius = 0.48 if id == P4Content.HORNED else 0.38
	collider.shape = capsule
	collider.position.y = 0.72
	body.add_child(collider)
	geometry.bodies[id] = body
	var anchor := Node3D.new()
	land.add_child(anchor)
	var model := Node3D.new()
	anchor.add_child(model)
	var size_factor := 1.3 if id == P4Content.HORNED else 0.95
	var mesh := land.shape(Vector3(0, 0.68, 0), Vector3(1.0, 1.21, 1.33) * size_factor, COLORS[id], true)
	mesh.rotation.z = 0.32
	mesh.reparent(model, false)
	var head := land.shape(Vector3(0, 0.78, -0.6) * size_factor, Vector3(0.68, 0.58, 0.65), Color("#5b4f45"))
	head.reparent(model, false)
	var label := Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position.y = 1.72 * size_factor
	label.font_size = 46
	label.pixel_size = 0.0038
	label.outline_size = 12
	anchor.add_child(label)
	world_meshes[id] = {"anchor":anchor, "model":model, "label":label}

func translucent(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material

func sphere(parent: Node3D, colour: Color, radius: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radial_segments = 16
	mesh.rings = 8
	mesh.radius = radius
	mesh.height = radius * 2
	node.mesh = mesh
	node.material_override = translucent(colour)
	parent.add_child(node)
	return node

func in_court() -> bool:
	return session.state.exploration.place == SedgeWorld.YARD

func project(capture_pose: bool, snap_hero: bool = false) -> void:
	var c := session.state.combat
	var a: Dictionary = c.actors[HERO]
	if capture_pose:
		player.position = CombatWorld.pos(a)
		var facing := CombatState.vec(a.face)
		motion.capture(HERO, player.position, atan2(facing.x, facing.z), snap_hero)
	var speed := Vector2(a.velocity[0], a.velocity[2]).length() / 1000.0
	var clip := "idle" if speed < 0.3 or a.flight != "ground" else ("sprint" if speed > 5 else "walk")
	SedgeLandscape.play_clip(player.actor, clip, perception_rate())
	ward.visible = a.shield > 0
	board.visible = a.flight == "artifact"
	if world_meshes.has("barrier"):
		var barrier: Node3D = world_meshes.barrier
		var won: bool = c.actors[P4Content.HORNED].hp == 0
		barrier.position.y = -4 if won else 0
		barrier.visible = not won
		world_meshes.passage.text = "Тропа открыта" if won else "Тропа за водосбросом · перекрыта"
	if c.collapse and rubble == null and in_court() and not CombatWorld.crossing(session.state):
		rubble = Node3D.new()
		land.add_child(rubble)
		var center := P4Content.SHORT_EXIT + Vector3(-1.0, 0.7, 0)
		land.shape(center, Vector3(1.1, 1.5, 4), Color("#766350")).reparent(rubble)
		land.solid(center, Vector3(1.1, 1.5, 4), rubble)
	for id: String in volumes:
		var actor: Dictionary = c.actors[id]
		var phase: Dictionary = actor.action
		var volume: MeshInstance3D = volumes[id]
		var card: Dictionary = P4Content.ACTIONS.get(phase.key, {})
		volume.visible = phase.wind > 0 and card.get("kind", "") in ["ground", "sphere", "pulse"]
		if volume.visible:
			show_volume(volume, card, CombatState.vec(phase.center))
		if id == HERO:
			continue
		var body := geometry.bodies[id]
		if capture_pose:
			body.position = CombatWorld.pos(actor)
			motion.capture(id, body.position, atan2(-float(actor.face[0]), -float(actor.face[2])))
		body.collision_layer = 2 if actor.hp > 0 else 0
		var visual: Dictionary = world_meshes[id]
		visual.model.scale.y = 1.0 if actor.hp > 0 else 0.25
		visual.model.visible = actor.hp > 0 or actor.loot != ""
		visual.label.visible = actor.hp > 0 or actor.loot in ["intact", "damaged"]
		var status := " · %s" % P4Content.LABELS[phase.key] if phase.wind > 0 else (" · открыт бок" if phase.rest > 0 and id != P4Content.AIR else "")
		visual.label.text = "%s%s%s%s" % [P4Content.NAMES[id], " ‹ " if target == id else "", " · %d" % actor.hp if actor.hp > 0 else " · пластина", status]
		var accent := Color("#fff6c0") if target == id else (Color("#ffd2a2") if phase.wind > 0 else Color.WHITE)
		visual.label.modulate = accent
	var active := {}
	for shot: Dictionary in c.projectiles:
		if not shot_meshes.has(shot.id):
			var tint := Color("#f7a66f") if shot.owner != HERO else (Color("#a9d2ff") if shot.key == "seek" else Color("#fff3ae"))
			shot_meshes[shot.id] = sphere(land, tint, 0.17)
		if capture_pose:
			motion.capture(shot.id, CombatState.vec(shot.pos))
		active[shot.id] = true
	for sid: int in shot_meshes.keys():
		if not active.has(sid):
			shot_meshes[sid].hide()
			shot_meshes[sid].queue_free()
			shot_meshes.erase(sid)
			motion.erase(sid)

func render_motion(fraction: float) -> void:
	var ticks_back := motion.lookback(fraction)
	var hero_pose := motion.pose(HERO, ticks_back)
	apply_pose(player.actor, hero_pose)
	player.pivot.position = player.actor.position + Vector3.UP * camera_height
	ward.position = player.actor.position + Vector3.UP * 0.78
	board.position = player.actor.position - Vector3.UP * 0.03
	board.rotation.y = hero_pose.w
	for id: String in volumes:
		if id != HERO:
			apply_pose(world_meshes[id].anchor, motion.pose(id, ticks_back))
	for sid: int in shot_meshes:
		apply_pose(shot_meshes[sid], motion.pose(sid, ticks_back))

static func apply_pose(node: Node3D, pose: Vector4) -> void:
	node.position = Vector3(pose.x, pose.y, pose.z)
	node.rotation.y = pose.w

func show_volume(node: MeshInstance3D, card: Dictionary, center: Vector3) -> void:
	var height: float = card.get("height", card.radius * 2.0)
	node.mesh = VOLUME_SPHERE if card.kind in ["sphere", "pulse"] else VOLUME_CYLINDER
	node.scale = Vector3(card.radius * 2.0, height, card.radius * 2.0)
	node.position = center if card.kind in ["sphere", "pulse"] else center + Vector3.UP * (height / 2.0)

static var VOLUME_CYLINDER: CylinderMesh = cylinder()
static var VOLUME_SPHERE: SphereMesh = unit_sphere()

static func cylinder() -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 24
	mesh.height = 1.0
	return mesh

static func unit_sphere() -> SphereMesh:
	var mesh := SphereMesh.new()
	mesh.radial_segments = 24
	mesh.rings = 12
	return mesh

func _physics_process(delta: float) -> void:
	if session == null or land == null or get_tree().paused:
		return
	var start_usec := Time.get_ticks_usec()
	player.pivot.rotate_y(Input.get_axis("orbit_right", "orbit_left") * delta * 1.9)
	var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	held = player.pivot.basis * Vector3(move.x, 0, move.y)
	held.y = float(Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_CTRL))
	update_aim()
	for key: int in keys:
		handle_key(key)
		if get_tree().paused:
			break
	keys.clear()
	if click and not get_tree().paused:
		if selection != "":
			if aim.is_finite():
				command(selection, true)
			else:
				input_notice = "Выберите подходящую поверхность в пределах дальности."
		else:
			target = pick(pointer)
	click = false
	if get_tree().paused:
		return
	var c := session.state.combat
	var old_tick: int = c.tick
	var action: Dictionary = c.actors[HERO].action
	var blink_end: Array = action.center if action.key == "blink" and action.wind == 1 else []
	var important := CombatWorld.advance(session.state, geometry, held, Input.is_action_pressed("sprint"))
	motion.advance_clock(c.tick, c.credit)
	project(c.tick != old_tick, blink_end == c.actors[HERO].pos)
	checkpoint_seconds += delta
	if important or checkpoint_seconds >= 5.0:
		checkpoint()
	if session.state.mode != "active" and not session.dirty:
		pause("death")
	if not probe.is_empty():
		step_samples.append(Time.get_ticks_usec() - start_usec)
		if step_samples.size() > 3600:
			step_samples.pop_front()

func _process(delta: float) -> void:
	if session == null or land == null:
		return
	if not get_tree().paused:
		render_motion(Engine.get_physics_interpolation_fraction())
	render_hud()
	if probe != "":
		probe_elapsed += delta
		if not get_tree().paused:
			frames.append(delta * 1000.0)
			if frames.size() > 3600:
				frames.pop_front()
		if probe_elapsed >= 0.2:
			probe_elapsed = 0
			write_probe()
	if capture_requested:
		capture_requested = false
		await RenderingServer.frame_post_draw
		capture_serial += 1
		get_viewport().get_texture().get_image().save_png("%s.%02d.png" % [probe, capture_serial])

func record_motion() -> void:
	if not world_meshes.has(P4Content.YOUNG) or motion_samples.size() >= 2400:
		return
	var c := session.state.combat
	var camera := get_viewport().get_camera_3d()
	var hero := player.actor.global_position
	var opponent: Node3D = world_meshes[P4Content.YOUNG].model
	if c.projectiles.is_empty() or not shot_meshes.has(c.projectiles[0].id):
		return
	var shot: MeshInstance3D = shot_meshes[c.projectiles[0].id]
	var landmark := camera.unproject_position(Vector3(1.8, 1.0, -12.0))
	var missile := camera.unproject_position(shot.global_position)
	var enemy := camera.unproject_position(opponent.global_position + Vector3.UP)
	var hero_screen := camera.unproject_position(hero + Vector3.UP)
	motion_samples.append([
		Time.get_ticks_usec(), c.tick, c.credit, c.perception, Engine.get_physics_frames(),
		xyz(hero), xyz(opponent.global_position), xyz(shot.global_position), xyz(camera.global_position),
		[landmark.x, landmark.y], [missile.x, missile.y], [enemy.x, enemy.y], [hero_screen.x, hero_screen.y],
		c.actors[HERO].pos.duplicate(), c.actors[P4Content.YOUNG].pos.duplicate(), c.projectiles[0].pos.duplicate(),
		get_tree().paused
	])

func xyz(point: Vector3) -> Array[float]:
	return [point.x, point.y, point.z]

func write_probe() -> void:
	var buttons := {}
	for panel in [book_box, pause_box]:
		for child in panel.get_children():
			if child is Button and child.is_visible_in_tree():
				var midpoint: Vector2 = child.get_global_rect().get_center()
				buttons[child.text] = [midpoint.x, midpoint.y]
	var output := FileAccess.open(probe, FileAccess.WRITE)
	if output == null:
		return
	output.store_string(JSON.stringify({
		"combat":session.state.combat, "campaign":session.state.campaign_id, "day":session.state.day,
		"place":session.state.exploration.place, "crossing":CombatWorld.crossing(session.state), "mode":session.state.mode, "modal":modal,
		"sequence":session.store.sequence, "paused":get_tree().paused, "target":target, "selection":selection,
		"frames_ms":frames, "process_us":step_samples, "items":session.state.materials.items,
		"video_bytes":int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
		"resolution":[get_viewport().size.x, get_viewport().size.y],
		"checkpoint_us":last_checkpoint_us, "load_us":load_usec,
		"storage":session.store.directory, "notice":input_notice, "buttons":buttons
	}))

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		var key: int = event.physical_keycode if event.physical_keycode != 0 else event.keycode
		if key == KEY_F10 and probe != "":
			capture_requested = true
		elif key == KEY_ESCAPE:
			if get_tree().paused:
				resume()
			else:
				pause("manual")
			get_viewport().set_input_as_handled()
		elif not get_tree().paused:
			keys.append(key)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not get_tree().paused:
		click = true
		pointer = event.position

func handle_key(key: int) -> void:
	input_notice = ""
	var s := session.state
	if HOTKEYS.has(key):
		choose(HOTKEYS[key])
		return
	match key:
		KEY_TAB:
			var seen: Array[String] = visible_targets()
			if seen.is_empty():
				target = ""
			else:
				target = "" if seen.find(target) == seen.size() - 1 else seen[seen.find(target) + 1]
			update_aim()
		KEY_B:
			book.visible = not book.visible
		KEY_R:
			CombatWorld.toggle_perception(s)
		KEY_V:
			CombatWorld.toggle_flight(s.combat)
		KEY_M:
			CombatWorld.toggle_meditation(s)
		KEY_X:
			s.combat.actors[HERO].shield = 0
			s.combat.actors[HERO].shield_ticks = 0
		KEY_E:
			if CombatWorld.crossing(s):
				if s.combat.actors[P4Content.CROSSING].hp == 0 and not CombatWorld.engaged(s):
					finish_crossing()
				else:
					input_notice = "Устраните угрозу, прежде чем продолжить путь."
			elif CombatWorld.claim(s):
				checkpoint()
			elif near_route() and safe():
				pause("route")
			elif safe():
				pause("rest")
			else:
				input_notice = "Отойдите по южной тропе к безопасному месту."

func choose(key: String) -> void:
	if key in ["blink", "ground", "sphere"]:
		selection = "" if selection == key else key
		aim = Vector3.INF
	else:
		selection = ""
		command(key)

func command(key: String, ground_click: bool = false) -> void:
	var c := session.state.combat
	var a: Dictionary = c.actors[HERO]
	var card: Dictionary = P4Content.ACTIONS[key]
	var direction := -player.pivot.basis.z
	var victim := target if card.kind in ["melee", "shot", "sphere", "ground"] else ""
	if card.kind == "dodge" and Vector2(held.x, held.z).length_squared() > 0.1:
		direction = Vector3(held.x, 0, held.z)
	if card.kind == "guard" and target != "" and c.actors[target].hp > 0:
		direction = (CombatWorld.pos(c.actors[target]) - CombatWorld.pos(a)).normalized()
	CombatWorld.submit(session.state, CombatState.order(key, victim, aim if ground_click else Vector3.ZERO, direction))
	selection = ""

func visible_targets() -> Array[String]:
	var result: Array[String] = []
	if not in_court() and not CombatWorld.crossing(session.state):
		return result
	var c := session.state.combat
	for id: String in P4Content.ACTORS:
		if CombatWorld.present(session.state, id) and CombatWorld.opponent(c, HERO, id) and CombatWorld.chest(c.actors[HERO]).distance_to(CombatWorld.chest(c.actors[id])) <= 22 and not geometry.blocked(CombatWorld.chest(c.actors[HERO]), CombatWorld.chest(c.actors[id])):
			result.append(id)
	return result

func pick(at: Vector2) -> String:
	var camera := get_viewport().get_camera_3d()
	var closest := 58.0
	var result := ""
	for id: String in visible_targets():
		var model: Node3D = world_meshes[id].anchor
		var point := model.global_position + Vector3.UP * 0.78
		if not camera.is_position_behind(point):
			var distance := camera.unproject_position(point).distance_to(at)
			if distance < closest:
				closest = distance
				result = id
	return result

func update_aim() -> void:
	preview.visible = false
	var c := session.state.combat
	if target != "" and not CombatWorld.opponent(c, HERO, target):
		target = ""
	if selection == "":
		return
	var a: Dictionary = c.actors[HERO]
	var camera := get_viewport().get_camera_3d()
	var mouse := get_viewport().get_mouse_position()
	if click:
		mouse = pointer
	var from := camera.project_ray_origin(mouse)
	var hit := geometry.ray(from, from + camera.project_ray_normal(mouse) * 35)
	var middle := CombatWorld.pos(a) - player.pivot.basis.z * 4.0
	var ability: Dictionary = P4Content.ACTIONS[selection]
	if selection == "sphere":
		aim = CombatWorld.chest(c.actors[target]) if target != "" else Vector3.INF
	elif selection == "ground" and target != "":
		aim = geometry.surface(CombatWorld.chest(c.actors[target]))
	else:
		aim = geometry.surface(middle) if hit.is_empty() else geometry.surface(hit.position)
	if aim.is_finite() and CombatWorld.pos(a).distance_to(aim) <= ability.range:
		preview.visible = true
		show_volume(preview, ability if selection != "blink" else {"kind":"ground", "radius":0.5, "height":0.15}, aim)
	else:
		aim = Vector3.INF

func safe() -> bool:
	var a: Dictionary = session.state.combat.actors[HERO]
	return a.flight == "ground" and not CombatWorld.engaged(session.state) and (not in_court() or CombatWorld.refuge(session.state.combat, player.position))

func near_route() -> bool:
	return player.position.distance_to(P4Content.WAYPOINT if in_court() else Vector3(0, 0, 2)) < 3.25

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Arial"])
	theme.default_font = font
	theme.default_font_size = 18
	canvas.theme = theme
	add_label(hud, Vector2(16, 12))
	add_label(targets, Vector2(16, 113))
	add_label(help, Vector2(16, 0))
	help.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	help.offset_left = 16
	help.offset_top = -105
	canvas.add_child(book)
	book.position = Vector2(690,12)
	book.custom_minimum_size.x = 250
	book.add_theme_stylebox_override("panel", panel_style())
	book.add_child(book_box)
	for key: String in P4Content.skills(session.state):
		var action := key
		var label: String = P4Content.LABELS[key]
		var card: Dictionary = P4Content.ACTIONS[key]
		add_button(book_box, "%s · %d Ци" % [label, card.qi], func() -> void:
			if not get_tree().paused:
				choose(action))
	book.hide()
	canvas.add_child(pause_panel)
	pause_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pause_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pause_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	pause_panel.add_theme_stylebox_override("panel", panel_style())
	pause_panel.add_child(pause_box)
	pause_panel.hide()

func panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#162b2bf5")
	style.border_color = Color("#bd9b65")
	style.border_width_left = 3
	for side: Side in [SIDE_LEFT, SIDE_RIGHT, SIDE_BOTTOM, SIDE_TOP]:
		style.set_content_margin(side, 10)
	return style

func add_label(label: Label, at: Vector2) -> void:
	canvas.add_child(label)
	label.position = at
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_stylebox_override("normal", panel_style())

func add_button(parent: VBoxContainer, label: String, handler: Callable) -> void:
	var button := Button.new()
	button.text = label
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(handler)
	parent.add_child(button)

func perception_rate() -> float:
	if not session.state.combat.perception:
		return 1.0
	return 0.25 if session.state.soul.mastery.get("combat.perception", 0) == 2 else 0.5

func render_hud() -> void:
	var s := session.state
	var c := s.combat
	var a: Dictionary = c.actors[HERO]
	var site := "Переправа" if CombatWorld.crossing(s) else ("Водосброс" if in_court() else "Дальний берег")
	var flight: String = {"ground":"земля", "artifact":"артефакт", "self":"самостоятельный полёт", "glide":"снижение"}[a.flight]
	var speed := "  ·  Восприятие ×%.2f" % perception_rate() if c.perception else ""
	hud.text = "%s  /  %s  ·  %s\nЗдоровье %d  ·  Ци %.1f  ·  Щит %d  ·  Талисманы %d  ·  Управление %d/%d\n%s  ·  %.1f м%s%s%s" % [
		site, P4Content.RANK_NAMES[c.rank], WorldCalendar.label(s.day), a.hp, float(a.qi)/1000, a.shield, c.wards,
		CombatWorld.control_load(c), CombatWorld.control(c), flight, maxf(0, player.position.y), speed,
		"  ·  Медитация" if c.meditating else "", "  ·  Травма рёбер" if a.injury else ""]
	if s.slice.get("unstable",0) > 0: hud.text += "\nНестабильная Ци %d · распад %s" % [s.slice.unstable,WorldCalendar.label(s.slice.decay)]
	var phase := ""
	if a.action.key != "":
		phase = "%s: %s %.1f c" % [P4Content.LABELS[a.action.key], "подготовка" if a.action.wind else "восстановление", maxf(a.action.wind, a.action.rest) / 60.0]
	if c.queued.key != "":
		phase += "  →  " + str(P4Content.LABELS[c.queued.key])
	var info := ""
	if target != "":
		var victim: Dictionary = c.actors[target]
		info = "%s  ·  Здоровье %d  ·  %.1f м" % [P4Content.NAMES[target], victim.hp, CombatWorld.pos(a).distance_to(CombatWorld.pos(victim))]
		if victim.armor > 0: info += "  ·  Каменный панцирь %d" % victim.armor
	var status: String = input_notice if input_notice != "" else c.notice
	var parts := PackedStringArray()
	if CombatWorld.crossing(s):
		var trip := SedgeWorld.active_trip(s)
		parts.append("Путь прерван · %d из %d дней" % [trip.progress, trip.duration])
	for line: String in [info, phase, status, c.warning]:
		if line != "": parts.append(line)
	targets.text = "\n".join(parts)
	targets.visible = not parts.is_empty() and not get_tree().paused
	hud.visible = not get_tree().paused
	help.text = "WASD ходьба  ·  ПКМ / ← → обзор  ·  ЛКМ / Tab цель  ·  Shift быстрее  ·  Esc пауза\n1 удар  2 искра  3 наведение  4 круг  5 сфера  Q уклонение  G блок  T талисман  X снять щит\nR восприятие  ·  M медитация  ·  B техники  ·  V полёт  ·  Space / Ctrl высота  ·  E добыча / отдых / путь"
	if selection != "":
		help.text += "\nЛКМ подтвердить точку  ·  %s" % P4Content.LABELS[selection]
		help.offset_top = -125
	else:
		help.offset_top = -105
	help.visible = not get_tree().paused

func checkpoint() -> bool:
	checkpoint_seconds = 0.0
	var s := session.state
	var a: Dictionary = s.combat.actors[HERO]
	s.exploration.x = roundi(float(a.pos[0]) / 10)
	s.exploration.z = roundi(float(a.pos[2]) / 10)
	s.revision += 1
	var before := Time.get_ticks_usec()
	if not session.save():
		pause("error")
		return false
	last_checkpoint_us = Time.get_ticks_usec() - before
	return true

func pause(view: String) -> void:
	get_tree().paused = true
	player.locked = true
	keys.clear()
	click = false
	book.hide()
	modal = view
	for child in pause_box.get_children():
		pause_box.remove_child(child)
		child.queue_free()
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 28)
	pause_box.add_child(title)
	var c := session.state.combat
	var a: Dictionary = c.actors[HERO]
	var text := Label.new()
	text.custom_minimum_size.x = 464
	pause_box.add_child(text)
	match view:
		"error":
			title.text = "Ошибка сохранения"
			text.text = session.error
			add_button(pause_box, "Повторить запись", func() -> void:
				if session.save(): pause("manual" if session.state.mode == "active" else "death"))
		"death":
			title.text = "Тело погибло"
			text.text = "%s\nСостояние сохранено. Дата %s." % [c.notice, WorldCalendar.label(session.state.day)]
		"route":
			title.text = "Межлокационный путь"
			text.text = "Переправа на другой берег займёт %d дней.\nПрибытие %s. Возможна остановка в пути." % [SedgeWorld.ROUTE_BASE + SedgeWorld.FLOOD_DELAY, WorldCalendar.label(session.state.day + SedgeWorld.ROUTE_BASE + SedgeWorld.FLOOD_DELAY)]
			add_button(pause_box, "Лодка · подтвердить 5 дней", travel.bind(false))
			if CombatWorld.flight_mode(c) != "":
				add_button(pause_box, "Перелёт · 5 дней и 6 Ци", travel.bind(true))
		"interrupted":
			var trip := SedgeWorld.active_trip(session.state)
			title.text = "Путь прерван"
			text.text = "Пройдено %d из %d дней · %s\nКанат парома зацепился у затопленной косы." % [trip.progress, trip.duration, WorldCalendar.label(session.state.day)]
			add_button(pause_box, "Удержать канат и продолжить", finish_trip)
		"rest":
			title.text = "Отдых на берегу"
			text.text = "Здоровье %d/100. Доз лекарства: %d.\nДля восстановления Ци используйте медитацию (M)." % [a.hp, c.medicine]
			if a.hp < SliceWorld.vitals(session.state).hp:
				add_button(pause_box, "Лечение +50 здоровья · 7 дней", recovery.bind(false, false))
				if c.medicine > 0:
					add_button(pause_box, "Лечение с лекарством · 2 дня и доза", recovery.bind(true, false))
			if a.injury:
				add_button(pause_box, "Восстановить рёбра · 1 год", recovery.bind(false, true))
		_:
			title.text = "Продолжение на паузе" if view == "restore" else "Системная пауза"
			text.text = "Ци %.1f  ·  Щит %d  ·  В полёте снарядов %d\nБоевые команды доступны после продолжения." % [float(a.qi) / 1000, a.shield, c.projectiles.size()]
	if SliceSession.current != null and (view == "death" or (view in ["manual","restore","rest"] and safe() and not MaterialWorld.occupied(session.state))):
		add_button(pause_box,"Продолжить путь души" if view == "death" else "Вернуться в долину",return_village)
	if view not in ["error", "death", "interrupted"]:
		add_button(pause_box, "Продолжить   /   Esc", resume)
	if view != "error":
		add_button(pause_box, "Сохранить и выйти   /   F12", leave)
	pause_panel.reset_size()
	pause_panel.show()

func return_village() -> void:
	if not SliceSession.current.switch_area("village"):
		show_error(session.error if session.error != "" else "Дождитесь окончания действия и выйдите из боя.")
		return
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(SliceSession.VILLAGE)

func resume() -> void:
	if session.dirty:
		return
	if session.state.mode != "active":
		pause("death")
		return
	var active := session.state.running()
	if active != null and active.kind == "recovery":
		if session.advance(active.duration - active.progress):
			pause("rest" if session.state.mode == "active" else "death")
		else:
			show_error(session.error)
		return
	var trip := SedgeWorld.active_trip(session.state)
	if trip != null:
		if trip.status == "paused":
			if not CombatWorld.crossing(session.state):
				pause("interrupted")
				return
		else:
			continue_trip()
			return
	pause_panel.hide()
	modal = ""
	player.locked = false
	get_tree().paused = false

func travel(by_air: bool) -> void:
	if not safe() or not near_route():
		return
	var s := session.state
	var candidate := StateCodec.clone(s)
	var plan := SedgeWorld.route_plan(candidate)
	var result := SedgeWorld.depart(candidate, plan, by_air)
	if not session.commit(candidate, result):
		if session.dirty: pause("error")
		else: show_error(session.error)
		return
	continue_trip()

func finish_trip() -> void:
	if session.act("rope"): continue_trip()
	else: show_error(session.error)

func finish_crossing() -> void:
	var trip := SedgeWorld.active_trip(session.state)
	if session.resume(trip.id, trip.id + ".cleared"):
		continue_trip()
	else:
		show_error(session.error)

func continue_trip() -> void:
	var trip := SedgeWorld.active_trip(session.state)
	if trip != null and not session.advance(trip.duration - trip.progress):
		show_error(session.error)
		return
	if CombatWorld.crossing(session.state):
		load_scene()
		resume()
	elif SedgeWorld.active_trip(session.state) != null:
		pause("interrupted")
	else:
		load_scene()
		resume()
		input_notice = "Прибытие. Время пути записано в календарь."

func recovery(with_medicine: bool, ribs: bool) -> void:
	if not safe():
		return
	var s := session.state
	var candidate := StateCodec.clone(s)
	if not session.commit(candidate, CombatWorld.begin_recovery(candidate, with_medicine, ribs)):
		show_error(session.error)
		return
	resume()

func show_error(message: String) -> void:
	if session.dirty:
		pause("error")
	else:
		input_notice = message
		resume()

func leave() -> void:
	if session == null:
		return
	pause("manual")
	if checkpoint():
		if not motion_samples.is_empty():
			var trace := FileAccess.open(motion_probe, FileAccess.WRITE)
			if trace == null:
				push_error("Cannot write P4 motion trace")
			else:
				trace.store_string(JSON.stringify(motion_samples, "", true, true))
		get_tree().quit()

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F12 and get_tree().paused and session != null:
		leave()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		leave()
