class_name EventGraph
extends RefCounted
## Explicit causal edges; stable IDs break ties only between independent events.

static func depends(state: CampaignState, event: CampaignState.WorldEvent, ancestor: String, visited: Dictionary = {}) -> bool:
	if visited.has(event.id):
		return false
	visited[event.id] = true
	for id: String in event.prerequisites:
		if id == ancestor:
			return true
		var parent := state.event(id)
		if parent != null and depends(state, parent, ancestor, visited):
			return true
	return false

static func writes(event: CampaignState.WorldEvent) -> Array[String]:
	if event.kind == "death":
		return ["person:" + event.target]
	if event.kind in ["flag", "chance_flag"]:
		return ["flag:" + event.target]
	return []

static func reads(event: CampaignState.WorldEvent) -> Array[String]:
	var keys: Array[String] = []
	if not event.requires_person.is_empty():
		keys.append("person:" + event.requires_person)
	if not event.requires_flag.is_empty():
		keys.append("flag:" + event.requires_flag)
	return keys

static func problems(state: CampaignState) -> PackedStringArray:
	var errors := PackedStringArray()
	for event: CampaignState.WorldEvent in state.events:
		if event.kind not in ["death", "flag", "chance_flag", "call"] or event.day < 0 or event.day >= WorldCalendar.ordinal(3000) or event.status not in ["pending", "applied", "cancelled"]:
			errors.append("Invalid event definition/status: " + event.id)
		if event.status == "pending" and (event.day < state.day or event.resolved != -1):
			errors.append("Stale pending event: " + event.id)
		if event.status != "pending" and (event.resolved != event.day or event.resolved > state.day):
			errors.append("Invalid resolved date: " + event.id)
		if event.kind == "death" and state.person(event.target) == null:
			errors.append("Missing death target: " + event.id)
		if not event.requires_person.is_empty() and state.person(event.requires_person) == null:
			errors.append("Missing prerequisite person: " + event.id)
		if event.kind in ["flag", "chance_flag"] and event.target.is_empty():
			errors.append("Missing flag target: " + event.id)
		for id: String in event.prerequisites:
			var parent := state.event(id)
			if parent == null or parent.day > event.day:
				errors.append("Missing/future prerequisite: " + event.id)
		if depends(state, event, event.id):
			errors.append("Causal event cycle: " + event.id)
	for a: CampaignState.WorldEvent in state.events:
		for b: CampaignState.WorldEvent in state.events:
			if a.id >= b.id or a.day != b.day:
				continue
			if a.interrupt and b.interrupt:
				errors.append("P1 requires one authored interruption channel per date: %s / %s" % [a.id, b.id])
			var conflict := false
			for key: String in writes(a):
				conflict = conflict or key in writes(b) or key in reads(b)
			for key: String in writes(b):
				conflict = conflict or key in reads(a)
			if conflict and not depends(state, a, b.id) and not depends(state, b, a.id):
				errors.append("Same-day conflict needs causal edge: %s / %s" % [a.id, b.id])
	return errors

static func due(state: CampaignState) -> Array[CampaignState.WorldEvent]:
	var pending: Array[CampaignState.WorldEvent] = []
	var ordered: Array[CampaignState.WorldEvent] = []
	for event: CampaignState.WorldEvent in state.events:
		if event.status == "pending" and event.day == state.day:
			pending.append(event)
	pending.sort_custom(func(a: CampaignState.WorldEvent, b: CampaignState.WorldEvent) -> bool: return a.id < b.id)
	while not pending.is_empty():
		var selected: CampaignState.WorldEvent = null
		for event: CampaignState.WorldEvent in pending:
			var ready := true
			for other: CampaignState.WorldEvent in pending:
				ready = ready and other.id not in event.prerequisites
			if ready:
				selected = event
				break
		if selected == null:
			return [] # Caller validates graph before any mutation.
		ordered.append(selected)
		pending.erase(selected)
	return ordered
