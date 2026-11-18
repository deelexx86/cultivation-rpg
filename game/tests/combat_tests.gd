extends SceneTree

const H := P4Content.HERO
const Y := P4Content.YOUNG
const E := P4Content.HORNED
const AIR := P4Content.AIR
var space := CombatSpace.new()
var checks := 0
var failures := 0

class WallSpace extends CombatSpace:
	func obstacle_fraction(from: Vector3, to: Vector3) -> float:
		if minf(from.z, to.z) <= -1 and maxf(from.z, to.z) >= -1 and absf(to.z - from.z) > 0.001:
			return absf((from.z + 1) / (to.z - from.z))
		return INF

	func blocked(from: Vector3, to: Vector3) -> bool:
		return obstacle_fraction(from, to) != INF

	func fits(id: String, at: Vector3) -> bool:
		return super.fits(id, at) and at.distance_to(Vector3(1, 0, 0)) > 0.45

func _initialize() -> void:
	clock_and_flow()
	presentation_clock()
	commands()
	forewarning()
	space_and_protection()
	consequences()
	restore()
	print("P4_RULE_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(int(failures != 0))

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func fresh(rank: String = "qi") -> CampaignState:
	return CombatState.fresh("test", rank)

func actor(s: CampaignState, id: String = H) -> Dictionary:
	return s.combat.actors[id]

func place(s: CampaignState, id: String, at: Vector3) -> void:
	actor(s,id).pos = CombatState.pack(at)

func advance(s: CampaignState, ticks: int, dir: Vector3 = Vector3.ZERO, geometry: CombatSpace = space) -> void:
	for i in ticks:
		CombatWorld.advance(s, geometry, dir)

func presentation_clock() -> void:
	var motion := CombatMotion.new()
	motion.reset(0, 0)
	motion.capture(H, Vector3.ZERO)
	motion.advance_clock(1, 0)
	motion.capture(H, Vector3.RIGHT)
	motion.advance_clock(1, 1)
	expect(is_equal_approx(motion.pose(H, motion.lookback(0.5)).x, 0.125), "Interpolate over the entire slow combat interval")
	motion.advance_clock(1, 2)
	var before_switch := motion.pose(H, motion.lookback(1.0))
	# Switch off R with two units of accumulated credit. The next host tick
	# crosses a combat boundary and still has two units left.
	motion.advance_clock(2, 2)
	motion.capture(H, Vector3.RIGHT * 2)
	expect(motion.pose(H, motion.lookback(0.0)) == before_switch, "Changing pace with residual credit preserves visual continuity")
	expect(is_equal_approx(motion.pose(H, motion.lookback(0.5)).x, 1.0), "Blend only between completed poses across a rate change")
	motion.capture(H, Vector3.RIGHT * 6, 0.0, true)
	expect(motion.pose(H, motion.lookback(0.75)).x == 6.0, "Blink presents the destination without a swept visual path")
	motion.reset(90, 3)
	motion.capture(H, Vector3.RIGHT * 11)
	expect(motion.pose(H, motion.lookback(0.9)).x == 11.0, "Restored world with residual credit starts at the saved pose")

func clock_and_flow() -> void:
	var normal := fresh("core")
	var slow := fresh("core")
	for s: CampaignState in [normal, slow]:
		place(s, H, Vector3(0, 0, -4.1))
		place(s, AIR, Vector3(21, 5, -20))
		actor(s).qi = 40000
	CombatWorld.toggle_perception(slow)
	advance(normal, 20, Vector3.RIGHT)
	advance(slow, 80, Vector3.RIGHT)
	expect(slow.combat.tick == 20 and normal.combat.tick == 20, "One 60 Hz world clock at 1× and 0.25×")
	expect(actor(normal).pos == actor(slow).pos and actor(normal,Y).pos == actor(slow,Y).pos, "Hero and enemy travel exactly the same per world tick")
	expect(actor(normal).qi - actor(slow).qi == 20 * 42, "Own perception upkeep uses the same clock")
	var junior := fresh()
	actor(junior).qi = 1000
	advance(junior, 100)
	expect(actor(junior).qi == 1000 and junior.day == 0, "Low rank no passive refill during idle/retreat")
	actor(junior).hp = 65
	actor(junior).injury = true
	CombatWorld.toggle_meditation(junior)
	advance(junior, 60)
	expect(actor(junior).qi == 19600 and actor(junior).hp == 65 and actor(junior).injury and junior.day == 0 and junior.combat.wards == 3 and junior.body().practice_days == 0, "Only Qi recovers during meditation")
	advance(junior, 1, Vector3.RIGHT)
	expect(not junior.combat.meditating, "Movement ends meditation")
	CombatWorld.toggle_meditation(junior)
	CombatWorld.hit(junior, Y, H, P4Content.ACTIONS.lunge, Vector3.FORWARD)
	expect(not junior.combat.meditating, "A wound interrupts meditation")
	CombatWorld.toggle_flight(junior.combat)
	expect(actor(junior).flight == "ground", "Qi stage cannot fly")
	var foundation := fresh("foundation")
	foundation.combat.artifact = false
	CombatWorld.toggle_flight(foundation.combat)
	expect(actor(foundation).flight == "ground", "Foundation without prepared artifact cannot fly")
	foundation.combat.artifact = true
	CombatWorld.toggle_flight(foundation.combat)
	advance(foundation, 60, Vector3.UP)
	expect(actor(foundation).flight == "artifact" and actor(foundation).pos[1] > 3000, "Artifact flight and climb")
	var core := fresh("core")
	CombatWorld.toggle_flight(core.combat)
	advance(core, 60, Vector3.UP)
	expect(actor(core).flight == "self" and actor(core).pos[1] > actor(foundation).pos[1], "Core self-flight is faster")
	var reserve: int = actor(core).qi
	advance(core, 120)
	expect(actor(core).qi >= reserve and actor(core).qi <= 100000, "Core passive covers hover")
	CombatWorld.toggle_perception(core)
	reserve = actor(core).qi
	advance(core, 120)
	expect(actor(core).qi < reserve, "Combined altitude and perception exceeds passive flow")
	CombatWorld.hit(foundation, AIR, H, P4Content.ACTIONS.lunge, Vector3.FORWARD)
	expect(actor(foundation).flight == "artifact", "Ordinary hit does not drop artifact flight")
	actor(foundation).qi = 1
	advance(foundation, 1)
	expect(actor(foundation).flight == "glide", "Flight exhaustion explicitly transitions to glide")
	advance(foundation, 240, Vector3.DOWN)
	expect(actor(foundation).flight == "ground" and actor(foundation).pos[1] == 0, "Emergency landing completes with movement")

func commands() -> void:
	var s := fresh()
	var hero := actor(s)
	CombatWorld.toggle_perception(s)
	CombatWorld.submit(s, CombatState.order("ward"))
	advance(s, 2)
	expect(hero.action.wind == 60 and hero.qi == 89928 and s.combat.wards == 3, "Technique begins in slow motion and pays Qi once")
	CombatWorld.submit(s, CombatState.order("strike", Y))
	CombatWorld.submit(s, CombatState.order("guard"))
	expect(s.combat.queued.key == "guard" and hero.action.key == "ward" and s.combat.wards == 3, "Single replaceable pending command without cost")
	advance(s, 120)
	expect(hero.shield == 40 and s.combat.wards == 2 and hero.action.rest == 12, "Talisman consumed on release only")
	advance(s, 24)
	expect(hero.action.key == "guard" and s.combat.queued.key == "", "Queued command runs without disabling perception")
	var cut := fresh()
	CombatWorld.start(cut, H, CombatState.order("ward"), space)
	CombatWorld.hit(cut, E, H, P4Content.ACTIONS.crush, Vector3.FORWARD)
	expect(actor(cut).qi == 90000 and cut.combat.wards == 3 and actor(cut).action.key == "", "Interrupted talisman keeps item and loses paid Qi")
	var aim := fresh("core")
	place(aim, Y, Vector3(5, 0, -7))
	CombatWorld.start(aim, H, CombatState.order("ward"), space)
	CombatWorld.submit(aim, CombatState.order("ground", Y))
	place(aim, Y, Vector3(6, 0, -7))
	advance(aim, 72)
	var center: Array = actor(aim).action.center.duplicate()
	expect(center == [6000, 0, -7000], "Area captures target at actual windup")
	place(aim, Y, Vector3(12, 0, -8))
	CombatWorld.submit(aim, CombatState.order("ground", E))
	advance(aim, 52)
	expect(actor(aim).action.center == center, "Next target cannot move a fixed volume")
	advance(aim, 1)
	expect(actor(aim, Y).hp == 30, "Moving out of a fixed volume avoids the hit")
	var flight := fresh("foundation")
	CombatWorld.start(flight, H, CombatState.order("ward"), space)
	advance(flight, 72)
	CombatWorld.toggle_flight(flight.combat)
	var qi: int = actor(flight).qi
	CombatWorld.start(flight, H, CombatState.order("ground", "", Vector3(2,0,-7)), space)
	expect(actor(flight).flight == "artifact" and actor(flight).action.key == "" and actor(flight).qi == qi, "Flight and ward exhaust control budget")
	actor(flight).shield = 0
	actor(flight).shield_ticks = 0
	CombatWorld.start(flight, H, CombatState.order("ground", "", Vector3(2,0,-7)), space)
	expect(actor(flight).action.key == "ground", "Ended shield frees control without refund")

func forewarning() -> void:
	for prepared: bool in [true, false]:
		var s := fresh("core")
		if not prepared:
			s.soul.mastery.erase("combat.forewarning")
		place(s, H, Vector3(8, 4, -6))
		actor(s).flight = "self"
		advance(s, 1)
		expect((s.combat.warning != "") == prepared, "Forewarning requires mastered technique and author air threat")
		expect(not s.combat.perception and actor(s).shield == 0 and actor(s,AIR).action.wind > 0, "Signal neither activates response nor waits for input")
		actor(s).qi = 0
		CombatWorld.toggle_perception(s)
		expect(not s.combat.perception, "Signal gives no free activation at zero Qi")
		advance(s, 160)
		expect(actor(s).hp < 100 and s.combat.warning == "", "Ignoring the signal permits damage and it expires on the combat clock")

func space_and_protection() -> void:
	var wall := WallSpace.new()
	var s := fresh("soul")
	place(s, H, Vector3.ZERO)
	expect(not CombatWorld.blink_allowed(s.combat, H, Vector3(0, 0, -3), wall), "Teleport cannot go through cover")
	expect(not CombatWorld.blink_allowed(s.combat, H, Vector3(1, 0, 0), wall), "Occupied landing is rejected")
	expect(CombatWorld.blink_allowed(s.combat, H, Vector3(3, 0, 0), wall), "Visible free landing is allowed")
	CombatWorld.start(s, H, CombatState.order("blink", "", Vector3(3,0,0)), wall)
	advance(s, 18, Vector3.ZERO, wall)
	expect(actor(s).pos == [3000,0,0], "Blink releases at fixed destination")
	var area := fresh("core")
	place(area, H, Vector3(0,0,-6))
	place(area, AIR, Vector3(3,5,-6))
	CombatWorld.start(area, H, CombatState.order("ground", AIR), space)
	expect(actor(area).action.center == [3000,0,-6000], "Ground projection under air target")
	for i in 53: CombatWorld.step_action(area, H, space)
	expect(actor(area,AIR).hp == 55, "Ground volume has limited height")
	for i in 38: CombatWorld.step_action(area, H, space)
	CombatWorld.start(area, H, CombatState.order("sphere", AIR), space)
	for i in 43: CombatWorld.step_action(area, H, space)
	expect(actor(area,AIR).hp == 28, "Spatial sphere strikes the same actor in midair")
	var bolt := fresh()
	place(bolt, H, Vector3.ZERO)
	place(bolt, Y, Vector3(0,0,-2))
	CombatWorld.start(bolt, H, CombatState.order("strike", Y), wall)
	expect(actor(bolt).action.key == "" and actor(bolt).qi == 100000, "Melee assistance neither attacks nor crosses a wall")
	CombatWorld.start(bolt, H, CombatState.order("bolt", Y), space)
	for i in 21: CombatWorld.step_action(bolt, H, space)
	for i in 20: CombatWorld.projectiles(bolt, wall)
	expect(bolt.combat.projectiles.is_empty() and actor(bolt,Y).hp == 30, "Swept projectile hits wall before actor")
	place(bolt, Y, Vector3(0,0,-6))
	var impact: Array = []
	for key: String in ["bolt", "seek"]:
		var shot_test := StateCodec.clone(bolt)
		actor(shot_test).action = CombatState.action()
		CombatWorld.start(shot_test, H, CombatState.order(key, Y), space)
		for i in int(P4Content.ACTIONS[key].wind): CombatWorld.step_action(shot_test, H, space)
		place(shot_test, Y, Vector3(2,0,-5))
		for i in 135: CombatWorld.projectiles(shot_test, space)
		impact.append(actor(shot_test,Y).hp)
	expect(impact == [30,11], "Directed projectile misses subsequent lateral shift, bounded homing can turn")
	expect(CombatWorld.segment_hit(Vector3(0,0,0), Vector3(0,0,-9), Vector3(0,0,-3), 0.6) < 0.3, "Swept collision detects a complete crossing between samples")
	var defence := fresh()
	CombatWorld.start(defence, H, CombatState.order("guard", "", Vector3.ZERO, Vector3.FORWARD), space)
	CombatWorld.hit(defence, Y, H, P4Content.ACTIONS.lunge, CombatWorld.chest(actor(defence)) + Vector3.FORWARD)
	expect(actor(defence).hp == 100, "Facing block absorbs appropriate impact")
	CombatWorld.hit(defence, Y, H, P4Content.ACTIONS.lunge, CombatWorld.chest(actor(defence)) + Vector3.BACK)
	expect(actor(defence).hp == 90, "Rear hit bypasses block")

func consequences() -> void:
	var s := fresh()
	var enemy := actor(s,E)
	CombatWorld.hit(s, H, E, P4Content.ACTIONS.strike, CombatWorld.chest(enemy) + Vector3.FORWARD)
	expect(enemy.hp == 80 and enemy.armor == 40, "Repeated frontal melee cannot bypass intact stone armor")
	enemy.action = {"key":"crush", "target":H, "center":CombatState.pack(P4Content.SHORT_EXIT), "direction":[0,0,-1000], "wind":1, "rest":0}
	CombatWorld.step_action(s,E,space)
	expect(s.combat.collapse, "Crush centred at retreat route closes the shortcut")
	CombatWorld.hit(s, H, E, P4Content.ACTIONS.strike, CombatWorld.chest(enemy) + Vector3.BACK)
	expect(enemy.hp == 70, "During recovery the exposed flank is vulnerable")
	var hero := actor(s)
	CombatWorld.hit(s, E, H, P4Content.ACTIONS.crush, Vector3.FORWARD)
	CombatWorld.hit(s, E, H, P4Content.ACTIONS.crush, Vector3.FORWARD)
	expect(hero.hp == 30 and hero.injury, "Unshielded heavy damage accumulates distinct rib injury")
	hero.shield = 40
	hero.shield_ticks = 400
	CombatWorld.hit(s, E, H, P4Content.ACTIONS.crush, Vector3.FORWARD)
	expect(hero.hp == 30 and hero.shield == 5, "Ward absorbs heavy blow without removing injury")
	for i in 7: CombatWorld.hit(s, H, E, P4Content.ACTIONS.ground, CombatWorld.chest(enemy) + Vector3.FORWARD)
	place(s,H,CombatWorld.pos(enemy))
	expect(enemy.hp == 0 and CombatWorld.claim(s) and not CombatWorld.claim(s), "Defeated elite gives one collectible material")
	expect(s.materials.items.size() == 1 and s.materials.items[0].kind == "horn_plate" and s.materials.items[0].integrity == "damaged", "Destructive attack persists in material quality")
	expect(s.day == 0 and s.body().practice_days == 0 and s.soul.first_milestones.is_empty(), "Combat never advances calendar or cultivation")
	expect(CombatWorld.begin_recovery(s, true, false) == "", "Recovery uses explicit calendar confirmation")
	expect(Simulation.step(s, 2) == "" and s.day == 2 and hero.hp == 80 and hero.injury and s.combat.medicine == 0, "Medicine changes declared recovery, leaves separate injury")
	hero.shield = 0
	hero.shield_ticks = 0
	CombatWorld.hit(s, E, H, P4Content.ACTIONS.crush, Vector3.FORWARD)
	CombatWorld.hit(s, E, H, P4Content.ACTIONS.crush, Vector3.FORWARD)
	CombatWorld.hit(s, E, H, P4Content.ACTIONS.crush, Vector3.FORWARD)
	expect(s.mode == "body_dead" and not s.body().alive and s.body().died == 2 and s.materials.items[0].holder == "p4.corpse", "Lethal transition uses campaign body and retains property at corpse")
	expect(StateCodec.clone(s) != null, "Dead continuation survives codec")
	var trip := fresh("core")
	var plan := SedgeWorld.route_plan(trip)
	expect(SedgeWorld.depart(trip, plan, true) == "" and Simulation.step(trip, 5) == "", "Flight route uses same confirmed travel operation")
	var leg := SedgeWorld.active_trip(trip)
	expect(CombatWorld.crossing(trip) and trip.day == 2 and leg.progress == 2, "Prepared ambush retains actual elapsed date and travel progress")
	var resumed_trip := StateCodec.clone(trip)
	expect(resumed_trip != null and CombatWorld.crossing(resumed_trip), "Interrupted route restores one existing opponent")
	expect(Simulation.resume(trip, leg.id, "too-soon") != "" and actor(trip).qi == 94000, "Flight route charges once and cannot skip its active encounter")
	var sentinel := P4Content.CROSSING
	CombatWorld.hit(trip, H, sentinel, P4Content.ACTIONS.bolt, Vector3.ZERO)
	CombatWorld.hit(trip, H, sentinel, P4Content.ACTIONS.bolt, Vector3.ZERO)
	expect(actor(trip, sentinel).hp == 0 and trip.day == 2, "Crossing uses shared combat without charging additional days")
	expect(Simulation.resume(trip, leg.id, leg.id + ".cleared") == "" and Simulation.step(trip, 3) == "", "Resolve encounter and advance just the remaining days")
	expect(trip.day == 5 and trip.exploration.place == SedgeWorld.BANK and actor(trip).pos == [0,0,4500], "Route charges days and restores arrival position")

func restore() -> void:
	var s := fresh("core")
	var c := s.combat
	var base := "user://p4-rule-" + str(Time.get_ticks_usec()) + "-" + str(OS.get_process_id())
	var storage := SnapshotStore.new(base, s.campaign_id, true, true, true)
	expect(storage.save(s), "Initial schema-4 snapshot")
	CombatWorld.toggle_flight(c)
	CombatWorld.toggle_perception(s)
	var hero := actor(s)
	place(s,H,Vector3(0,3,-8))
	place(s,AIR,Vector3(0,4,-13))
	actor(s,AIR).action = {"key":"spit", "target":H, "center":CombatState.pack(CombatWorld.chest(hero)), "direction":[0,-200,980], "wind":8, "rest":0}
	CombatWorld.start(s,H,CombatState.order("ward"),space)
	# Core has room for flight, perception and ward. Snapshot one tick before consumption.
	for i in 59: CombatWorld.step_action(s,H,space)
	s.revision += 1
	expect(storage.save(s), "Snapshot before ward release")
	var latest := storage.load_current()
	var loaded: CampaignState = latest.state
	CombatWorld.step_action(s,H,space)
	CombatWorld.step_action(loaded,H,space)
	expect(s.fingerprint() == loaded.fingerprint() and c.wards == 2 and hero.shield == 40, "Windup exactly-once cost across reload")
	c.serial += 1
	c.projectiles.append({"id":c.serial, "owner":AIR, "target":H, "key":"spit", "pos":[0,3780,-8640], "direction":[0,0,1000], "life":45})
	s.revision += 1
	expect(storage.save(s), "Snapshot with in-flight hero, hostile preparation, ward and projectile")
	latest = storage.load_current()
	loaded = latest.state
	expect(s.fingerprint() == loaded.fingerprint() and latest.sequence == 3, "Exact dynamic round trip including position and target references")
	var hits := int(c.hits)
	CombatWorld.projectiles(s,space)
	CombatWorld.projectiles(loaded,space)
	expect(s.fingerprint() == loaded.fingerprint() and c.hits == hits + 1 and hero.shield == 23 and c.projectiles.is_empty(), "Saved last-tick impact consumes shield exactly once")
	CombatWorld.projectiles(loaded,space)
	expect(loaded.combat.hits == hits + 1 and actor(loaded).shield == 23, "No replay without projectile")
	s.revision += 1
	storage.fail_at = "after_main_replace"
	expect(not storage.save(s), "Injected interruption after durable replacement")
	storage.fail_at = ""
	expect(storage.save(s) and storage.sequence == 4, "Retry acknowledges committed state without new step or spend")
	var wrong_family := SnapshotStore.new(base, s.campaign_id, true, true)
	expect(wrong_family.load_current().get("incompatible", false) or wrong_family.last_error.contains("Unsupported"), "P3 reader refuses P4 slot")
	var corrupt := s.encode()
	corrupt.combat.actors.hero.pos = [900]
	expect(StateCodec.decode(corrupt) == null, "Malformed dynamic vector refused")
	corrupt = s.encode()
	corrupt.combat.actors.hero.action.target = "absent"
	expect(StateCodec.decode(corrupt) == null, "Broken phase reference refused")
	DirAccess.remove_absolute(storage.path("current.json"))
	DirAccess.remove_absolute(storage.path("previous.json"))
	DirAccess.remove_absolute(storage.directory)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(base))
