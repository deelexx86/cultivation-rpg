extends SceneTree

func fixture(kind: String) -> SliceRoute:
	var r := SliceRoute.new()
	r.chamber("smooth-reserve")
	if kind=="infuse": return r
	r.step("infuse")
	r.step("endure")
	r.play("finish")
	if kind=="finish": return r
	r.finish()
	r.trip()
	r.workshop()
	r.play("bury")
	if kind=="death": return r
	Simulation.lose_body(r.state,"combat")
	r.state.revision += 1
	if kind=="transfer": return r
	r.play("transfer")
	# Immediately before the final day, after any world and cache events.
	while r.state.running().duration-r.state.running().progress>1:
		var a := r.state.running()
		r.applied(Simulation.step(r.state,a.duration-a.progress-1),"transit")
	return r

func change(s: CampaignState,kind: String) -> String:
	match kind:
		"infuse","transfer": return SliceWorld.apply(s,kind)
		"death":
			Simulation.lose_body(s,"combat")
			s.revision += 1
			return ""
		_: return Simulation.step(s,s.running().duration-s.running().progress)

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var kind := args[3]
	var r := fixture(kind)
	var store := SnapshotStore.new(args[0],"route",true,true,true,true)
	var before := r.state
	var after := StateCodec.clone(before)
	if r.error!="" or change(after,kind)!="" or StateCodec.clone(after)==null:
		push_error("Invalid crash fixture "+kind+" "+r.error)
		quit(1)
		return
	if args[1]=="write":
		if not store.save(before): push_error(store.last_error); quit(1); return
		store.crash_at = args[2]
		store.save(after)
		quit(2)
		return
	var result := store.load_current()
	var committed := args[2]=="after_main_replace"
	var expected := after if committed else before
	if result.error!="" or result.state.fingerprint()!=expected.fingerprint(): push_error("Torn "+kind); quit(1); return
	var session := SliceSession.new(result.state,store)
	if not committed:
		var candidate := StateCodec.clone(session.state)
		if not session.commit(candidate,change(candidate,kind)): push_error(session.error); quit(1); return
	for i in 2:
		if not session.reload() or session.state.fingerprint()!=after.fingerprint(): push_error("Replay "+kind); quit(1); return
	print("P5_CRASH_RECOVERY_PASS:",kind,":",args[2])
	quit()
