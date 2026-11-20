class_name SliceSession
extends SedgeSession

static var current: SliceSession
const VILLAGE := "res://scenes/sedge.tscn"
const RAVINE := "res://scenes/combat_stand.tscn"

static func storage(id: String) -> SnapshotStore:
	return SnapshotStore.new("user://sedge-campaign",id,true,true,true,true)

static func open(id: String, seed_key: String) -> SliceSession:
	var slot := storage(id)
	var session := SliceSession.new(SliceWorld.fresh(id,seed_key),slot)
	if FileAccess.file_exists(slot.path("current.json")) or FileAccess.file_exists(slot.path("previous.json")):
		session.reload()
	else:
		session.save()
	return session

func play(cmd: String, fatal: bool = false) -> bool:
	if dirty: return false
	var candidate := StateCodec.clone(state)
	return commit(candidate,SliceWorld.apply(candidate,cmd,fatal))

func switch_area(area: String) -> bool:
	if dirty or MaterialWorld.occupied(state) or state.slice.phase != "": return false
	var candidate := StateCodec.clone(state)
	candidate.slice.area = area
	if area == "ravine":
		if candidate.mode != "active" or candidate.exploration.place != SedgeWorld.YARD: return false
		candidate.combat.actors.hero.pos = CombatState.pack(Vector3(0,0,4))
	elif candidate.mode == "active":
		var hero: Dictionary = candidate.combat.actors.hero
		if hero.flight != "ground" or CombatWorld.engaged(candidate) or not candidate.combat.projectiles.is_empty() or hero.action.key != "" or candidate.combat.queued.key != "": return false
		candidate.combat.meditating = false
		candidate.combat.perception = false
		candidate.exploration.x = 0
		candidate.exploration.z = 450
	candidate.revision += 1
	return commit(candidate,"")
