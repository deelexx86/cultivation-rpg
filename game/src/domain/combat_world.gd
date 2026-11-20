class_name CombatWorld
extends RefCounted
## Shared player/AI actions and one fixed clock. Space queries are supplied by the scene.
const STEP := 1.0 / 60.0
const HERO := P4Content.HERO

static func pos(actor: Dictionary) -> Vector3:
	return CombatState.vec(actor.pos)

static func chest(actor: Dictionary) -> Vector3:
	return pos(actor) + Vector3.UP * 0.78

static func passive(s: CampaignState) -> int:
	return 55 if s.body().alive and s.body().milestone in ["core", "soul"] and s.soul.mastery.has("combat.passive") else 0

static func flight_mode(c: Dictionary) -> String:
	if c.rank in ["core", "soul"]:
		return "self"
	return "artifact" if c.rank == "foundation" and c.artifact else ""

static func flight_load(a: Dictionary) -> int:
	return 2 if a.flight == "artifact" else int(a.flight == "self")

static func control_load(c: Dictionary) -> int:
	var a: Dictionary = c.actors[HERO]
	var total := flight_load(a) + int(c.perception) + (2 if a.shield > 0 else 0)
	if a.action.wind > 0:
		total += int(P4Content.ACTIONS[a.action.key].get("load", 0))
	for shot: Dictionary in c.projectiles:
		if shot.owner == HERO and shot.key == "seek":
			total += 1
	return total

static func control(s: CampaignState) -> int:
	if not s.slice.is_empty(): return s.soul.mental.control
	var c := s.combat
	return int(P4Content.VITALS[HERO].control) + int(c.rank in ["core", "soul"])

static func toggle_perception(s: CampaignState) -> void:
	var c := s.combat
	if c.perception:
		c.perception = false
	elif not s.soul.mastery.has("combat.perception") or control_load(c) >= control(s) or c.actors[HERO].qi <= 0:
		c.notice = "Для восприятия нужны Ци и свободное управление."
	else:
		c.perception = true

static func toggle_flight(s: CampaignState) -> void:
	var c := s.combat
	var a: Dictionary = c.actors[HERO]
	if flight_load(a) > 0:
		a.flight = "glide"
		c.notice = "Снижение. Удерживайте Ctrl для посадки."
		return
	var mode := flight_mode(c)
	var needed := 2 if mode == "artifact" else 1
	if mode == "" or a.qi < 6000 or control_load(c) + needed > control(s) or a.action.key == "dodge":
		c.notice = "Для взлёта нужны подходящая стадия, 6 Ци и свободное управление."
		return
	a.qi -= 6000
	a.flight = mode
	a.velocity = CombatState.pack(Vector3.UP * 4)
	c.meditating = false

static func toggle_meditation(s: CampaignState) -> void:
	var c := s.combat
	if c.meditating:
		c.meditating = false
	elif not s.soul.mastery.has("combat.meditate") or c.actors[HERO].flight != "ground" or c.actors[HERO].action.key != "":
		c.notice = "Для медитации остановитесь и завершите действие на земле."
	else:
		c.meditating = true
		c.notice = "Медитация восстанавливает текущую Ци."

static func submit(s: CampaignState, command: Dictionary) -> void:
	if s.mode == "active" and command.key in P4Content.skills(s):
		s.combat.queued = command

static func refuge(c: Dictionary, point: Vector3) -> bool:
	return point.z >= P4Content.SAFE_Z or (point.x < P4Content.SHORT_REFUGE_X and absf(point.z - P4Content.SHORT_EXIT.z) <= 1.7 and not c.collapse)

static func crossing(s: CampaignState) -> bool:
	var trip := SedgeWorld.active_trip(s)
	return trip != null and trip.status == "paused" and trip.blocker == P4Content.AMBUSH

static func present(s: CampaignState, id: String) -> bool:
	if id == HERO:
		return true
	if crossing(s):
		return id == P4Content.CROSSING
	return id != P4Content.CROSSING and s.exploration.place == SedgeWorld.YARD

