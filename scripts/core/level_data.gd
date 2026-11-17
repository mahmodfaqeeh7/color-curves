class_name LevelData
extends RefCounted
## Loading, shape expansion and validation for declarative level files.
## Level files are plain JSON; nothing in them is ever executed.

const SCHEMA_VERSION := 1
const INDEX_PATH := "res://levels/index.json"

## Limits that protect performance for any level file (also future imports).
const MAX_OBSTACLES := 60
const MAX_POLY_VERTICES := 32
const MAX_LAUNCHERS := 4
const MAX_COLLECTORS := 3
const MAX_SHOTS_PER_LAUNCHER := 20
const SPAWN_CLEARANCE := 22.0
const TYPES := ["neutral", "painter", "gate", "switch", "bumper", "flip", "splitter", "booster", "zone", "rock",
	"poison", "lava", "fan", "conveyor", "glass", "door", "portal", "blackhole", "magnet", "mixer"]
## v1.2 pieces need rulesVersion 3.
const V3_TYPES := ["poison", "lava", "fan", "conveyor", "glass", "door", "portal", "blackhole", "magnet", "mixer"]
const NEW_TYPES := ["gate", "switch", "bumper", "flip", "splitter", "booster", "zone", "rock"]
const SENSOR_TYPES := ["splitter", "booster", "zone"]
const COLLECTOR_CLEARANCE := 6.0

const DEFAULTS := {
	"gravity": [0, 420],
	"runDurationLimit": 45.0,
	"ballLifetime": 20.0,
	"material": {
		"obstacle": {"restitution": 0.5, "friction": 0.6},
		"rail": {"restitution": 0.25, "friction": 0.35},
	},
}


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	return JSON.parse_string(f.get_as_text())


static func level_paths() -> Array:
	var idx = read_json(INDEX_PATH)
	if typeof(idx) != TYPE_DICTIONARY:
		return []
	var out: Array = []
	for name in idx.get("levels", []):
		out.append("res://levels/%s" % name)
	return out


static func load_level(path: String) -> Dictionary:
	var d = read_json(path)
	if typeof(d) != TYPE_DICTIONARY:
		return {}
	return d


static func load_all() -> Array:
	var out: Array = []
	for p in level_paths():
		var lv := load_level(p)
		if not lv.is_empty():
			out.append(lv)
	return out


static func solution_path(level_id: String) -> String:
	return "res://levels/solutions/%s.json" % level_id


static func v2(a) -> Vector2:
	return Vector2(float(a[0]), float(a[1]))


static func board_size(level: Dictionary) -> Vector2:
	var b: Dictionary = level.get("board", {})
	return Vector2(float(b.get("width", 640)), float(b.get("height", 360)))


static func gravity(level: Dictionary) -> Vector2:
	return v2(level.get("gravity", DEFAULTS.gravity))


static func material(level: Dictionary, kind: String) -> Dictionary:
	var m: Dictionary = level.get("material", {})
	var base: Dictionary = DEFAULTS.material[kind].duplicate()
	if m.has(kind):
		base.merge(m[kind], true)
	return base


## Expands an authored obstacle to a closed polygon in board units.
static func polygon_of(o: Dictionary) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var shape: String = o.get("shape", "rect")
	var rot := deg_to_rad(float(o.get("rotation", 0.0)))
	match shape:
		"rect":
			var c := v2(o.center)
			var s := v2(o.size) * 0.5
			for p in [Vector2(-s.x, -s.y), Vector2(s.x, -s.y), Vector2(s.x, s.y), Vector2(-s.x, s.y)]:
				pts.append(c + p.rotated(rot))
		"regular":
			var c := v2(o.center)
			var r := float(o.radius)
			var n := int(o.sides)
			for i in n:
				var a := rot - PI / 2.0 + TAU * i / n
				pts.append(c + Vector2(cos(a), sin(a)) * r)
		"poly":
			for p in o.points:
				pts.append(v2(p))
		_:
			pass
	return pts


