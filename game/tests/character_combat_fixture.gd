extends SceneTree
## Prepared campaigns for the exported combat scene, using the actual first breakthrough.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var r := SliceRoute.new("vs-root-whole")
	if args[1] == "foundation":
		r.chamber("condense")
		r.step("infuse")
		r.step("align")
		r.step("finish")
		r.trip()
	r.state.campaign_id = args[0]
	r.state.slice.area = "ravine"
	r.state.combat.actors.hero.pos = CombatState.pack(Vector3(0.5,0,-4.5))
	r.state.combat.actors.hero.qi = 50000
	if r.error != "" or not SliceSession.storage(args[0]).save(r.state):
		push_error("Cannot prepare combat campaign: " + r.error)
		quit(1)
		return
	print("P71_COMBAT_FIXTURE ",args[1])
	quit()
