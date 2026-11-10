extends SceneTree
## External harness hard-kills this process at each persistence stage.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 3:
		quit(2)
		return
	var store := SnapshotStore.new(args[0], "crash-probe")
	var mode: String = args[1]
	if mode == "write":
		var session := CampaignSession.new(P1Fixture.fresh("crash-probe"), store)
		var plan := Simulation.preview(session.state, 20)
		if not session.confirm(plan, "practice") or not session.advance(5):
			push_error(session.error)
			quit(1)
			return
		store.crash_at = args[2]
		session.advance(5)
		quit(3) # Fault point was not reached.
	else:
		var loaded := store.load_current()
		if loaded.error != "":
			push_error(loaded.error)
			quit(1)
			return
		var state: CampaignState = loaded.state
		var expected := 10 if args[2] == "after_main_replace" else 5
		if state.day != expected or state.actions[0].progress != expected or state.spent != 1 or state.supplies != 19:
			push_error("Mixed crash checkpoint")
			quit(1)
			return
		var session := CampaignSession.new(state, store)
		if not session.advance(30) or not session.reload() or session.state.day != 20 or session.state.spent != 1:
			push_error("Crash recovery did not continue: " + session.error)
			quit(1)
			return
		print("P1_CRASH_RECOVERY_PASS:", args[2], " checkpoint=", expected)
		quit(0)
