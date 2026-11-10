class_name MaterialSceneProbe
extends RefCounted
## Drives the normal scene's menu callbacks; separate processes share the slot.

static func near(h, key: String) -> bool:
	h.close_panel()
	h.player.position = h.land.points[key]+Vector3(0,0.1,1.3)
	await h.get_tree().physics_frame
	await h.get_tree().create_timer(0.15).timeout
	if not h.verify_scene(h.target==key,"P3 proximity "+key): return false
	h.interact(key)
	return true

static func capture(h, label: String) -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--capture="):
			await h.get_tree().create_timer(0.3).timeout
			await RenderingServer.frame_post_draw
			var destination := argument.trim_prefix("--capture=")+"-"+label+".png"
			h.verify_scene(h.get_viewport().get_texture().get_image().save_png(destination)==OK,"Capture "+label)

static func select_input(h, recipe: String, kind: String) -> void:
	h.material_ui.recipe_inputs(recipe)
	var id: String = MaterialWorld.available(h.session.state,kind)[0]
	h.press_choice(h.material_ui.item_name(MaterialWorld.item(h.session.state,id)))
	h.press_choice("Подтвердить работу")

static func collect(h, id: String) -> void:
	h.material_ui.processes()
	var row := MaterialWorld.job(h.session.state,id)
	h.press_choice("Получить: "+str(MaterialPanel.RECIPES[row.recipe])+" №"+id.get_slice(".",2))

