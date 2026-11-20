extends SceneTree
## Isolated fixture three years before the soul limit, with the first carrier dead.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size()!=1 or not args[0].begins_with("qa-ending-"): quit(2); return
	var store := SliceSession.storage(args[0])
	if FileAccess.file_exists(store.path("current.json")): quit(2); return
	var s := SliceWorld.fresh(args[0],"ending")
	Simulation.lose_body(s,"combat")
	for e: CampaignState.WorldEvent in s.events:
		s.day=e.day
		Simulation.apply_event(s,e)
	s.day=WorldCalendar.ordinal(97)
	s.revision+=1
	if not store.save(s): push_error(store.last_error); quit(1); return
	print("P5_ENDING_FIXTURE")
	quit()
