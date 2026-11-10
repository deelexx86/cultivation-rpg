class_name MaterialWorld
extends RefCounted
## VS-03 rules. Candidates are committed only by the existing session boundary.
const ROOT := "vs.glass_root.001"
const QUARTZ := "vs.dull_quartz.001"
const MENTOR := "shen-yu"
const PLAN := "preparation"

static func schema() -> Dictionary:
	return {"profile":"str", "wallet":"int", "paid":"int", "earned":"int", "serial":"int", "root":"str", "quartz_left":"int", "stock":{"*":"int"}, "notes":{"*":"int"}, "items":[item_schema()], "jobs":[job_schema()], "method":"str", "pledged":"int"}

static func item_schema() -> Dictionary:
	return {"id":"str", "kind":"str", "origin":"str", "age":"int", "integrity":"str", "purity":"str", "energy":"str", "owner":"str", "holder":"str", "container":"str", "reserved":"str", "parents":["str"], "created":"int"}

static func job_schema() -> Dictionary:
	return {"id":"str", "recipe":"str", "inputs":["str"], "outputs":["str"], "equipment":["str"], "start":"int", "due":"int", "status":"str", "customer":"str", "executor":"str", "known":"bool"}

static func fresh(id: String) -> CampaignState:
	var s := SedgeWorld.fresh(id)
	s.seed_value = "p3-fixed-1"
	var stock := {}
	for key: String in P3Content.data().offers: stock[key] = P3Content.data().offers[key].count
	s.materials = {"profile":P3Content.data().profile, "wallet":80, "paid":0, "earned":0, "serial":0, "root":"standing", "quartz_left":6, "stock":stock, "notes":{}, "items":[], "jobs":[], "method":"", "pledged":0}
	var npc := CampaignState.Person.new()
	npc.id = MENTOR
	s.people.append(npc)
	s.events.append(P1Fixture.event("shen-yu.death",WorldCalendar.ordinal(60),"death",MENTOR))
	return s

static func item(s: CampaignState, id: String) -> Dictionary:
	for row: Dictionary in s.materials.items:
		if row.id == id: return row
	return {}

static func job(s: CampaignState, id: String) -> Dictionary:
	for row: Dictionary in s.materials.jobs:
		if row.id == id: return row
	return {}

static func available(s: CampaignState, kind: String) -> Array[String]:
	var result: Array[String] = []
	for row: Dictionary in s.materials.items:
		if row.kind == kind and row.owner == s.body().id and row.holder == s.body().id and row.reserved == "": result.append(row.id)
	return result

static func equipment(s: CampaignState, kind: String) -> String:
	var ids := available(s,kind)
	return "" if ids.is_empty() else ids[0]

static func serial(s: CampaignState, prefix: String) -> String:
	s.materials.serial += 1
	return "p3.%s.%d" % [prefix,s.materials.serial]

static func add_item(s: CampaignState, kind: String, origin: String, parents: Array[String] = [], holder: String = "", container: String = "") -> String:
	var id := serial(s,"item")
	var row := {"id":id, "kind":kind, "origin":origin, "age":600 if origin == ROOT else 0, "integrity":"whole" if kind == "root" else "part", "purity":"tainted" if kind in ["tainted_quartz","unstable_essence"] else "clean", "energy":"unstable" if kind == "unstable_essence" else "retained", "owner":s.body().id, "holder":s.body().id if holder == "" else holder, "container":container, "reserved":"", "parents":parents.duplicate(), "created":s.day}
	if not parents.is_empty():
		row.age = item(s,parents[0]).age
		if item(s,parents[0]).energy == "reduced": row.energy = "reduced"
	s.materials.items.append(row)
	return id

static func spend(s: CampaignState, amount: int) -> bool:
	if amount < 0 or s.materials.wallet - s.materials.pledged < amount: return false
	s.materials.wallet -= amount
	s.materials.paid += amount
	return true

