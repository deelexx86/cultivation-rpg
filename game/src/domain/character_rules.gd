class_name CharacterRules
extends RefCounted
## Immutable schema-6 carrier cards. Only the chosen card and acquired changes are saved.
const ELEMENTS := {"wood":"дерево", "fire":"огонь", "earth":"земля", "metal":"металл", "water":"вода"}
const CARDS := {
	"first": {"roots":["wood","fire","earth"], "fortitude":5, "mobility":2, "capacity":100, "conductivity":2, "sensitivity":2},
	"warm": {"roots":["wood","fire","metal"], "fortitude":5, "mobility":3, "capacity":100, "conductivity":3, "sensitivity":1},
	"cold": {"roots":["earth","metal","water"], "fortitude":4, "mobility":1, "capacity":120, "conductivity":1, "sensitivity":1}
}
const MIND := {"control":4, "focus":2, "reason":1}
const QUALITY := {"initial":1, "middle":1, "late":2, "perfect":2, "foundation":3}
const DRILLS := {
	"footwork":{"label":"Школа шага", "result":"Подвижность +1", "years":1, "stones":3},
	"sensitivity":{"label":"Развить чувствительность", "result":"Чувствительность +1", "years":2, "stones":4},
	"reason":{"label":"Созерцание трактата", "result":"Разум +1", "years":4, "stones":8},
	"weave":{"label":"Разведение потоков", "result":"Контроль +1", "years":1, "stones":3},
	"focus":{"label":"Удержание печати", "result":"Сосредоточение +1", "years":1, "stones":2}
}

static func card(s: CampaignState) -> Dictionary:
	return CARDS[s.body().profile]

static func sensitivity(s: CampaignState) -> int:
	if s.slice.is_empty(): return 2
	return int(card(s).sensitivity) + s.body().sense_drills

static func mobility(s: CampaignState) -> int:
	return int(card(s).mobility) + s.body().footwork

static func stride(s: CampaignState) -> float:
	if s.slice.is_empty(): return 1.0
	return 1.0 + 0.1 * (mobility(s) - 2)

static func carry_limit(s: CampaignState) -> int:
	var grams: int = P3Content.data().carry_grams
	if not s.slice.is_empty(): grams += (int(card(s).fortitude) - 5) * 500
	return grams

static func quality(s: CampaignState) -> int:
	return QUALITY[s.body().milestone]

static func has_root(s: CampaignState, element: String) -> bool:
	return element in card(s).roots

static func study_days(s: CampaignState, years: int) -> int:
	var days := WorldCalendar.add_years(s.day, years) - s.day
	if s.slice.is_empty(): return days
	return ceili(float(days) / int(s.soul.mental.reason))

static func craft_days(s: CampaignState, recipe: String, days: int) -> int:
	if recipe == "stabilize" and not s.slice.is_empty() and not has_root(s,"wood"):
		return days + 1
	return days

static func bolt_cost(s: CampaignState) -> int:
	return int(P4Content.ACTIONS.bolt.qi) + int(not has_root(s,"fire"))

static func bolt_bonus(s: CampaignState) -> int:
	return clampi(3 * (quality(s) - 1), 0, 6)

static func saturated(s: CampaignState, cmd: String) -> bool:
	match cmd:
		"footwork": return s.body().footwork == 1
		"sensitivity": return sensitivity(s) >= 2
		"reason": return s.soul.mental.reason == 2
		"weave": return s.soul.mental.control == 5
		"focus": return s.soul.mental.focus == 3
	return true

static func start(s: CampaignState, cmd: String, fatal: bool) -> String:
	if s.slice.area != "village" or s.slice.phase != "" or not MaterialWorld.at_workshop(s) or not s.person(MaterialWorld.MENTOR).alive:
		return "Практика доступна у живого Шэнь Юя в мастерской."
	if saturated(s,cmd): return "Предел пользы этой практики уже достигнут."
	if not s.soul.mastery.has("method.white-sedge"): return "Нужен освоенный метод Белой осоки."
	if cmd == "reason" and MaterialWorld.equipment(s,"treatise") == "": return "Для созерцания нужен трактат при себе."
	var drill: Dictionary = DRILLS[cmd]
	if s.materials.wallet - s.materials.pledged < int(drill.stones): return "Недостаточно свободных камней."
	var result := SliceWorld.start_time(s,cmd,drill.years,fatal)
	if result == "": SliceWorld.charge(s,drill.stones)
	return result

static func complete(s: CampaignState, cmd: String) -> void:
	match cmd:
		"footwork": s.body().footwork = 1
		"sensitivity": s.body().sense_drills = 1
		"reason": s.soul.mental.reason = 2
		"weave": s.soul.mental.control = 5
		"focus": s.soul.mental.focus = 3
	s.slice.result = DRILLS[cmd].result + ". Практика завершена."

static func check_teacher(s: CampaignState) -> void:
	if s.person(MaterialWorld.MENTOR).alive: return
	for action: CampaignState.Action in s.actions:
		if action.kind == "slice" and action.status in ["running","paused"] and DRILLS.has(action.id.get_slice(".",1)):
			action.status = "stopped"
			s.slice.result = "Наставник умер. Практика остановлена, оплата и прошедшие дни сохранены."
			s.record("training.stopped:"+action.id)

static func valid(s: CampaignState) -> bool:
	var mind := s.soul.mental
	if not StateCodec.shape(mind, {"control":"int","focus":"int","reason":"int"}): return false
	if mind.reason not in [1,2] or mind.focus not in [2,3] or mind.control not in [4,5]: return false
	if s.active_body != s.bodies.size()-1: return false
	for i in s.bodies.size():
		var body := s.bodies[i]
		if body.id != "body.%d" % (i+1) or (i < s.active_body and body.alive): return false
		var expected := "first"
		if i > 0:
			var selection: int = s.outcomes.get("carrier."+body.id,-1)
			if selection not in [0,1]: return false
			expected = "cold" if selection == 1 else "warm"
		if body.profile != expected or not QUALITY.has(body.milestone): return false
		if body.footwork not in [0,1] or body.sense_drills not in [0,1] or int(CARDS[expected].sensitivity) + body.sense_drills > 2: return false
	return true
