extends Node3D

const NAMES := {"merchant":"Торговец", "root":"Бледные цветы", "sign":"Медный блеск", "gate":"Старый затвор", "ferry":"Переправа", "retreat":"Уединение"}
const NOTES := {"accept":"Ло Вэй просил вернуть знак из водосброса.", "decline":"Я отказалась от просьбы Ло Вэя.", "take":"У старого водосброса найден медный знак.", "return":"Я вернула знак. Ло Вэй дал мне припасы.", "gift":"Ло Вэй доверил мне свой ключ к формации.", "notch":"На обороте знака — насечка с разрывом.", "open":"Знак установлен. Каменная решётка открыта.", "rope":"Я удержала канат. Вода поднялась.", "observe.dry":"Осмотр берега: прозрачные прожилки под сухим илом.", "observe.flooded":"Осмотр берега: корни скрыты под свежей водой.", "interpret.dry":"По прожилкам предполагаю стеклянный корень. Для извлечения нужно травничество.", "interpret.flooded":"После разлива прежний способ осмотра непригоден.", "successor":"Инь Цю сообщил о смерти Ло Вэя. Личного обещания он не давал."}
var session: SedgeSession
var land: SedgeLandscape
var player: SedgePlayer
var ui := Control.new()
var heading := Label.new()
var hint := Label.new()
var panel := PanelContainer.new()
var column := VBoxContainer.new()
var target := ""
var elapsed := 0.0
var smoke := false

func _ready() -> void:
	smoke = "--p2-smoke" in OS.get_cmdline_user_args()
	var id := "white-sedge" if not smoke else "visit-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var base := "user://sedge"
	if smoke:
		base = "user://sedge-smoke"
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--slot="): id = arg.trim_prefix("--slot=")
	session = SedgeSession.new(SedgeWorld.fresh(id),SnapshotStore.new(base,id,true))
	var storage := session.store
	if FileAccess.file_exists(storage.path("current.json")) or FileAccess.file_exists(storage.path("previous.json")):
		if not session.reload():
			push_error(session.error)
			get_tree().quit(1)
			return
	elif not session.save():
		push_error(session.error)
		get_tree().quit(1)
		return
	get_tree().auto_accept_quit = false
	var env := Environment.new()
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#668a94")
	sky_material.sky_horizon_color = Color("#e2d8b6")
	sky_material.ground_horizon_color = sky_material.sky_horizon_color
	sky.sky_material = sky_material
	env.sky = sky
	env.background_mode = Environment.BG_SKY
	env.background_color = Color("#b9d5cb")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#e0e7da")
	env.ambient_light_energy = 0.46 if RenderingServer.get_current_rendering_method() == "forward_plus" else 0.32
	env.fog_enabled = true
	env.fog_light_color = Color("#b3ccbe")
	env.fog_density = 0.012
	var world := WorldEnvironment.new()
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-46,-32,0)
	sun.light_color = Color("#ffebce")
	sun.light_energy = 0.88 if RenderingServer.get_current_rendering_method() == "forward_plus" else 0.49
	sun.shadow_enabled = true
	add_child(sun)
	player = SedgePlayer.new()
	add_child(player)
	build_ui()
	enter()
	restore_action()
	if smoke: call_deferred("tour")

func enter() -> void:
	if land != null:
		remove_child(land)
		land.queue_free()
	land = SedgeLandscape.new()
	add_child(land)
	land.populate(session.state)
	player.position = Vector3(float(session.state.exploration.x)/100,0.12,float(session.state.exploration.z)/100)
	player.velocity = Vector3.ZERO
	refresh()