static func room(s: CampaignState, count: int) -> bool:
	var vessel := equipment(s,"vessel")
	if vessel == "": return false
	var used := 0
	for row: Dictionary in s.materials.items:
		if row.container == vessel and row.holder != "consumed": used += 1
	return used + count <= int(P3Content.data().vessel_capacity)

static func weight(s: CampaignState) -> int:
	var total := 0
	for row: Dictionary in s.materials.items:
		if row.holder == s.body().id or (row.holder.begins_with("p3.job.") and job(s,row.holder).get("executor","") == "self"):
			total += int(P3Content.data().weights[row.kind])
	return total

static func buy(s: CampaignState, offer: String) -> String:
	var offers: Dictionary = P3Content.data().offers
	if not offers.has(offer): return "Нет такого предложения."
	if (offer.begins_with("lo.") and not s.person(SedgeWorld.LO).alive) or (offer.begins_with("yin.") and (s.person(SedgeWorld.LO).alive or s.day < WorldCalendar.ordinal(24))): return "Продавец или поставка недоступны."
	if s.materials.stock[offer] <= 0: return "Конечное предложение исчерпано."
	var def: Dictionary = offers[offer]
	if def.kind in ["stabilizer","pill"] and not room(s,1): return "Нужен свободный сосуд: 8 мест."
	if not spend(s,def.price): return "Недостаточно свободных камней духа."
	s.materials.stock[offer] -= 1
	add_item(s,def.kind,"shop."+offer,[],"",equipment(s,"vessel") if def.kind in ["stabilizer","pill"] else "")
	return ""

static func extract(s: CampaignState, command: String) -> String:
	if equipment(s,"kit") == "" or not room(s,2 if command.begins_with("root.") else 1): return "Нужны набор сбора и свободный подходящий сосуд."
	if command.begins_with("root."):
		if s.materials.root != "standing": return "Источник уже извлечён; нового роста нет."
		if not SedgeWorld.qualified(s) or not s.materials.notes.has("root.recognized."+str(s.exploration.source)): return "Нужны травничество и новое духовное обследование."
		if command not in ["root.careful","root.whole"]: return "Способ извлечения недоступен."
		var whole := false
		if command == "root.whole":
			var outcome := (s.seed_value+":sha256-keyed-v1:"+ROOT).sha256_text().left(8).hex_to_int() % 2
			if s.seed_value == "vs-root-whole": outcome = 1
			if s.seed_value == "vs-root-damaged": outcome = 0
			s.outcomes[ROOT] = outcome
			whole = outcome == 1
		s.materials.root = "intact" if whole else "parts"
		if whole:
			add_item(s,"root",ROOT,[],"",equipment(s,"vessel"))
		else:
			for i in 2:
				var id := add_item(s,"root_part",ROOT,[],"",equipment(s,"vessel"))
				item(s,id).integrity = "damaged"
	else:
		if s.soul.mastery.get("alchemy.materials",0) == 0 or not s.materials.notes.has("quartz.recognized"): return "Алхимия и распознавание породы обязательны."
		if command == "quartz.core": return "Внутренний монолит: нет операции и подходящего инструмента."
		if command not in ["quartz.surface","quartz.rough"]: return "Способ извлечения недоступен."
		if s.materials.quartz_left <= 0: return "Наружная часть исчерпана. Монолит недоступен."
		s.materials.quartz_left -= 1
		var id := add_item(s,"quartz" if command == "quartz.surface" else "tainted_quartz",QUARTZ,[],"",equipment(s,"vessel"))
		if command == "quartz.rough": item(s,id).energy = "reduced"
	return ""

