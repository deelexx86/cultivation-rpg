class_name CombatState
extends RefCounted
## Integer snapshot fields. Distances use millimetres; resources use milli-Qi.
const ZERO := [0, 0, 0]
const MAX_PROJECTILES := 16

static func vec(value: Array) -> Vector3:
	return Vector3(float(value[0]), float(value[1]), float(value[2])) / 1000.0

static func pack(value: Vector3) -> Array[int]:
	return [roundi(value.x * 1000), roundi(value.y * 1000), roundi(value.z * 1000)]

static func order(key: String = "", target: String = "", point: Vector3 = Vector3.ZERO, direction: Vector3 = Vector3.ZERO) -> Dictionary:
	return {"key":key, "target":target, "point":pack(point), "direction":pack(direction)}

static func action() -> Dictionary:
	return {"key":"", "target":"", "center":ZERO.duplicate(), "direction":ZERO.duplicate(), "wind":0, "rest":0}

static func actor(id: String, at: Vector3) -> Dictionary:
	var vitals: Dictionary = P4Content.VITALS[id]
	return {
		"pos":pack(at), "velocity":ZERO.duplicate(), "face":pack(Vector3.FORWARD), "hp":vitals.hp,
		"qi":int(vitals.qi) * 1000, "action":action(), "shield":0, "shield_ticks":0,
		"armor":40 if id == P4Content.HORNED else 0, "heavy_hits":0, "injury":false,
		"flight":"ground", "alert":false, "stagger":0, "loot":"", "damaged":false
	}

static func fresh(id: String, rank: String) -> CampaignState:
	var s := MaterialWorld.fresh(id)
	s.seed_value = "p4-fixed-1"
	s.body().milestone = {"qi":"initial", "foundation":"foundation", "core":"core", "soul":"soul"}[rank]
	for key: String in P4Content.HERO_SKILLS:
		s.soul.mastery["combat." + key] = 1
	s.soul.mastery["combat.perception"] = 1
	s.soul.mastery["combat.meditate"] = 1
	if rank in ["core", "soul"]:
		s.soul.mastery["combat.perception"] = 2
		s.soul.mastery["combat.passive"] = 1
		s.soul.mastery["combat.forewarning"] = 1
	if rank == "soul":
		s.soul.mastery["combat.blink"] = 1
	var actors := {P4Content.HERO: actor(P4Content.HERO, P4Content.START)}
	for key: String in P4Content.SPAWNS:
		if key != P4Content.AIR or rank != "qi":
			actors[key] = actor(key, P4Content.SPAWNS[key])
	if actors.has(P4Content.AIR):
		actors[P4Content.AIR].flight = "self"
	s.combat = {
		"rank":rank, "tick":0, "serial":0, "actors":actors, "projectiles":[],
		"queued":order(), "perception":false, "meditating":false, "credit":0,
		"wards":3, "medicine":1, "artifact":rank == "foundation", "collapse":false,
		"hits":0, "notice":"", "warning":"", "warning_ticks":0
	}
	s.exploration.z = roundi(P4Content.START.z * 100)
	return s

static func schema() -> Dictionary:
	var v := ["int"]
	var command := {"key":"str", "target":"str", "point":v, "direction":v}
	var phase := {"key":"str", "target":"str", "center":v, "direction":v, "wind":"int", "rest":"int"}
	var unit := {
		"pos":v, "velocity":v, "face":v, "hp":"int", "qi":"int", "action":phase,
		"shield":"int", "shield_ticks":"int", "armor":"int", "heavy_hits":"int", "injury":"bool",
		"flight":"str", "alert":"bool", "stagger":"int", "loot":"str", "damaged":"bool"
	}
	var shot := {"id":"int", "owner":"str", "target":"str", "key":"str", "pos":v, "direction":v, "life":"int"}
	return {
		"rank":"str", "tick":"int", "serial":"int", "actors":{"*":unit}, "projectiles":[shot],
		"queued":command, "perception":"bool", "meditating":"bool", "credit":"int",
		"wards":"int", "medicine":"int", "artifact":"bool", "collapse":"bool",
		"hits":"int", "notice":"str", "warning":"str", "warning_ticks":"int"
	}

static func valid_vector(data: Array, bound: int) -> bool:
	return data.size() == 3 and data.all(func(value: Variant) -> bool: return absi(int(value)) <= bound)

static func valid_target(c: Dictionary, id: String) -> bool:
	return id == "" or c.actors.has(id)