static func prepare_crossing(s: CampaignState) -> void:
	var c := s.combat
	var a: Dictionary = c.actors[HERO]
	var origin := P4Content.WAYPOINT if s.exploration.place == SedgeWorld.YARD else Vector3(0, 0, 2)
	a.pos = CombatState.pack(origin + Vector3.UP * 2.7)
	a.velocity = CombatState.ZERO.duplicate()
	a.flight = flight_mode(c)
	a.action = CombatState.action()
	a.shield = 0
	a.shield_ticks = 0
	c.queued = CombatState.order()
	c.perception = false
	c.meditating = false
	c.projectiles.clear()
	var sentinel := CombatState.actor(P4Content.CROSSING, origin + Vector3(4.2, 4.0, -4.7))
	sentinel.flight = "self"
	c.actors[P4Content.CROSSING] = sentinel
	c.notice = "Страж преградил путь. Победите его и нажмите E."

static func engaged(s: CampaignState) -> bool:
	for id: String in s.combat.actors:
		if id != HERO and present(s, id) and s.combat.actors[id].alert and s.combat.actors[id].hp > 0:
			return true
	return not s.combat.projectiles.is_empty()

static func lose_body(s: CampaignState,reason: String = "combat") -> void:
	var c := s.combat
	var a: Dictionary = c.actors[HERO]
	a.hp = 0
	a.action = CombatState.action()
	a.flight = "ground"
	a.velocity = CombatState.ZERO.duplicate()
	c.perception = false
	c.meditating = false
	c.queued = CombatState.order()
	if not s.slice.is_empty():
		SliceWorld.death(s,reason)
		return
	for item: Dictionary in s.materials.items:
		if item.holder == s.body().id:
			item.holder = "p4.corpse"
			item.reserved = ""
	s.materials.method = ""
	s.materials.pledged = 0

static func begin_recovery(s: CampaignState, with_medicine: bool, ribs: bool) -> String:
	var a: Dictionary = s.combat.actors[HERO]
	if (ribs and not a.injury) or (not ribs and a.hp >= SliceWorld.vitals(s).hp) or (with_medicine and (ribs or s.combat.medicine <= 0)):
		return "Лечение сейчас недоступно."
	var days := WorldCalendar.add_years(s.day, 1) - s.day if ribs else (2 if with_medicine else 7)
	var plan := Simulation.preview(s, days, 0, "", 100, 100, "recovery")
	var result := Simulation.confirm(s, plan, "p4.%s.%d" % ["ribs" if ribs else "health", s.revision])
	if result == "" and with_medicine:
		s.combat.medicine -= 1
		if not s.slice.is_empty(): SliceWorld.consume_carried(s,"medicine")
	return result

static func recover(s: CampaignState, operation: String) -> void:
	var a: Dictionary = s.combat.actors[HERO]
	if operation.begins_with("p4.ribs."):
		a.injury = false
		a.heavy_hits = 0
	else:
		a.hp = mini(SliceWorld.vitals(s).hp, int(a.hp) + 50)

static func arrive(s: CampaignState) -> void:
	var c := s.combat
	var a: Dictionary = c.actors[HERO]
	a.pos = CombatState.pack(Vector3(float(s.exploration.x) / 100, 0, float(s.exploration.z) / 100))
	a.velocity = CombatState.ZERO.duplicate()
	a.flight = "ground"
	a.action = CombatState.action()
	c.queued = CombatState.order()
	c.meditating = false
	c.projectiles.clear()

static func claim(s: CampaignState) -> bool:
	if s.mode != "active" or s.exploration.place != SedgeWorld.YARD or engaged(s):
		return false
	var c := s.combat
	for id: String in [P4Content.YOUNG, P4Content.HORNED]:
		var a: Dictionary = c.actors[id]
		if a.loot not in ["intact", "damaged"] or pos(a).distance_to(pos(c.actors[HERO])) > 2.5:
			continue
		var kind := "bone_plate" if id == P4Content.YOUNG else "horn_plate"
		var item_id := MaterialWorld.add_item(s, kind, id)
		MaterialWorld.item(s, item_id).integrity = "damaged" if a.loot == "damaged" else "whole"
		a.loot = "collected"
		c.notice = "Пластина взята."
		s.record("combat:loot:" + id)
		return true
	return false

