class_name SliceRoute
extends RefCounted
## Runs the public domain commands, serializing at each boundary.
var state: CampaignState
var error := ""
var checks := 0

func _init(seed_key: String = "vs_smooth_no_overload") -> void:
	state = SliceWorld.fresh("route",seed_key)

func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok and error == "": error = label
	return ok

func applied(result: String,label: String) -> void:
	if error != "": return
	if not check(result == "",label+": "+result): return
	var restored := StateCodec.clone(state)
	if check(restored != null,label+": "+str(StateCodec.problems(state))): state = restored

func material(cmd: String,arg: String) -> void:
	if error == "": applied(MaterialWorld.apply(state,cmd,arg),cmd+"/"+arg)

func play(cmd: String) -> void:
	if error == "": applied(SliceWorld.apply(state,cmd),cmd)

func finish() -> void:
	while error == "" and state.running() != null:
		var a := state.running()
		applied(Simulation.step(state,a.duration-a.progress),a.id)

func step(cmd: String) -> void:
	play(cmd)
	finish()

func trip() -> void:
	if error != "": return
	applied(SedgeWorld.depart(state,SedgeWorld.route_plan(state)),"depart")
	finish()
	if SedgeWorld.active_trip(state) != null:
		applied(SedgeWorld.apply(state,"rope"),"rope")
		finish()

func workshop() -> void:
	state.exploration.x = MaterialWorld.WORKSHOP_POSITION.x
	state.exploration.z = MaterialWorld.WORKSHOP_POSITION.y

func prepare(method: String) -> void:
	workshop()
	for key: String in ["kit","vessel","ward","medicine","treatise"]: material("buy","lo."+key)
	for key: String in ["herbalism","alchemy"]:
		material("learn",key)
		finish()
	applied(SedgeWorld.apply(state,"observe"),"shore")
	material("inspect","root")
	material("extract","root.whole" if method == "condense" else "root.careful")
	material("inspect","quartz")
	material("inspect","quartz")
	for i in (2 if method == "condense" else 1): material("extract","quartz.surface")
	if method != "condense":
		for i in 2:
			material("recipe.stabilize",MaterialWorld.equipment(state,"root_part"))
			finish()
			material("recipe.mature",MaterialWorld.equipment(state,"essence"))
			applied(Simulation.confirm(state,Simulation.preview(state,30,0),"wait."+str(i)),"wait")
			finish()
			material("claim",state.materials.jobs.back().id)
	material("choose",method)

func grow() -> void:
	for i in 3:
		step("gather")
		step("minor")
	step("gather")

func chamber(method: String) -> void:
	prepare(method)
	trip()
	grow()
	play("begin")
