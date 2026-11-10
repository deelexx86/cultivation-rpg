class_name SedgeLandscape
extends Node3D

const NATURE := "nature-kit"
const TOWN := "fantasy-town-kit"
const PEOPLE := "mini-characters"
const POINTS := {"merchant":Vector3(-4,0,1), "root":Vector3(6,0,-5), "sign":Vector3(-3,0,-13), "gate":Vector3(0,0,-16), "ferry":Vector3(10,0,4)}
var points: Dictionary = {}
var gate: Node3D
var coin: Node3D
var root_visual: Node3D
var quartz_visuals: Array[Node3D] = []
var stored_vessel: Node3D
var merchant_actor: Node3D
var tutor_actor: Node3D
var merchant_alive := true
var tutor_alive := true

static func model(parent: Node3D, pack: String, id: String, pos: Vector3, size_factor: Vector3, angle: float = 0) -> Node3D:
	var scene := load("res://assets/sedge/%s/%s.glb" % [pack,id]) as PackedScene
	var obj := scene.instantiate() as Node3D
	parent.add_child(obj)
	obj.position = pos
	obj.scale = size_factor
	obj.rotation.y = angle
	return obj

func prop(pack: String, id: String, pos: Vector3, factor: float, angle: float = 0) -> Node3D:
	return model(self,pack,id,pos,Vector3.ONE*factor,angle)

func shape(pos: Vector3, dimensions: Vector3, tint: Color, oval: bool = false) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	if oval:
		var disc := CylinderMesh.new()
		disc.radial_segments = 20
		disc.top_radius = 0.5
		disc.bottom_radius = 0.5
		disc.height = 1
		obj.mesh = disc
	else:
		var box := BoxMesh.new()
		box.size = Vector3.ONE
		obj.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = tint
	mat.roughness = 0.88
	obj.material_override = mat
	add_child(obj)
	obj.position = pos
	obj.scale = dimensions
	return obj

func solid(pos: Vector3, dimensions: Vector3, parent: Node3D = self) -> void:
	var body := StaticBody3D.new()
	parent.add_child(body)
	body.position = pos
	var collider := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = dimensions
	collider.shape = box
	body.add_child(collider)