## Areas where the player may never draw: launcher spawn circles, collector
## interiors (with clearance) and authored no-draw zones.
static func protected_circles(level: Dictionary) -> Array:
	var out: Array = []
	for l in level.get("launchers", []):
		out.append({"center": v2(l.pos), "radius": SPAWN_CLEARANCE})
	for c in level.get("collectors", []):
		out.append({"center": v2(c.center), "radius": float(c.innerRadius) + COLLECTOR_CLEARANCE})
	for z in level.get("drawingRules", {}).get("forbiddenZones", []):
		if z.has("circle"):
			out.append({"center": v2(z.circle.center), "radius": float(z.circle.radius)})
	return out


static func forbidden_rects(level: Dictionary) -> Array:
	var out: Array = []
	for z in level.get("drawingRules", {}).get("forbiddenZones", []):
		if z.has("rect"):
			var r = z.rect
			out.append(Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3])))
	return out


static func total_capacity(level: Dictionary) -> int:
	var n := 0
	for c in level.get("collectors", []):
		n += int(c.get("requiredCount", 5))
	return n


static func total_supply(level: Dictionary) -> int:
	var n := 0
	for l in level.get("launchers", []):
		n += int(l.get("count", 0))
	return n


static func title(level: Dictionary, lang: String) -> String:
	var t = level.get("title", {})
	if typeof(t) == TYPE_DICTIONARY:
		return str(t.get(lang, t.get("en", level.get("levelId", "?"))))
	return str(t)


static func text(level: Dictionary, key: String, lang: String) -> String:
	var t = level.get(key, {})
	if typeof(t) == TYPE_DICTIONARY:
		return str(t.get(lang, t.get("en", "")))
	return ""


