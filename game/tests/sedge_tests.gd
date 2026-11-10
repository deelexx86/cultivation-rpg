extends SceneTree

var errors := 0
var checks := 0
var home := "user://sedge-checks/%s-%s" % [OS.get_process_id(),Time.get_ticks_usec()]

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		errors += 1
		push_error(label)

func fresh(id: String) -> SedgeSession:
	var result := SedgeSession.new(SedgeWorld.fresh(id),SnapshotStore.new(home,id,true))
	check(result.save(),"Create "+id)
	return result

func reopen(previous: SedgeSession) -> SedgeSession:
	var id := previous.state.campaign_id
	var other := SedgeSession.new(SedgeWorld.fresh(id),SnapshotStore.new(home,id,true))
	check(other.reload(),"Fresh reader "+id)
	check(other.state.fingerprint()==previous.state.fingerprint(),"Whole snapshot survived")
	return other

func late(s: SedgeSession) -> void:
	var days := WorldCalendar.ordinal(16)-s.state.day
	check(s.confirm(Simulation.preview(s.state,days,0),"retreat"),"Confirm practice")
	check(s.advance(days),"Process exact mortality date")
	check(not s.state.person(SedgeWorld.LO).alive and s.state.person(SedgeWorld.LO).died==WorldCalendar.ordinal(15),"Lo Wei dies in year 15")

func _initialize() -> void:
	var s := fresh("timely")
	check(s.checkpoint(Vector3(3.54,0,-4.21)),"Save position")
	check(not s.act("interpret"),"Location alone insufficient")
	check(s.act("observe") and s.act("interpret"),"Firsthand evidence and interpretation")
	check(not SedgeWorld.qualified(s.state),"Observation confers no extraction mastery")
	check(s.act("accept") and s.act("take") and s.act("return"),"Return instance while owner lives")
	check(not s.act("return") and s.state.supplies==21 and s.state.day==0,"No duplicate reward or local time")
	s = reopen(s)
	check(s.state.exploration.x==354 and s.state.exploration.z==-421 and s.state.exploration.holder==SedgeWorld.LO,"Restore position and physical custody")
	check(not s.act("gift"),"Separate later meeting")
	var plan := SedgeWorld.route_plan(s.state)
	var signature := s.state.fingerprint()
	check(SedgeWorld.route_plan(s.state)==plan and s.state.fingerprint()==signature,"Forecast pure")
	check(s.depart(plan) and s.advance(5),"Set out")
	var trip := SedgeWorld.active_trip(s.state)
	check(trip.status=="paused" and trip.progress==2 and s.state.day==2 and trip.duration==5,"Actual encounter date and remaining days")
	s = reopen(s)
	check(s.act("rope") and not s.act("rope"),"Resolve once")
	s = reopen(s)
	check(s.advance(3) and s.state.day==5 and s.state.exploration.place=="landing","Arrive at second location")
	check(s.state.exploration.source=="flooded" and s.state.exploration.notes["observe.dry"]==0,"Dated evidence retained after world change")
	check(s.depart(SedgeWorld.route_plan(s.state)) and s.advance(5),"Return without repeating encounter")
	check(s.state.day==10 and s.state.exploration.place=="court","Return costs actual days")
	check(s.act("gift") and s.act("open"),"Transfer same key and open grate")
	s = reopen(s)
	check(s.state.exploration.gate and s.state.exploration.holder=="socket" and not s.act("take"),"One key remains installed")
	var missed := fresh("late")
	check(missed.act("accept"),"Personal promise")
	late(missed)
	check(not missed.act("return") and missed.act("successor") and not missed.state.obligations[0].active,"Successor offers no payment")
	check(missed.act("take") and not missed.act("open") and missed.act("notch") and missed.act("open"),"Independent deduction requires key and clue")
	var estate := fresh("estate")
	check(estate.act("accept") and estate.act("take") and estate.act("return"),"Return before death")
	late(estate)
	estate = reopen(estate)
	check(estate.state.exploration.holder==SedgeWorld.LO and not estate.act("gift") and not estate.act("open"),"Estate keeps physical sign")
	var refused := fresh("refusal")
	check(refused.act("decline") and not refused.act("accept") and refused.state.obligations.is_empty(),"Refusal persists")
	var old := SnapshotStore.new(home,"old")
	check(old.save(P1Fixture.demo("old")),"Write real schema 1")
	var original := FileAccess.get_file_as_string(old.path("current.json"))
	var wrong := SnapshotStore.new(home,"old",true)
	check(wrong.load_current().get("incompatible",false) and not wrong.save(SedgeWorld.fresh("old")),"P2 refuses P1 in place")
	check(FileAccess.get_file_as_string(old.path("current.json"))==original and old.load_current().error=="","P1 remains byte-identical and readable")
	if errors==0: print("P2_RULE_PASS checks=",checks)
	quit(1 if errors else 0)
