class_name CampaignState
extends RefCounted
## The mutable simulation model. No Nodes, frame clock or filesystem access.

class Soul extends RefCounted:
	var born: int = 0
	var limit_years: int = 100
	var first_milestones: Dictionary[String, int] = {}
	var mastery: Dictionary[String, int] = {}
	func encode() -> Dictionary:
		return {"born": born, "limit_years": limit_years, "first_milestones": first_milestones.duplicate(), "mastery": mastery.duplicate()}

class Body extends RefCounted:
	var id: String = "body.1"
	var born: int = WorldCalendar.ordinal(-18)
	var limit_years: int = 100
	var alive: bool = true
	var died: int = -1
	var milestone: String = "initial"
	var practice_days: int = 0
	func encode() -> Dictionary:
		return {"id": id, "born": born, "limit_years": limit_years, "alive": alive, "died": died, "milestone": milestone, "practice_days": practice_days}

class Action extends RefCounted:
	var id: String = ""
	var kind: String = "practice"
	var duration: int = 0
	var progress: int = 0
	var cost: int = 0
	var milestone: String = ""
	var soul_years: int = 100
	var body_years: int = 100
	var status: String = "running"
	var blocker: String = ""
	func encode() -> Dictionary:
		return {"id": id, "kind": kind, "duration": duration, "progress": progress, "cost": cost, "milestone": milestone, "soul_years": soul_years, "body_years": body_years, "status": status, "blocker": blocker}

class Person extends RefCounted:
	var id: String = ""
	var alive: bool = true
	var died: int = -1
	func encode() -> Dictionary:
		return {"id": id, "alive": alive, "died": died}

class Obligation extends RefCounted:
	var id: String = ""
	var person: String = ""
	var body: String = "body.1"
	var active: bool = true
	var ended: int = -1
	func encode() -> Dictionary:
		return {"id": id, "person": person, "body": body, "active": active, "ended": ended}

class WorldEvent extends RefCounted:
	var id: String = ""
	var day: int = 0
	var kind: String = "flag"
	var target: String = ""
	var value: String = ""
	var prerequisites: Array[String] = []
	var requires_flag: String = ""
	var requires_value: String = ""
	var requires_person: String = ""
	var status: String = "pending"
	var resolved: int = -1
	var interrupt: bool = false
	func encode() -> Dictionary:
		return {"id": id, "day": day, "kind": kind, "target": target, "value": value, "prerequisites": prerequisites.duplicate(), "requires_flag": requires_flag, "requires_value": requires_value, "requires_person": requires_person, "status": status, "resolved": resolved, "interrupt": interrupt}

var campaign_id: String = "p1-demo"
var exploration: Dictionary = {}
var materials: Dictionary = {}
var day: int = 0
var revision: int = 0
var mode: String = "active"
var end_reason: String = ""
var soul: Soul = Soul.new()
var bodies: Array[Body] = [Body.new()]
var active_body: int = 0
var supplies: int = 20
var spent: int = 0
var actions: Array[Action] = []
var events: Array[WorldEvent] = []
var people: Array[Person] = []
var obligations: Array[Obligation] = []
var flags: Dictionary[String, String] = {}
var known: Dictionary[String, int] = {}
var receipts: Dictionary[String, String] = {}
var history: Array[String] = []
# P1 has no random gameplay. A versioned operation-keyed stream fixture is saved.
var seed_value: String = "p1-fixed-1"
var outcomes: Dictionary[String, int] = {}

func body() -> Body:
	return bodies[active_body]

func person(id: String) -> Person:
	for value: Person in people:
		if value.id == id:
			return value
	return null

func event(id: String) -> WorldEvent:
	for value: WorldEvent in events:
		if value.id == id:
			return value
	return null

func action(id: String) -> Action:
	for value: Action in actions:
		if value.id == id:
			return value
	return null

func running() -> Action:
	for value: Action in actions:
		if value.status == "running":
			return value
	return null

func soul_expiry() -> int:
	return WorldCalendar.add_years(soul.born, soul.limit_years)

func body_expiry() -> int:
	return WorldCalendar.add_years(body().born, body().limit_years)

func record(message: String) -> void:
	history.append("%d:%s" % [day, message])

func encode() -> Dictionary:
	var result := {"campaign_id": campaign_id, "day": day, "revision": revision, "mode": mode, "end_reason": end_reason, "soul": soul.encode(), "active_body": active_body, "supplies": supplies, "spent": spent, "flags": flags.duplicate(), "known": known.duplicate(), "receipts": receipts.duplicate(), "history": history.duplicate(), "seed_value": seed_value, "outcomes": outcomes.duplicate()}
	for field: String in ["bodies", "actions", "events", "people", "obligations"]:
		var rows: Array = []
		for item: RefCounted in get(field):
			rows.append(item.encode())
		result[field] = rows
	if not exploration.is_empty():
		result["exploration"] = exploration.duplicate(true)
	if not materials.is_empty():
		result["materials"] = materials.duplicate(true)
	return result

func fingerprint() -> String:
	return JSON.stringify(encode()).sha256_text()
