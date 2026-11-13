extends SceneTree
## Controlled fixture; the regular tests separately earn these conditions in play.

func must(ok: bool, message: String) -> void:
	if not ok:
		push_error(message)
		quit(1)
		assert(ok,message)

func command(s: CampaignState, cmd: String, arg: String = "") -> void:
	must(MaterialWorld.apply(s,cmd,arg)=="","Fixture "+cmd)

func first(s: CampaignState, kind: String) -> String:
	return MaterialWorld.available(s,kind)[0]

func advance(s: CampaignState, days: int) -> void:
	must(Simulation.step(s,days)=="","Fixture advance")

func fixture(id: String, kind: String) -> CampaignState:
	var s := MaterialWorld.fresh(id)
	s.exploration.x = MaterialWorld.WORKSHOP_POSITION.x
	s.exploration.z = MaterialWorld.WORKSHOP_POSITION.y
	if kind=="buy": return s
	for key: String in ["lo.kit","lo.vessel","lo.treatise"]: command(s,"buy",key)
	# Explicitly controlled knowledge, without pretending these are playtest steps.
	for key: String in ["herbalism.glass-root","alchemy.materials","operation.stabilization","foundation.smooth.vs","foundation.condense.vs"]: s.soul.mastery[key]=1
	s.exploration.notes["observe.dry"]=0
	command(s,"inspect","root")
	command(s,"inspect","quartz")
	command(s,"inspect","quartz")
	s.seed_value="vs-root-damaged"
	if kind=="extract": return s
	command(s,"extract","root.careful")
	command(s,"extract","quartz.surface")
	if kind in ["order","sell"]: return s
	command(s,"recipe.stabilize",first(s,"root_part"))
	advance(s,1)
	if kind=="active": return s
	advance(s,1)
	command(s,"recipe.mature",first(s,"essence"))
	must(Simulation.confirm(s,Simulation.preview(s,30,0),"fixture-practice")=="","Fixture practice")
	advance(s,29)
	if kind=="finish": return s
	advance(s,1)
	command(s,"visit")
	if kind=="claim": return s
	command(s,"claim",s.materials.jobs.back().id)
	return s

func mutation(session: SedgeSession, kind: String) -> bool:
	match kind:
		"buy": return session.material("buy","lo.kit")
		"extract": return session.material("extract","root.whole")
		"order": return session.material("recipe.order",first(session.state,"root_part"))
		"sell": return session.material("sell",first(session.state,"root_part"))
		"active","finish": return session.advance(1)
		"claim": return session.material("claim",session.state.materials.jobs.back().id)
		"choose": return session.material("choose","smooth")
	return false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=4: quit(2); return
	var kind: String = args[3]
	var store := SnapshotStore.new(args[0],"material-crash",true,true)
	var before := fixture("material-crash",kind)
	var after := StateCodec.clone(before)
	# Compute the expected domain result without touching the store being killed.
	match kind:
		"active","finish": must(Simulation.step(after,1)=="","Expected calendar result")
		"buy": command(after,"buy","lo.kit")
		"extract": command(after,"extract","root.whole")
		"order": command(after,"recipe.order",first(after,"root_part"))
		"sell": command(after,"sell",first(after,"root_part"))
		"claim": command(after,"claim",after.materials.jobs.back().id)
		"choose": command(after,"choose","smooth")
	if args[1]=="write":
		var session := SedgeSession.new(before,store)
		must(session.save(),"Initial checkpoint")
		store.crash_at=args[2]
		mutation(session,kind)
		quit(3)
	else:
		var loaded := store.load_current()
		must(loaded.error=="","Recovery load: "+loaded.error)
		var expected := after if args[2]=="after_main_replace" else before
		must(loaded.state.fingerprint()==expected.fingerprint(),"Atomic "+kind+" "+args[2])
		var session := SedgeSession.new(loaded.state,store)
		if args[2]!="after_main_replace": must(mutation(session,kind),"Continue recovered operation "+session.error)
		must(session.reload() and session.state.fingerprint()==after.fingerprint(),"One consistent result after continuation")
		match kind:
			"buy": must(not mutation(session,kind),"No duplicate purchase")
			"extract": must(not mutation(session,kind),"No extraction reroll")
			"claim": must(not mutation(session,kind),"No duplicate result")
			"order":
				var work: Dictionary = session.state.materials.jobs.back()
				must(not session.material("recipe.order",work.inputs[0]),"No duplicate reserved input")
		print("P3_CRASH_RECOVERY_PASS:",kind,":",args[2]," sequence=",store.sequence)
		quit(0)