func populate(s: CampaignState) -> void:
	var far_bank: bool = s.exploration.place == SedgeWorld.BANK
	shape(Vector3(0,-0.55,0),Vector3(160,1,160),Color("#829775"))
	solid(Vector3(0,-0.55,0),Vector3(52,1,52))
	for edge: int in [-1,1]:
		solid(Vector3(edge*25,1,0),Vector3(1,4,51))
		solid(Vector3(0,1,edge*25),Vector3(51,4,1))
	var rng := RandomNumberGenerator.new()
	rng.seed = 894 if far_bank else 593
	for i in 90:
		var angle := rng.randf_range(-PI,PI)
		var r := rng.randf_range(24,65)
		var p := Vector3(cos(angle)*r,-0.15,sin(angle)*r)
		if r > 36 and i % 2 == 0:
			tint(model(self,NATURE,"rock_tallA",p,Vector3(18,rng.randf_range(10,27),19),angle),Color("#546d71"))
		else:
			prop(NATURE,"tree_plateau" if i%3 == 0 else "tree_pineRoundA",p,rng.randf_range(4,10),angle)
	var flooded: bool = s.exploration.source == "flooded"
	shape(Vector3(12,-0.035,-3),Vector3(18 if flooded else 15,0.14 if flooded else 0.09,24 if flooded else 23),Color("#57958c"),true)
	for i in 80:
		var angle := rng.randf_range(0,TAU)
		var p := Vector3(12+7*cos(angle),0,-3+11*sin(angle))
		tint(prop(NATURE,"plant_flatTall" if i%4==0 else "grass",p,rng.randf_range(1.4,3),angle),Color("#83955e") if i%3 else Color("#b6b780"))
	for i in 14:
		var p := Vector3(rng.randf_range(7,16),0.018,rng.randf_range(-11,4))
		shape(p,Vector3(1.6,0.025,0.10),Color("#a6bfb2"),true)
	for i in 34:
		var p := Vector3(rng.randf_range(-23,-12),-0.08,rng.randf_range(-24,21))
		var tall := i%3 == 0
		prop(NATURE,"tree_plateau" if tall else "rock_largeA",p,rng.randf_range(3,5))
		solid(p+Vector3.UP*0.6,Vector3(0.65,1.3,0.65) if tall else Vector3(2.2,1.0,1.9))
	prop(NATURE,"canoe",Vector3(11,0.04,3),3,0.4)
	var ferry_pos := Vector3(0,0,2) if far_bank else POINTS.ferry as Vector3
	points["ferry"] = ferry_pos
	prop(TOWN,"lantern",ferry_pos+Vector3.RIGHT,1.6)
	solid(ferry_pos+Vector3(1,1,0),Vector3(0.4,2,0.4))
	if far_bank:
		points["retreat"] = Vector3(-3,0,0)
		shape(Vector3(0,-0.025,2),Vector3(10,0.06,12),Color("#b9ae89"),true)
		prop(TOWN,"cart",Vector3(-3,0,0),2.5)
		solid(Vector3(-3,0.6,0),Vector3(1.5,1.2,3))
		return
	points = POINTS.duplicate()
	if not s.materials.is_empty():
		points["shop"] = POINTS.merchant
		points.erase("merchant")
		points["mentor"] = Vector3(1,0,2.4)
		points["quartz"] = Vector3(-8,0,-8)
		stored_vessel = shape(Vector3(2,0.45,4),Vector3(0.55,0.9,0.55),Color("#93b4b0"),true)
		tutor_alive = s.person(MaterialWorld.MENTOR).alive
		tutor_actor = prop(PEOPLE,"character-male-f" if tutor_alive else "character-male-b",points.mentor,2.4,-0.8)
		play_clip(tutor_actor,"idle")
		solid(points.mentor+Vector3.UP*0.7,Vector3(0.65,1.4,0.65))
		for i in 6:
			var chip := shape(points.quartz+Vector3(sin(i*2.4)*0.65,0.2+i*0.045,cos(i*2.4)*0.65),Vector3(0.45,0.65,0.45),Color("#c2d8d1"))
			chip.rotation_degrees = Vector3(i*9,i*33,i*13)
			quartz_visuals.append(chip)
		prop(NATURE,"rock_largeA",points.quartz,2.7)
	shape(Vector3(-2,-0.02,3),Vector3(15,0.07,14),Color("#c0aa85"),true)
	shape(Vector3(0,-0.02,-8),Vector3(4,0.055,23),Color("#b8ac90"))
	for x in [-7,4]:
		var z := 1 if x < 0 else 6
		prop(TOWN,"stall-red" if x<0 else "stall-green",Vector3(x,0,z),2.7,PI/2)
		solid(Vector3(x,1,z),Vector3(2.8,2.7,2.8))
		prop(TOWN,"stall-bench",Vector3(x,0,z+2),2,PI/2)
		solid(Vector3(x,0.3,z+2),Vector3(1.9,0.6,0.55))
	prop(TOWN,"cart",Vector3(-7,0,6),2.4,0.4)
	solid(Vector3(-7,0.6,6),Vector3(1.9,1.2,3))
	merchant_alive = s.person(SedgeWorld.LO).alive
	merchant_actor = prop(PEOPLE,"character-male-b" if merchant_alive else "character-male-f",POINTS.merchant,2.4,0.8)
	play_clip(merchant_actor,"idle")
	solid(POINTS.merchant+Vector3.UP*0.7,Vector3(0.65,1.4,0.65))
	for i in 75:
		var pos := Vector3(rng.randf_range(-13,3),0,rng.randf_range(-16,-3))
		if absf(pos.x) > 2.4 and pos.distance_to(POINTS.sign) > 2.1:
			tint(prop(NATURE,"grass",pos,rng.randf_range(0.9,2.0),i),Color("#747e55"))
	for i in 13:
		tint(model(self,NATURE,"rock_largeA",Vector3(sin(i*0.4)*0.32,-0.11,-3-i*0.86),Vector3(2.8,0.58,0.78),0.07*sin(i)),Color("#929585"))
	for i in 11:
		var pos := Vector3(3.8+sin(i*0.7),-0.15,-6-i*0.82)
		tint(prop(NATURE,"rock_largeA",pos,1.8,0.36*i),Color("#777e71"))
	for x in [-3,3]:
		prop(TOWN,"lantern",Vector3(x,0,-4),1.9)
		solid(Vector3(x,1,-4),Vector3(0.5,2,0.5))
	root_visual = Node3D.new()
	add_child(root_visual)
	for i in range(2 if flooded else 7):
		prop(NATURE,"flower_yellowA",POINTS.root+Vector3(sin(i*2.4)*0.55,0,cos(i*2.4)*0.55),2).reparent(root_visual)
	for x in [-4,4]:
		model(self,TOWN,"wall-block",Vector3(x,0,-19),Vector3(2,3.2,7))
		solid(Vector3(x,1.6,-19),Vector3(2,3.2,7))
		model(self,TOWN,"wall-block",Vector3(x*0.7,0,-16),Vector3(2.5,3.2,1))
		solid(Vector3(x*0.7,1.6,-16),Vector3(2.5,3.2,1))
	model(self,TOWN,"wall-block",Vector3(0,0,-22),Vector3(8,3.2,1))
	solid(Vector3(0,1.6,-22),Vector3(8,3.2,1))
	tint(model(self,TOWN,"roof-point",Vector3(0,3.2,-19),Vector3(9,3,8)),Color("#3d6462"))
	tint(model(self,TOWN,"roof-point",Vector3(0,4.3,-19),Vector3(5,2,4)),Color("#3d6462"))
	for x in [-2,2]:
		prop(TOWN,"pillar-stone",Vector3(x,0,-15.4),3.4)
	shape(Vector3(-0.4,-0.018,-14.4),Vector3(18,0.09,1.65),Color("#648c84"))
	for stone in 4:
		tint(model(self,NATURE,"rock_largeA",Vector3(0,-0.07,-13.7-stone*0.42),Vector3(2.9,0.7,0.55)),Color("#929585"))
	prop(TOWN,"watermill",Vector3(-4.8,1.65,-14.7),2.0,PI*0.43)
	solid(Vector3(-4.8,1.6,-14.7),Vector3(3.2,3.2,1.1))
	model(self,TOWN,"stall-bench",Vector3(0,0,-20.5),Vector3(3,3,3),PI/2)
	prop(TOWN,"lantern",Vector3(0,0,-20.5),1.5)
	solid(Vector3(0,0.65,-20.5),Vector3(2.8,1.3,1))
	for x in [-1,1]:
		model(self,TOWN,"pillar-stone",Vector3(9+x,0,3.4),Vector3(2,1.4,2))
	for i in 5:
		model(self,TOWN,"stall-bench",Vector3(9.7,0,3.5+i*0.42),Vector3(2,0.65,3.6),PI/2)
	gate = Node3D.new()
	add_child(gate)
	for x in 5:
		var pos := Vector3((x-2)*0.62,1.5,-16)
		shape(pos,Vector3(0.24,3,0.3),Color("#48534e")).reparent(gate)
	solid(Vector3(0,1.5,-16),Vector3(3.2,3,0.5),gate)
	coin = shape(POINTS.sign+Vector3.UP*0.055,Vector3(0.55,0.12,0.55),Color("#d78643"),true)
	sync(s)