static func advance(s: CampaignState, space: CombatSpace, direction: Vector3, running: bool = false) -> bool:
	var c := s.combat
	if s.mode != "active":
		return false
	c.credit += (1 if s.soul.mastery.get("combat.perception", 0) == 2 else 2) if c.perception else 4
	if c.credit < 4:
		return false
	c.credit -= 4
	c.tick += 1
	if c.warning_ticks > 0:
		c.warning_ticks -= 1
		if c.warning_ticks == 0:
			c.warning = ""
	var prior := [c.wards, c.collapse, s.mode]
	var hero: Dictionary = c.actors[HERO]
	var before_hp: int = hero.hp
	var before_injury: bool = hero.injury
	var history_size := s.history.size()
	if direction.length_squared() > 0.01:
		c.meditating = false
	flow(s)
	move_actor(s, HERO, space, direction, running)
	step_action(s, HERO, space)
	if c.queued.key != "" and hero.action.key == "" and hero.stagger == 0:
		var command: Dictionary = c.queued
		c.queued = CombatState.order()
		start(s, HERO, command, space)
	for id: String in P4Content.ACTORS:
		if id != HERO and c.actors.has(id) and present(s, id) and s.mode == "active":
			enemy(s, id, space)
	if s.mode == "active":
		projectiles(s, space)
	return prior != [c.wards, c.collapse, s.mode] or hero.hp != before_hp or hero.injury != before_injury or s.history.size() != history_size

static func flow(s: CampaignState) -> void:
	var c := s.combat
	var hero: Dictionary = c.actors[HERO]
	var upkeep := (42 if s.soul.mastery.get("combat.perception", 0) == 2 else 72) if c.perception else 0
	var air_cost := 0
	if hero.flight == "self":
		air_cost = 42 if CombatState.vec(hero.velocity).length() < 10 else 100
	elif hero.flight == "artifact":
		air_cost = 58 if CombatState.vec(hero.velocity).length() < 6 else 104
	var meditation_gain := 310
	if not s.slice.is_empty():
		meditation_gain += (int(CharacterRules.card(s).conductivity)-2)*40
		if c.perception: upkeep -= (int(s.soul.mental.reason)-1)*6
	hero.qi = clampi(int(hero.qi) + passive(s) + (meditation_gain if c.meditating else 0) - upkeep - air_cost, 0, int(SliceWorld.vitals(s).qi) * 1000)
	if hero.qi == 0:
		if c.perception:
			c.perception = false
		if air_cost > 0:
			hero.flight = "glide"
			c.notice = "Ци исчерпана. Аварийное снижение, Ctrl помогает сесть."

