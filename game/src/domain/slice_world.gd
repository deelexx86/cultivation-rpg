class_name SliceWorld
extends RefCounted
## VS-DEBUG-01 authored prototype. Calendar work always uses Simulation boundaries.
const STEPS := Vector3(4,0,-1)
const SHOP := {"lo.ward":{"kind":"ward","price":6,"count":2}, "lo.medicine":{"kind":"medicine","price":3,"count":2}}
const STAGES := ["initial","middle","late","perfect","foundation"]
const NAMES := ["Ранняя Ци","Средняя Ци","Поздняя Ци","Великое Совершенство Ци","Раннее Основание"]
const YEARS := [19,4,3]
const LIMITS := [100,115,130,150,200]

static func fresh(id: String, seed_key: String) -> CampaignState:
	var s := CombatState.fresh(id,"qi")
	s.soul.mastery["method.white-sedge"] = 1
	s.seed_value = seed_key
	s.body().born = WorldCalendar.ordinal(-20)
	s.exploration.z = 700
	s.slice = {"area":"village","phase":"","method":"","load":false,"aligned":false,"attempt":0,
		"pool":false,"unstable":0,"decay":0,"sensitive":true,"carrier":"first","fees":0,
		"outer":0,"inner":0,"lost":0,"buried":false,"raid":-1,"robbed":false,"result":""}
	for key: String in SHOP: s.materials.stock[key] = SHOP[key].count
	sync_consumables(s)
	return s

static func schema() -> Dictionary:
	return {"area":"str","phase":"str","method":"str","load":"bool","aligned":"bool","attempt":"int",
		"pool":"bool","unstable":"int","decay":"int","sensitive":"bool","carrier":"str","fees":"int",
		"outer":"int","inner":"int","lost":"int","buried":"bool","raid":"int","robbed":"bool","result":"str"}

static func body_owner(s: CampaignState, id: String) -> bool:
	if id == s.body().id: return true
	if not s.slice.is_empty():
		for old: CampaignState.Body in s.bodies:
			if old.id == id: return true
	return false

static func sign_holder(s: CampaignState,id: String) -> bool:
	return not s.slice.is_empty() and (id == "vault" or body_owner(s,id) or (id.begins_with("grave.") and body_owner(s,id.trim_prefix("grave."))))

static func property_holder(s: CampaignState, row: Dictionary) -> bool:
	return not s.slice.is_empty() and (row.holder == "vault" or row.holder == "grave."+str(row.owner))

static func stored_stones(s: CampaignState) -> int:
	if s.slice.is_empty(): return 0
	return s.slice.inner + s.slice.outer + s.slice.lost

static func vitals(s: CampaignState) -> Dictionary:
	if s.slice.get("carrier","") == "cold": return {"hp":80,"qi":120}
	return P4Content.VITALS[P4Content.HERO]

static func sync_consumables(s: CampaignState) -> void:
	s.combat.wards = MaterialWorld.available(s,"ward").size()
	s.combat.medicine = MaterialWorld.available(s,"medicine").size()

static func consume(row: Dictionary) -> void:
	row.holder = "consumed"
	row.reserved = ""
	row.container = ""

static func consume_carried(s: CampaignState,kind: String) -> void:
	consume(MaterialWorld.item(s,MaterialWorld.equipment(s,kind)))

static func charge(s: CampaignState,amount: int) -> bool:
	if not MaterialWorld.spend(s,amount): return false
	s.slice.fees += amount
	return true

static func calendar(s: CampaignState) -> void:
	var p := s.slice
	if p.raid >= 0 and s.day >= p.raid and not p.robbed:
		p.lost += p.outer
		p.outer = 0
		p.robbed = true
		s.record("cache.raided")
	if p.unstable > 0 and s.day >= p.decay:
		p.unstable = 0
		p.decay = 0
		s.record("unstable.expired")

static func drain(s: CampaignState) -> void:
	s.slice.unstable -= 1
	if s.slice.unstable == 0: s.slice.decay = 0

static func reserved(s: CampaignState, kinds: Array) -> Dictionary:
	for row: Dictionary in s.materials.items:
		if row.reserved == "chamber" and row.kind in kinds: return row
	return {}

static func release(s: CampaignState) -> void:
	for row: Dictionary in s.materials.items:
		if row.reserved == "chamber": row.reserved = ""
	s.slice.phase = ""
	s.slice.method = ""
	s.slice.load = false
	s.slice.aligned = false