static func inspect(s: CampaignState, target: String) -> String:
	if target == "root":
		if not s.exploration.notes.has("observe."+str(s.exploration.source)): return "Сначала осмотрите физические признаки берега."
		if not SedgeWorld.qualified(s): return "Сведения о месте не заменяют травничество."
	else:
		if not s.materials.notes.has("quartz.observed"):
			s.materials.notes["quartz.observed"] = s.day
			return ""
		if s.soul.mastery.get("alchemy.materials",0) == 0: return "Видна аномалия; без алхимии структура неизвестна."
	s.materials.notes[target+".recognized"+("."+str(s.exploration.source) if target=="root" else "")] = s.day
	return ""

static func occupied(s: CampaignState) -> bool:
	if s.running() != null: return true
	for row: CampaignState.Action in s.actions:
		if row.status == "paused": return true
	return false

static func start(s: CampaignState, recipe: String, input_id: String) -> String:
	var learn := recipe.begins_with("learn.")
	var def: Dictionary
	var inputs: Array[String] = []
	var equipment_ids: Array[String] = []
	var days := 0
	if learn:
		var key := recipe.trim_prefix("learn.")
		if not P3Content.data().training.has(key): return "Нет такого обучения."
		def = P3Content.data().training[key]
		if not s.person(MENTOR).alive or s.soul.mastery.get(def.mastery,0) > 0: return "Наставник недоступен либо знание уже освоено."
		if key == "alchemy" and equipment(s,"treatise") == "": return "Нужен учебный трактат; покупка сама не обучает."
		days = WorldCalendar.add_years(s.day,def.years)-s.day
		if not spend(s,def.price): return "Недостаточно камней для обучения."
	else:
		if not P3Content.data().recipes.has(recipe): return "Нет такой операции."
		def = P3Content.data().recipes[recipe]
		var raw := item(s,input_id)
		if raw.is_empty() or raw.kind != def.input or raw.holder != s.body().id or raw.owner != s.body().id or raw.reserved != "": return "Нужно подходящее свободное сырьё."
		if recipe != "order" and s.soul.mastery.get("alchemy.materials",0) == 0: return "Сначала освоите алхимию по трактату."
		if not room(s,int(def.quantity)-1): return "Сосуд занят или заполнен."
		if recipe != "order" and equipment(s,"kit") == "": return "Нужен свободный набор."
		if not spend(s,def.fee): return "Недостаточно свободных камней для работы."
		days = def.days
		inputs.append(input_id)
		if recipe != "order": equipment_ids.assign([equipment(s,"vessel"),equipment(s,"kit")])
	var id := serial(s,"job")
	var mode: String = "active" if learn else def.mode
	if mode == "active":
		var plan := Simulation.preview(s,days,0,"",100,100,"study" if learn else "craft")
		var response := Simulation.confirm(s,plan,id)
		if response != "": return response
	var row := {"id":id, "recipe":recipe, "inputs":inputs, "outputs":[], "equipment":equipment_ids, "start":s.day, "due":s.day+days, "status":"running", "customer":s.body().id, "executor":"workshop" if mode == "workshop" else "self", "known":false}
	s.materials.jobs.append(row)
	for raw_id: String in inputs:
		var raw := item(s,raw_id)
		raw.reserved = id
		raw.holder = id
		if mode == "workshop": raw.container = ""
	for equip_id: String in equipment_ids: item(s,equip_id).reserved = id
	return ""

static func release_equipment(s: CampaignState, row: Dictionary) -> void:
	for id: String in row.equipment: item(s,id).reserved = ""

