extends SceneTree

var failures: PackedStringArray = []
var checks: int = 0
var base: String

func _initialize() -> void:
	base = "user://p1-tests/run-" + str(Time.get_ticks_usec())
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)

func session(id: String, state: CampaignState = null) -> CampaignSession:
	var initial := state if state != null else P1Fixture.fresh(id)
	initial.campaign_id = id
	return CampaignSession.new(initial, SnapshotStore.new(base, id))

func begin(value: CampaignSession, days: int, id: String = "practice", milestone: String = "", soul_years: int = 100, body_years: int = 100, kind: String = "practice", fatal: bool = false) -> bool:
	return value.confirm(Simulation.preview(value.state, days, 1, milestone, soul_years, body_years, kind), id, fatal)

func _run() -> void:
	calendar_tests()
	preview_tests()
	chronology_tests()
	life_tests()
	causality_tests()
	save_tests()
	if failures.is_empty():
		print("P1_TEST_PASS checks=", checks, " calendar preview chronology life causality save")
		quit(0)
	else:
		for failure: String in failures:
			push_error(failure)
		print("P1_TEST_FAIL failures=", failures.size(), " checks=", checks)
		quit(1)

func calendar_tests() -> void:
	check(WorldCalendar.leap(0) and WorldCalendar.leap(400) and not WorldCalendar.leap(100), "AT-SPACE-01 Gregorian century rules")
	check(WorldCalendar.ordinal(0, 2, 29) == 59 and WorldCalendar.ordinal(1) == 366, "AT-SPACE-01 year zero is leap")
	check(WorldCalendar.date(365) == Vector3i(0, 12, 31) and WorldCalendar.date(366) == Vector3i(1, 1, 1), "AT-SPACE-01 year boundary")
	check(WorldCalendar.date(WorldCalendar.ordinal(1, 2, 28) + 1) == Vector3i(1, 3, 1), "AT-SPACE-01 common February")
	check(WorldCalendar.add_years(59, 1) == WorldCalendar.ordinal(1, 2, 28), "OPEN-01 February anniversary clamping")
	check(WorldCalendar.add_years(59, 4) == WorldCalendar.ordinal(4, 2, 29), "OPEN-01 original leap anniversary retained")
	check(WorldCalendar.age_years(59, WorldCalendar.ordinal(1, 2, 27)) == 0 and WorldCalendar.age_years(59, WorldCalendar.ordinal(1, 2, 28)) == 1, "OPEN-01 age anniversary")
	check(WorldCalendar.weekday(0) == 5 and WorldCalendar.weekday(7) == 5 and WorldCalendar.weekday(-1) == 4, "OPEN-01 Saturday anchor and seven-day week")
	var roundtrip := true
	# Every day of a complete Gregorian cycle, including negative birth ordinals.
	for day: int in range(-146097, 146098):
		var date := WorldCalendar.date(day)
		if WorldCalendar.ordinal(date.x, date.y, date.z) != day:
			roundtrip = false
			break
	check(roundtrip, "AT-SPACE-01 exhaustive signed 800-year date roundtrip")
	for year: int in [0, 4, 99, 100, 399, 400, 2999]:
		check(WorldCalendar.add_years(WorldCalendar.ordinal(year), 1) - WorldCalendar.ordinal(year) == (366 if WorldCalendar.leap(year) else 365), "Calendar year length " + str(year))
	print("P1_GROUP_PASS calendar")

func preview_tests() -> void:
	var value := session("preview", P1Fixture.demo())
	var before := value.state.fingerprint()
	var plan: Dictionary
	for repeat: int in range(20):
		plan = Simulation.preview(value.state, 100)
	check(value.state.fingerprint() == before, "AT-TIME-01/07 preview has no date, resource, RNG or knowledge mutation")
	check(not JSON.stringify(plan).contains("elder.death") and plan.known_obligations.size() == 1, "AT-TIME-07 preview does not expose hidden death date")
	check(value.intervene("preparation", "changed", "prepare"), "Intervention succeeds")
	var stale_before := value.state.fingerprint()
	check(not value.confirm(plan, "stale") and value.state.fingerprint() == stale_before, "Stale preview rejected without costs")
	plan = Simulation.preview(value.state, 100)
	var changed := plan.duplicate(true)
	changed.cost = 0
	check(not value.confirm(changed, "tampered"), "Changed preview requires renewed forecast")
	check(value.confirm(plan, "valid"), "Current preview confirmed: " + value.error)
	var spent := value.state.spent
	check(value.confirm(plan, "valid") and value.state.spent == spent, "Repeated confirmation is idempotent")
	check(not value.confirm(changed, "valid") and value.state.spent == spent, "Reused operation ID with changed payload rejected")
	check(value.reload() and value.confirm(plan, "valid") and value.state.spent == spent, "Confirmation receipt survives reload")
	print("P1_GROUP_PASS preview")

