class_name Simulation
extends RefCounted
## Commands run on an application-owned candidate, never on a scene.

static func preview(state: CampaignState, duration: int, cost: int = 1, milestone: String = "", soul_years: int = 100, body_years: int = 100, kind: String = "practice") -> Dictionary:
	var finish := state.day + duration
	var life_day := state.soul_expiry()
	if kind != "transfer_probe":
		life_day = mini(life_day, state.body_expiry())
	var reason := ""
	if duration <= 0 or duration > 1095728 or finish >= WorldCalendar.ordinal(3000):
		reason = "Invalid duration or outside P1 pre-endgame range"
	elif cost < 0 or cost > state.supplies:
		reason = "Insufficient supplies"
	elif state.running() != null:
		reason = "Another action is running"
	elif state.mode != "active" and not (kind == "transfer_probe" and state.mode == "body_dead"):
		reason = "No living actor"
	elif kind not in ["practice", "recovery", "transfer_probe", "travel_probe", "travel"] or soul_years < 100 or soul_years > 5000 or body_years <= 0 or body_years > 5000:
		reason = "Invalid method parameters"
	elif kind == "travel" and state.exploration.is_empty():
		reason = "No playable route in this campaign"
	elif not milestone.is_empty() and kind != "practice":
		reason = "Only the practice fixture can grant a milestone"
	var obligations: Array[String] = []
	for obligation: CampaignState.Obligation in state.obligations:
		if obligation.active and obligation.body == state.body().id:
			obligations.append(obligation.id)
	var result := {"fingerprint": state.fingerprint(), "revision": state.revision, "duration": duration, "cost": cost, "milestone": milestone, "soul_years": soul_years, "body_years": body_years, "kind": kind, "finish": finish, "soul_age_days": finish - state.soul.born, "body_age_days": finish - state.body().born if kind != "transfer_probe" else -1, "life_boundary": life_day, "fatal": finish >= life_day, "reason": reason, "known_obligations": obligations, "risk": "Prepared technical fixture; interruption possible. Personal promises can expire; hidden dates are not disclosed."}
	result["checksum"] = JSON.stringify(result).sha256_text()
	return result

static func confirm(state: CampaignState, plan: Dictionary, operation_id: String, accept_fatal: bool = false) -> String:
	if operation_id.is_empty():
		return "Operation ID required"
	var signature := JSON.stringify(plan).sha256_text()
	if state.receipts.has(operation_id):
		return "duplicate" if state.receipts[operation_id] == signature else "Operation ID reused with a different request"
	for key: String in ["duration", "cost", "soul_years", "body_years"]:
		if not plan.has(key) or not (plan[key] is int or plan[key] is float) or not is_finite(float(plan[key])) or float(plan[key]) != floor(float(plan[key])) or absf(float(plan[key])) > 1000000000:
			return "Invalid preview"
	for key: String in ["milestone", "kind"]:
		if not plan.has(key) or not plan[key] is String:
			return "Invalid preview"
	var current := preview(state, int(plan.duration), int(plan.cost), plan.milestone, int(plan.soul_years), int(plan.body_years), plan.kind)
	if JSON.stringify(current) != JSON.stringify(plan):
		return "Preview is stale or changed; preview and confirm again"
	if not current.reason.is_empty():
		return current.reason
	if current.fatal and not accept_fatal:
		return "Known life expiry requires separate confirmation"
	var action := CampaignState.Action.new()
	action.id = operation_id
	action.kind = plan.kind
	action.duration = int(plan.duration)
	action.cost = int(plan.cost)
	action.milestone = plan.milestone
	action.soul_years = int(plan.soul_years)
	action.body_years = int(plan.body_years)
	state.supplies -= action.cost
	state.spent += action.cost
	state.actions.append(action)
	state.receipts[operation_id] = signature
	state.record("confirmed:" + operation_id)
	state.revision += 1
	return ""

static func expire(state: CampaignState) -> void:
	if state.soul_expiry() <= state.day and state.mode != "ended":
		state.mode = "ended"
		state.end_reason = "soul_expired"
		state.record("soul_expired")
	if state.body().alive and state.body_expiry() <= state.day:
		state.body().alive = false
		state.body().died = state.day
		state.record("body_expired:" + state.body().id)
		if state.mode != "ended":
			state.mode = "body_dead"
		for obligation: CampaignState.Obligation in state.obligations:
			if obligation.active and obligation.body == state.body().id:
				obligation.active = false
				obligation.ended = state.day
				state.record("obligation_ended:" + obligation.id)
	var action := state.running()
	if action != null and (state.mode == "ended" or (state.mode == "body_dead" and action.kind != "transfer_probe")):
		action.status = "stopped"