static func finish(s: CampaignState, id: String) -> void:
	var row := job(s,id)
	if row.is_empty() or row.status != "running": return
	if row.recipe.begins_with("learn."):
		var key: String = row.recipe.trim_prefix("learn.")
		s.soul.mastery[P3Content.data().training[key].mastery] = 1
		if key == "alchemy":
			for skill: String in ["operation.stabilization","foundation.smooth.vs","foundation.condense.vs"]: s.soul.mastery[skill] = 1
		row.status = "claimed"
		row.known = true
		return
	var def: Dictionary = P3Content.data().recipes[row.recipe]
	for input_id: String in row.inputs:
		var raw := item(s,input_id)
		raw.holder = "consumed"
		raw.container = ""
		raw.reserved = ""
	for i in int(def.quantity):
		var parent_ids: Array[String] = []
		parent_ids.assign(row.inputs)
		var output := add_item(s,def.output,item(s,row.inputs[0]).origin,parent_ids,id)
		row.outputs.append(output)
	row.status = "ready"
	if def.mode == "active":
		release_equipment(s,row)
		for output_id: String in row.outputs:
			var output := item(s,output_id)
			output.holder = s.body().id
			output.container = equipment(s,"vessel")
		row.status = "claimed"
		row.known = true
		if row.recipe == "stabilize": s.soul.mastery["operation.stabilization"] = 2
	s.record("material.ready:"+id)

static func settle(s: CampaignState) -> void:
	if s.materials.is_empty(): return
	for raw: Dictionary in s.materials.items:
		if raw.kind == "unstable_essence" and raw.holder == s.body().id and raw.reserved == "" and s.day >= int(raw.created)+365:
			raw.kind = "spent_essence"
			raw.energy = "reduced"
			s.record("material.decayed:"+raw.id)
	for row: Dictionary in s.materials.jobs:
		if row.status != "running": continue
		if row.recipe.begins_with("learn."):
			if not s.person(MENTOR).alive:
				var action := s.action(row.id)
				if action != null and action.status in ["running","paused"]: action.status = "stopped"
				row.status = "stopped"
				continue
		elif P3Content.data().recipes[row.recipe].mode != "active" and s.day >= int(row.due):
			finish(s,row.id)
		var action := s.action(row.id)
		if action != null and action.status == "stopped":
			row.status = "stopped"
			# Preserve owned inputs at the bench; no duplicated result or free restart.
			# Death handling/rights for a future body belong to P5.

static func next_boundary(s: CampaignState, boundary: int) -> int:
	if s.materials.is_empty(): return boundary
	for raw: Dictionary in s.materials.items:
		if raw.kind == "unstable_essence" and raw.holder == s.body().id and raw.reserved == "": boundary = mini(boundary,int(raw.created)+365)
	for row: Dictionary in s.materials.jobs:
		if row.status == "running" and not row.recipe.begins_with("learn.") and P3Content.data().recipes[row.recipe].mode != "active": boundary = mini(boundary,int(row.due))
	return boundary

static func claim(s: CampaignState, id: String) -> String:
	var row := job(s,id)
	if row.is_empty() or row.customer != s.body().id or row.status != "ready": return "Нет доступного результата этого заказа."
	# A personal maturation still occupies its own vessel until collection.
	release_equipment(s,row)
	if not room(s,row.outputs.size()): return "Освободите подходящий сосуд для результата."
	for output_id: String in row.outputs:
		var output := item(s,output_id)
		output.holder = s.body().id
		output.container = equipment(s,"vessel")
	row.status = "claimed"
	row.known = true
	return ""

static func cancel(s: CampaignState, id: String) -> String:
	var row := job(s,id)
	if row.is_empty() or row.customer != s.body().id or row.status != "running" or row.recipe.begins_with("learn.") or P3Content.data().recipes[row.recipe].mode == "active": return "Активную работу можно сохранить; безопасной отмены нет."
	release_equipment(s,row)
	if not room(s,row.inputs.size() if row.executor == "workshop" else 0): return "Нужен свободный сосуд для возвращаемого сырья."
	for input_id: String in row.inputs:
		var raw := item(s,input_id)
		raw.reserved = ""
		raw.holder = s.body().id
		raw.container = equipment(s,"vessel")
		if s.day > int(row.start):
			raw.kind = "unstable_essence"
			raw.purity = "tainted"
			raw.energy = "unstable"
			raw.created = s.day
	row.status = "cancelled"
	row.known = true
	return ""