static func death(s: CampaignState,reason: String) -> void:
	var old := s.body().id
	var grave := "grave."+old
	release(s)
	for a: CampaignState.Action in s.actions:
		if a.status in ["paused","running"]: a.status = "stopped"
	s.exploration.journey = ""
	for row: Dictionary in s.materials.items:
		if row.holder == old:
			row.holder = grave
			if row.reserved == MaterialWorld.PLAN: row.reserved = ""
	if s.exploration.holder == old: s.exploration.holder = grave
	s.materials.method = ""
	s.materials.pledged = 0
	s.slice.lost += s.materials.wallet
	s.materials.wallet = 0
	s.slice.unstable = 0
	s.slice.decay = 0
	s.slice.pool = false
	s.slice.result = "Носитель погиб. "+("Достигнут предел тела." if reason == "body_expired" else "Перегрузка в камере." if reason == "chamber" else "Смертельный удар у водосброса.")
	s.combat.artifact = false
	sync_consumables(s)
	MaterialWorld.settle(s)

static func rebirth(s: CampaignState) -> void:
	var body := CampaignState.Body.new()
	body.id = "body.%d" % (s.bodies.size()+1)
	body.born = WorldCalendar.add_years(s.day,-18)
	s.bodies.append(body)
	s.active_body += 1
	s.mode = "active"
	var key := "carrier."+body.id
	var cold: int = s.outcomes[key]
	s.slice.carrier = "cold" if cold else "warm"
	s.slice.sensitive = false
	s.slice.area = "village"
	s.exploration.place = SedgeWorld.YARD
	s.exploration.x = 100
	s.exploration.z = 520
	var hero := CombatState.actor(P4Content.HERO,P4Content.START)
	hero.hp = vitals(s).hp
	hero.qi = int(vitals(s).qi)*1000
	s.combat.actors[P4Content.HERO] = hero
	s.combat.rank = "qi"
	s.combat.artifact = false
	s.combat.credit = 0
	s.combat.projectiles.clear()
	for id: String in s.combat.actors:
		var a: Dictionary = s.combat.actors[id]
		a.alert = false
		a.action = CombatState.action()
	s.slice.result = "Вы очнулись у знакомой мастерской. Прежняя ступень полёта утрачена. К востоку от навеса видны старые ступени. Вы помните путь к тайнику." if s.slice.buried else "Вы очнулись у знакомой мастерской. Проверьте старую тропу или вернитесь к практике на дальнем берегу."
	s.record("reborn:"+body.id)

static func cache(s: CampaignState, deposit: bool) -> String:
	if not MaterialWorld.at_workshop(s): return "Тайник у зелёного навеса."
	var p := s.slice
	if deposit:
		if p.buried or s.materials.wallet-s.materials.pledged < 24: return "Нужны 24 свободных камня и пустой тайник."
		var vessel := MaterialWorld.equipment(s,"vessel")
		if vessel == "": return "Нужен свободный сосуд."
		for row: Dictionary in s.materials.items:
			if row.container == vessel and row.reserved != "": return "Содержимое сосуда занято."
		for row: Dictionary in s.materials.items:
			if row.id == vessel or row.container == vessel or (row.kind == "kit" and row.holder == s.body().id and row.reserved == ""):
				row.holder = "vault"
		if s.exploration.holder == s.body().id: s.exploration.holder = "vault"
		p.buried = true
		p.outer = 8
		p.inner = 16
		p.raid = WorldCalendar.add_years(s.day,1)
		s.materials.wallet -= 24
		p.result = "Карта тайника сохранена. Восемь камней снаружи, шестнадцать и имущество внутри."
	else:
		if s.active_body>0 and not s.known.has("path."+s.body().id): return "Сначала сверьте старые ступени к востоку от мастерской с прежней картой."
		if p.inner+p.outer == 0: return "В тайнике ничего нет."
		for row: Dictionary in s.materials.items:
			if row.holder == "vault":
				row.owner = s.body().id
				row.holder = s.body().id
		if s.exploration.holder == "vault": s.exploration.holder = s.body().id
		s.materials.wallet += p.inner+p.outer
		p.inner = 0
		p.outer = 0
		p.result = "Внешнее отделение разграблено. Внутреннее уцелело." if p.robbed else "Оба отделения целы."
	return ""