static func move_actor(s: CampaignState, id: String, space: CombatSpace, direction: Vector3, running: bool = false) -> void:
	var c := s.combat
	var a: Dictionary = c.actors[id]
	var velocity := CombatState.vec(a.velocity)
	var input := direction.limit_length()
	var at := pos(a)
	var horizontal := Vector3(input.x, 0, input.z)
	var speed: float = P4Content.VITALS[id].speed
	if id == HERO: speed *= CharacterRules.stride(s)
	var movement_locked: bool = a.action.wind > 0 or a.stagger > 0 or (id == HERO and c.meditating)
	if movement_locked:
		input = Vector3.ZERO
		horizontal = Vector3.ZERO
	elif horizontal.length_squared() > 0.01 and a.action.key not in ["guard", "dodge"]:
		a.face = CombatState.pack(horizontal.normalized())
	if a.action.key == "dodge" and a.action.rest > 13:
		var dodge_dir := CombatState.vec(a.action.direction)
		velocity.x = dodge_dir.x * 9.0
		velocity.z = dodge_dir.z * 9.0
	elif a.flight in ["self", "artifact"]:
		var air_speed := 1.5 if id != HERO else (10.0 if a.flight == "self" else 5.8)
		if running and id == HERO:
			air_speed *= 1.6
		velocity = velocity.move_toward(input * air_speed, STEP * 19.0)
	else:
		var factor := 1.35 if running else 1.0
		if a.injury:
			factor *= 0.78
		if a.flight == "glide":
			factor *= 0.72
		velocity.x = horizontal.x * speed * factor
		velocity.z = horizontal.z * speed * factor
	if a.flight == "glide":
		velocity.y = move_toward(velocity.y, -2.8 if input.y < 0 else -5.7, STEP * 12)
	elif a.flight == "ground":
		velocity.y = maxf(-9.0, velocity.y - 18.0 * STEP)
	var motion := velocity * STEP
	var destination := space.move(id, at, motion)
	for axis in 3:
		if absf(motion[axis]) > 0.001 and absf(destination[axis] - at[axis]) < absf(motion[axis]) * 0.6:
			velocity[axis] = 0
			if axis == 1 and motion.y < 0 and a.flight == "glide":
				a.flight = "ground"
	a.pos = CombatState.pack(destination)
	a.velocity = CombatState.pack(velocity)

static func enemy(s: CampaignState, id: String, space: CombatSpace) -> void:
	var c := s.combat
	var a: Dictionary = c.actors[id]
	if a.hp <= 0:
		return
	var hero: Dictionary = c.actors[HERO]
	var delta := chest(hero) - chest(a)
	if id != P4Content.CROSSING and (refuge(c, pos(hero)) or delta.length() > 21.0):
		a.alert = false
		a.action = CombatState.action()
		a.velocity = CombatState.ZERO.duplicate()
		return
	var airborne := id in [P4Content.AIR, P4Content.CROSSING]
	var reach := 11.5 if airborne else (7.0 if id == P4Content.HORNED else 5.8)
	if delta.length() <= reach and not space.blocked(chest(a), chest(hero)):
		if not a.alert and airborne and s.soul.mastery.has("combat.forewarning"):
			c.warning = "Предчувствие · сверху нарастает давление."
			c.warning_ticks = 120
		a.alert = true
	if not a.alert:
		return
	var direction := delta.normalized() if airborne else Vector3(delta.x, 0, delta.z).normalized()
	var key := "spit" if airborne else ("lunge" if id == P4Content.YOUNG else "crush")
	var card: Dictionary = P4Content.ACTIONS[key]
	var moving: bool = a.action.key == "" and delta.length() > (8.0 if airborne else float(card.range) * 0.82)
	if not airborne and absf(delta.y) > 2.4:
		moving = false
	move_actor(s, id, space, direction if moving else Vector3.ZERO)
	step_action(s, id, space)
	if a.action.key == "" and a.stagger == 0 and delta.length() <= card.range:
		start(s, id, CombatState.order(key, HERO, Vector3.ZERO, direction), space)

static func focus(s: CampaignState, id: String, space: CombatSpace, distance: float) -> String:
	var c := s.combat
	var a: Dictionary = c.actors[id]
	var result := ""
	for target: String in P4Content.ACTORS:
		if not present(s, target) or not opponent(c, id, target):
			continue
		var b: Dictionary = c.actors[target]
		var delta := chest(b) - chest(a)
		if delta.length() < distance and delta.normalized().dot(CombatState.vec(a.face)) > 0.15 and not space.blocked(chest(a), chest(b)):
			result = target
			distance = delta.length()
	return result

static func opponent(c: Dictionary, owner: String, target: String) -> bool:
	return target != "" and (owner == HERO) != (target == HERO) and c.actors.has(target) and c.actors[target].hp > 0

static func reject(c: Dictionary, id: String, message: String) -> void:
	if id == HERO:
		c.notice = message