func chronology_tests() -> void:
	var value := session("chronology", P1Fixture.demo())
	check(begin(value, WorldCalendar.ordinal(20)), "Demo confirmation")
	check(value.advance(WorldCalendar.ordinal(20)), "Demo reaches interruption: " + value.error)
	check(value.state.day == WorldCalendar.ordinal(9) and value.state.action("practice").progress == value.state.day, "AT-TIME-04 interruption at actual date")
	check(not value.state.people[0].alive and value.state.people[0].died == value.state.day and not value.state.obligations[0].active and value.state.obligations[0].ended == value.state.day, "NPC death and personal obligation cease on same date")
	check(value.state.flags.get("region.a.market") == "closed" and value.state.action("practice").status == "paused", "Causal world consequence before interruption")
	var interrupted := value.state.fingerprint()
	check(value.reload() and value.state.fingerprint() == interrupted, "AT-SAVE-03 exact unresolved interruption restored")
	check(value.advance(100) and value.state.fingerprint() == interrupted, "Unresolved interruption does not advance")
	check(value.resume("practice", "resume-1") and value.resume("practice", "resume-1"), "Resume delivery idempotent")
	check(value.advance(WorldCalendar.ordinal(20)), "Resume finishes remaining days: " + value.error)
	check(value.state.day == WorldCalendar.ordinal(20) and value.state.action("practice").status == "complete" and value.state.spent == 1, "AT-SAVE-03 no repeated startup cost/progress")
	check(value.state.event("elder.later-death").status == "cancelled", "Already-dead NPC cannot die again")
	var completed := value.state.fingerprint()
	check(value.advance(10) and value.reload() and value.state.fingerprint() == completed, "Repeated advance/load of completion has no effects")
	# Exact GDD controlled late-stage dates, without implementing late-stage content.
	var state := P1Fixture.fresh()
	state.day = WorldCalendar.ordinal(312)
	state.soul.limit_years = 1000
	state.body().limit_years = 1000
	var call := P1Fixture.event("sect.call", WorldCalendar.ordinal(346), "call")
	call.interrupt = true
	state.events.append(call)
	var late := session("late-interruption", state)
	check(begin(late, WorldCalendar.ordinal(402) - state.day), "AT-TIME-06 prepared 90-year practice")
	check(late.advance(WorldCalendar.ordinal(402) - state.day) and late.state.day == WorldCalendar.ordinal(346), "AT-TIME-06 stop at 346")
	check(begin(late, WorldCalendar.ordinal(354) - late.state.day, "recovery", "", 100, 1000, "recovery") and late.advance(4000), "AT-TIME-06 eight-year recovery")
	check(late.state.day == WorldCalendar.ordinal(354), "Recovery finishes at 354")
	check(late.resume("practice", "after-recovery") and late.advance(50000), "Resume late practice")
	check(late.state.day == WorldCalendar.ordinal(410) and late.state.actions[0].progress == late.state.actions[0].duration and late.state.spent == 2, "AT-TIME-06 98 elapsed years, 90 practice, eight recovery")
	# Background death does not interrupt without a communication channel.
	state = P1Fixture.demo()
	state.day = WorldCalendar.ordinal(4)
	state.events.clear()
	state.events.append(P1Fixture.event("death.15", WorldCalendar.ordinal(15), "death", state.people[0].id))
	var background := session("background", state)
	check(begin(background, WorldCalendar.ordinal(24) - state.day) and background.advance(10000), "Background death inside long action")
	check(background.state.day == WorldCalendar.ordinal(24) and background.state.people[0].died == WorldCalendar.ordinal(15) and background.state.known.is_empty(), "AT-TIME-04 hidden news is not revealed by world change")
	# An interruption on the completion date must not silently grant the milestone.
	state = P1Fixture.fresh()
	call = P1Fixture.event("last-day.call", 10, "call")
	call.interrupt = true
	state.events.append(call)
	var same_day := session("same-day-completion", state)
	check(begin(same_day, 10, "practice", "first", 150, 150) and same_day.advance(10), "Same-day action completion/interruption")
	check(same_day.state.actions[0].progress == 10 and same_day.state.actions[0].status == "paused" and not same_day.state.soul.first_milestones.has("first"), "World choice precedes milestone completion")
	check(same_day.reload() and same_day.resume("practice", "resume") and same_day.advance(0) and same_day.state.soul.first_milestones.has("first") and same_day.state.day == 10, "Zero remaining days resolves once after explicit continuation")
	# Route/encounter state is only a data fixture; no route UI, movement or combat.
	state = P1Fixture.fresh()
	call = P1Fixture.event("route.encounter", 4, "chance_flag", "encounter.outcome")
	call.interrupt = true
	state.events.append(call)
	var route := session("route-probe", state)
	check(begin(route, 10, "route", "", 100, 100, "travel_probe") and route.advance(10) and route.reload(), "AT-SPACE-02/03 encounter checkpoint fixture")
	check(route.state.day == 4 and route.state.actions[0].progress == 4 and route.state.outcomes.size() == 1, "Route retains date, paid start, section progress and resolved outcome")
	var outcome := route.state.outcomes.duplicate()
	check(route.resume("route", "encounter-done") and route.advance(10) and route.state.day == 10 and route.state.outcomes == outcome and route.state.spent == 1, "AT-SPACE-02/03 remaining route resumes without reroll or re-payment")
	print("P1_GROUP_PASS chronology")