static func apply_event(state: CampaignState, event: CampaignState.WorldEvent) -> void:
	var allowed := true
	for id: String in event.prerequisites:
		allowed = allowed and state.event(id).status == "applied"
	if not event.requires_flag.is_empty():
		allowed = allowed and state.flags.get(event.requires_flag, "") == event.requires_value
	if not event.requires_person.is_empty():
		allowed = allowed and state.person(event.requires_person).alive
	if event.kind == "death":
		allowed = allowed and state.person(event.target).alive
	event.status = "applied" if allowed else "cancelled"
	event.resolved = state.day
	state.record(event.status + ":" + event.id)
	if not allowed:
		return
	match event.kind:
		"death":
			state.person(event.target).alive = false
			state.person(event.target).died = state.day
			for obligation: CampaignState.Obligation in state.obligations:
				if obligation.person == event.target and obligation.active:
					obligation.active = false
					obligation.ended = state.day
					state.record("obligation_ended:" + obligation.id)
		"flag":
			state.flags[event.target] = event.value
		"chance_flag":
			# Small operation-keyed reproducibility fixture, not a balance formula.
			if not state.outcomes.has(event.id):
				state.outcomes[event.id] = (state.seed_value + ":sha256-keyed-v1:" + event.id).sha256_text().left(8).hex_to_int() % 2
			state.flags[event.target] = str(state.outcomes[event.id])
	var action := state.running()
	if event.interrupt and action != null:
		action.status = "paused"
		action.blocker = event.id
		state.known[event.id] = state.day # Only an explicit communication channel interrupts.
		state.record("interrupted:" + action.id + ":" + event.id)

static func complete(state: CampaignState, action: CampaignState.Action) -> void:
	if action.status != "running" or action.progress != action.duration:
		return
	if not action.milestone.is_empty():
		state.body().milestone = action.milestone
		state.body().limit_years = maxi(state.body().limit_years, action.body_years)
		if not state.soul.first_milestones.has(action.milestone):
			state.soul.first_milestones[action.milestone] = state.day
			state.soul.limit_years = maxi(state.soul.limit_years, action.soul_years)
			state.record("first_milestone:" + action.milestone)
	if action.kind == "travel":
		SedgeWorld.arrive(state)
	action.status = "complete"
	state.record("completed:" + action.id)

static func next_boundary(state: CampaignState, budget: int) -> int:
	var action := state.running()
	if action == null:
		return state.day
	var boundary := mini(state.day + budget, state.day + action.duration - action.progress)
	boundary = mini(boundary, state.soul_expiry())
	if state.body().alive:
		boundary = mini(boundary, state.body_expiry())
	for event: CampaignState.WorldEvent in state.events:
		if event.status == "pending":
			boundary = mini(boundary, event.day)
	return boundary

static func step(state: CampaignState, budget: int) -> String:
	if budget < 0 or budget > 1095728:
		return "Invalid calendar budget"
	if not EventGraph.problems(state).is_empty():
		return "; ".join(EventGraph.problems(state))
	var action := state.running()
	if action == null:
		return "No running action"
	var boundary := next_boundary(state, budget)
	var elapsed := boundary - state.day
	if elapsed < 0:
		return "Stale calendar boundary"
	action.progress += elapsed
	if action.kind == "practice":
		state.body().practice_days += elapsed
	state.day = boundary
	expire(state)
	for event: CampaignState.WorldEvent in EventGraph.due(state):
		apply_event(state, event)
	complete(state, action)
	state.revision += 1
	return ""

static func resume(state: CampaignState, id: String, operation_id: String) -> String:
	var signature := "resume:" + id
	if state.receipts.has(operation_id):
		return "duplicate" if state.receipts[operation_id] == signature else "Operation ID reused"
	var action := state.action(id)
	if operation_id.is_empty() or action == null or action.status != "paused" or state.running() != null or state.mode != "active":
		return "Cannot resume this action"
	action.blocker = ""
	action.status = "running"
	state.receipts[operation_id] = signature
	state.record("resumed:" + id)
	state.revision += 1
	return ""

static func intervene(state: CampaignState, flag: String, value: String, operation_id: String) -> String:
	var signature := "intervene:" + flag + ":" + value
	if state.receipts.has(operation_id):
		return "duplicate" if state.receipts[operation_id] == signature else "Operation ID reused"
	if operation_id.is_empty() or flag.is_empty() or state.mode != "active":
		return "Invalid intervention"
	state.flags[flag] = value
	state.receipts[operation_id] = signature
	state.record(signature)
	state.revision += 1
	return ""