static func start(s: CampaignState, id: String, command: Dictionary, space: CombatSpace) -> void:
	var c := s.combat
	var a: Dictionary = c.actors[id]
	var key: String = command.key
	var card: Dictionary = P4Content.ACTIONS[key]
	var kind: String = card.kind
	var target: String = command.target
	var point := CombatState.vec(command.point)
	var direction := CombatState.vec(command.direction).normalized()
	if direction.is_zero_approx():
		direction = CombatState.vec(a.face)
	if id == HERO and s.exploration.place != SedgeWorld.YARD and not crossing(s) and kind in ["shot", "sphere", "ground", "melee", "cone", "line", "pulse"]:
		reject(c, id, "Боевые цели находятся на торговом берегу.")
		return
	var cost := action_cost(s,key) if id == HERO else int(card.qi)
	if id == HERO and (a.qi < cost * 1000 or control_load(c) + int(card.get("load", 0)) > control(s)):
		reject(c, id, "Не хватает Ци или свободного управления.")
		return
	if kind == "ward" and (c.wards <= 0 or a.shield > 0):
		reject(c, id, "Нет талисмана или щит уже действует.")
		return
	if id == HERO and a.injury and kind in ["sphere", "blink"]:
		reject(c, id, "Повреждённые рёбра мешают сложной технике.")
		return
	if kind == "melee" and target == "":
		target = focus(s, id, space, card.range)
	if kind in ["melee", "shot", "sphere"] and not opponent(c, id, target):
		reject(c, id, "Нужна доступная цель.")
		return
	if target != "" and (not present(s, target) or not opponent(c, id, target)):
		reject(c, id, "Выбранная цель больше недоступна.")
		return
	if kind == "pulse":
		point = chest(a)
	if target != "":
		var other: Dictionary = c.actors[target]
		point = chest(other)
		if point.distance_to(chest(a)) > float(card.get("range", 20.0)) or space.blocked(chest(a), point):
			reject(c, id, "Цель вне дальности или за укрытием.")
			return
		var toward := (point - chest(a)).normalized()
		if not toward.is_zero_approx():
			direction = toward
	if kind == "ground":
		point = space.surface(point)
		if not point.is_finite() or point.distance_to(pos(a)) > card.range:
			reject(c, id, "Подходящая поверхность вне дальности.")
			return
	if kind == "blink" and not blink_allowed(c, id, point, space):
		reject(c, id, "Шаг требует видимой свободной точки в пределах 5 м.")
		return
	if kind == "dodge":
		direction.y = 0
		direction = direction.normalized()
		if not space.fits(id, pos(a) + direction * 0.24):
			reject(c, id, "Нет места для уклонения.")
			return
	var horizontal := Vector3(direction.x, 0, direction.z).normalized()
	if not horizontal.is_zero_approx():
		a.face = CombatState.pack(horizontal)
	a.qi -= cost * 1000
	a.action = {"key":key, "target":target, "center":CombatState.pack(point), "direction":CombatState.pack(direction), "wind":card.wind, "rest":0}
	if id == HERO:
		c.meditating = false
		c.notice = P4Content.LABELS[key]
	if card.wind == 0:
		release(s, id, space)

static func action_cost(s: CampaignState, key: String) -> int:
	if key == "bolt" and not s.slice.is_empty(): return CharacterRules.bolt_cost(s)
	return P4Content.ACTIONS[key].qi

static func blink_allowed(c: Dictionary, id: String, point: Vector3, space: CombatSpace) -> bool:
	var a: Dictionary = c.actors[id]
	return c.rank == "soul" and pos(a).distance_to(point) <= 5.02 and space.fits(id, point) and not space.blocked(chest(a), point + Vector3.UP * 0.78)

static func step_action(s: CampaignState, id: String, space: CombatSpace) -> void:
	var a: Dictionary = s.combat.actors[id]
	a.stagger = maxi(0, int(a.stagger) - 1)
	if a.shield_ticks > 0:
		a.shield_ticks -= 1
		if a.shield_ticks == 0:
			a.shield = 0
	var phase: Dictionary = a.action
	if phase.wind > 0:
		phase.wind -= 1
		if phase.wind == 0:
			release(s, id, space)
	elif phase.rest > 0:
		phase.rest -= 1
		if phase.rest == 0:
			a.action = CombatState.action()