static func start_time(s: CampaignState, cmd: String, years: int, fatal: bool) -> String:
	var kind := "transfer" if cmd == "transfer" else "slice"
	var plan := Simulation.preview(s,WorldCalendar.add_years(s.day,years)-s.day,0,"",100,100,kind)
	return Simulation.confirm(s,plan,"slice.%s.%d" % [cmd,s.revision],fatal)

static func apply(s: CampaignState,cmd: String,fatal: bool = false) -> String:
	if s.slice.is_empty() or MaterialWorld.occupied(s) or s.mode == "ended": return "Сначала завершите текущее действие."
	if cmd == "transfer" and s.mode == "body_dead":
		var result := start_time(s,cmd,5,fatal)
		if result == "":
			var key := "carrier.body.%d" % (s.bodies.size()+1)
			s.outcomes[key] = (s.seed_value+":"+key).sha256_text().left(8).hex_to_int()%2
		return result
	if s.mode != "active": return "Это тело погибло."
	var p := s.slice
	var stage := STAGES.find(s.body().milestone)
	var phase: String = p.phase
	var smooth: bool = p.method.begins_with("smooth")
	var years := 0
	match cmd:
		"bury","unearth":
			if phase != "": return "Вы заняты в камере."
			var result := cache(s,cmd=="bury")
			if result != "": return result
		"survey":
			var pos := Vector2(s.exploration.x,s.exploration.z)/100.0
			if phase!="" or s.active_body==0 or s.exploration.place!=SedgeWorld.YARD or pos.distance_to(Vector2(STEPS.x,STEPS.z))>2.85: return "Нужно осмотреть старые ступени на месте."
			s.known["path."+s.body().id] = s.day
			p.result = "Ступени осыпались. По знакомой кладке вы нашли пеший обход к мастерской. Теперь можно проверить тайник." if p.buried else "Вы нашли пеший обход к мастерской и переправе. Можно начать практику, даже без оставленного тайника."
		"board":
			if phase != "" or s.exploration.place != SedgeWorld.YARD or not s.exploration.gate or s.flags.has("hall.board"): return "В зале больше нет полётной доски."
			MaterialWorld.add_item(s,"flight_board","hall")
			s.flags["hall.board"] = "taken"
			s.combat.artifact = s.combat.rank == "foundation"
			p.result = "Доска формации у вас. На Основании её полёт потребует Ци и управления."
		"sensitivity":
			if p.sensitive or not MaterialWorld.at_workshop(s) or not s.person(MaterialWorld.MENTOR).alive or phase != "": return "Практика у живого наставника недоступна."
			if not charge(s,4): return "Нужны четыре камня."
			years = 2
		"gather","minor","risk_minor","steady","begin":
			if phase != "" or s.exploration.place != SedgeWorld.BANK: return "Нужна свободная камера на дальнем берегу."
			if cmd == "steady":
				if not s.flags.has("unsteady."+s.body().id): return "Поток уже устойчив."
				years = 2
			elif cmd == "gather":
				if stage >= 4 or p.pool: return "Накопление уже заполнено."
				years = YEARS[stage] if stage < 3 else 1
			elif cmd != "begin":
				if s.flags.has("unsteady."+s.body().id): return "Для новой попытки нужны два года восстановления."
				if stage >= 3 or not p.pool: return "Нужно полное накопление текущей подстадии."
				if cmd == "risk_minor" or s.flags.has("retry."+s.body().id):
					if not charge(s,1): return "Для этой попытки нужен свободный камень."
				years = 1
			else:
				if stage != 3 or not p.pool or s.materials.method == "" or p.unstable > 0 or s.combat.actors.hero.injury: return "Нужны Совершенство, полное накопление, устойчивое тело и подготовленные средства."
				var earliest := WorldCalendar.add_years(s.day,2 if s.materials.method=="condense" else 5)
				if earliest >= mini(s.body_expiry(),s.soul_expiry()) and not fatal: return "За срок попытки будет достигнут предел жизни. Требуется отдельное подтверждение."
				p.method = s.materials.method
				for row: Dictionary in s.materials.items:
					if row.reserved == MaterialWorld.PLAN: row.reserved = "chamber"
				s.materials.method = ""
				s.materials.pledged = 0
				charge(s,4)
				p.phase = "entry"
				p.attempt += 1
				p.result = "Камера оплачена. Введение компонентов ещё впереди."
		"infuse":
			if phase != "entry": return "Введение уже разрешено."
			consume(reserved(s,["stabilizer","root","pill"]))
			consume(reserved(s,["quartz"]))
			charge(s,2 if smooth else 4)
			p.phase = "infusing"
			years = 1
		"reserve","endure","align":
			if phase != "wave": return "Нет колебания для разрешения."
			if cmd == "reserve":
				var dose := reserved(s,["stabilizer"])
				if dose.is_empty(): return "Резервной дозы нет."
				consume(dose)
			if cmd == "reserve" and not smooth: return "У конденсации нет дозы резерва."
			if cmd == "align" and smooth: return "Выравнивание доступно при конденсации."
			p.aligned = cmd == "align"
			p.load = cmd == "endure" and s.outcomes.get("wave.%d"%p.attempt,0)==1
			if not smooth and p.carrier == "cold" and not p.aligned: p.load = true
			p.phase = "settling"
			if smooth: years = 3
			elif p.aligned: years = 1
			else: p.phase = "final"
		"finish","extend","force","unstable":
			if phase != "final": return "Закрепление ещё не началось."
			if smooth and s.outcomes.get("critical.%d"%p.attempt,0)==1: return "Контур распадается. Требуется контролируемое прекращение."
			if cmd == "finish" and p.load: return "Осталась нагрузка."
			if cmd == "extend" and (not smooth or not p.load): return "Продление здесь неприменимо."
			if cmd in ["force","unstable"] and not p.load: return "Контур устойчив."
			if not smooth: consume(reserved(s,["quartz"]))
			charge(s,2 if smooth else 4)
			p.phase = "finishing"
			years = 3 if cmd == "extend" else 1
		"stop":
			if phase not in ["entry","wave","final"]: return "Нет открытого этапа."
			release(s)
			p.result = "Попытка прекращена. Прежняя Ци и неиспользованные средства сохранены."
		_: return "Неизвестное действие."
	if years > 0: return start_time(s,cmd,years,fatal)
	s.revision += 1
	s.record("slice:"+cmd)
	return ""

