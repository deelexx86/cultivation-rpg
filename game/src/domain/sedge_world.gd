class_name SedgeWorld
extends RefCounted

const SIGN := "lo-wei.copper-seal.01"
const LO := "lo-wei"
const ROUTE_BASE := 3
const FLOOD_DELAY := 2
const YARD := "court"
const BANK := "landing"

static func schema() -> Dictionary:
	return {"place":"str", "x":"int", "z":"int", "sign_id":"str", "holder":"str", "story":"str", "gate":"bool", "source":"str", "notes":{"*":"int"}, "journey":"str"}

static func fresh(id: String) -> CampaignState:
	var s := CampaignState.new()
	s.campaign_id = id
	s.exploration = {"place":YARD, "x":0, "z":700, "sign_id":SIGN, "holder":"spillway", "story":"new", "gate":false, "source":"dry", "notes":{}, "journey":""}
	for id_value: String in [LO, "yin-qiu"]:
		var npc := CampaignState.Person.new()
		npc.id = id_value
		s.people.append(npc)
	var death := P1Fixture.event("lo-wei.death", WorldCalendar.ordinal(15), "death", LO)
	s.events.append(death)
	return s

static func valid(s: CampaignState) -> bool:
	var e := s.exploration
	if not StateCodec.shape(e, schema()) or e.sign_id != SIGN or e.place not in [YARD,BANK] or absf(e.x) > 2600 or absf(e.z) > 2600:
		return false
	if s.person(LO) == null or s.person("yin-qiu") == null or e.holder not in ["spillway","body.1",LO,"socket"] or e.story not in ["new","asked","declined","returned","gift"] or e.source not in ["dry","flooded"]:
		return false
	if e.gate != (e.holder == "socket") or (e.story == "returned") != (e.holder == LO):
		return false
	for date: Variant in e.notes.values():
		if int(date) < 0 or int(date) > s.day:
			return false
	if e.story in ["asked","returned","gift"] and s.obligations.is_empty():
		return false
	if e.story == "gift" and e.holder not in [s.body().id,"socket"]:
		return false
	var trip := s.action(e.journey)
	if e.journey != "" and (trip == null or trip.kind != "travel" or trip.status == "complete"):
		return false
	for action: CampaignState.Action in s.actions:
		if action.kind == "travel" and action.status in ["running","paused"] and action != trip:
			return false
	return true

static func qualified(s: CampaignState) -> bool:
	return s.soul.mastery.get("herbalism.glass-root",0) > 0

static func active_trip(s: CampaignState) -> CampaignState.Action:
	return s.action(s.exploration.journey)

static func arrive(s: CampaignState) -> void:
	var e := s.exploration
	e.place = BANK if e.place == YARD else YARD
	e.x = 0 if e.place == BANK else 900
	e.z = 450
	e.journey = ""

static func route_plan(s: CampaignState) -> Dictionary:
	return Simulation.preview(s, ROUTE_BASE + FLOOD_DELAY, 0, "", 100, 100, "travel")

static func depart(s: CampaignState, plan: Dictionary) -> String:
	if not s.exploration.journey.is_empty() or plan != route_plan(s):
		return "Обновите прогноз пути."
	var id := "ferry.%d" % s.revision
	var result := Simulation.confirm(s, plan, id)
	if result != "":
		return result
	s.exploration.journey = id
	if s.event("ferryman") == null:
		var encounter := P1Fixture.event("ferryman", s.day + 2, "call")
		encounter.interrupt = true
		s.events.append(encounter)
	return ""

static func apply(s: CampaignState, cmd: String) -> String:
	var e := s.exploration
	var alive := s.person(LO).alive
	var trip := active_trip(s)
	if s.mode != "active" or (trip != null and cmd != "rope"):
		return "Сейчас это невозможно."
	if cmd != "rope" and e.place != YARD:
		return "Вернитесь к торговому двору."
	match cmd:
		"accept","decline":
			if not alive or e.story != "new": return "Просьба уже решена."
			e.story = "asked" if cmd == "accept" else "declined"
			if cmd == "accept":
				var oath := CampaignState.Obligation.new()
				oath.id = "trade-sign"
				oath.person = LO
				s.obligations.append(oath)
		"take":
			if e.holder != "spillway": return "Знака здесь нет."
			e.holder = s.body().id
		"return":
			if not alive or e.story != "asked" or e.holder != s.body().id: return "Некому вернуть знак."
			e.holder = LO
			e.story = "returned"
			s.obligations[0].active = false
			s.obligations[0].ended = s.day
			s.supplies += 1
		"gift":
			if not alive or e.story != "returned" or s.day <= int(e.notes["return"]): return "Зайдите в другой день."
			e.story = "gift"
			e.holder = s.body().id
		"notch":
			if e.holder != s.body().id: return "Нужен сам знак."
		"open":
			if e.holder != s.body().id or not (e.notes.has("gift") or e.notes.has("notch")): return "Осмотрите оборот знака."
			e.holder = "socket"
			e.gate = true
		"observe","interpret":
			if cmd == "interpret" and not e.notes.has("observe."+e.source): return "Сначала осмотрите берег."
			cmd += "." + str(e.source)
		"successor":
			if alive: return "Лавкой ещё владеет Ло Вэй."
		"rope":
			if trip == null or trip.blocker != "ferryman": return "Паромщик уже прошёл."
			var result := Simulation.resume(s, trip.id, "ferryman.rope")
			if result != "": return result
			e.source = "flooded"
		_: return "Неизвестное действие."
	if e.notes.has(cmd): return "duplicate"
	e.notes[cmd] = s.day
	s.revision += 1
	return ""
