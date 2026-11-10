class_name StateCodec
extends RefCounted
## Explicit schema and invariant checks before constructing typed objects.

static func shape(value: Variant, spec: Variant) -> bool:
	if spec is String:
		match spec:
			"int": return (value is int or value is float) and is_finite(float(value)) and float(value) == floor(float(value)) and absf(float(value)) <= 1000000000
			"str": return value is String and value.length() <= 4096
			"bool": return value is bool
	if spec is Array:
		if not value is Array or value.size() > 100000:
			return false
		for element: Variant in value:
			if not shape(element, spec[0]):
				return false
		return true
	if spec is Dictionary:
		if not value is Dictionary:
			return false
		if spec.has("*"):
			for key: Variant in value:
				if not shape(key, "str") or not shape(value[key], spec["*"]):
					return false
			return true
		if value.size() != spec.size():
			return false
		for key: String in spec:
			if not value.has(key) or not shape(value[key], spec[key]):
				return false
		return true
	return false

static func schema() -> Dictionary:
	return {
		"campaign_id": "str", "day": "int", "revision": "int", "mode": "str", "end_reason": "str",
		"soul": {"born": "int", "limit_years": "int", "first_milestones": {"*": "int"}, "mastery": {"*": "int"}},
		"bodies": [{"id": "str", "born": "int", "limit_years": "int", "alive": "bool", "died": "int", "milestone": "str", "practice_days": "int"}],
		"active_body": "int", "supplies": "int", "spent": "int",
		"actions": [{"id": "str", "kind": "str", "duration": "int", "progress": "int", "cost": "int", "milestone": "str", "soul_years": "int", "body_years": "int", "status": "str", "blocker": "str"}],
		"events": [{"id": "str", "day": "int", "kind": "str", "target": "str", "value": "str", "prerequisites": ["str"], "requires_flag": "str", "requires_value": "str", "requires_person": "str", "status": "str", "resolved": "int", "interrupt": "bool"}],
		"people": [{"id": "str", "alive": "bool", "died": "int"}],
		"obligations": [{"id": "str", "person": "str", "body": "str", "active": "bool", "ended": "int"}],
		"flags": {"*": "str"}, "known": {"*": "int"}, "receipts": {"*": "str"}, "history": ["str"],
		"seed_value": "str", "outcomes": {"*": "int"}}

static func assign_fields(object: RefCounted, data: Dictionary) -> void:
	for key: String in data:
		var old: Variant = object.get(key)
		if old is int:
			object.set(key, int(data[key]))
		elif old is Dictionary:
			old.clear()
			for entry: String in data[key]:
				old[entry] = int(data[key][entry]) if key in ["first_milestones", "mastery", "known", "outcomes"] else data[key][entry]
		elif old is Array:
			old.assign(data[key])
		else:
			object.set(key, data[key])

static func decode(data: Variant) -> CampaignState:
	var spec := schema()
	if data is Dictionary and data.has("exploration"):
		spec["exploration"] = SedgeWorld.schema()
	if data is Dictionary and data.has("materials"):
		spec["materials"] = MaterialWorld.schema()
	if not shape(data, spec):
		return null
	var state := CampaignState.new()
	var scalars: Dictionary = data.duplicate(true)
	for key: String in ["soul", "bodies", "actions", "events", "people", "obligations"]:
		scalars.erase(key)
	assign_fields(state, scalars)
	if not state.materials.is_empty():
		state.materials = P3Content.integers(state.materials)
	if not state.exploration.is_empty():
		for key: String in ["x","z"]:
			state.exploration[key] = int(state.exploration[key])
		for key: String in state.exploration.notes:
			state.exploration.notes[key] = int(state.exploration.notes[key])
	assign_fields(state.soul, data.soul)
	for key: String in ["bodies", "actions", "events", "people", "obligations"]:
		var target: Array = state.get(key)
		target.clear()
		for row: Dictionary in data[key]:
			var item: RefCounted
			match key:
				"bodies": item = CampaignState.Body.new()
				"actions": item = CampaignState.Action.new()
				"events": item = CampaignState.WorldEvent.new()
				"people": item = CampaignState.Person.new()
				"obligations": item = CampaignState.Obligation.new()
			assign_fields(item, row)
			target.append(item)
	return state if problems(state).is_empty() else null

static func clone(state: CampaignState) -> CampaignState:
	return decode(state.encode())