func style(bg: Color, pad: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = bg
	box.border_width_left = 3
	box.border_color = Color("#d2ab71")
	for side: Side in [SIDE_LEFT,SIDE_RIGHT,SIDE_TOP,SIDE_BOTTOM]:
		box.set_content_margin(side,pad)
	return box

func build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font_size = 19
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI","Arial"])
	theme.default_font = font
	ui.theme = theme
	for item: Label in [heading,hint]:
		ui.add_child(item)
		item.add_theme_stylebox_override("normal",style(Color("#172e2cec"),10))
	heading.position = Vector2(20,18)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	hint.offset_left = 20
	hint.offset_top = -66
	ui.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size.x = 510
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.add_theme_stylebox_override("panel",style(Color("#182e2ef9"),23))
	panel.add_child(column)
	column.add_theme_constant_override("separation",9)
	panel.hide()

func refresh() -> void:
	var s := session.state
	var name_text := "Торговый двор" if s.exploration.place == "court" else "Дальний берег"
	heading.text = "Белая осока   /   %s    ·    %s" % [name_text, WorldCalendar.label(s.day)]

func _process(delta: float) -> void:
	if land == null: return
	target = ""
	var distance := 2.85
	for key: String in land.points:
		if key == "sign" and session.state.exploration.holder != "spillway": continue
		var d := player.position.distance_to(land.points[key])
		if d < distance:
			target = key
			distance = d
	hint.text = "E   %s" % NAMES[target] if target != "" else "WASD  Ходьба     Shift  Бег     ← →  Камера     J  Журнал     Esc  Меню"
	hint.visible = not panel.visible
	if not player.locked:
		elapsed += delta
		if elapsed >= 5:
			elapsed = 0
			if not session.checkpoint(player.position): failure()

func _unhandled_input(event: InputEvent) -> void:
	if player == null: return
	if event.is_action_pressed("sedge_menu"):
		if panel.visible: close_panel()
		else: menu()
	elif not panel.visible and event.is_action_pressed("journal"): journal()
	elif not panel.visible and event.is_action_pressed("use") and target != "":
		if session.checkpoint(player.position): interact(target)
		else: failure()

func show_panel(title: String, body: String, options: Dictionary = {}) -> void:
	for child in column.get_children():
		column.remove_child(child)
		child.queue_free()
	var caption := Label.new()
	caption.text = title
	caption.add_theme_font_size_override("font_size",26)
	caption.modulate = Color("#efd0a0")
	column.add_child(caption)
	var content := Label.new()
	content.text = body
	content.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.custom_minimum_size.x = 470
	if body.length() > 450:
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(505,265)
		column.add_child(scroll)
		scroll.add_child(content)
	else:
		column.add_child(content)
	for label: String in options:
		button(label,options[label])
	button("Закрыть",close_panel)
	panel.reset_size()
	panel.show()
	player.locked = true
	refresh()

func button(label: String, callback: Callable) -> void:
	var control := Button.new()
	control.text = label
	control.pressed.connect(callback)
	column.add_child(control)

func close_panel() -> void:
	panel.hide()
	player.locked = false
	if session.dirty: failure()
	elif SedgeWorld.active_trip(session.state) != null: restore_action()

func failure() -> void:
	show_panel("Сохранение",session.error,{"Повторить запись":retry})

func retry() -> void:
	if session.save():
		enter()
		close_panel()
	else: failure()

func act(command: String) -> void:
	if not session.act(command):
		show_panel("Действие недоступно",session.error)
		return
	land.sync(session.state)
	show_panel("Запись в журнале",NOTES.get(command,NOTES.get(command+"."+str(session.state.exploration.source),"Сведения сохранены.")))

func interact(key: String) -> void:
	var s := session.state
	var e := s.exploration
	match key:
		"merchant":
			if not s.person(SedgeWorld.LO).alive:
				if not session.act("successor"):
					failure()
					return
				show_panel("Инь Цю","Старик умер. Я взял его лавку, но о медном знаке мы с ним не говорили.")
			elif e.story == "new":
				show_panel("Ло Вэй","Видишь колесо за осокой? Там я обронил медный знак. Сил спуститься к затвору уже нет. Верни его — поделюсь припасами.",{"Я поищу знак":act.bind("accept"),"Прости, у меня свой путь":act.bind("decline")})
			elif e.story == "asked" and e.holder == s.body().id:
				show_panel("Ло Вэй","Узнаю потёртый край. Ты могла оставить его себе. Вот припасы, как обещал. Загляни ещё как-нибудь.",{"Передать знак":act.bind("return")})
			elif e.story == "returned" and s.day > int(e.notes["return"]):
				show_panel("Ло Вэй","Я всю жизнь берег ключ, а пройти так и не решился. Куда ведёт затвор — не знаю. Возьми его. Ты ведь уже однажды выбрала вернуть его мне.",{"Принять его просьбу":act.bind("gift")})
			else:
				show_panel("Ло Вэй",{"asked":"Ищи под колесом, у старого водосброса.","declined":"Что ж. Тогда просто посиди в тени.","returned":"Сегодня я хочу подержать его сам. До другой встречи.","gift":"Ищи разрыв в узоре камня."}.get(e.story,""))
		"sign": show_panel("Под водяным колесом","Из ила выступает край медной пластины.",{"Поднять знак":act.bind("take")})
		"root":
			var observed: bool = e.notes.has("observe."+e.source)
			var actions := {"Истолковать признаки":act.bind("interpret")} if observed else {"Осмотреть след":act.bind("observe")}
			if e.notes.has("interpret."+e.source):
				actions["Оценить возможность извлечения"] = assess_root
			show_panel("Берег старицы","Вода закрыла старый след." if e.source=="flooded" else "У бледных цветов ил растрескался тонкими полосами.",actions)
		"gate":
			var options := {}
			if e.holder == s.body().id:
				options["Осмотреть оборот знака"] = act.bind("notch")
				if e.notes.has("notch") or e.notes.has("gift"): options["Вставить знак в оправу"] = act.bind("open")
			show_panel("Старый затвор","Порог свободен. За ним тот самый каменный зал." if e.gate else "Сквозь решётку виден зал. Узор на оправе прерывается.",options)
		"retreat":
			var days := WorldCalendar.add_years(s.day,16)-s.day
			var plan := Simulation.preview(s,days,0)
			show_panel("Уединение у дальней пристани","Практика займёт 16 лет. Выход: %s. Мир продолжит жить; пожилые знакомые могут не дождаться. Личные обещания могут утратить силу." % WorldCalendar.label(plan.finish),{"Подтвердить уединение":retreat.bind(plan)})
		"ferry":
			var plan := SedgeWorld.route_plan(s)
			var destination := "дальний берег" if e.place=="court" else "торговый двор"
			show_panel("Переправа","Путь на %s: 3 дня + 2 дня из-за разлива. Прибытие %s. В пути возможна остановка." % [destination,WorldCalendar.label(plan.finish)],{"Отправиться":start_trip.bind(plan)})

func assess_root() -> void:
	var response := "Метод извлечения освоен." if SedgeWorld.qualified(session.state) else "Я знаю, где искать корень, но не умею отделить оболочку от живых волокон. Нужно учиться травничеству."
	show_panel("Стеклянный корень",response)

func start_trip(plan: Dictionary) -> void:
	if not session.depart(plan):
		show_panel("Переправа",session.error)
		return
	restore_action()

func retreat(plan: Dictionary) -> void:
	if not session.confirm(plan,"retreat.%d" % session.state.revision):
		show_panel("Уединение",session.error)
		return
	restore_action()

func restore_action() -> void:
	var active := session.state.running()
	if active != null and active.kind == "practice":
		if not session.advance(active.duration-active.progress):
			failure()
			return
		enter()
		show_panel("Конец уединения","Пора вернуться на торговый двор.")
		return
	var trip := SedgeWorld.active_trip(session.state)
	if trip == null: return
	if trip.status == "running":
		if not session.advance(trip.duration-trip.progress):
			failure()
			return
		trip = SedgeWorld.active_trip(session.state)
	if trip == null:
		enter()
		show_panel("Прибытие","Лодка коснулась берега. Путь записан в календаре.")
	elif trip.status == "paused":
		show_panel("Канат в камышах","Паромщик удерживает лодку у затопленной косы. «Подхвати конец!»\nПройдено %d из %d дней. Остановка: %s." % [trip.progress,trip.duration,WorldCalendar.label(session.state.day)],{"Удержать канат и продолжить":resolve_trip,"Сохранить и выйти":leave})
	else: show_panel("Путешествие завершено",session.state.mode)

func resolve_trip() -> void:
	if session.act("rope"): restore_action()
	else: failure()

func journal() -> void:
	var lines := PackedStringArray()
	var e := session.state.exploration
	for k: String in e.notes:
		var stale: bool = k.ends_with(".dry") and e.source == "flooded" and e.notes.has("observe.flooded")
		lines.append("%s · %s%s" % [WorldCalendar.label(e.notes[k]),NOTES.get(k,k)," (прежние сведения)" if stale else ""])
	show_panel("Путевой журнал","Записей ещё нет. Найдите торговца у красного навеса." if lines.is_empty() else "\n".join(lines))

func menu() -> void:
	show_panel("Долина Белой Осоки","WASD — движение · Shift — бег · E — взаимодействие\nПКМ и мышь или стрелки — поворот · Колесо — расстояние\nJ — журнал. Осмотр и разговоры не расходуют дни.",{"Журнал":journal,"Сохранить и выйти":leave})

func leave() -> void:
	if session.checkpoint(player.position) and session.save(): get_tree().quit()
	else: failure()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and session != null and player != null: leave()

func tour() -> void:
	if "--resume-check" in OS.get_cmdline_user_args():
		if not verify_scene(SedgeWorld.active_trip(session.state) != null and session.state.day == 2,"Restored interrupted crossing"): return
		resolve_trip()
		if not verify_scene(session.state.exploration.place == "landing" and session.state.day == 5,"Resumed on far bank"): return
		start_trip(SedgeWorld.route_plan(session.state))
		if not verify_scene(session.state.exploration.holder == SedgeWorld.LO and session.state.day == 10,"Reentered persisted yard"): return
		print("P2_RESUME_PASS")
		leave()
		return
	await get_tree().create_timer(0.3).timeout
	var start := player.position
	Input.action_press("move_up")
	await get_tree().create_timer(0.4).timeout
	var anim := player.actor.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if not verify_scene(anim.current_animation=="walk" and player.position.distance_to(start)>0.35,"Walking input + clip"): return
	Input.action_press("sprint")
	await get_tree().create_timer(0.3).timeout
	if not verify_scene(anim.current_animation=="sprint","Sprint clip"): return
	Input.action_release("move_up")
	Input.action_release("sprint")
	player.position = Vector3(-7,0.1,3.9)
	Input.action_press("move_up")
	await get_tree().create_timer(1.0).timeout
	Input.action_release("move_up")
	if not verify_scene(player.position.z>2.6,"Market furniture collision"): return
	player.position = start
	await get_tree().create_timer(0.2).timeout
	if not verify_scene(anim.current_animation=="idle","Idle transition"): return
	var folder := ""
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="): folder = arg.trim_prefix("--capture=")
	for shot: String in ["court","marsh","sluice","dialogue"]:
		match shot:
			"marsh":
				player.position = Vector3(1,0.1,-1)
				player.pivot.rotation.y = -0.85
			"sluice":
				player.position = Vector3(-1,0.1,-8)
				player.pivot.rotation.y = 0
			"dialogue":
				player.position = Vector3(-3.5,0.1,3)
				player.pivot.rotation.y = 0.3
				interact("merchant")
		await get_tree().create_timer(0.9).timeout
		await RenderingServer.frame_post_draw
		if folder != "" and get_viewport().get_texture().get_image().save_png(folder+"-"+shot+".png") != OK:
			get_tree().quit(1)
			return
	act("accept")
	close_panel()
	for step: Array in [["root","observe"],["root","interpret"],["sign","take"],["merchant","return"]]:
		player.position = land.points[step[0]] + Vector3(0,0.1,1.2)
		await get_tree().physics_frame
		await get_tree().create_timer(0.18).timeout
		if not verify_scene(target == step[0],"Proximity "+str(step[0])): return
		interact(target)
		act(step[1])
		close_panel()
	if not verify_scene(session.state.exploration.holder == SedgeWorld.LO and session.state.day == 0,"Timely return without local calendar cost"): return
	player.position = land.points["ferry"] + Vector3(0,0.1,1)
	if not session.checkpoint(player.position):
		failure()
		return
	start_trip(SedgeWorld.route_plan(session.state))
	if not verify_scene(session.state.day==2 and SedgeWorld.active_trip(session.state).status=="paused","Interrupted ferry"): return
	print("P2_SCENE_PASS")
	leave()

func verify_scene(ok: bool, message: String) -> bool:
	if not ok:
		push_error(message)
		get_tree().quit(1)
	return ok