static func run(h) -> void:
	await h.get_tree().create_timer(0.35).timeout
	var s: SedgeSession = h.session
	var intact := "--intact-route" in OS.get_cmdline_user_args()
	var property_check := "--property-route" in OS.get_cmdline_user_args()
	if "--resume-check" not in OS.get_cmdline_user_args():
		var before_preview:=s.state.fingerprint()
		var scroll:=h.panel.get_child(0) as ScrollContainer
		h.material_ui.guide()
		await h.get_tree().process_frame
		scroll.scroll_vertical=200
		await h.get_tree().process_frame
		h.material_ui.methods()
		await h.get_tree().process_frame
		await h.get_tree().process_frame
		if not h.verify_scene(scroll.scroll_vertical==0 and s.state.fingerprint()==before_preview,"New panels reset scroll; previews spend nothing"): return
	if "--resume-check" in OS.get_cmdline_user_args():
		if not h.verify_scene(s.state.running()!=null and s.state.running().progress==10,"Restored partial practice"): return
		var order_id: String = s.state.materials.jobs.back().id
		var start_day := s.state.day-10
		h.press_choice("Завершить оставшуюся работу")
		if not h.verify_scene(s.state.day==start_day+30 and MaterialWorld.job(s.state,order_id).status=="ready","Common calendar completion"): return
		if not await near(h,"mentor"): return
		collect(h,order_id)
		select_input(h,"mature","essence")
		var maturity_id: String = s.state.materials.jobs.back().id
		h.material_ui.processes()
		h.press_choice("Практиковаться 30 дней параллельно")
		h.press_choice("Подтвердить практику")
		h.press_choice("Завершить оставшуюся работу")
		collect(h,maturity_id)
		h.material_ui.methods()
		await capture(h,"methods")
		h.press_choice("Подготовить плавный способ")
		if not h.verify_scene(s.state.materials.method=="smooth" and s.state.materials.pledged==8 and s.state.body().milestone=="initial","Saved preparation without a breakthrough"): return
		h.material_ui.inventory()
		await capture(h,"prepared")
		if not h.verify_scene(s.reload() and s.state.materials.method=="smooth","Reload selected method"): return
		print("P3_RESUME_PASS day=",s.state.day," wallet=",s.state.materials.wallet)
		h.leave()
		return
	# Verify real locomotion still runs before interacting.
	h.close_panel()
	var start_position: Vector3 = h.player.position
	Input.action_press("move_up")
	await h.get_tree().create_timer(0.4).timeout
	Input.action_release("move_up")
	if not h.verify_scene(h.player.position.distance_to(start_position)>0.3,"P3 walking input"): return
	for offer: String in ["lo.kit","lo.vessel","lo.treatise"]:
		if not await near(h,"shop"): return
		var def: Dictionary = P3Content.data().offers[offer]
		h.press_choice("Купить: %s · %d" % [MaterialPanel.LABELS[def.kind],def.price])
	for key: String in ["herbalism","alchemy"]:
		if not await near(h,"mentor"): return
		h.press_choice("Травничество · 8 камней / 4 года" if key=="herbalism" else "Алхимия и оба способа · трактат / 6 лет")
		h.press_choice("Начать обучение")
		h.press_choice("Завершить оставшуюся работу")
	if not h.verify_scene(s.state.day==WorldCalendar.ordinal(10),"P3 exact education dates"): return
	if not await near(h,"root"): return
	h.press_choice("Осмотреть физический след")
	h.interact("root")
	h.press_choice("Духовное обследование и распознавание")
	h.interact("root")
	await capture(h,"extraction")
	h.press_choice("Попытаться извлечь целиком · риск повреждения" if intact else "Бережно отделить части · без живого контура")
	h.press_choice("Подтвердить способ")
	if not h.verify_scene(s.state.materials.root==("intact" if intact else "parts") and not h.land.root_visual.visible,"Extracted root changes actual scene"): return
	if not await near(h,"quartz"): return
	h.press_choice("Осмотреть / распознать породу")
	h.interact("quartz")
	h.press_choice("Осмотреть / распознать породу")
	for i in (6 if property_check else 2):
		h.interact("quartz")
		h.press_choice("Выделить наружный фрагмент")
		h.press_choice("Подтвердить способ")
	if not h.verify_scene(s.state.materials.quartz_left==(0 if property_check else 4) and not h.land.quartz_visuals[4].visible,"Partial quartz changes actual scene"): return
	if not await near(h,"mentor"): return
	if "--mortality-route" in OS.get_cmdline_user_args():
		select_input(h,"order","root_part")
		var order_id: String=s.state.materials.jobs.back().id
		h.material_ui.practice(WorldCalendar.ordinal(60)-s.state.day)
		h.press_choice("Подтвердить практику")
		h.press_choice("Завершить оставшуюся работу")
		if not h.verify_scene(not h.land.tutor_alive and not h.land.merchant_alive,"Visible NPC succession follows calendar immediately"): return
		if not await near(h,"mentor"): return
		if not h.verify_scene(h.column.get_child(0).text=="Мастерская · новый исполнитель","Dead teacher is replaced by institutional service"): return
		collect(h,order_id)
		if not h.verify_scene(not MaterialWorld.available(s.state,"essence").is_empty(),"Institutional result remains collectible after succession"): return
		print("P3_MORTALITY_PASS")
		h.leave()
		return
	if property_check:
		h.refresh()
		if not h.verify_scene(h.player.load_factor==0.55,"Overload applies movement penalty"): return
		h.close_panel()
		h.player.position=Vector3(0,0.1,8)
		var before: Vector3=h.player.position
		Input.action_press("move_right")
		await h.get_tree().create_timer(0.5).timeout
		Input.action_release("move_right")
		var burdened_distance: float=h.player.position.distance_to(before)
		if not await near(h,"mentor"): return
		h.press_choice("Оставить сосуд с содержимым на хранении")
		h.refresh()
		if not h.verify_scene(h.player.load_factor==1.0 and h.land.stored_vessel.visible,"Stored vessel and contents stay in world"): return
		h.close_panel()
		h.player.position=Vector3(0,0.1,8)
		before=h.player.position
		Input.action_press("move_right")
		await h.get_tree().create_timer(0.5).timeout
		Input.action_release("move_right")
		if not h.verify_scene(h.player.position.distance_to(before)>burdened_distance*1.4,"Load changes actual traversal speed"): return
		if not await near(h,"mentor"): return
		h.press_choice("Забрать сосуд с хранения")
		if not h.verify_scene(not h.land.stored_vessel.visible and MaterialWorld.weight(s.state)==7900,"Retrieve same contents once"): return
		print("P3_PROPERTY_PASS")
		h.leave()
		return
	if intact:
		h.material_ui.methods()
		h.press_choice("Подготовить конденсацию")
		if not h.verify_scene(s.state.materials.method=="condense" and s.state.materials.pledged==12,"Condensation plan selected in scene"): return
		h.material_ui.inventory()
		await capture(h,"condensation")
		if not h.verify_scene(s.reload() and s.state.materials.method=="condense","Condensation plan reloaded"): return
		print("P3_CONDENSE_PASS day=",s.state.day)
		h.leave()
		return
	h.press_choice("Обработка и заказы")
	h.press_choice("Заказать стабилизацию")
	var part: String = MaterialWorld.available(s.state,"root_part")[0]
	h.press_choice(h.material_ui.item_name(MaterialWorld.item(s.state,part)))
	await capture(h,"contract")
	h.press_choice("Подтвердить работу")
	h.material_ui.processes()
	h.press_choice("Практиковаться 30 дней параллельно")
	h.press_choice("Подтвердить практику")
	for i in 10: h.press_choice("Продвинуть 1 день")
	if not h.verify_scene(s.state.running().progress==10 and s.state.materials.wallet==47,"Persisted active practice and paid order"): return
	await capture(h,"unfinished")
	print("P3_SCENE_PASS day=",s.state.day," partial_practice=10")
	h.leave()
