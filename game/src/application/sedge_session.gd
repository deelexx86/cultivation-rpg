class_name SedgeSession
extends CampaignSession

func act(command: String) -> bool:
	if dirty: return false
	var candidate := StateCodec.clone(state)
	return commit(candidate, SedgeWorld.apply(candidate, command))

func depart(plan: Dictionary) -> bool:
	if dirty: return false
	var candidate := StateCodec.clone(state)
	return commit(candidate, SedgeWorld.depart(candidate, plan))

func checkpoint(pos: Vector3) -> bool:
	if dirty and not save(): return false
	var x := roundi(pos.x * 100.0)
	var z := roundi(pos.z * 100.0)
	if x == state.exploration.x and z == state.exploration.z: return true
	var candidate := StateCodec.clone(state)
	candidate.exploration.x = x
	candidate.exploration.z = z
	candidate.revision += 1
	return commit(candidate, "")
