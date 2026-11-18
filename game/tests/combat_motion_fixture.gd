extends SceneTree
## An ordinary schema-4 save from which native Windows input starts each sample.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var flight := args[1] == "air"
	var s := CombatState.fresh(args[0], "core" if flight else "qi")
	var c := s.combat
	var hero: Dictionary = c.actors[P4Content.HERO]
	hero.pos = [-800, 3800 if flight else -55, -5800]
	if flight:
		hero.flight = "self"
		hero.velocity = [4500, 0, 0]
	var young: Dictionary = c.actors[P4Content.YOUNG]
	young.pos = [-3800, -55, -9000]
	s.exploration.x = -80
	s.exploration.z = -580
	s.soul.mastery["combat.perception"] = 2 if args[2] == "quarter" else 1
	c.perception = args[2] != "normal"
	c.serial = 1
	c.projectiles.append({
		"id":1, "owner":P4Content.HERO, "target":"", "key":"bolt",
		"pos":[-800, 4700 if flight else 850, -6600], "direction":[1000, 0, 0], "life":100
	})
	var slot := SnapshotStore.new("user://sedge-combat-probe", s.campaign_id, true, true, true)
	if not slot.save(s):
		push_error(slot.last_error)
		quit(1)
		return
	quit(0)
