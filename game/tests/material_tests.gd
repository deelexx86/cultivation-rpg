extends SceneTree

var checks := 0
var errors := 0
var home := "user://material-tests/%d-%d" % [OS.get_process_id(),Time.get_ticks_usec()]

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		push_error(label)

func fresh(id: String) -> SedgeSession:
	var session := SedgeSession.new(MaterialWorld.fresh(id),SnapshotStore.new(home,id,true,true))
	session.state.exploration.x = MaterialWorld.WORKSHOP_POSITION.x
	session.state.exploration.z = MaterialWorld.WORKSHOP_POSITION.y
	check(session.save(),"Initial material save "+id)
	return session

func do(s: SedgeSession, command: String, argument: String = "") -> bool:
	var result := s.material(command,argument)
	check(result,command+":"+argument+" "+s.error)
	return result

func first(s: SedgeSession, kind: String) -> String:
	var ids := MaterialWorld.available(s.state,kind)
	check(not ids.is_empty(),"Available "+kind)
	return "" if ids.is_empty() else ids[0]

func finish(s: SedgeSession) -> void:
	var action := s.state.running()
	check(action != null,"Active personal process")
	if action != null: check(s.advance(action.duration-action.progress),"Complete personal process "+s.error)

func practice(s: SedgeSession, days: int) -> void:
	check(s.confirm(Simulation.preview(s.state,days,0),"test.practice.%d" % s.state.revision),"Confirm practice")
	check(s.advance(days),"Advance practice "+s.error)

func reload(s: SedgeSession) -> SedgeSession:
	var other := SedgeSession.new(MaterialWorld.fresh(s.state.campaign_id),SnapshotStore.new(home,s.state.campaign_id,true,true))
	check(other.reload(),"New reader "+other.error)
	check(other.state.fingerprint() == s.state.fingerprint(),"Exact snapshot round trip")
	return other