static func valid(s: CampaignState) -> bool:
	var c := s.combat
	if s.materials.is_empty() or not StateCodec.shape(c, schema()):
		return false
	if c.rank not in P4Content.RANKS or c.tick < 0 or c.serial < 0 or c.hits < 0 or c.credit < 0 or c.credit > 3:
		return false
	if c.warning_ticks < 0 or c.warning_ticks > 120 or (c.warning_ticks == 0) != (c.warning == ""):
		return false
	if c.wards < 0 or c.wards > 3 or c.medicine < 0 or c.medicine > (1 if s.slice.is_empty() else 2) or (c.artifact and c.rank != "foundation"):
		return false
	var has_crossing := s.event(P4Content.AMBUSH) != null and s.event(P4Content.AMBUSH).status == "applied"
	var has_air: bool = c.rank != "qi" and s.slice.is_empty()
	var expected_count := (4 if has_air else 3) + int(has_crossing)
	if c.actors.has(P4Content.CROSSING) != has_crossing or c.actors.has(P4Content.AIR) != has_air:
		return false
	if s.slice.is_empty() and s.body().milestone != ("initial" if c.rank == "qi" else c.rank):
		return false
	if c.actors.size() != expected_count or not c.actors.has(P4Content.HERO) or not c.actors.has(P4Content.YOUNG) or not c.actors.has(P4Content.HORNED):
		return false
	var queued: Dictionary = c.queued
	if queued.key != "" and queued.key not in P4Content.skills(s):
		return false
	if not valid_target(c, queued.target) or not valid_vector(queued.point, 30000) or not valid_vector(queued.direction, 1000):
		return false
	for id: String in c.actors:
		if not P4Content.VITALS.has(id):
			return false
		var a: Dictionary = c.actors[id]
		var limits: Dictionary = SliceWorld.vitals(s) if id == P4Content.HERO else P4Content.VITALS[id]
		if a.hp < 0 or a.hp > limits.hp or a.qi < 0 or a.qi > limits.qi * 1000 or a.shield < 0 or a.shield > 40 or a.shield_ticks < 0 or a.shield_ticks > 480 or (a.shield == 0) != (a.shield_ticks == 0):
			return false
		if a.armor < 0 or a.armor > (40 if id == P4Content.HORNED else 0) or a.heavy_hits < 0 or a.stagger < 0 or a.stagger > 30:
			return false
		if a.flight not in ["ground", "artifact", "self", "glide"] or a.loot not in ["", "intact", "damaged", "collected"]:
			return false
		if not valid_vector(a.pos, 24500) or not valid_vector(a.velocity, 20000) or not valid_vector(a.face, 1000):
			return false
		if a.pos[1] < -500 or a.pos[1] > 12000 or (a.hp > 0 and a.loot != ""):
			return false
		if (a.flight == "artifact" and (id != P4Content.HERO or not c.artifact)) or (id == P4Content.HERO and a.flight == "self" and c.rank not in ["core", "soul"]):
			return false
		var phase: Dictionary = a.action
		var card: Dictionary = P4Content.ACTIONS.get(phase.key, {})
		if phase.wind < 0 or phase.rest < 0 or phase.wind > card.get("wind", 0) or phase.rest > card.get("rest", 0) or (phase.wind > 0 and phase.rest > 0):
			return false
		var allowed: Array = P4Content.skills(s) if id == P4Content.HERO else [{P4Content.YOUNG:"lunge", P4Content.HORNED:"crush"}.get(id, "spit")]
		if phase.key != "" and phase.key not in allowed:
			return false
		if (phase.key == "") != (phase.wind == 0 and phase.rest == 0) or not valid_target(c, phase.target):
			return false
		if not valid_vector(phase.center, 30000) or not valid_vector(phase.direction, 1000):
			return false
	var hero: Dictionary = c.actors[P4Content.HERO]
	if c.meditating and (hero.flight != "ground" or hero.action.key != "" or not s.body().alive):
		return false
	for id: String in [P4Content.YOUNG, P4Content.HORNED]:
		var a: Dictionary = c.actors[id]
		var count := 0
		for row: Dictionary in s.materials.items:
			count += int(row.origin == id)
		if count != int(a.loot == "collected") or (a.hp == 0 and a.loot == ""):
			return false
	if (hero.hp > 0) != s.body().alive or c.projectiles.size() > MAX_PROJECTILES:
		return false
	var seen := {}
	for shot: Dictionary in c.projectiles:
		var card: Dictionary = P4Content.ACTIONS.get(shot.key, {})
		if shot.id <= 0 or shot.id > c.serial or seen.has(shot.id) or card.get("kind") != "shot" or shot.life <= 0 or shot.life > card.life:
			return false
		if not c.actors.has(shot.owner) or not valid_target(c, shot.target) or not valid_vector(shot.pos, 30000) or not valid_vector(shot.direction, 1000):
			return false
		seen[shot.id] = true
	return true