static func release(s: CampaignState, id: String, space: CombatSpace) -> void:
	var c := s.combat
	var a: Dictionary = c.actors[id]
	var phase: Dictionary = a.action
	var card: Dictionary = P4Content.ACTIONS[phase.key]
	var point := CombatState.vec(phase.center)
	var direction := CombatState.vec(phase.direction).normalized()
	phase.rest = card.rest
	match card.kind:
		"ward":
			c.wards -= 1
			if not s.slice.is_empty(): SliceWorld.consume_carried(s,"ward")
			a.shield = 40
			a.shield_ticks = 480
		"blink":
			if blink_allowed(c, id, point, space):
				a.pos = CombatState.pack(point)
				a.velocity = CombatState.ZERO.duplicate()
			else:
				c.notice = "Точка шага закрылась во время подготовки."
		"shot":
			if c.projectiles.size() < CombatState.MAX_PROJECTILES:
				var launch := chest(a)
				var aim := launch.direction_to(point)
				if aim.is_zero_approx():
					aim = direction
				c.serial += 1
				c.projectiles.append({"id":c.serial, "owner":id, "target":phase.target, "key":phase.key, "pos":CombatState.pack(launch), "direction":CombatState.pack(aim), "life":card.life})
		"melee", "ground", "sphere", "cone", "line", "pulse":
			for target: String in P4Content.ACTORS:
				if present(s, target) and opponent(c, id, target) and (card.kind != "melee" or phase.target == target):
					var victim: Dictionary = c.actors[target]
					if overlaps(a, victim, card, point, direction) and not space.blocked(chest(a), chest(victim)):
						hit(s, id, target, card, chest(a))
			if phase.key == "crush" and not c.collapse and point.distance_to(P4Content.SHORT_EXIT) < 3.5:
				c.collapse = true
				c.notice = "Обвал перекрыл короткий выход. Южный путь остаётся открыт."

static func overlaps(a: Dictionary, b: Dictionary, card: Dictionary, point: Vector3, direction: Vector3) -> bool:
	var distance := chest(b) - chest(a)
	match card.kind:
		"melee":
			return distance.length() <= card.range and distance.normalized().dot(direction) >= 0.25
		"ground":
			var offset := chest(b) - point
			return Vector2(offset.x, offset.z).length() <= card.radius and offset.y >= 0 and offset.y <= card.height
		"sphere":
			return chest(b).distance_to(point) <= card.radius
		"pulse":
			return chest(b).distance_to(point) <= card.radius
		"cone":
			return distance.length() <= card.range and distance.normalized().dot(direction) > 0.48
		"line":
			var along := distance.dot(direction)
			return along > 0 and along <= card.range and (distance - direction * along).length() <= 0.95
	return false

static func segment_hit(from: Vector3, to: Vector3, center: Vector3, radius: float) -> float:
	var direction := to - from
	var relative := from - center
	var square := direction.length_squared()
	if square <= 0.0000001:
		return INF
	var c := relative.length_squared() - radius * radius
	if c <= 0:
		return 0.0
	var b := relative.dot(direction)
	var discriminant := b * b - square * c
	if discriminant < 0.0:
		return INF
	var fraction := (-b - sqrt(discriminant)) / square
	return fraction if fraction >= 0.0 and fraction <= 1.0 else INF