static func choose(s: CampaignState, method: String) -> String:
	if method not in ["smooth","smooth-reserve","condense",""]: return "Неизвестный способ."
	for raw: Dictionary in s.materials.items:
		if raw.reserved == PLAN: raw.reserved = ""
	s.materials.method = ""
	s.materials.pledged = 0
	if method == "": return ""
	var smooth := method.begins_with("smooth")
	if s.soul.mastery.get("foundation.smooth.vs" if smooth else "foundation.condense.vs",0) == 0: return "Изучите оба способа по трактату."
	var selected: Array[String] = []
	var roots := available(s,"stabilizer" if smooth else "root")
	if not smooth and roots.is_empty(): roots = available(s,"pill")
	var required := 2 if method == "smooth-reserve" else 1
	if roots.size() < required: return "Нужны стабилизатор (и выбранный резерв) либо целый живой корень / пилюля. Повреждённые части не заменяют живой контур."
	for i in required: selected.append(roots[i])
	var quartz := available(s,"quartz")
	if not smooth:
		quartz = quartz.filter(func(id: String) -> bool: return item(s,id).energy == "retained")
	var count := 1 if smooth else 2
	if quartz.size() < count: return "Нужны %d чистых фрагмента кварца; конденсация требует сохранённую энергию." % count
	for i in count: selected.append(quartz[i])
	var stones := 8 if smooth else 12 # Includes the future chamber fee; no attempt charged here.
	if s.materials.wallet < stones: return "Недостаточно камней на материалы и будущую камеру."
	for id: String in selected: item(s,id).reserved = PLAN
	s.materials.method = method
	s.materials.pledged = stones
	return ""

static func apply(s: CampaignState, command: String, argument: String = "") -> String:
	if s.materials.is_empty() or s.mode != "active" or occupied(s) or s.exploration.place != SedgeWorld.YARD: return "Завершите текущую работу или вернитесь во двор."
	var result := ""
	match command:
		"buy": result = buy(s,argument)
		"inspect": result = inspect(s,argument)
		"extract": result = extract(s,argument)
		"learn": result = start(s,"learn."+argument,"")
		"claim": result = claim(s,argument)
		"cancel": result = cancel(s,argument)
		"choose": result = choose(s,argument)
		"sell":
			var raw := item(s,argument)
			if raw.is_empty() or not P3Content.data().sell.has(raw.kind) or raw.holder != s.body().id or raw.reserved != "": return "Материал недоступен для продажи."
			var amount: int = P3Content.data().sell[raw.kind]
			s.materials.wallet += amount
			s.materials.earned += amount
			raw.holder = "merchant"
			raw.owner = "merchant"
			raw.container = ""
		"visit":
			for row: Dictionary in s.materials.jobs:
				if row.executor == "workshop" and row.status == "ready": row.known = true
		"stash","retrieve":
			var vessel := ""
			for raw: Dictionary in s.materials.items:
				if raw.kind == "vessel" and raw.owner == s.body().id and raw.holder == (s.body().id if command == "stash" else "court.cache"): vessel = raw.id
			if vessel == "": return "Сосуд недоступен."
			for raw: Dictionary in s.materials.items:
				if (raw.id == vessel or raw.container == vessel) and raw.reserved != "": return "Сосуд или содержимое заняты. Сначала освободите работу или подготовку."
			for raw: Dictionary in s.materials.items:
				if raw.id == vessel or raw.container == vessel: raw.holder = "court.cache" if command == "stash" else s.body().id
		_:
			if command.begins_with("recipe."): result = start(s,command.trim_prefix("recipe."),argument)
			else: return "Неизвестная материальная операция."
	if result == "":
		s.record("material:"+command+":"+argument)
		s.revision += 1
	return result

