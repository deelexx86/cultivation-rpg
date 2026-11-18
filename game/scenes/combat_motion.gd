class_name CombatMotion
extends RefCounted
## Presentation only. Each track holds three resolved poses, newest first.

var tracks: Dictionary = {}
var previous_clock := 0.0
var clock := 0.0
var display_tick := 0.0

func reset(tick: int, credit: int) -> void:
	tracks.clear()
	clock = tick + credit / 4.0
	previous_clock = clock
	display_tick = tick - 1.0

func advance_clock(tick: int, credit: int) -> void:
	previous_clock = clock
	clock = tick + credit / 4.0

func capture(id: Variant, at: Vector3, yaw: float = 0.0, snap: bool = false) -> void:
	var pose := Vector4(at.x, at.y, at.z, yaw)
	if snap or not tracks.has(id):
		tracks[id] = [pose, pose, pose]
		return
	var history: Array = tracks[id]
	history[2] = history[1]
	history[1] = history[0]
	history[0] = pose

func erase(id: Variant) -> void:
	tracks.erase(id)

func lookback(physics_fraction: float) -> float:
	# Interpolate the wall-clock physics interval, then show one completed combat
	# tick behind it. Both endpoints exist even when R changes between physics steps.
	var drawn := lerpf(previous_clock, clock, physics_fraction) - 1.0
	display_tick = maxf(display_tick, drawn)
	return clampf(floorf(clock) - display_tick, 0.0, 2.0)

func pose(id: Variant, ticks_back: float) -> Vector4:
	var history: Array = tracks[id]
	var newer := mini(1, int(ticks_back))
	var fraction := ticks_back - newer
	var a: Vector4 = history[newer]
	var b: Vector4 = history[newer + 1]
	var result := a.lerp(b, fraction)
	result.w = lerp_angle(a.w, b.w, fraction)
	return result