func life_tests() -> void:
	for actor: String in ["soul", "body"]:
		for offset: int in [-1, 0, 1]:
			var state := P1Fixture.fresh()
			if actor == "soul":
				state.body().limit_years = 500
			var expiry := state.soul_expiry() if actor == "soul" else state.body_expiry()
			state.day = expiry - 10
			var value := session("expiry-%s-%d" % [actor, offset], state)
			var plan := Simulation.preview(state, 10 + offset, 1, "new", 200, 200)
			check(plan.fatal == (offset >= 0), "TIME-08 preview " + actor + str(offset))
			if offset >= 0:
				var before := state.fingerprint()
				check(not value.confirm(plan, "boundary") and value.state.fingerprint() == before, "AT-SAVE-08 separate known-fatal confirmation")
			check(value.confirm(plan, "boundary", true) and value.advance(30), "Life boundary execution " + actor + str(offset) + value.error)
			if offset < 0:
				check(value.state.mode == "active" and value.state.soul.first_milestones.has("new"), "Positive life margin permits breakthrough")
			else:
				check(value.state.day == expiry and not value.state.soul.first_milestones.has("new") and value.state.mode == ("ended" if actor == "soul" else "body_dead"), "AT-TIME-02/03 expiry before reward " + actor)
			check(value.reload(), "Death/milestone durably saved " + value.error)
	var state := P1Fixture.fresh()
	state.day = WorldCalendar.ordinal(445)
	state.soul.limit_years = 1030
	state.soul.first_milestones = {"foundation": WorldCalendar.ordinal(50), "core": WorldCalendar.ordinal(200), "soul.middle": WorldCalendar.ordinal(400)}
	state.soul.mastery = {"mastered": 100, "partial": 30}
	state.body().alive = false
	state.body().died = WorldCalendar.ordinal(440)
	state.body().limit_years = 1000
	var young := CampaignState.Body.new()
	young.id = "body.2"
	young.born = WorldCalendar.ordinal(427)
	state.bodies.append(young)
	state.active_body = 1
	state.flags["cache"] = "unchanged"
	var value := session("two-bodies", state)
	check(WorldCalendar.age_years(0, state.soul_expiry()) - WorldCalendar.age_years(0, state.day) == 585 and WorldCalendar.age_years(young.born, state.day) == 18, "AT-SOUL-01 two independent ages/limits")
	for row: Array in [["foundation", 500, 200], ["core", 550, 600], ["soul.middle", 585, 1030]]:
		var milestone: String = row[0]
		check(begin(value, WorldCalendar.ordinal(row[1]) - value.state.day, "repeat-" + milestone, milestone, row[2], row[2]) and value.advance(100000), "Repeat prepared milestone " + milestone + value.error)
	check(value.state.soul.limit_years == 1030 and value.state.body().limit_years == 1030, "AT-SOUL-02 repeated milestones extend body only")
	check(value.state.day == WorldCalendar.ordinal(585), "AT-SOUL-02 former peak restored at 585")
	check(begin(value, WorldCalendar.ordinal(695) - value.state.day, "first-later", "soul.late", 1160, 1160) and value.advance(100000) and value.state.soul.limit_years == 1160 and value.state.day == WorldCalendar.ordinal(695), "AT-SOUL-02 first higher milestone at 695 raises maximum soul limit")
	check(value.reload() and value.state.soul.mastery == state.soul.mastery and value.state.flags["cache"] == "unchanged" and value.state.bodies.size() == 2, "AT-SOUL-04/05 prepared bodies preserve soul mastery/world")
	state = P1Fixture.fresh()
	state.day = WorldCalendar.ordinal(97)
	state.body().alive = false
	state.body().died = state.day
	state.mode = "body_dead"
	value = session("transfer-expiry", state)
	check(begin(value, WorldCalendar.ordinal(102) - state.day, "transfer", "", 100, 100, "transfer_probe", true) and value.advance(3000), "AT-SOUL-03 no-body transfer clock probe")
	check(value.state.day == WorldCalendar.ordinal(100) and value.state.mode == "ended" and value.state.bodies.size() == 1 and value.state.soul.limit_years == 100 and value.state.soul.mastery.is_empty(), "AT-SOUL-03/06 expired soul receives no body/bonus")
	state = P1Fixture.fresh()
	state.body().born = 0
	state.day = WorldCalendar.ordinal(100) - 1
	value = session("simultaneous-expiry", state)
	check(begin(value, 1, "end", "new", 200, 200, "practice", true) and value.advance(1) and value.state.mode == "ended" and not value.state.body().alive and value.state.soul.first_milestones.is_empty(), "Simultaneous soul/body expiry ends campaign before same-day milestone")
	print("P1_GROUP_PASS life")

