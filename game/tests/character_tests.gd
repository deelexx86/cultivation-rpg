extends SceneTree

var checks := 0
var failures := 0
var space := CombatSpace.new()

func expect(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	lessons()
	inheritance()
	interruption()
	combat()
	snapshots()
	print("P71_RULE_%s checks=%d failures=%d" % ["PASS" if failures == 0 else "FAIL",checks,failures])
	quit(int(failures != 0))

func lessons() -> void:
	var totals := []
	for timing: String in ["never","early","late"]:
		var r := SliceRoute.new()
		r.workshop()
		var initial := r.state.fingerprint()
		expect(SliceWorld.apply(r.state,"reason") != "" and r.state.fingerprint() == initial,"Missing treatise costs nothing")
		r.material("buy","lo.treatise")
		if timing == "early": r.step("reason")
		r.material("learn","herbalism")
		var herb := r.state.running().duration
		r.finish()
		if timing == "late": r.step("reason")
		r.material("learn","alchemy")
		var alchemy := r.state.running().duration
		r.finish()
		expect(r.error == "" and r.state.soul.mastery.has("operation.stabilization"),"Completed both lessons: "+r.error)
		if timing == "early": expect(herb in [730,731],"Early investment halves herbalism")
		else: expect(herb == 1461,"Base herbalism takes four calendar years")
		expect(alchemy in ([1095,1096] if timing != "never" else [2191,2192]),"Reason changes only remaining lessons")
		totals.append(r.state.day)
		var start := r.state.day
		r.trip()
		expect(r.state.day == start+5,"Same travel duration")
		r.play("gather")
		expect(r.state.running().duration == WorldCalendar.add_years(r.state.day,19)-r.state.day,"Body formation still takes 19 years")
		print("P71_STUDY timing=",timing," herb=",herb," alchemy=",alchemy," total_days=",start," spent=",r.state.materials.paid)
	expect(totals[1] < totals[0] and totals[0] < totals[2],"Opportunity cost depends on remaining lessons")

func inheritance() -> void:
	var r := SliceRoute.new("vs-root-whole")
	r.prepare("condense")
	r.material("choose","")
	r.step("footwork")
	r.step("reason")
	r.step("weave")
	expect(r.state.soul.mental.focus == 2, "Control training does not train focus")
	r.step("focus")
	var known := r.state.soul.mastery.duplicate()
	var mind := r.state.soul.mental.duplicate()
	expect(mind == {"control":5,"focus":3,"reason":2} and CharacterRules.mobility(r.state)==3,"Earned body and soul")
	r.play("bury")
	Simulation.lose_body(r.state,"combat")
	r.step("transfer")
	expect(r.error == "" and r.state.body().profile=="cold" and r.state.soul.mental==mind and r.state.soul.mastery==known,"One real transfer preserves all learned values: "+r.error)
	expect(r.state.bodies[0].footwork==1 and r.state.body().footwork==0 and CharacterRules.mobility(r.state)==1 and CharacterRules.quality(r.state)==1,"New carrier starts from its own card")
	expect(CharacterRules.card(r.state).roots==["earth","metal","water"] and CharacterRules.CARDS.first.roots==["wood","fire","earth"],"Two distinct three-element carriers")
	r.state.exploration.x = int(SliceWorld.STEPS.x*100)
	r.state.exploration.z = int(SliceWorld.STEPS.z*100)
	r.play("survey")
	r.workshop()
	r.play("unearth")
	var weak_senses := StateCodec.clone(r.state)
	weak_senses.soul.mental.reason = 1
	weak_senses.materials.notes.erase("quartz.recognized")
	expect(MaterialWorld.inspect(weak_senses,"quartz") != "", "Untrained reason and weak senses miss weak trace")
	weak_senses.soul.mental.reason = 2
	expect(MaterialWorld.inspect(weak_senses,"quartz") == "" and MaterialWorld.extract(weak_senses,"quartz.surface") != "", "Reason assists recognition but cannot restore physical extraction")
	var root := MaterialWorld.equipment(r.state,"root")
	expect(root != "" and MaterialWorld.start(r.state,"divide",root)!="","Intellect and an inherited recipe cannot replace the physical threshold")
	for cmd: String in ["weave","focus","reason"]:
		var prior := r.state.fingerprint()
		expect(SliceWorld.apply(r.state,cmd)!="" and r.state.fingerprint()==prior,"Soul saturation survives transfer: "+cmd)
	r.step("sensitivity")
	expect(MaterialWorld.start(r.state,"divide","missing") != "","Restored senses cannot replace raw material")
	r.material("recipe.divide",root)
	r.finish()
	r.material("recipe.stabilize",MaterialWorld.equipment(r.state,"root_part"))
	expect(r.state.running().duration==3,"Stabilization works without wood for one extra day")
	r.finish()
	r.step("footwork")
	var prior := r.state.fingerprint()
	expect(SliceWorld.apply(r.state,"footwork")!="" and SliceWorld.apply(r.state,"sensitivity")!="" and r.state.fingerprint()==prior,"New body can pay once for each exercise")
	var practiced := known.duplicate()
	practiced["operation.stabilization"] = 2
	expect(r.error=="" and MaterialWorld.equipment(r.state,"essence")!="" and r.state.soul.mastery==practiced,"Same recipe actually produces essence without another lesson")
	print("P71_RECIPE carrier=cold wood=false days=3 restored_sensitivity=",CharacterRules.sensitivity(r.state))

func interruption() -> void:
	var r := SliceRoute.new()
	r.workshop()
	var e := P1Fixture.event("training.call",1,"call")
	e.interrupt = true
	r.state.events.append(e)
	r.play("footwork")
	r.finish()
	expect(r.error=="" and r.state.day==1 and r.state.body().footwork==0 and r.state.materials.wallet==77 and r.state.actions.back().status=="paused","Event interrupts after payment, before improvement")
	var snapshot := r.state.encode()
	expect(SliceWorld.apply(r.state,"footwork")!="" and r.state.encode()==snapshot,"Cannot stack paused exercise")
	r.applied(Simulation.resume(r.state,r.state.actions.back().id,"resume.lesson"),"resume")
	r.finish()
	expect(r.state.body().footwork==1 and r.state.materials.wallet==77 and r.state.day==366,"Resumes remaining days without charging twice")
	for expires: String in ["teacher","body"]:
		r = SliceRoute.new()
		r.workshop()
		if expires=="teacher":
			r.state.event("shen-yu.death").day = 366
		else:
			r.state.body().born = WorldCalendar.ordinal(-99)
			var prior := r.state.fingerprint()
			expect(SliceWorld.apply(r.state,"footwork") != "" and r.state.fingerprint()==prior,"Known fatal end cannot charge without consent")
		r.applied(SliceWorld.apply(r.state,"footwork",true),"consent")
		r.finish()
		expect(r.error=="" and r.state.body().footwork==0 and r.state.actions.back().status=="stopped" and r.state.materials.paid==3,"Expiry on last day precedes improvement: "+expires)

func bolt(s: CampaignState, amount: int) -> Dictionary:
	var c := s.combat
	c.actors.hero.pos = CombatState.pack(Vector3(0,0,-4.5))
	c.actors.hero.qi = amount
	c.actors[P4Content.YOUNG].pos = CombatState.pack(Vector3(0,0,-8.5))
	CombatWorld.submit(s,CombatState.order("bolt",P4Content.YOUNG))
	for i in 120:
		CombatWorld.advance(s,space,Vector3.ZERO)
		if c.actors[P4Content.YOUNG].hp < 30: break
	return {"loss":30-int(c.actors[P4Content.YOUNG].hp),"spent":amount-int(c.actors.hero.qi)}

func combat() -> void:
	var r := SliceRoute.new("vs-root-whole")
	var weak := StateCodec.clone(r.state)
	var skills := P4Content.skills(weak)
	r.chamber("condense")
	r.step("infuse")
	r.step("align")
	r.step("finish")
	r.trip()
	expect(r.error=="" and CharacterRules.quality(r.state)==3 and P4Content.skills(r.state)==skills,"Reaching Foundation changes energy while preserving known combat actions")
	expect(bolt(StateCodec.clone(weak),50000)=={"loss":15,"spent":7000},"Early spark at 50 Qi")
	expect(bolt(StateCodec.clone(r.state),50000)=={"loss":21,"spent":7000},"Foundation spark at the same 50 Qi")
	expect(bolt(StateCodec.clone(weak),100000)=={"loss":15,"spent":7000},"Larger weak reserve increases no damage")
	Simulation.lose_body(r.state,"combat")
	r.step("transfer")
	expect(r.state.body().profile=="cold" and r.state.combat.actors.hero.qi==120000 and bolt(StateCodec.clone(r.state),50000)=={"loss":15,"spent":8000},"Cold carrier has higher capacity, low quality and one more Qi per spark")
	expect(CharacterRules.carry_limit(weak) == 6500 and CharacterRules.carry_limit(r.state) == 6000,"Fortitude sets the overload threshold")
	var unknown := StateCodec.clone(r.state)
	unknown.exploration.place = SedgeWorld.BANK
	unknown.soul.mastery.erase("method.white-sedge")
	expect(SliceWorld.apply(unknown,"gather")!="","Formation needs the known main method")
	unknown.exploration.place = SedgeWorld.YARD
	unknown.soul.mastery.erase("combat.bolt")
	CombatWorld.submit(unknown,CombatState.order("bolt",P4Content.YOUNG))
	expect(unknown.combat.queued.key=="" and not P4Content.skills(unknown).has("bolt"),"No free technique from a body or energy grade")
	for s: CampaignState in [weak,r.state]:
		s.combat.actors.hero.qi=0
		CombatWorld.toggle_meditation(s)
		CombatWorld.flow(s)
		expect(s.combat.actors.hero.qi==(310 if s==weak else 270),"Conductivity changes meditation gain")
		s.combat.actors.hero.qi=SliceWorld.vitals(s).qi*1000-1
		CombatWorld.flow(s)
		expect(s.combat.actors.hero.qi==SliceWorld.vitals(s).qi*1000,"Meditation cannot exceed this body's capacity")
		CombatWorld.toggle_meditation(s)
	var trained := SliceRoute.new()
	trained.workshop()
	trained.step("footwork")
	trained.step("weave")
	trained.step("focus")
	for s: CampaignState in [weak,trained.state]:
		var x: int = s.combat.actors.hero.pos[0]
		for i in 60: CombatWorld.move_actor(s,"hero",space,Vector3.RIGHT)
		var distance: int = s.combat.actors.hero.pos[0]-x
		expect(distance==(4320 if s==weak else 4740),"Same 60 ground ticks measure different strides")
		s.combat.actors.hero.action = {"key":"bolt","target":P4Content.YOUNG,"center":[0,0,0],"direction":[0,0,-1000],"wind":5,"rest":0}
		CombatWorld.hit(s,P4Content.YOUNG,"hero",{"damage":17},Vector3.ZERO)
		expect((s.combat.actors.hero.action.key=="bolt")==(s==trained.state),"Focus retains windup under a 17-point hit")
		s.combat.actors.hero.action = CombatState.action()
		s.combat.perception=true
		s.combat.actors.hero.shield=40
		s.combat.actors.hero.shield_ticks=480
		CombatWorld.start(s,"hero",CombatState.order("pulse"),space)
		expect(s.combat.actors.hero.action.key=="pulse","One spare control suffices")
		s.combat.actors.hero.action=CombatState.action()
		CombatWorld.start(s,"hero",CombatState.order("ground","",Vector3.ZERO),space)
		expect((s.combat.actors.hero.action.key=="ground")==(s==trained.state),"Two spare control units needed for ground circle")

func snapshots() -> void:
	var base := "user://p71-rule-%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]
	var slot := SnapshotStore.new(base,"route",true,true,true,true)
	DirAccess.make_dir_recursive_absolute(slot.directory)
	var old := {}
	for name: String in ["current.json","previous.json"]:
		var source := "res://tests/fixtures/schema5/"+name.get_basename()+".snapshot"
		old[name] = FileAccess.get_file_as_bytes(source)
		DirAccess.copy_absolute(ProjectSettings.globalize_path(source),slot.path(name))
	var r := SliceRoute.new()
	expect(slot.load_current().get("incompatible",false) and not slot.save(r.state),"Reject P5 load and write")
	for name: String in old:
		expect(FileAccess.get_file_as_bytes(slot.path(name))==old[name],"P5 fixture byte preservation "+name)
	DirAccess.remove_absolute(slot.path("current.json"))
	expect(slot.load_current().get("incompatible",false) and not slot.save(r.state) and not FileAccess.file_exists(slot.path("current.json")) and FileAccess.get_file_as_bytes(slot.path("previous.json"))==old["previous.json"],"Lone P5 backup stays intact")
	var current := SnapshotStore.new(base+"-active","route",true,true,true,true)
	r.workshop()
	r.material("buy","lo.treatise")
	r.play("reason")
	r.applied(Simulation.step(r.state,1),"partial practice")
	expect(current.save(r.state),"Save paid practice before improvement")
	var session := SliceSession.new(SliceWorld.fresh("route","unused"),SnapshotStore.new(base+"-active","route",true,true,true,true))
	expect(session.reload() and session.state.running().progress==1 and session.state.soul.mental.reason==1,"Disk round trip of unfinished practice")
	expect(session.advance(2000) and session.reload() and session.state.soul.mental.reason==2,"Completed practice survives disk round trip")
	var meditating := StateCodec.clone(session.state)
	CombatWorld.toggle_perception(meditating)
	for i in 60: CombatWorld.advance(meditating,space,Vector3.ZERO)
	expect(meditating.combat.tick==30 and meditating.combat.actors.hero.qi==100000-30*66,"Trained reason sustains perception at its existing clock rate")
	var before := session.state.fingerprint()
	expect(not session.play("reason") and session.state.fingerprint()==before,"Reload cannot award or charge a saturated practice")
	DirAccess.copy_absolute(slot.path("previous.json"),current.path("previous.json"))
	var mixed := SnapshotStore.new(base+"-active","route",true,true,true,true)
	expect(mixed.load_current().get("incompatible",false) and not mixed.save(session.state) and not session.save() and FileAccess.get_file_as_bytes(current.path("previous.json"))==old["previous.json"],"Mixed schema backup is never rotated away")
	for change: String in ["profile","footwork","sense_drills","missing","reason"]:
		var data := session.state.encode()
		match change:
			"profile": data.bodies[0].profile="cold"
			"footwork": data.bodies[0].footwork=2
			"sense_drills": data.bodies[0].sense_drills=1
			"missing": data.bodies[0].erase("profile")
			"reason": data.soul.mental.reason=0
		expect(StateCodec.decode(data)==null,"Reject invalid character state: "+change)