static func problems(s: CampaignState) -> PackedStringArray:
	var errors := PackedStringArray()
	var m := s.materials
	if s.exploration.is_empty() or not StateCodec.shape(m,schema()): return PackedStringArray(["Invalid material shape"])
	if m.profile != P3Content.data().profile or m.wallet < 0 or m.paid < 0 or m.earned < 0 or m.wallet != 80 + m.earned - m.paid or m.pledged < 0 or m.pledged > m.wallet or m.serial < 0 or m.root not in ["standing","intact","parts"] or m.quartz_left < 0 or m.quartz_left > 6: errors.append("Invalid material economy/source")
	if s.person(MENTOR) == null: errors.append("Missing material teacher")
	if m.stock.size() != P3Content.data().offers.size(): errors.append("Invalid offer keys")
	for key: String in m.stock:
		if not P3Content.data().offers.has(key) or m.stock[key] < 0 or m.stock[key] > P3Content.data().offers[key].count: errors.append("Invalid finite stock")
	var ids := {}
	var root_units := 0
	var quartz_units := 0
	var purchases := {}
	var sales := 0
	for raw: Dictionary in m.items:
		if ids.has(raw.id) or raw.id == "" or not P3Content.data().weights.has(raw.kind): errors.append("Invalid/duplicate material item")
		ids[raw.id] = true
		if raw.parents.is_empty():
			if raw.origin == ROOT: root_units += 1
			elif raw.origin == QUARTZ: quartz_units += 1
			elif raw.origin.begins_with("shop."):
				var key: String = raw.origin.trim_prefix("shop.")
				purchases[key] = purchases.get(key,0)+1
		if raw.holder == "merchant":
			if not P3Content.data().sell.has(raw.kind): errors.append("Unsaleable merchant item")
			else: sales += int(P3Content.data().sell[raw.kind])
		if raw.created < 0 or raw.created > s.day or raw.age < 0 or (raw.origin == ROOT and raw.age != 600) or raw.purity not in ["clean","tainted"] or raw.energy not in ["retained","reduced","unstable"] or raw.integrity not in ["whole","part","damaged"]: errors.append("Invalid material provenance/quality")
		if raw.owner != ("merchant" if raw.holder == "merchant" else s.body().id): errors.append("Invalid material ownership")
		if raw.origin not in [ROOT,QUARTZ] and not P3Content.data().offers.has(raw.origin.trim_prefix("shop.")): errors.append("Unknown material origin")
		if raw.container != "" and (item(s,raw.container).get("kind","") != "vessel" or raw.holder in ["consumed","merchant"]): errors.append("Invalid container linkage")
		if raw.container != "":
			var vessel := item(s,raw.container)
			if not vessel.is_empty() and raw.holder != vessel.holder and not (raw.holder.begins_with("p3.job.") and vessel.holder == s.body().id and job(s,raw.holder).get("executor","") == "self"): errors.append("Container and content have conflicting locations")
		for parent: String in raw.parents:
			if parent == raw.id or item(s,parent).is_empty() or item(s,parent).holder != "consumed" or item(s,parent).origin != raw.origin: errors.append("Broken material lineage")
		if raw.reserved == PLAN:
			if m.method == "" or raw.holder != s.body().id: errors.append("Invalid preparation reservation")
		elif raw.reserved != "":
			var work := job(s,raw.reserved)
			if work.is_empty() or work.status not in ["running","ready","stopped"] or (raw.id not in work.inputs and raw.id not in work.equipment): errors.append("Orphaned material reservation")
		if raw.holder.begins_with("p3.job."):
			var work := job(s,raw.holder)
			if work.is_empty() or (raw.id not in work.inputs and raw.id not in work.outputs): errors.append("Orphaned workshop item")
		elif raw.holder not in [s.body().id,"consumed","merchant","court.cache"]: errors.append("Unknown material holder")
	var jobs := {}
	var expenses := 0
	for key: String in P3Content.data().offers:
		var offer: Dictionary = P3Content.data().offers[key]
		if m.stock.has(key):
			var bought: int = offer.count-m.stock[key]
			expenses += bought*int(offer.price)
			if purchases.get(key,0) != bought: errors.append("Purchase/stock conservation failure")
	if sales != m.earned: errors.append("Sale ledger mismatch")
	if root_units != (0 if m.root == "standing" else 1 if m.root == "intact" else 2) or quartz_units != 6-int(m.quartz_left): errors.append("Source/material conservation failure")
	for row: Dictionary in m.jobs:
		if jobs.has(row.id) or row.id == "" or row.status not in ["running","ready","claimed","cancelled","stopped"] or row.start < 0 or row.start > s.day or row.due <= row.start or row.executor not in ["self","workshop"] or row.customer != s.body().id: errors.append("Invalid material process")
		jobs[row.id] = true
		if row.recipe.begins_with("learn."):
			if not P3Content.data().training.has(row.recipe.trim_prefix("learn.")): errors.append("Unknown training")
			else: expenses += int(P3Content.data().training[row.recipe.trim_prefix("learn.")].price)
		elif not P3Content.data().recipes.has(row.recipe): errors.append("Unknown material recipe")
		else:
			var def: Dictionary = P3Content.data().recipes[row.recipe]
			expenses += int(def.fee)
			if row.inputs.size()!=1 or (row.status in ["ready","claimed"] and row.outputs.size()!=int(def.quantity)) or (row.status in ["running","stopped","cancelled"] and not row.outputs.is_empty()): errors.append("Invalid process yield")
		for id: String in row.inputs:
			var raw := item(s,id)
			if raw.is_empty() or (row.status in ["running","stopped"] and (raw.reserved != row.id or raw.holder != row.id)): errors.append("Process input is not exclusively reserved")
			if not raw.is_empty() and row.status in ["ready","claimed"] and raw.holder != "consumed": errors.append("Completed process retains usable input")
		for id: String in row.outputs:
			var raw := item(s,id)
			if raw.is_empty() or (row.status == "ready" and raw.holder != row.id): errors.append("Invalid process output custody")
			if not raw.is_empty() and raw.parents != row.inputs: errors.append("Process output has incorrect lineage")
		for id: String in row.equipment:
			var raw := item(s,id)
			if raw.is_empty() or (row.status in ["running","ready","stopped"] and raw.reserved != row.id): errors.append("Equipment is not exclusively reserved")
	for key: String in m.notes:
		if m.notes[key] < 0 or m.notes[key] > s.day: errors.append("Future material observation")
	if m.method not in ["","smooth","smooth-reserve","condense"] or (m.method == "") != (m.pledged == 0): errors.append("Invalid preparation method")
	if expenses != m.paid: errors.append("Material expense ledger mismatch")
	var reserved: Array[Dictionary] = []
	for raw: Dictionary in m.items:
		if raw.reserved == PLAN: reserved.append(raw)
		if raw.kind == "vessel":
			var occupied_count := 0
			for other: Dictionary in m.items:
				if other.container == raw.id: occupied_count += 1
			if occupied_count > int(P3Content.data().vessel_capacity): errors.append("Overfilled vessel")
	if m.method != "":
		var smooth: bool = m.method.begins_with("smooth")
		var doses := 0
		var quartz := 0
		for raw: Dictionary in reserved:
			var suitable: bool = raw.kind == "stabilizer" if smooth else raw.kind in ["root","pill"]
			if suitable:
				doses += 1
			elif raw.kind == "quartz" and (smooth or raw.energy == "retained"): quartz += 1
			else: errors.append("Unsuitable preparation reservation")
		if doses != (2 if m.method == "smooth-reserve" else 1) or quartz != (1 if smooth else 2) or m.pledged != (8 if smooth else 12): errors.append("Incomplete preparation reservation")
	elif not reserved.is_empty(): errors.append("Items reserved without a material plan")
	return errors
