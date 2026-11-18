class_name CombatGeometry
extends CombatSpace
## Godot-space queries for the shared combat clock. Layer 1 is terrain, 2 combatants.
var bodies: Dictionary[String, CharacterBody3D] = {}
var world: World3D

func _init(scene_world: World3D) -> void:
	world = scene_world

func move(id: String, origin: Vector3, motion: Vector3) -> Vector3:
	var body := bodies[id]
	body.position = origin
	var goal := origin + motion
	motion = Vector3(clampf(goal.x, -23.8, 23.8), minf(goal.y, 10.5), clampf(goal.z, -23.8, 23.8)) - origin
	var collision := body.move_and_collide(motion)
	if collision != null:
		body.move_and_collide(collision.get_remainder().slide(collision.get_normal()))
	return body.position

func surface(point: Vector3) -> Vector3:
	if absf(point.x) >= 24 or absf(point.z) >= 24:
		return Vector3.INF
	var result := ray(Vector3(point.x, maxf(point.y + 0.5, 2), point.z), Vector3(point.x, -1.0, point.z))
	if result.is_empty() or result.normal.y < 0.85:
		return Vector3.INF
	return result.position

func ray(from: Vector3, to: Vector3) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	return world.direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1))

func blocked(from: Vector3, to: Vector3) -> bool:
	return not ray(from, to).is_empty()

func obstacle_fraction(from: Vector3, to: Vector3) -> float:
	var intersection := ray(from, to)
	return INF if intersection.is_empty() else from.distance_to(intersection.position) / from.distance_to(to)

func fits(id: String, at: Vector3) -> bool:
	if absf(at.x) >= 24 or absf(at.z) >= 24 or at.y < -0.1 or at.y > 10.5:
		return false
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.34
	capsule.height = 1.45
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform.origin = at + Vector3.UP * 0.79
	query.collision_mask = 3
	query.exclude = [bodies[id].get_rid()]
	return world.direct_space_state.intersect_shape(query, 1).is_empty()