func world_history(state: CampaignState) -> String:
	return JSON.stringify({"flags": state.flags, "outcomes": state.outcomes, "events": state.encode().events, "people": state.encode().people, "obligations": state.encode().obligations})

func causality_tests() -> void:
	var source := P1Fixture.demo()
	for event: CampaignState.WorldEvent in source.events:
		event.interrupt = false
	var random_event := P1Fixture.event("find", WorldCalendar.ordinal(8), "chance_flag", "region.a.find")
	source.events.append(random_event)
	var long := session("long", StateCodec.clone(source))
	var split := session("split", StateCodec.clone(source))
	check(begin(long, WorldCalendar.ordinal(20)) and long.advance(WorldCalendar.ordinal(20)), "Twenty-year wait")
	for year: int in [5, 10, 15, 20]:
		check(begin(split, WorldCalendar.ordinal(year) - split.state.day, "part-" + str(year)) and split.advance(10000) and split.reload(), "Split wait " + str(year))
	check(world_history(long.state) == world_history(split.state), "AT-TIME-05/AT-SPACE-03 same world and outcome with four waits and reloads")
	var history := long.state.history.filter(func(entry: String) -> bool: return "applied:" in entry or "cancelled:" in entry or "obligation_ended:" in entry)
	var split_history := split.state.history.filter(func(entry: String) -> bool: return "applied:" in entry or "cancelled:" in entry or "obligation_ended:" in entry)
	check(history == split_history, "Identical chronological world history across split waits")
	var expanded := StateCodec.clone(source)
	expanded.events.append(P1Fixture.event("independent.region-c", 1, "flag", "region.c.fact", "changed"))
	var unrelated := session("unrelated-region", expanded)
	check(begin(unrelated, WorldCalendar.ordinal(20)) and unrelated.advance(10000), "Independent region fixture executes")
	var original_flags := unrelated.state.flags.duplicate()
	original_flags.erase("region.c.fact")
	check(original_flags == long.state.flags and unrelated.state.outcomes == long.state.outcomes, "AT-SPACE-05 independent region cannot shift old outcomes/facts")
	# One global calendar; B is a data-only fixture with no loaded scene.
	source = P1Fixture.fresh()
	var send := P1Fixture.event("z.a.send", 5, "flag", "region.b.message", "arrived")
	var receive := P1Fixture.event("a.b.receive", 5, "flag", "region.b.state", "changed")
	receive.prerequisites = [send.id]
	receive.requires_flag = "region.b.message"
	receive.requires_value = "arrived"
	source.events.assign([receive, send])
	long = session("region-ab", StateCodec.clone(source))
	source.events.reverse()
	split = session("region-ba", StateCodec.clone(source))
	check(begin(long, 10) and long.advance(10) and begin(split, 10) and split.advance(3) and split.advance(7), "Two-region causal fixture executes")
	check(long.state.flags == split.state.flags and long.state.flags.get("region.b.state") == "changed" and long.state.history == split.state.history, "AT-SPACE-04/05 global actual date, causal order independent of region/array order")
	var invalid := StateCodec.clone(source)
	invalid.events[1].prerequisites.clear()
	check(not StateCodec.problems(invalid).is_empty(), "Same-day conflicting read/write requires explicit dependency")
	invalid = StateCodec.clone(source)
	invalid.events[0].prerequisites = [invalid.events[1].id]
	check(not StateCodec.problems(invalid).is_empty(), "Same-day event cycle diagnosed")
	invalid = StateCodec.clone(source)
	invalid.events[0].prerequisites = ["missing"]
	check(not StateCodec.problems(invalid).is_empty(), "Missing causal prerequisite rejected")
	var changed := session("cancel", P1Fixture.demo())
	check(changed.intervene("region.a.bridge", "destroyed", "destroy") and begin(changed, WorldCalendar.ordinal(20)) and changed.advance(10000), "Intervention and interruption")
	check(changed.resume("practice", "go") and changed.advance(10000), "Intervention continuation")
	check(changed.state.event("bridge.repair").status == "cancelled" and changed.state.flags["region.a.bridge"] == "destroyed", "AT-SPACE-06 invalid future repair cancelled")
	# Change the causal premise before a prepared death; its downstream event cancels.
	source = P1Fixture.demo()
	source.events[4].requires_flag = "illness"
	source.events[4].requires_value = "untreated"
	source.flags["illness"] = "untreated"
	changed = session("saved-npc", source)
	check(changed.intervene("illness", "treated", "treat") and begin(changed, 4000) and changed.advance(4000), "Change future death premise")
	check(changed.state.event("elder.death").status == "cancelled" and changed.state.event("market.closed").status == "cancelled" and changed.state.people[0].alive and changed.state.obligations[0].active, "AT-SPACE-06 cancelled cause cancels dependent future")
	print("P1_GROUP_PASS causality")

