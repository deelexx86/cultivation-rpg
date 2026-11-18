class_name P4Content
extends RefCounted
## Authored VS-04 fixtures. Positions, timings and costs are prototype tuning.
const HERO := "hero"
const YOUNG := "stone.young"
const HORNED := "stone.horned"
const AIR := "stand.air"
const CROSSING := "route.air"
const AMBUSH := "p4.crossing-ambush"
const START := Vector3(0, 0, -2.8)
const SAFE_Z := -4.0
const SHORT_REFUGE_X := -8.6
const SHORT_EXIT := Vector3(-5.5, 0, -9.0)
const PASSAGE := Vector3(4.4, 0, -14.4)
const WAYPOINT := Vector3(9.2, 0, 4.4)
const RANKS := ["qi", "foundation", "core", "soul"]
const RANK_NAMES := {"qi": "Конденсация Ци", "foundation": "Основание", "core": "Ядро", "soul": "Душа"}
const NAMES := {HERO: "Практик", YOUNG: "Молодой камнеед", HORNED: "Рогатый камнеед", AIR: "Воздушная мишень", CROSSING: "Страж переправы"}
const ACTORS := [HERO, YOUNG, HORNED, AIR, CROSSING]
const HERO_SKILLS := ["strike", "bolt", "seek", "ground", "sphere", "pulse", "sweep", "line", "ward", "guard", "dodge"]
const LABELS := {
	"strike":"Удар", "bolt":"Искра", "seek":"Самонаведение", "ground":"Наземный круг",
	"sphere":"Воздушная сфера", "pulse":"Импульс вокруг", "sweep":"Конус", "line":"Линия", "ward":"Талисман",
	"guard":"Блок", "dodge":"Уклонение", "blink":"Шаг Души", "lunge":"Выпад",
	"crush":"Обвал", "spit":"Воздушный снаряд"
}
# Windup/recovery in world ticks at 60 Hz. Cost in whole Qi.
const ACTIONS := {
	"strike": {"kind":"melee", "wind":23, "rest":31, "qi":0, "range":2.3, "damage":10},
	"bolt": {"kind":"shot", "wind":21, "rest":24, "qi":7, "range":16.0, "damage":15, "speed":9.0, "life":115, "type":"force"},
	"seek": {"kind":"shot", "wind":29, "rest":31, "qi":11, "range":17.0, "damage":19, "speed":8.0, "life":136, "type":"force", "turn":2.5, "load":1},
	"ground": {"kind":"ground", "wind":53, "rest":38, "qi":15, "range":15.0, "damage":28, "radius":2.7, "height":1.7, "type":"shatter", "load":2},
	"sphere": {"kind":"sphere", "wind":43, "rest":32, "qi":14, "range":17.0, "damage":23, "radius":2.1, "type":"force", "load":2},
	"pulse": {"kind":"pulse", "wind":24, "rest":31, "qi":8, "radius":2.35, "damage":14, "type":"force", "load":1},
	"sweep": {"kind":"cone", "wind":26, "rest":24, "qi":6, "range":3.3, "damage":12},
	"line": {"kind":"line", "wind":32, "rest":34, "qi":10, "range":8.0, "damage":16, "type":"force", "load":1},
	"ward": {"kind":"ward", "wind":60, "rest":12, "qi":10, "load":2},
	"guard": {"kind":"guard", "wind":0, "rest":51, "qi":3},
	"dodge": {"kind":"dodge", "wind":0, "rest":27, "qi":5},
	"blink": {"kind":"blink", "wind":18, "rest":40, "qi":16, "range":5.0, "load":2},
	"lunge": {"kind":"melee", "wind":45, "rest":74, "qi":0, "range":2.45, "damage":10},
	"crush": {"kind":"ground", "wind":108, "rest":102, "qi":0, "range":5.3, "damage":35, "radius":2.8, "height":1.9, "type":"heavy"},
	"spit": {"kind":"shot", "wind":96, "rest":80, "qi":0, "range":19.0, "damage":17, "speed":6.6, "life":176, "type":"force"}
}
const VITALS := {
	HERO: {"hp":100, "qi":100, "speed":4.3, "control":4, "stability":15},
	YOUNG: {"hp":30, "qi":0, "speed":2.25, "control":0, "stability":12},
	HORNED: {"hp":80, "qi":0, "speed":2.5, "control":0, "stability":26},
	AIR: {"hp":55, "qi":0, "speed":1.5, "control":0, "stability":17},
	CROSSING: {"hp":30, "qi":0, "speed":1.5, "control":0, "stability":17}
}
const SPAWNS := {YOUNG: Vector3(0.5, 0, -9.2), HORNED: Vector3(-1.4, 0, -15.1), AIR: Vector3(8, 5.2, -9.5)}

static func skills(s: CampaignState) -> Array[String]:
	var result: Array[String] = []
	for id: String in LABELS:
		if s.soul.mastery.get("combat." + id, 0) > 0:
			result.append(id)
	return result
