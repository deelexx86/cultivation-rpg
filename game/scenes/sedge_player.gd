class_name SedgePlayer
extends CharacterBody3D

var pivot := Node3D.new()
var arm := SpringArm3D.new()
var actor: Node3D
var locked := false

func _ready() -> void:
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.55
	capsule.radius = 0.32
	collider.shape = capsule
	collider.position.y = 0.78
	add_child(collider)
	actor = SedgeLandscape.model(self,SedgeLandscape.PEOPLE,"character-female-b",Vector3.ZERO,Vector3.ONE*2.4,PI)
	add_child(pivot)
	pivot.position.y = 1.35
	pivot.add_child(arm)
	arm.rotation.x = -0.26
	arm.spring_length = 4.4
	arm.margin = 0.2
	arm.add_excluded_object(get_rid())
	var camera := Camera3D.new()
	camera.fov = 65
	arm.add_child(camera)
	camera.current = true

func _unhandled_input(event: InputEvent) -> void:
	if locked: return
	if event is InputEventMouseMotion and Input.is_action_pressed("orbit_drag"):
		pivot.rotate_y(-event.relative.x*0.006)
		arm.rotation.x = clampf(arm.rotation.x-event.relative.y*0.004,-0.95,0.18)
	if event.is_action_pressed("zoom_in"): arm.spring_length = maxf(2.4,arm.spring_length-0.5)
	if event.is_action_pressed("zoom_out"): arm.spring_length = minf(7,arm.spring_length+0.5)

func _physics_process(delta: float) -> void:
	var motion := Vector2.ZERO
	if not locked:
		pivot.rotate_y(Input.get_axis("orbit_right","orbit_left")*delta*1.9)
		motion = Input.get_vector("move_left","move_right","move_up","move_down")
	var dir := pivot.basis * Vector3(motion.x,0,motion.y)
	var fast := Input.is_action_pressed("sprint")
	# Nominal stride from the scaled leg swing and the 0.50/0.67 s clips.
	var speed := 3.38 if fast else 2.2
	velocity.x = dir.x*speed
	velocity.z = dir.z*speed
	velocity.y = -1.0 if is_on_floor() else velocity.y-18*delta
	move_and_slide()
	var actual := Vector2(get_real_velocity().x,get_real_velocity().z).length()
	if motion.length() > 0.1:
		actor.rotation.y = lerp_angle(actor.rotation.y,atan2(dir.x,dir.z),minf(1,12*delta))
	var clip := "idle" if actual < 0.15 else ("sprint" if fast else "walk")
	SedgeLandscape.play_clip(actor,clip,1.0 if clip == "idle" else clampf(actual/speed,0.4,1.2))
