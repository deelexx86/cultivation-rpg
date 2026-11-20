extends SceneTree
var checks := 0
var failures := 0

func must(ok: bool,label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL ",label)

func _initialize() -> void:
	for method: String in ["smooth-reserve","condense"]:
		var r := SliceRoute.new("vs-root-whole" if method=="condense" else "vs_smooth_no_overload")
		r.chamber(method)
		must(r.error=="",r.error)
		if r.error!="": continue
		var entry := StateCodec.clone(r.state)
		r.step("infuse")
		var wave := StateCodec.clone(r.state)
		r.step("align" if method=="condense" else "endure")
		r.step("finish")
		must(r.error == "" and r.state.body().milestone=="foundation" and r.state.soul.limit_years==200,r.error+" Foundation")
		r.trip()
		must(r.state.mode=="active" and r.state.active_body==0 and not r.state.person(SedgeWorld.LO).alive and r.state.exploration.place==SedgeWorld.YARD,"return in first life")
		if method=="smooth-reserve":
			must(r.state.materials.wallet==33,"first life budget")
			r.workshop()
			r.play("bury")
			var inheritance := StateCodec.clone(r.state)
			for seed_key: String in ["warm-route","cold-route","third-route"]:
				r.state = StateCodec.clone(inheritance)
				r.state.seed_value = seed_key
				second_life(r)
		if method=="condense":
			r.state = StateCodec.clone(wave)
			r.state.outcomes["wave.1"] = 0
			var started := entry.day
			r.step("endure")
			r.step("finish")
			must(r.state.day==WorldCalendar.add_years(started,2) and r.state.soul.limit_years==200,"two-year stable condensation")
			r.state = StateCodec.clone(wave)
			r.state.slice.carrier="cold"
			r.state.combat.actors.hero.hp=80
			r.step("endure")
			must(SliceWorld.apply(r.state,"finish")!="" and r.state.slice.load,"cold body cannot skip alignment for stable condensation")
		r.state = StateCodec.clone(wave)
		var wallet: int = r.state.materials.wallet
		r.play("stop")
		must(r.state.materials.wallet==wallet and r.state.body().milestone=="perfect" and r.state.slice.phase=="" and not r.state.soul.first_milestones.has("foundation"),"controlled stop")
		if method == "condense": must(MaterialWorld.available(r.state,"quartz").size()==1,"second quartz released")
		r.state = entry
		r.step("infuse")
		r.state.outcomes["wave.1"] = 1
		r.step("endure")
		var loaded := StateCodec.clone(r.state)
		r.step("force")
		must(r.state.body().milestone=="perfect" and r.state.combat.actors.hero.injury,"failed overloaded contour")
		r.state = StateCodec.clone(loaded)
		r.step("unstable")
		must(r.state.slice.unstable==3 and r.state.soul.limit_years==150,"incomplete without life extension")
		var day := r.state.day
		r.state.exploration.place=SedgeWorld.YARD
		CombatWorld.hit(r.state,"hero",P4Content.YOUNG,P4Content.ACTIONS.bolt,Vector3.ZERO)
		must(r.state.slice.unstable==2 and r.state.day==day and StateCodec.clone(r.state)!=null,"unstable hit/reload")
		var partial := StateCodec.clone(r.state)
		for i in 2: CombatWorld.hit(r.state,"hero",P4Content.HORNED,P4Content.ACTIONS.bolt,Vector3.ZERO)
		must(r.state.slice.unstable==0 and r.state.body().milestone=="perfect","depleted by combat")
		r.state=partial
		r.state.slice.decay=r.state.day+2
		r.trip()
		must(r.state.slice.unstable==0 and r.state.day==day+5,"decay during journey")
		if method=="smooth-reserve":
			r.trip()
			r.material("extract","quartz.surface")
			r.material("choose","smooth")
			r.trip()
			r.step("begin")
			r.step("infuse")
			r.step("endure")
			r.step("extend" if r.state.slice.load else "finish")
			must(r.state.soul.limit_years==200,"new attempt after incomplete contour")
		must(r.error=="",r.error)
		checks += r.checks
	boundaries()
	story()
	mortality()
	print("P5_RULE_", "PASS" if failures==0 else "FAIL"," checks=",checks," failures=",failures)
	quit(int(failures!=0))

func second_life(r: SliceRoute) -> void:
	Simulation.lose_body(r.state,"combat")
	must(StateCodec.clone(r.state)!=null and r.state.mode=="body_dead" and r.state.materials.wallet==0,"durable death")
	var date := r.state.day
	var first: int = r.state.soul.first_milestones.foundation
	r.step("transfer")
	must(r.state.active_body==1 and WorldCalendar.age_years(r.state.body().born,r.state.day)==18 and r.state.day==WorldCalendar.add_years(date,5),"new carrier")
	must(r.state.soul.mastery.get("operation.stabilization")==2 and not r.state.slice.sensitive and r.state.body().limit_years==100,"mastery and physical reset")
	r.workshop()
	must(SliceWorld.cache(r.state,false)!="","new carrier first surveys approach")
	r.state.exploration.x = int(SliceWorld.STEPS.x*100)
	r.state.exploration.z = int(SliceWorld.STEPS.z*100)
	r.play("survey")
	r.workshop()
	r.play("unearth")
	must(r.state.materials.wallet==16 and r.state.slice.robbed and MaterialWorld.available(r.state,"stabilizer").size()==1,"raided inheritance")
	must(MaterialWorld.extract(r.state,"quartz.surface")!="","physical sensitivity gate")
	r.step("sensitivity")
	r.material("extract","quartz.surface")
	r.material("choose","smooth")
	r.trip()
	r.grow()
	r.step("begin")
	r.step("infuse")
	r.step("endure")
	r.step("extend" if r.state.slice.load else "finish")
	must(r.state.soul.first_milestones.foundation==first and r.state.soul.limit_years==200 and r.state.body().limit_years==200,"same milestone in second life")
	print("P5_SECOND_LIFE carrier=",r.state.slice.carrier," wallet=",r.state.materials.wallet," day=",r.state.day)

func story() -> void:
	for branch: String in ["gift","late","estate"]:
		var r := SliceRoute.new()
		r.applied(SedgeWorld.apply(r.state,"accept"),"accept")
		if branch != "late":
			r.applied(SedgeWorld.apply(r.state,"take"),"take")
			r.applied(SedgeWorld.apply(r.state,"return"),"return")
		var days := 1 if branch=="gift" else WorldCalendar.ordinal(16)
		r.applied(Simulation.confirm(r.state,Simulation.preview(r.state,days,0),"wait"),"wait")
		r.finish()
		if branch=="late":
			r.applied(SedgeWorld.apply(r.state,"successor"),"successor")
			r.applied(SedgeWorld.apply(r.state,"take"),"late take")
			must(SedgeWorld.apply(r.state,"return")!="" and r.state.supplies==20,"no inherited reward")
			r.applied(SedgeWorld.apply(r.state,"notch"),"notch")
		elif branch=="gift": r.applied(SedgeWorld.apply(r.state,"gift"),"gift")
		else:
			must(r.state.exploration.holder==SedgeWorld.LO and SedgeWorld.apply(r.state,"gift")!="" and SedgeWorld.apply(r.state,"open")!="","estate retains sole sign")
			continue
		r.applied(SedgeWorld.apply(r.state,"open"),"open")
		must(r.error=="" and r.state.exploration.gate and r.state.exploration.holder=="socket",r.error+" one socket")

func mortality() -> void:
	var r := SliceRoute.new()
	Simulation.lose_body(r.state,"combat")
	for e: CampaignState.WorldEvent in r.state.events:
		r.state.day=e.day
		Simulation.apply_event(r.state,e)
	r.state.day=WorldCalendar.ordinal(98)
	var before:=r.state.fingerprint()
	must(SliceWorld.apply(r.state,"transfer")!="" and r.state.fingerprint()==before,"known fatal transfer requires separate confirmation")
	r.applied(SliceWorld.apply(r.state,"transfer",true),"fatal consent")
	r.finish()
	must(r.error=="" and r.state.mode=="ended" and r.state.bodies.size()==1 and r.state.day==WorldCalendar.ordinal(100),r.error+" soul expires in transit")

func boundaries() -> void:
	var r := SliceRoute.new()
	r.trip()
	r.step("gather")
	var retained := StateCodec.clone(r.state)
	for i in 32:
		r.state=StateCodec.clone(retained)
		r.state.seed_value="minor-%d"%i
		r.step("risk_minor")
		if r.state.flags.has("unsteady.body.1"): break
	must(r.state.slice.pool and r.state.body().milestone=="initial" and r.state.materials.wallet==79,"failed minor retains accumulation")
	r.step("steady")
	r.step("minor")
	must(r.error=="" and r.state.body().milestone=="middle" and r.state.materials.wallet==78,"recovered minor costs without repurchasing accumulation")
	r=SliceRoute.new()
	r.chamber("smooth-reserve")
	r.step("infuse")
	r.state.outcomes["critical.1"]=1
	r.step("reserve")
	must(SliceWorld.apply(r.state,"finish")!="" and SliceWorld.apply(r.state,"extend")!="","critical instability cannot be bought off")
	r.step("stop")
	must(r.error=="" and r.state.body().milestone=="perfect" and MaterialWorld.available(r.state,"stabilizer").is_empty(),"controlled termination with actual reserve expense")
	r=SliceRoute.new()
	Simulation.lose_body(r.state,"combat")
	r.step("transfer")
	var born:=r.state.fingerprint()
	must(StateCodec.clone(r.state).fingerprint()==born and r.state.materials.wallet==0 and not r.state.slice.buried,"awakening without inheritance is durable")
	r.trip()
	r.step("gather")
	must(r.error=="" and r.state.slice.pool,"beginner action without inheritance")
	# P3 and P5 headers never share a writer, even if the directory was copied.
	var dir := "user://schema-check-%d" % Time.get_ticks_usec()
	var old := SnapshotStore.new(dir,"legacy",true,true)
	var current := SnapshotStore.new(dir,"legacy",true,true,true,true)
	must(old.save(MaterialWorld.fresh("legacy")),"legacy fixture")
	var original := FileAccess.get_file_as_bytes(old.path("current.json"))
	must(current.load_current().get("incompatible",false) and not current.save(SliceWorld.fresh("legacy","seed")) and original==FileAccess.get_file_as_bytes(old.path("current.json")),"old slot byte-preserved")