static func projectiles(s: CampaignState, space: CombatSpace) -> void:
	var c := s.combat
	var remaining: Array = []
	for shot: Dictionary in c.projectiles:
		if s.mode != "active":
			break
		var card: Dictionary = P4Content.ACTIONS[shot.key]
		var from := CombatState.vec(shot.pos)
		var direction := CombatState.vec(shot.direction).normalized()
		if card.has("turn") and opponent(c, shot.owner, shot.target):
			var goal := chest(c.actors[shot.target])
			if not space.blocked(from, goal):
				var desired := (goal - from).normalized()
				var angle := direction.angle_to(desired)
				if not desired.is_zero_approx() and angle > 0.0001:
					direction = direction.slerp(desired, minf(1, float(card.turn) * STEP / angle)).normalized()
		var to := from + direction * float(card.speed) * STEP
		var nearest := space.obstacle_fraction(from, to)
		var struck := ""
		for target: String in P4Content.ACTORS:
			if not present(s, target) or not opponent(c, shot.owner, target):
				continue
			var fraction := segment_hit(from, to, chest(c.actors[target]), 0.60 if target == HERO else 0.72)
			if fraction < nearest:
				nearest = fraction
				struck = target
		if struck != "":
			var bonus := CharacterRules.bolt_bonus(s) if shot.key == "bolt" and shot.owner == HERO and not s.slice.is_empty() else 0
			hit(s, shot.owner, struck, card, from, bonus)
		elif nearest == INF and shot.life > 1 and maxf(absf(to.x), maxf(absf(to.y), absf(to.z))) <= 26.0:
			shot.life -= 1
			shot.pos = CombatState.pack(to)
			shot.direction = CombatState.pack(direction)
			remaining.append(shot)
	c.projectiles = remaining

static func hit(s: CampaignState, owner: String, id: String, card: Dictionary, source: Vector3, bonus: int = 0) -> void:
	var c := s.combat
	var a: Dictionary = c.actors[id]
	var damage: int = card.damage + bonus
	if owner == HERO and not s.slice.is_empty() and s.slice.unstable > 0:
		damage += 5
		SliceWorld.drain(s)
	if owner == HERO and c.rank in ["core", "soul"]:
		damage += mini(4, damage / 4)
	var kind: String = card.get("type", "plain")
	var incoming := (source - chest(a)).normalized()
	var frontal := CombatState.vec(a.face).dot(incoming)
	c.hits += 1
	if a.action.key == "guard" and a.action.rest > 27 and frontal > 0.45 and kind not in ["heavy", "shatter"]:
		damage = maxi(0, damage - 17)
	if a.shield > 0:
		var shielded := mini(damage, int(a.shield))
		damage -= shielded
		a.shield -= shielded
		if a.shield == 0:
			a.shield_ticks = 0
	if a.armor > 0 and (frontal > -0.15 or a.action.rest == 0):
		if kind in ["force", "shatter"]:
			var absorbed := mini(damage, int(a.armor))
			a.armor -= absorbed
			damage -= absorbed
		else:
			damage = 0
	if id != HERO and kind == "shatter":
		a.damaged = true
	if damage <= 0:
		return
	a.hp = maxi(0, int(a.hp) - damage)
	if id == HERO:
		c.meditating = false
		if kind == "heavy":
			a.heavy_hits += 1
			if a.heavy_hits >= 2:
				a.injury = true
		if (kind == "heavy" or damage >= 28) and a.flight in ["artifact", "self"]:
			a.flight = "glide"
			c.notice = "Тяжёлый удар сорвал полёт."
	var stability := int(P4Content.VITALS[id].stability)
	if id == HERO and not s.slice.is_empty(): stability += (int(s.soul.mental.focus)-2)*4
	if damage >= stability:
		a.stagger = 24
		if a.action.wind > 0:
			a.action = CombatState.action()
			reject(c, id, "Подготовка прервана. Потраченная Ци не возвращается.")
	if a.hp > 0:
		return
	a.action = CombatState.action()
	a.alert = false
	a.flight = "ground"
	a.velocity = CombatState.ZERO.duplicate()
	if id == HERO:
		c.notice = "Тело погибло · " + str(P4Content.NAMES[owner])
		Simulation.lose_body(s, "combat:" + owner)
	else:
		if id in [P4Content.YOUNG, P4Content.HORNED]:
			a.loot = "damaged" if a.damaged else "intact"
		c.notice = "Победа · " + str(P4Content.NAMES[id])
		s.record("combat:defeated:" + id)