static func completed(s: CampaignState,a: CampaignState.Action) -> void:
	if a.kind not in ["slice","transfer"]: return
	var cmd := a.id.get_slice(".",1)
	var p := s.slice
	var stage := STAGES.find(s.body().milestone)
	match cmd:
		"transfer": rebirth(s)
		"sensitivity":
			p.sensitive = true
			p.result = "Чувствительность тела развита. Знакомые операции снова доступны."
		"steady":
			s.flags.erase("unsteady."+s.body().id)
			s.flags["retry."+s.body().id] = "yes"
			p.result = "Поток восстановлен. Накопление сохранено; повторная попытка требует одного камня."
		"gather":
			p.pool = true
			p.result = "Накопление заполнено."
		"minor":
			s.flags.erase("retry."+s.body().id)
			Simulation.milestone(s,STAGES[stage+1],LIMITS[stage+1],LIMITS[stage+1])
			p.pool = false
			p.result = "Достигнута ступень: "+NAMES[stage+1]
		"risk_minor":
			s.flags.erase("retry."+s.body().id)
			var key := "minor."+a.id
			s.outcomes[key] = (s.seed_value+key).sha256_text().left(8).hex_to_int()%2
			if s.outcomes[key] == 1:
				Simulation.milestone(s,STAGES[stage+1],LIMITS[stage+1],LIMITS[stage+1])
				p.pool = false
				p.result = "Малый переход завершён."
			else:
				s.flags["unsteady."+s.body().id] = "yes"
				p.result = "Малый переход сорван. Год прошёл, накопление сохранено. Потоку нужны два года восстановления."
		"infuse":
			p.phase = "wave"
			var key := "wave.%d"%p.attempt
			s.outcomes[key] = (s.seed_value+key).sha256_text().left(8).hex_to_int()%2
			if s.seed_value == "vs_smooth_no_overload": s.outcomes[key] = 0
			var critical := (s.seed_value+":"+key+":critical").sha256_text().left(8).hex_to_int()%16==0
			s.outcomes["critical.%d"%p.attempt] = int(p.method.begins_with("smooth") and critical and s.seed_value!="vs_smooth_no_overload")
			p.result = "Контур дрожит. Можно вмешаться или сохранить резерв."
		"align","endure","reserve":
			p.phase = "final"
			p.result = "Нагрузка сохраняется." if p.load else "Контур устойчив и готов к закреплению."
			if s.outcomes.get("critical.%d"%p.attempt,0)==1: p.result = "Предельная нестабильность. Камеру нужно покинуть, пока остановка безопасна."
		"finish","extend":
			Simulation.milestone(s,"foundation",200,200)
			s.combat.rank = "foundation"
			s.combat.artifact = MaterialWorld.equipment(s,"flight_board") != ""
			p.pool = false
			p.result = "Раннее Основание. Вернитесь к торговому двору."
			release(s)
		"unstable","force":
			release(s)
			if cmd == "unstable":
				p.unstable = 3
				p.decay = s.day+30
				p.result = "Закрепление неполно. Усилены три попадания, запас распадётся через 30 дней."
			else:
				var hero: Dictionary = s.combat.actors.hero
				hero.hp = maxi(0,hero.hp-35)
				hero.injury = true
				p.result = "Контур разрушен. Потеряно 35 здоровья, повреждены рёбра."
				if hero.hp == 0: Simulation.lose_body(s,"chamber")

