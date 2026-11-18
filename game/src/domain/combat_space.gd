class_name CombatSpace
extends RefCounted
## Geometry interface. The flat fixture is also used by headless rule checks.

func move(_id: String, origin: Vector3, motion: Vector3) -> Vector3:
	var goal := origin + motion
	return Vector3(clampf(goal.x, -24, 24), clampf(goal.y, 0, 12), clampf(goal.z, -24, 24))

func surface(point: Vector3) -> Vector3:
	return Vector3(point.x, 0, point.z) if absf(point.x) <= 24 and absf(point.z) <= 24 else Vector3.INF

func blocked(_from: Vector3, _to: Vector3) -> bool:
	return false

func obstacle_fraction(_from: Vector3, _to: Vector3) -> float:
	return INF

func fits(_id: String, at: Vector3) -> bool:
	return absf(at.x) < 24 and absf(at.z) < 24 and at.y >= 0 and at.y < 12
