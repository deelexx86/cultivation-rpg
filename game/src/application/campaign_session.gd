class_name CampaignSession
extends RefCounted
## One synchronous writer. Every mutation checkpoint is durable before continuing.
var state: CampaignState
var store: SnapshotStore
var error: String = ""
var dirty: bool = false

func _init(initial: CampaignState, storage: SnapshotStore) -> void:
	state = initial
	store = storage

func save() -> bool:
	if not store.save(state):
		error = store.last_error
		dirty = true
		return false
	dirty = false
	error = ""
	return true

func reload() -> bool:
	if dirty:
		error = "Unsaved state must be retried before loading"
		return false
	var result := store.load_current()
	if result.error != "":
		error = result.error
		return false
	state = result.state
	error = ""
	return true

func commit(candidate: CampaignState, result: String) -> bool:
	if result == "duplicate":
		error = ""
		return true
	if result != "":
		error = result
		return false
	var problems := StateCodec.problems(candidate)
	if not problems.is_empty():
		error = "; ".join(problems)
		return false
	state = candidate
	return save()

func confirm(plan: Dictionary, operation_id: String, accept_fatal: bool = false) -> bool:
	if dirty:
		error = "Retry failed save before further commands"
		return false
	var candidate := StateCodec.clone(state)
	return commit(candidate, Simulation.confirm(candidate, plan, operation_id, accept_fatal))

func advance(days: int) -> bool:
	if dirty:
		error = "Retry failed save before calendar advancement"
		return false
	if days < 0 or days > 1095728:
		error = "Invalid calendar budget"
		return false
	var target := state.day + days
	while state.running() != null:
		var before := state.day
		var candidate := StateCodec.clone(state)
		if not commit(candidate, Simulation.step(candidate, target - state.day)):
			return false
		if state.day >= target or state.running() == null:
			break
		if state.day == before and Simulation.next_boundary(state, target - state.day) == state.day:
			error = "Calendar made no progress"
			return false
	return true

func resume(action_id: String, operation_id: String) -> bool:
	if dirty:
		error = "Retry failed save before resuming"
		return false
	var candidate := StateCodec.clone(state)
	return commit(candidate, Simulation.resume(candidate, action_id, operation_id))

func intervene(flag: String, value: String, operation_id: String) -> bool:
	if dirty:
		error = "Retry failed save before intervention"
		return false
	var candidate := StateCodec.clone(state)
	return commit(candidate, Simulation.intervene(candidate, flag, value, operation_id))