static func problems(state: CampaignState) -> PackedStringArray:
	var errors := PackedStringArray()
	if state.campaign_id.is_empty() or state.day < 0 or state.day >= WorldCalendar.ordinal(3000) or state.revision < 0:
		errors.append("Invalid campaign identity/date/revision (P1 supports pre-endgame dates)")
	if state.soul.born != 0 or state.soul.limit_years < 100 or state.soul.limit_years > 5000:
		errors.append("Invalid soul origin/limit")
	if state.bodies.is_empty() or state.active_body < 0 or state.active_body >= state.bodies.size():
		errors.append("Missing active body")
		return errors
	if state.mode not in ["active", "body_dead", "ended"] or state.supplies < 0 or state.spent < 0:
		errors.append("Invalid mode or negative resource")
	for field: String in ["bodies", "actions", "events", "people", "obligations"]:
		var ids: Dictionary = {}
		for item: RefCounted in state.get(field):
			if item.id.is_empty() or ids.has(item.id):
				errors.append("Empty/duplicate ID in " + field)
			ids[item.id] = true
	for body: CampaignState.Body in state.bodies:
		if body.born < WorldCalendar.ordinal(-10000) or body.born > state.day or body.limit_years <= 0 or body.limit_years > 5000 or body.practice_days < 0:
			errors.append("Invalid body age/limit/progress")
		if (body.alive and body.died != -1) or (not body.alive and (body.died < 0 or body.died > state.day)):
			errors.append("Inconsistent body death")
	# Do not calculate anniversaries from malformed dates/limits.
	if not errors.is_empty():
		return errors
	if state.mode == "active" and (not state.body().alive or state.soul_expiry() <= state.day or state.body_expiry() <= state.day):
		errors.append("Expired active life")
	if state.mode == "body_dead" and (state.body().alive or state.soul_expiry() <= state.day):
		errors.append("Invalid body-dead continuation")
	if state.mode == "ended" and (state.end_reason != "soul_expired" or state.soul_expiry() > state.day):
		errors.append("Invalid campaign ending")
	var running := 0
	var total_cost := 0
	for action: CampaignState.Action in state.actions:
		if action.kind not in ["practice", "recovery", "transfer_probe", "travel_probe", "travel", "study", "craft"] or action.status not in ["running", "paused", "complete", "stopped"]:
			errors.append("Unknown action kind/status")
		if action.kind in ["study","craft"] and (state.materials.is_empty() or MaterialWorld.job(state,action.id).is_empty()):
			errors.append("Material action requires its process")
		if action.kind == "travel" and state.exploration.is_empty():
			errors.append("Playable travel requires an exploration campaign")
		if action.duration <= 0 or action.duration > 1095728 or action.progress < 0 or action.progress > action.duration or action.cost < 0 or action.soul_years < 100 or action.soul_years > 5000 or action.body_years <= 0 or action.body_years > 5000:
			errors.append("Invalid action values")
		if action.status == "complete" and action.progress != action.duration:
			errors.append("Inconsistent completion")
		if not state.receipts.has(action.id):
			errors.append("Action without confirmation receipt")
		if action.status == "running":
			running += 1
		if not action.blocker.is_empty() and (state.event(action.blocker) == null or state.event(action.blocker).status != "applied"):
			errors.append("Unknown unresolved interruption")
		total_cost += action.cost
	if total_cost != state.spent or running > 1 or (state.mode != "active" and running > 0):
		# transfer_probe is only a controlled no-body calendar fixture.
		if not (total_cost == state.spent and running == 1 and state.mode == "body_dead" and state.running().kind == "transfer_probe"):
			errors.append("Inconsistent expenses/running action")
	for person: CampaignState.Person in state.people:
		if (person.alive and person.died != -1) or (not person.alive and (person.died < 0 or person.died > state.day)):
			errors.append("Inconsistent NPC death")
	for obligation: CampaignState.Obligation in state.obligations:
		var person := state.person(obligation.person)
		var body_exists := false
		for body: CampaignState.Body in state.bodies:
			body_exists = body_exists or body.id == obligation.body
		if person == null or not body_exists:
			errors.append("Missing obligation participant")
			continue
		if (obligation.active and (not person.alive or obligation.ended != -1)) or (not obligation.active and (obligation.ended < 0 or obligation.ended > state.day)):
			errors.append("Inconsistent personal obligation")
	for milestone: String in state.soul.first_milestones:
		if state.soul.first_milestones[milestone] < 0 or state.soul.first_milestones[milestone] > state.day:
			errors.append("Future milestone")
	for key: String in state.known:
		if state.known[key] < 0 or state.known[key] > state.day:
			errors.append("Future knowledge")
	for key: String in state.outcomes:
		if state.outcomes[key] not in [0, 1]:
			errors.append("Invalid resolved outcome")
	if not state.exploration.is_empty() and not SedgeWorld.valid(state):
		errors.append("Invalid White Sedge state")
	if not state.materials.is_empty():
		errors.append_array(MaterialWorld.problems(state))
	errors.append_array(EventGraph.problems(state))
	return errors