static func problems(s: CampaignState) -> PackedStringArray:
	var p := s.slice
	var errors := PackedStringArray()
	if s.combat.is_empty() or not StateCodec.shape(p,schema()): return PackedStringArray(["Invalid integrated campaign"])
	if p.area not in ["village","ravine"] or p.carrier not in ["first","warm","cold"] or p.phase not in ["","entry","infusing","wave","settling","final","finishing"]: errors.append("Invalid campaign phase")
	var locked_items := 0
	var quartz := 0
	var ingredients := 0
	for row: Dictionary in s.materials.items:
		if row.reserved == "chamber":
			locked_items += 1
			if row.kind == "quartz": quartz += 1
			if row.kind in ["root","pill","stabilizer"]: ingredients += 1
	var running := s.running()
	if p.phase in ["infusing","settling","finishing"] and (running==null or running.kind!="slice") and s.mode!="ended": errors.append("Missing chamber process")
	if running!=null and running.kind=="transfer" and (s.mode!="body_dead" or not s.outcomes.has("carrier.body.%d"%(s.bodies.size()+1))): errors.append("Missing selected carrier")
	if p.phase != "" and (s.exploration.place!=SedgeWorld.BANK or s.body().milestone!="perfect" or not p.pool): errors.append("Invalid chamber actor or place")
	if p.robbed and (p.outer!=0 or p.raid>s.day): errors.append("Inconsistent cache raid")
	if p.buried != (p.raid>=0) or (not p.buried and p.inner+p.outer>0): errors.append("Missing cache provenance")
	if p.phase == "" and locked_items != 0: errors.append("Released chamber retains materials")
	if p.phase != "":
		var smooth: bool = p.method.begins_with("smooth")
		var expected_quartz := 1 if p.phase == "entry" or (not smooth and p.phase != "finishing") else 0
		if not smooth and p.phase == "entry": expected_quartz = 2
		var due := (4 if smooth else 8) if p.phase == "entry" else (2 if smooth else 4)
		if p.phase == "finishing": due = 0
		if quartz != expected_quartz or ingredients + quartz != locked_items or s.materials.wallet < due: errors.append("Chamber reserves do not cover phase")
		if p.phase == "entry" and ingredients != (2 if p.method == "smooth-reserve" else 1): errors.append("Incomplete chamber ingredients")
	if p.phase == "" and p.method != "" or p.phase != "" and p.method not in ["smooth","smooth-reserve","condense"]: errors.append("Invalid chamber method")
	if p.fees < 0 or p.outer not in [0,8] or p.inner not in [0,16] or p.lost < 0 or p.unstable < 0 or p.unstable > 3 or (p.unstable > 0) != (p.decay > s.day): errors.append("Invalid inheritance or temporary Qi")
	if s.body().milestone not in STAGES or (s.body().milestone == "foundation") != (s.combat.rank == "foundation"): errors.append("Rank mismatch")
	if s.combat.wards != MaterialWorld.available(s,"ward").size() or s.combat.medicine != MaterialWorld.available(s,"medicine").size(): errors.append("Combat inventory mismatch")
	return errors