func prepare(s: SedgeSession) -> void:
	for offer: String in ["lo.kit","lo.vessel","lo.treatise"]: do(s,"buy",offer)
	check(s.state.soul.mastery.is_empty(),"Buying a book grants no mastery")
	do(s,"learn","herbalism")
	check(s.advance(1),"One day of learning")
	s = reload(s)
	check(not SedgeWorld.qualified(s.state),"No instant or partial qualification")
	finish(s)
	do(s,"learn","alchemy")
	finish(s)
	check(s.state.day == WorldCalendar.ordinal(10),"Exactly four plus six years")
	check(s.act("observe"),"Physical source evidence")
	do(s,"inspect","root")
	do(s,"inspect","quartz")
	do(s,"inspect","quartz")

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var s := fresh("damaged")
	check(not s.material("extract","root.whole"),"Location without kit and qualification insufficient")
	prepare(s)
	# prepare's reload creates a new session; read its committed continuation.
	check(s.reload(),"Read completed education")
	check(s.state.materials.wallet == 50,"Finite initial wallet minus kit/vessel/treatise/tuition")
	check(not s.material("buy","lo.kit"),"No restock by opening shop")
	check(not s.material("learn","alchemy"),"No repeated learning cost or bonus")
	var learned_state := s.state.fingerprint()
	for skill: String in ["herbalism","alchemy"]:
		check(not s.material("learn",skill) and s.state.fingerprint()==learned_state,"Mastered skill cannot charge money or calendar again: "+skill)
	s=reload(s)
	learned_state=s.state.fingerprint()
	check(not s.material("learn","herbalism") and not s.material("learn","alchemy") and s.state.fingerprint()==learned_state,"Learning remains nonrepeatable after reload")
	var observed_day := s.state.day
	var before := s.state.fingerprint()
	check(not s.material("extract","quartz.core") and s.state.fingerprint()==before,"Impossible core consumes nothing")
	do(s,"extract","root.careful")
	check(s.state.materials.root == "parts" and MaterialWorld.available(s.state,"root_part").size()==2,"Damage retains two usable parts")
	s = reload(s)
	check(not s.material("extract","root.whole"),"Damaged root cannot be rerolled or restored")
	for raw: Dictionary in s.state.materials.items:
		if raw.kind == "root_part": check(raw.origin == MaterialWorld.ROOT and raw.age == 600 and raw.integrity == "damaged","Origin/age distinct from damage")
	for i in 6: do(s,"extract","quartz.surface")
	check(not s.material("extract","quartz.surface") and s.state.materials.quartz_left==0,"Six fragments, no free replenishment")
	check(s.state.day==observed_day,"Local extraction spends no calendar days")
	var raw := first(s,"root_part")
	do(s,"recipe.order",raw)
	var order_id: String = s.state.materials.jobs.back().id
	check(s.state.materials.wallet==47 and MaterialWorld.item(s.state,raw).holder==order_id,"One fee and transferred custody")
	check(not s.material("sell",raw) and not s.material("recipe.order",raw),"Reserved material cannot be sold or ordered twice")
	check(s.confirm(Simulation.preview(s.state,30,0),"parallel"),"Cultivation alongside workshop")
	check(s.advance(10),"Partial common calendar")
	s = reload(s)
	check(MaterialWorld.job(s.state,order_id).status=="running" and s.state.running().progress==10,"Partial process and practice restored")
	check(s.advance(20),"Remaining common calendar")
	check(s.state.day==observed_day+30 and s.state.body().practice_days==30,"Thirty days elapsed once, not sixty")
	check(MaterialWorld.job(s.state,order_id).status=="ready" and not MaterialWorld.job(s.state,order_id).known,"Ready independently of knowledge/visit")
	do(s,"visit")
	do(s,"claim",order_id)
	check(not s.material("claim",order_id),"No second collection")
	check(s.state.soul.mastery["operation.stabilization"]==1,"Workshop does not teach mastery")
	var essence := first(s,"essence")
	do(s,"recipe.mature",essence)
	var maturation: String = s.state.materials.jobs.back().id
	check(MaterialWorld.equipment(s.state,"vessel")=="","Autonomous equipment exclusive")
	check(not s.material("recipe.stabilize",first(s,"root_part")),"Occupied vessel prevents second personal job")
	practice(s,30)
	do(s,"claim",maturation)
	do(s,"choose","smooth")
	check(s.state.materials.pledged==8 and s.state.materials.wallet==47 and s.state.body().milestone=="initial","Material plan reserves future costs, grants no breakthrough")
	s = reload(s)
	var reserved_id := ""
	for row: Dictionary in s.state.materials.items:
		if row.reserved==MaterialWorld.PLAN:
			reserved_id = row.id
			check(not s.material("sell",reserved_id),"Preparation items cannot be sold")
	var chosen := s.state.fingerprint()
	check(not s.material("choose","condense") and s.state.fingerprint()==chosen,"Damaged material rejects condensation, failed switch preserves chosen plan")
	do(s,"choose","")
	do(s,"choose","smooth")
	check(s.state.materials.wallet==47,"Repeated planning never charges or creates money")
	do(s,"choose","")
	# Correctable defect and mastered routine.
	raw = first(s,"root_part")
	do(s,"recipe.force",raw)
	check(s.advance(1),"Known hurried-heat defect")
	var unstable := first(s,"unstable_essence")
	do(s,"recipe.repair",unstable)
	check(s.advance(1),"Partial active repair")
	s = reload(s)
	check(not s.material("sell",unstable) and not s.confirm(Simulation.preview(s.state,2,0),"double-work"),"Personal control cannot be abandoned for parallel practice")
	finish(s)
	check(s.state.materials.wallet==46 and MaterialWorld.item(s.state,unstable).holder=="consumed","Repair charges once, preserves spent input as provenance only")
	var refined := first(s,"essence")
	do(s,"recipe.mature",refined)
	var cancelled: String = s.state.materials.jobs.back().id
	practice(s,1)
	do(s,"cancel",cancelled)
	var returned := first(s,"unstable_essence")
	check(MaterialWorld.item(s.state,returned).origin==MaterialWorld.ROOT,"Cancellation keeps provenance, returns a defect")
	practice(s,365)
	check(MaterialWorld.available(s.state,"unstable_essence").is_empty() and not MaterialWorld.available(s.state,"spent_essence").is_empty(),"Announced calendar storage expiry, no wall-clock timer")
	check(not s.material("recipe.repair",returned),"Expired essence cannot become fresh raw material")
	# Whole-root outcome and partial mineral persistence.
	var whole := fresh("whole")
	prepare(whole)
	check(whole.reload(),"Read whole education")
	whole.state.seed_value = "vs-root-whole"
	whole.state.revision += 1
	check(whole.save(),"Controlled whole-root fixture")
	do(whole,"extract","root.whole")
	check(whole.state.outcomes[MaterialWorld.ROOT]==1 and MaterialWorld.available(whole.state,"root").size()==1,"Prepared intact outcome")
	for i in 2: do(whole,"extract","quartz.surface")
	whole = reload(whole)
	check(whole.state.materials.quartz_left==4,"Partially extracted source persists")
	do(whole,"choose","condense")
	check(whole.state.materials.pledged==12,"Condensation reserves higher cost and distinct input")
	check(not whole.material("recipe.divide",first_unreserved_kind(whole,"root")),"Chosen living root unavailable for another recipe")
	do(whole,"choose","")
	do(whole,"recipe.divide",first(whole,"root"))
	finish(whole)
	check(MaterialWorld.available(whole.state,"root").is_empty() and MaterialWorld.available(whole.state,"root_part").size()==2,"One-way whole-root processing")
	do(whole,"extract","quartz.rough")
	do(whole,"recipe.clean",first(whole,"tainted_quartz"))
	finish(whole)
	var lowered := false
	for row: Dictionary in whole.state.materials.items:
		if row.kind=="quartz" and row.energy=="reduced" and row.holder==whole.state.body().id: lowered = true
	check(lowered,"Cleaning removes impurity without restoring lost energy")
	do(whole,"recipe.stabilize",first(whole,"root_part"))
	finish(whole)
	check(whole.state.soul.mastery["operation.stabilization"]==2,"Successful familiar operation earns bounded mastery")
	# Ground storage preserves one physical vessel and its contents.
	var carried := MaterialWorld.weight(whole.state)
	do(whole,"stash")
	check(MaterialWorld.weight(whole.state)<carried and MaterialWorld.equipment(whole.state,"vessel")=="","Stored container removes carried contents and availability")
	whole = reload(whole)
	check(not whole.material("extract","quartz.surface"),"Remote vessel cannot preserve new extraction")
	do(whole,"retrieve")
	check(MaterialWorld.weight(whole.state)==carried and not whole.material("retrieve"),"One return, exact carried weight, no copied contents")
	# Successor's shipment is explicit and finite, independent of old stock.
	practice(whole,WorldCalendar.ordinal(24)-whole.state.day)
	check(not whole.state.person(SedgeWorld.LO).alive,"Old shop owner remains dead")
	check(not whole.material("buy","lo.kit"),"Successor cannot replenish old offer")
	do(whole,"buy","yin.pill")
	check(not whole.material("buy","yin.pill"),"One condensation pill in dated shipment")
	do(whole,"buy","yin.stabilizer")
	do(whole,"buy","yin.stabilizer")
	check(not whole.material("buy","yin.stabilizer"),"Two stabilizer doses, no implicit restock")
	do(whole,"choose","condense")
	check(whole.state.materials.pledged==12,"Purchased pill is a real alternative to lost living root")
	do(whole,"choose","")
	do(whole,"choose","smooth-reserve")
	var reserve_doses:=0
	for row: Dictionary in whole.state.materials.items:
		if row.kind=="stabilizer" and row.reserved==MaterialWorld.PLAN: reserve_doses+=1
	check(reserve_doses==2 and whole.state.materials.pledged==8,"Optional reserve is a second real dose, not a duplicated guarantee")
	do(whole,"choose","")
	# A real interruption during personal work preserves the phase and payment.
	var interrupted := fresh("interrupted")
	do(interrupted,"buy","lo.treatise")
	var event := P1Fixture.event("lesson.call",1,"call")
	event.interrupt=true
	interrupted.state.events.append(event)
	interrupted.state.revision+=1
	check(interrupted.save(),"Authored interruption fixture")
	do(interrupted,"learn","alchemy")
	check(interrupted.advance(2) and interrupted.state.day==1 and interrupted.state.actions.back().status=="paused","Stops at actual event day")
	interrupted=reload(interrupted)
	check(not interrupted.confirm(Simulation.preview(interrupted.state,1,0),"illegal-parallel"),"Paused personal control excludes a second occupation")
	check(interrupted.resume(interrupted.state.actions.back().id,"resume-lesson"),"Resolve interruption without repaying")
	finish(interrupted)
	check(interrupted.state.materials.wallet==68 and interrupted.state.soul.mastery["alchemy.materials"]==1,"Resumed education keeps original cost and duration")
	# A mortal personal teacher stops training; a workshop follows its contract.
	var mortal := fresh("mortal-teacher")
	do(mortal,"buy","lo.treatise")
	practice(mortal,WorldCalendar.ordinal(58))
	do(mortal,"learn","herbalism")
	finish(mortal)
	check(mortal.state.day==WorldCalendar.ordinal(60) and not mortal.state.person(MaterialWorld.MENTOR).alive and not SedgeWorld.qualified(mortal.state),"Teacher death stops unfinished personal learning on that date")
	check(mortal.state.materials.jobs.back().status=="stopped" and mortal.state.materials.wallet==60,"Stopped lesson retains payment and partial progress")
	check(not mortal.material("learn","herbalism"),"Dead mentor cannot offer teaching")
	var workshop := fresh("mortal-workshop")
	prepare(workshop)
	check(workshop.reload(),"Read workshop education")
	do(workshop,"extract","root.careful")
	practice(workshop,WorldCalendar.ordinal(60)-10-workshop.state.day)
	do(workshop,"recipe.order",first(workshop,"root_part"))
	var lasting_order: String=workshop.state.materials.jobs.back().id
	practice(workshop,30)
	check(not workshop.state.person(MaterialWorld.MENTOR).alive and MaterialWorld.job(workshop.state,lasting_order).status=="ready","Workshop continues through staff mortality under disclosed terms")
	do(workshop,"visit")
	do(workshop,"claim",lasting_order)
	# World readiness is independent of travel/visits and wait partition.
	var travel := fresh("travel-order")
	prepare(travel)
	check(travel.reload(),"Read travel education")
	do(travel,"extract","root.careful")
	do(travel,"recipe.order",first(travel,"root_part"))
	var continuous:=StateCodec.clone(travel.state)
	var partitioned:=StateCodec.clone(travel.state)
	check(Simulation.confirm(continuous,Simulation.preview(continuous,30,0),"partition-proof")=="" and Simulation.confirm(partitioned,Simulation.preview(partitioned,30,0),"partition-proof")=="","Identical parallel forecasts")
	check(Simulation.step(continuous,30)=="" and Simulation.step(partitioned,10)=="" and Simulation.step(partitioned,20)=="","Single and divided waits")
	check(continuous.materials==partitioned.materials and continuous.day==partitioned.day and continuous.body().practice_days==partitioned.body().practice_days,"Wait partition cannot reroll outcome, readiness or costs")
	var travelling_order: String=travel.state.materials.jobs.back().id
	var depart_day:=travel.state.day
	check(travel.depart(SedgeWorld.route_plan(travel.state)) and travel.advance(5),"Order accompanies route")
	travel=reload(travel)
	check(travel.act("rope") and travel.advance(3),"Resume route with order in progress")
	practice(travel,25)
	check(travel.state.day==depart_day+30 and MaterialWorld.job(travel.state,travelling_order).status=="ready" and not MaterialWorld.job(travel.state,travelling_order).known,"Workshop becomes ready on date while hero is away")
	check(not travel.material("claim",travelling_order),"Cannot collect a remote workshop result")
	check(travel.depart(SedgeWorld.route_plan(travel.state)) and travel.advance(5),"Return with unchanged completed job")
	var remote_state := travel.state.fingerprint()
	check(not travel.material("claim",travelling_order) and travel.state.fingerprint()==remote_state,"Same court is not physical workshop presence")
	travel=reload(travel)
	remote_state=travel.state.fingerprint()
	check(MaterialWorld.claim(travel.state,travelling_order)!="" and travel.state.fingerprint()==remote_state,"Direct domain claim also rejects remote collection after reload")
	check(travel.checkpoint(Vector3(1,0,2.4)),"Walk to workshop")
	do(travel,"visit")
	do(travel,"claim",travelling_order)
	var spare:=first(travel,"root_part")
	var wallet_before: int=travel.state.materials.wallet
	do(travel,"recipe.order",spare)
	var cancelled_order: String=travel.state.materials.jobs.back().id
	check(travel.checkpoint(Vector3(0,0,10)),"Leave workshop with pending order")
	remote_state=travel.state.fingerprint()
	check(not travel.material("cancel",cancelled_order) and travel.state.fingerprint()==remote_state,"Remote cancellation cannot return physical input")
	check(MaterialWorld.cancel(travel.state,cancelled_order)!="" and travel.state.fingerprint()==remote_state,"Direct cancellation guard is atomic")
	travel=reload(travel)
	check(not travel.material("cancel",cancelled_order),"Reload does not grant remote return rights")
	check(travel.checkpoint(Vector3(1,0,2.4)),"Return for cancellation")
	do(travel,"cancel",cancelled_order)
	check(travel.state.materials.wallet==wallet_before-3 and MaterialWorld.item(travel.state,spare).kind=="root_part" and MaterialWorld.item(travel.state,spare).holder==travel.state.body().id,"Immediate order cancellation returns one raw input, keeps paid fee")
	# Check malformed state rejection beyond a checksum.
	var invalid:=StateCodec.clone(travel.state)
	invalid.materials.quartz_left=0
	check(not StateCodec.problems(invalid).is_empty(),"Reject invented/deleted source quantities")
	invalid=StateCodec.clone(travel.state)
	invalid.materials.wallet+=1
	check(not StateCodec.problems(invalid).is_empty(),"Reject money ledger mismatch")
	invalid=StateCodec.clone(travel.state)
	invalid.materials.items.back().parents=[]
	check(not StateCodec.problems(invalid).is_empty(),"Reject duplicated material ancestry")
	# Old slots are preserved, never silently upgraded or overwritten.
	var old := SnapshotStore.new(home,"old",true)
	check(old.save(SedgeWorld.fresh("old")),"Write schema 2")
	var original := FileAccess.get_file_as_string(old.path("current.json"))
	var wrong := SnapshotStore.new(home,"old",true,true)
	check(wrong.load_current().get("incompatible",false) and not wrong.save(MaterialWorld.fresh("old")),"Schema 3 refuses P2 in place")
	check(FileAccess.get_file_as_string(old.path("current.json"))==original,"Old campaign byte preservation")
	# Save failures block commands until exact retry, at every protocol boundary.
	for stage: String in SnapshotStore.STAGES:
		var io := fresh("io-"+stage)
		io.store.fail_at = stage
		check(not io.material("buy","lo.kit") and io.dirty,"Failed checkpoint "+stage)
		check(not io.material("buy","lo.vessel"),"No commands after failed save")
		io.store.fail_at = ""
		check(io.save() and io.reload(),"Exact retry "+stage)
		check(io.state.materials.wallet==76 and io.state.materials.stock["lo.kit"]==0 and MaterialWorld.available(io.state,"kit").size()==1,"Exactly one purchase after retry")
	if errors==0: print("P3_RULE_PASS checks=",checks)
	quit(1 if errors else 0)

func first_unreserved_kind(s: SedgeSession, kind: String) -> String:
	for row: Dictionary in s.state.materials.items:
		if row.kind == kind: return row.id
	return "missing"
