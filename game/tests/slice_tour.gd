class_name SliceTour
extends RefCounted
## Export acceptance. Keys move the player and rendered button hits commit every choice.
static func tap(code: Key) -> void:
	MaterialSceneProbe.send_key(code,true)
	MaterialSceneProbe.send_key(code,false)

static func click(h,label: String) -> void:
	for child: Node in h.column.get_children():
		if child is Button and child.text.begins_with(label):
			await MaterialSceneProbe.click_choice(h,child.text)
			return
	h.verify_scene(false,"Missing "+label+" on "+h.column.get_child(0).text)

static func walk(h,key: String) -> bool:
	var grid := AStarGrid2D.new()
	grid.region = Rect2i(-48,-48,97,97)
	grid.cell_size = Vector2(0.5,0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.update()
	for child in h.land.find_children("*","CollisionShape3D",true,false):
		var size: Vector3 = child.shape.size
		var pos: Vector3 = child.global_position
		if pos.y+size.y/2 < 0.05 or pos.y-size.y/2 > 1.5: continue
		var rect := Rect2(Vector2(pos.x-size.x/2,pos.z-size.z/2),Vector2(size.x,size.z)).grow(0.46)
		for x in range(ceili(rect.position.x*2),floori(rect.end.x*2)+1):
			for z in range(ceili(rect.position.y*2),floori(rect.end.y*2)+1):
				if grid.is_in_bounds(x,z): grid.set_point_solid(Vector2i(x,z))
	var from := Vector2i(roundi(h.player.position.x*2),roundi(h.player.position.z*2))
	var dest: Vector3 = h.land.points[key]
	var end := Vector2i(roundi(dest.x*2),roundi(dest.z*2))
	grid.set_point_solid(from,false)
	var best := Vector2i.ZERO
	var score := INF
	for x in range(end.x-3,end.x+4):
		for y in range(end.y-3,end.y+4):
			var tile := Vector2i(x,y)
			if grid.is_point_solid(tile) or tile.distance_to(end)>3.5: continue
			var d := tile.distance_to(from)+tile.distance_to(end)*0.1
			if d < score:
				score = d
				best = tile
	var path := grid.get_id_path(from,best)
	var held := [false,false,false,false]
	var keys := [KEY_A,KEY_D,KEY_W,KEY_S]
	for tile: Vector2i in path:
		for tick in 90:
			var dx: float = tile.x*0.5-h.player.position.x
			var dz: float = tile.y*0.5-h.player.position.z
			var needed := [dx < -0.09,dx > 0.09,dz < -0.09,dz > 0.09]
			for i in 4:
				if held[i]!=needed[i]:
					MaterialSceneProbe.send_key(keys[i],needed[i])
					held[i]=needed[i]
			if true not in needed or h.target==key and h.player.position.distance_to(dest)<2.25: break
			await h.get_tree().physics_frame
		if h.target==key and h.player.position.distance_to(dest)<2.25: break
	for i in 4:
		if held[i]: MaterialSceneProbe.send_key(keys[i],false)
	await h.get_tree().process_frame
	return h.verify_scene(h.target==key,"Walk to %s from %s, ended at %s, target %s" % [key,from,h.player.position,h.target])

static func near(h,key: String) -> void:
	print("P5_VISIT ",key)
	if h.panel.visible:
		tap(KEY_ESCAPE)
		await h.get_tree().process_frame
	if not await walk(h,key): return
	tap(KEY_E)
	await h.get_tree().process_frame

static func trip(h) -> void:
	await near(h,"ferry")
	await click(h,"Отправиться")
	if SedgeWorld.active_trip(h.session.state)!=null: await click(h,"Удержать канат")

static func choice(h,label: String, timed: bool=true) -> void:
	await click(h,label)
	await click(h,"Подтвердить")
	if timed: await click(h,"Завершить этап")

static func stage(h) -> void:
	for i in 3:
		await choice(h,"Накопить Ци")
		await choice(h,"Уравновесить поток")
	await choice(h,"Накопить Ци")

static func chamber(h,condense: bool) -> void:
	await trip(h)
	await near(h,"retreat")
	await stage(h)
	await choice(h,"Начать первый великий",false)
	await choice(h,"Ввести первую")
	await choice(h,"Выравнивание" if condense else "Сохранить резерв")
	await choice(h,"Снять нагрузку" if h.session.state.slice.load else "Закрепить Основание")
	await MaterialSceneProbe.capture(h,"second-life" if h.session.state.active_body>0 else "foundation")
	await trip(h)

static func mentor(h,key: String) -> void:
	await near(h,"mentor")
	await click(h,key)

static func craft(h) -> void:
	for i in 2:
		for recipe: String in ["Бережная стабилизация","Автономная выдержка"]:
			await mentor(h,"Обработка и заказы")
			await click(h,recipe)
			await click(h,"Повреждённая часть корня" if recipe=="Бережная стабилизация" else "Стабилизированный полуфабрикат")
			await click(h,"Подтвердить работу")
			if recipe=="Бережная стабилизация": await click(h,"Завершить оставшуюся работу")
			else:
				await click(h,"Имущество и процессы")
				await click(h,"Текущие процессы")
				await click(h,"Практиковаться 30 дней")
				await click(h,"Подтвердить практику")
				await click(h,"Завершить оставшуюся работу")
				await click(h,"Имущество и процессы")
				await click(h,"Текущие процессы")
				await click(h,"Получить: Автономная")

static func start(h) -> void:
	await h.get_tree().create_timer(0.3).timeout
	var s: SliceSession = h.integrated
	if s.state.mode=="body_dead":
		if s.state.running()==null:
			await choice(h,"Начать перенос души",false)
			await click(h,"Продвинуть один день")
			if h.verify_scene(s.state.running().progress==1,"Transfer checkpoint"):
				print("P5_TRANSFER_SAVED")
				await click(h,"Сохранить и выйти")
			return
		await click(h,"Завершить этап")
		await near(h,"steps")
		await choice(h,"Сверить кладку",false)
		await mentor(h,"Тайник и наследие")
		await choice(h,"Осмотреть и забрать",false)
		await mentor(h,"Тайник и наследие")
		await choice(h,"Развить чувствительность")
		await near(h,"quartz")
		await click(h,"Выделить наружный фрагмент")
		await click(h,"Подтвердить способ")
		await mentor(h,"Сравнить способы")
		await click(h,"Подготовить плавный способ")
		await chamber(h,false)
		if h.verify_scene(s.state.body().limit_years==200 and s.state.soul.limit_years==200 and s.state.soul.first_milestones.foundation<s.state.body().born+WorldCalendar.ordinal(18),"second Foundation"):
			print("P5_REBIRTH_PASS carrier=",s.state.slice.carrier," wallet=",s.state.materials.wallet)
			h.leave()
		return
	var quick := "--condense" in OS.get_cmdline_user_args()
	await near(h,"shop")
	await click(h,"Разговор о медном знаке")
	await click(h,"Я поищу знак")
	if quick:
		await near(h,"sign")
		await click(h,"Поднять знак")
		await near(h,"shop")
		await click(h,"Разговор о медном знаке")
		await click(h,"Передать знак")
	for kind: String in ["Набор","Герметичный","Учебный","Талисман","Лекарство"]:
		await near(h,"shop")
		await click(h,"Купить: "+kind)
	for label: String in ["Травничество","Алхимия и оба способа"]:
		await mentor(h,label)
		await click(h,"Начать обучение")
		await click(h,"Завершить оставшуюся работу")
	if quick:
		await near(h,"shop")
		await click(h,"Разговор о медном знаке")
		await click(h,"Принять его просьбу")
	await near(h,"root")
	await click(h,"Осмотреть физический след")
	await near(h,"root")
	await click(h,"Духовное обследование")
	await near(h,"root")
	await click(h,"Попытаться извлечь" if quick else "Бережно отделить части")
	await click(h,"Подтвердить способ")
	for i in 2:
		await near(h,"quartz")
		await click(h,"Осмотреть / распознать")
	for i in (2 if quick else 1):
		await near(h,"quartz")
		await click(h,"Выделить наружный фрагмент")
		await click(h,"Подтвердить способ")
	if not quick: await craft(h)
	await mentor(h,"Сравнить способы")
	await click(h,"Подготовить конденсацию" if quick else "Плавный способ +")
	await chamber(h,quick)
	if not h.verify_scene(s.state.body().milestone=="foundation" and s.state.active_body==0,"first Foundation"): return
	await near(h,"shop")
	await click(h,"Разговор о медном знаке")
	if not quick:
		await near(h,"sign")
		await click(h,"Поднять знак")
		await near(h,"gate")
		await click(h,"Осмотреть оборот")
	await near(h,"gate")
	await click(h,"Вставить знак")
	if not h.verify_scene(s.state.exploration.holder=="socket" and not s.state.person(SedgeWorld.LO).alive,"gate and succession"): return
	print("P5_FIRST_FOUNDATION method=","condense" if quick else "smooth"," day=",s.state.day," wallet=",s.state.materials.wallet)
	if quick:
		h.leave()
		return
	await mentor(h,"Тайник и наследие")
	await choice(h,"Спрятать 24",false)
	await click(h,"Спуститься к камнеедам")
	await click(h,"Войти в ущелье")

static func combat(h) -> void:
	await h.get_tree().process_frame
	if h.session.state.mode=="body_dead":
		await combat_click(h,"Продолжить путь души")
		return
	if h.modal != "restore": h.get_tree().quit(1); return
	if "--finish-combat" not in OS.get_cmdline_user_args():
		await combat_click(h,"Продолжить   /")
		tap(KEY_R)
		tap(KEY_T)
		for i in 250:
			await h.get_tree().physics_frame
			if h.session.state.combat.actors.hero.shield>0: break
		if not h.session.state.combat.perception or h.session.state.combat.wards!=0 or h.session.state.combat.actors.hero.shield<=0:
			push_error("Purchased ward and perception did not resolve in campaign")
			h.get_tree().quit(1)
			return
		MaterialSceneProbe.send_key(KEY_W,true)
		for i in 500:
			await h.get_tree().physics_frame
			if h.session.state.combat.actors[P4Content.YOUNG].action.wind>0: break
		MaterialSceneProbe.send_key(KEY_W,false)
		if h.session.state.combat.actors[P4Content.YOUNG].action.wind<=0: push_error("No windup in ravine"); h.get_tree().quit(1); return
		tap(KEY_ESCAPE)
		await h.get_tree().physics_frame
		print("P5_WINDUP_SAVED")
		h.leave()
		return
	if h.session.state.combat.actors[P4Content.YOUNG].action.wind<=0 or not h.get_tree().paused: push_error("Lost dynamic checkpoint"); h.get_tree().quit(1); return
	await combat_click(h,"Продолжить   /")
	for i in 3600:
		await h.get_tree().physics_frame
		if h.modal=="death": break
	if h.modal!="death": push_error("Expected lethal encounter"); h.get_tree().quit(1); return
	print("P5_DEATH_SAVED")
	h.leave()

static func combat_click(h,label: String) -> void:
	await h.get_tree().process_frame
	for child: Node in h.pause_box.get_children():
		if child is Button and child.text.begins_with(label):
			var point: Vector2 = child.get_global_rect().get_center()
			for down: bool in [true,false]:
				var event := InputEventMouseButton.new()
				event.position = point
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = down
				h.get_viewport().push_input(event,true)
			await h.get_tree().process_frame
			return
	push_error("Missing combat button "+label)
	h.get_tree().quit(1)