## Structural validation of a level. Returns a list of human-readable errors.
static func validate(level: Dictionary) -> Array:
	var errs: Array = []
	if int(level.get("schemaVersion", 0)) != SCHEMA_VERSION:
		errs.append("schemaVersion must be %d" % SCHEMA_VERSION)
	for k in ["levelId", "revision", "rulesVersion", "launchers", "obstacles", "collectors", "drawingRules"]:
		if not level.has(k):
			errs.append("missing field: %s" % k)
	if not errs.is_empty():
		return errs
	var size := board_size(level)
	var board := Rect2(Vector2.ZERO, size)
	var ids := {}
	var obstacles: Array = level.obstacles
	var splitter_count := 0
	if obstacles.size() > MAX_OBSTACLES:
		errs.append("too many obstacles")
	for o in obstacles:
		var oid := str(o.get("id", ""))
		if oid == "" or ids.has(oid):
			errs.append("obstacle id missing or duplicated: '%s'" % oid)
		ids[oid] = true
		var t := str(o.get("type", ""))
		if not t in TYPES:
			errs.append("%s: unknown type %s" % [oid, t])
		if t in V3_TYPES and int(level.get("rulesVersion", 1)) < 3:
			errs.append("%s: %s needs rulesVersion 3" % [oid, t])
		if t in ["mixer", "magnet"] and not GameColors.is_valid(str(o.get("color", ""))):
			errs.append("%s: %s needs a valid color" % [oid, t])
		if t == "portal" and not o.has("to"):
			errs.append("%s: portal needs to" % oid)
		if t in ["fan"] and not o.has("push"):
			errs.append("%s: fan needs push" % oid)
		if t in ["painter", "gate", "switch"] and not GameColors.is_valid(str(o.get("color", ""))):
			errs.append("%s: %s needs a valid color" % [oid, t])
		if t in NEW_TYPES and int(level.get("rulesVersion", 1)) < 2:
			errs.append("%s: %s needs rulesVersion 2" % [oid, t])
		if t == "switch" and not o.has("move"):
			errs.append("%s: switch needs move" % oid)
		if t == "booster" and not o.has("push"):
			errs.append("%s: booster needs push" % oid)
		if t == "zone" and not o.has("gravity"):
			errs.append("%s: zone needs gravity" % oid)
		if t == "splitter":
			splitter_count += 1
		var poly := polygon_of(o)
		if poly.size() < 3 or poly.size() > MAX_POLY_VERTICES:
			errs.append("%s: polygon needs 3..%d vertices" % [oid, MAX_POLY_VERTICES])
			continue
		if _self_intersects(poly):
			errs.append("%s: polygon self-intersects" % oid)
	var launchers: Array = level.launchers
	if launchers.is_empty() or launchers.size() > MAX_LAUNCHERS:
		errs.append("need 1..%d launchers" % MAX_LAUNCHERS)
	for l in launchers:
		var lid := str(l.get("id", ""))
		if lid == "" or ids.has(lid):
			errs.append("launcher id missing or duplicated: '%s'" % lid)
		ids[lid] = true
		if not board.has_point(v2(l.pos)):
			errs.append("%s: launcher outside board" % lid)
		var cnt := int(l.get("count", 0))
		if cnt < 1 or cnt > MAX_SHOTS_PER_LAUNCHER:
			errs.append("%s: count out of range" % lid)
		for c in l.get("colors", []):
			if not GameColors.is_valid(str(c)):
				errs.append("%s: invalid color %s" % [lid, c])
		if l.get("colors", []).is_empty():
			errs.append("%s: needs colors" % lid)
		for o in obstacles:
			if str(o.get("type", "")) in SENSOR_TYPES:
				continue
			var poly := polygon_of(o)
			if poly.size() >= 3 and _dist_point_poly(v2(l.pos), poly) < 6.0 + 2.0:
				errs.append("%s: spawn overlaps obstacle %s" % [lid, o.id])
	var cols: Array = level.collectors
	if cols.is_empty() or cols.size() > MAX_COLLECTORS:
		errs.append("need 1..%d collectors" % MAX_COLLECTORS)
	for i in cols.size():
		var c = cols[i]
		var cid := str(c.get("id", ""))
		if cid == "" or ids.has(cid):
			errs.append("collector id missing or duplicated: '%s'" % cid)
		ids[cid] = true
		if int(c.get("requiredCount", 0)) != 5:
			errs.append("%s: requiredCount must be 5" % cid)
		if not GameColors.is_valid(str(c.get("targetColor", ""))):
			errs.append("%s: invalid target color" % cid)
		for j in range(i + 1, cols.size()):
			var c2 = cols[j]
			if v2(c.center).distance_to(v2(c2.center)) < float(c.innerRadius) + float(c2.innerRadius):
				errs.append("collectors %s and %s overlap" % [cid, c2.id])
	for c in cols:
		var after := str(c.get("after", ""))
		if after != "" and not cols.any(func(o): return str(o.get("id", "")) == after):
			errs.append("%s: locked behind unknown collector %s" % [c.get("id", "?"), after])
	# Multipliers can double balls (capped at ColorSim.MAX_BALLS on the board).
	var reachable: int = total_supply(level) * int(pow(2, splitter_count))
	if reachable < total_capacity(level):
		errs.append("ball supply below collector capacity")
	var dr: Dictionary = level.drawingRules
	var ink_budget = dr.get("maxInkLength")
	if int(dr.get("maxStrokes", 0)) < 1 and (ink_budget == null or float(ink_budget) <= 0.0):
		errs.append("a level needs a stroke limit or an ink budget")
	return errs


static func _self_intersects(poly: PackedVector2Array) -> bool:
	var n := poly.size()
	for i in n:
		var a1 := poly[i]
		var a2 := poly[(i + 1) % n]
		for j in range(i + 1, n):
			if j == i or (j + 1) % n == i or (i + 1) % n == j:
				continue
			var b1 := poly[j]
			var b2 := poly[(j + 1) % n]
			if Geometry2D.segment_intersects_segment(a1, a2, b1, b2) != null:
				return true
	return false


static func _dist_point_poly(p: Vector2, poly: PackedVector2Array) -> float:
	if Geometry2D.is_point_in_polygon(p, poly):
		return 0.0
	var best := INF
	for i in poly.size():
		var cp := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		best = min(best, p.distance_to(cp))
	return best