func sync(s: CampaignState) -> void:
	if is_instance_valid(merchant_actor) and merchant_alive != s.person(SedgeWorld.LO).alive:
		merchant_alive = s.person(SedgeWorld.LO).alive
		merchant_actor.queue_free()
		merchant_actor = prop(PEOPLE,"character-male-b" if merchant_alive else "character-male-f",POINTS.merchant,2.4,0.8)
		play_clip(merchant_actor,"idle")
	if not s.materials.is_empty():
		if is_instance_valid(tutor_actor) and tutor_alive != s.person(MaterialWorld.MENTOR).alive:
			tutor_alive = s.person(MaterialWorld.MENTOR).alive
			tutor_actor.queue_free()
			tutor_actor = prop(PEOPLE,"character-male-f" if tutor_alive else "character-male-b",points.mentor,2.4,-0.8)
			play_clip(tutor_actor,"idle")
		if is_instance_valid(stored_vessel):
			stored_vessel.visible = false
			for raw: Dictionary in s.materials.items:
				if raw.kind == "vessel" and raw.holder == "court.cache": stored_vessel.visible = true
		if is_instance_valid(root_visual): root_visual.visible = s.materials.root == "standing"
		for i in quartz_visuals.size(): quartz_visuals[i].visible = i < int(s.materials.quartz_left)
	if is_instance_valid(coin):
		coin.visible = s.exploration.holder == "spillway"
		gate.position.y = -4.0 if s.exploration.gate else 0.0

static func tint(obj: Node3D, color: Color) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	for mesh: MeshInstance3D in obj.find_children("*","MeshInstance3D",true,false):
		mesh.material_override = mat

static func play_clip(actor: Node3D, clip: String, speed: float = 1.0) -> void:
	var anim := actor.find_child("AnimationPlayer",true,false) as AnimationPlayer
	if anim != null and anim.has_animation(clip):
		anim.speed_scale = speed
		if anim.current_animation != clip:
			anim.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			anim.play(clip,0.14)