func save_tests() -> void:
	var value := session("save-partial", P1Fixture.demo())
	check(begin(value, 100) and value.advance(40), "Partial practice persisted")
	var before := value.state.fingerprint()
	for repeat: int in range(4):
		check(value.reload() and value.state.fingerprint() == before, "AT-SAVE-01/03 repeated exact load " + str(repeat))
	check(value.state.actions[0].progress == 40 and value.state.spent == 1 and value.state.supplies == 19, "Partial progress, paid cost and remaining inventory agree")
	check(value.advance(100) and value.state.day == 100 and value.state.body().practice_days == 100, "Partial continuation preserves progress")
	# Main corruption restores prior consistent checkpoint and repairs the primary.
	var previous := value.store.read_file(value.store.path("previous.json"))
	value.store.write_file(value.store.path("current.json"), "{broken")
	check(value.reload() and value.state.fingerprint() == previous.state.fingerprint(), "AT-SAVE-07 recover previous snapshot after main corruption")
	before = value.state.fingerprint()
	check(value.reload() and value.state.fingerprint() == before and value.save(), "Recovery repairs primary and can save again")
	for stage: String in SnapshotStore.STAGES:
		var item := session("fault-" + stage)
		check(begin(item, 20) and item.advance(5), "Fault setup " + stage)
		var old := item.state.fingerprint()
		item.store.fail_at = stage
		check(not item.advance(5) and item.dirty, "Write failure reported and memory retained " + stage)
		var updated := item.state.fingerprint()
		check(not item.advance(5) and not item.reload(), "Failed save blocks further simulation/reload " + stage)
		var recovered := SnapshotStore.new(base, item.state.campaign_id).load_current()
		check(recovered.error == "" and recovered.state.fingerprint() == (updated if stage == "after_main_replace" else old), "AT-SAVE-07 coherent checkpoint at " + stage)
		item.store.fail_at = ""
		check(item.save() and not item.dirty, "Retry failed checkpoint " + stage + item.error)
	# Integrity and semantic corruption are independent checks.
	var state := P1Fixture.fresh("schema")
	var store := SnapshotStore.new(base, state.campaign_id)
	check(store.save(state), "Schema setup")
	var data := state.encode()
	for invalid: Variant in [-1, 1.5, "3", null]:
		data.day = invalid
		check(StateCodec.decode(data) == null, "Invalid day rejected " + str(invalid))
	data = state.encode()
	data.actions.append({})
	check(StateCodec.decode(data) == null, "Incomplete action schema rejected")
	data = state.encode()
	data.supplies = -1
	check(StateCodec.decode(data) == null, "Negative resources rejected")
	var invalid_envelope: Dictionary = JSON.parse_string(SnapshotStore.pack(state, 2))
	invalid_envelope.payload = JSON.stringify(data)
	invalid_envelope.checksum = SnapshotStore.digest(invalid_envelope.header, invalid_envelope.payload)
	store.write_file(store.path("writing.tmp"), JSON.stringify(invalid_envelope))
	check(store.read_file(store.path("writing.tmp")).error == "Snapshot state invariant violation", "Valid checksum cannot bypass state invariants")
	var parsed: Dictionary = JSON.parse_string(SnapshotStore.pack(state, 2))
	parsed.header.schema = 2
	parsed.checksum = SnapshotStore.digest(parsed.header, parsed.payload)
	store.write_file(store.path("current.json"), JSON.stringify(parsed))
	check(store.load_current().get("incompatible", false), "Unknown future schema refused without fallback")
	store.write_file(store.path("current.json"), SnapshotStore.pack(state, 2))
	parsed = JSON.parse_string(SnapshotStore.pack(state, 2))
	parsed.payload = parsed.payload.replace('"supplies":20', '"supplies":21')
	store.write_file(store.path("writing.tmp"), JSON.stringify(parsed))
	check(store.read_file(store.path("writing.tmp")).error == "Snapshot checksum mismatch", "Payload checksum detects changed costs")
	# Separate campaigns and stale writers.
	var first := session("campaign-a")
	var second := session("campaign-b")
	check(begin(first, 10) and first.advance(3) and begin(second, 20) and second.advance(7) and first.reload() and first.state.day == 3 and second.reload() and second.state.day == 7, "AT-SAVE-04 separate current lines, no offline time advance")
	var stale := SnapshotStore.new(base, "campaign-a")
	var old_load := stale.load_current()
	check(first.advance(2) and not stale.save(old_load.state), "Older writer cannot overwrite newer snapshot")
	check(not SnapshotStore.new(base, "../escape").save(state), "Campaign ID cannot escape slot directory")
	# Valid checksum alone cannot make a semantically invalid snapshot loadable.
	data = state.encode()
	data.soul.limit_years = 1000000000
	check(StateCodec.decode(data) == null, "Malformed life limit rejected before calendar arithmetic")
	data = state.encode()
	data.obligations.append({"id": "bad", "person": "absent", "body": "body.1", "active": true, "ended": -1})
	check(StateCodec.decode(data) == null, "Dangling participant rejected without runtime error")
	var healthy := session("backup-health")
	check(begin(healthy, 10) and healthy.advance(3), "Healthy primary setup")
	healthy.store.write_file(healthy.store.path("previous.json"), "broken")
	check(healthy.reload() and healthy.state.day == 3, "Corrupt backup cannot replace healthy primary")
	healthy.store.write_file(healthy.store.path("current.json"), "broken")
	check(not healthy.reload() and healthy.state.day == 3, "Both corrupt snapshots fail without resetting in-memory campaign")
	var missing := SnapshotStore.new(base, "only-backup")
	state = P1Fixture.fresh("only-backup")
	check(missing.save(state), "Missing primary setup")
	check(DirAccess.rename_absolute(missing.path("current.json"), missing.path("previous.json")) == OK and missing.load_current().error == "", "Missing main recovers previous valid state")
	var wrong_id := SnapshotStore.new(base, "wrong-slot")
	check(DirAccess.make_dir_recursive_absolute(wrong_id.directory) == OK and wrong_id.write_file(wrong_id.path("current.json"), SnapshotStore.pack(state, 1)), "Wrong slot setup")
	check(wrong_id.load_current().error != "", "Campaign snapshot cannot be loaded into another slot")
	# A real filesystem failure, separate from fault injection.
	var blocked_base := ProjectSettings.globalize_path(base).path_join("not-a-directory")
	var block_file := FileAccess.open(blocked_base, FileAccess.WRITE)
	block_file.store_string("occupied")
	block_file.close()
	check(not SnapshotStore.new(blocked_base, "blocked").save(P1Fixture.fresh("blocked")), "Actual filesystem create failure reported")
	print("P1_GROUP_PASS save")
