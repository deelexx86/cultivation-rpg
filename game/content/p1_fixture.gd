class_name P1Fixture
extends RefCounted
## Authored technical data. These values are not progression balance or examples/.

static func event(id: String, day: int, kind: String, target: String = "", value: String = "") -> CampaignState.WorldEvent:
	var result := CampaignState.WorldEvent.new()
	result.id = id
	result.day = day
	result.kind = kind
	result.target = target
	result.value = value
	return result

static func fresh(id: String = "p1-demo") -> CampaignState:
	var state := CampaignState.new()
	state.campaign_id = id
	return state

static func demo(id: String = "p1-demo") -> CampaignState:
	var state := fresh(id)
	var person := CampaignState.Person.new()
	person.id = "fixture.elder"
	state.people.append(person)
	var obligation := CampaignState.Obligation.new()
	obligation.id = "fixture.personal-promise"
	obligation.person = person.id
	state.obligations.append(obligation)
	state.flags["region.a.bridge"] = "intact"
	var death := event("elder.death", WorldCalendar.ordinal(9), "death", person.id)
	var changed := event("market.closed", death.day, "flag", "region.a.market", "closed")
	changed.prerequisites = [death.id]
	var news := event("messenger.arrived", death.day, "call")
	news.prerequisites = [changed.id]
	news.interrupt = true
	var obsolete := event("elder.later-death", WorldCalendar.ordinal(12), "death", person.id)
	var repair := event("bridge.repair", WorldCalendar.ordinal(18), "flag", "region.a.bridge", "repaired")
	repair.requires_flag = "region.a.bridge"
	repair.requires_value = "intact"
	state.events.assign([news, obsolete, repair, changed, death]) # Deliberately unsorted.
	return state
