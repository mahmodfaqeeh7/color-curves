class_name StrokeTools
extends RefCounted
## Turns a raw finger path into a committed rail centreline and validates it.
## The same centreline is used for rendering and for collision.

const DEDUPE_DIST := 1.5
const SIMPLIFY_EPS := 0.6
const MAX_SEG_LEN := 10.0       ## long straight runs are split for nicer joins
const TANGENCY_TOLERANCE := 0.75
const MAX_POINTS_PER_STROKE := 400
const MAX_TOTAL_POINTS := 2000
const MAX_STROKES_HARD := 30    ## technical cap even for "unlimited" levels

## Reason keys (translated by the UI).
const OK := ""
const TOO_SHORT := "too_short"
const OUTSIDE := "outside"
const OBSTACLE := "obstacle"
const PROTECTED := "protected"
const NO_DRAW := "no_draw"
const TOO_COMPLEX := "too_complex"


## The point at distance `d` along a polyline (clamped to its ends).
static func point_at_length(pts: PackedVector2Array, d: float) -> Vector2:
	if pts.is_empty():
		return Vector2.ZERO
	var acc := 0.0
	for j in range(1, pts.size()):
		var seg := pts[j - 1].distance_to(pts[j])
		if acc + seg >= d:
			return pts[j - 1].lerp(pts[j], clampf((d - acc) / maxf(seg, 0.0001), 0.0, 1.0))
		acc += seg
	return pts[pts.size() - 1]


static func path_length(pts: PackedVector2Array) -> float:
	var l := 0.0
	for i in range(1, pts.size()):
		l += pts[i - 1].distance_to(pts[i])
	return l


static func dedupe(raw: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in raw:
		if out.is_empty() or out[out.size() - 1].distance_to(p) >= DEDUPE_DIST:
			out.append(p)
	if raw.size() > 0 and out.size() > 0 and out[out.size() - 1] != raw[raw.size() - 1]:
		out[out.size() - 1] = raw[raw.size() - 1]
	return out


## Conservative jitter smoothing: two passes of a 1-2-1 kernel; ends fixed.
static func smooth(pts: PackedVector2Array, passes: int = 2) -> PackedVector2Array:
	var cur := pts
	for _p in passes:
		if cur.size() < 3:
			return cur
		var nxt := PackedVector2Array()
		nxt.append(cur[0])
		for i in range(1, cur.size() - 1):
			nxt.append((cur[i - 1] + cur[i] * 2.0 + cur[i + 1]) * 0.25)
		nxt.append(cur[cur.size() - 1])
		cur = nxt
	return cur


## Ramer-Douglas-Peucker simplification.
static func simplify(pts: PackedVector2Array, eps: float = SIMPLIFY_EPS) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var keep := PackedByteArray()
	keep.resize(pts.size())
	keep.fill(0)
	keep[0] = 1
	keep[pts.size() - 1] = 1
	var stack: Array = [[0, pts.size() - 1]]
	while not stack.is_empty():
		var rng: Array = stack.pop_back()
		var s: int = rng[0]
		var e: int = rng[1]
		var best := -1.0
		var bi := -1
		for i in range(s + 1, e):
			var cp := Geometry2D.get_closest_point_to_segment(pts[i], pts[s], pts[e])
			var d := pts[i].distance_to(cp)
			if d > best:
				best = d
				bi = i
		if bi >= 0 and best > eps:
			keep[bi] = 1
			stack.append([s, bi])
			stack.append([bi, e])
	var out := PackedVector2Array()
	for i in pts.size():
		if keep[i] == 1:
			out.append(pts[i])
	return out


static func subdivide(pts: PackedVector2Array, max_len: float = MAX_SEG_LEN) -> PackedVector2Array:
	if pts.size() < 2:
		return pts
	var out := PackedVector2Array()
	out.append(pts[0])
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var n := int(ceil(a.distance_to(b) / max_len))
		for k in range(1, n):
			out.append(a.lerp(b, float(k) / n))
		out.append(b)
	return out


## Full pipeline. Returns {ok, points, reason, length}.
## Never silently truncates: a stroke is accepted whole or rejected whole.
static func process(raw: PackedVector2Array, level: Dictionary) -> Dictionary:
	var rules: Dictionary = level.get("drawingRules", {})
	var min_len := float(rules.get("minStrokeLength", 12.0))
	var d := dedupe(raw)
	if d.size() < 2 or path_length(d) < min_len:
		return {"ok": false, "points": d, "reason": TOO_SHORT, "length": path_length(d)}
	var smoothed := simplify(smooth(d))
	var reason := validate(smoothed, level)
	if reason == OK:
		return {"ok": true, "points": smoothed, "reason": OK, "length": path_length(smoothed)}
	# Never smooth a line *into* an obstacle: fall back to the raw path.
	var plain := simplify(d)
	var reason2 := validate(plain, level)
	if reason2 == OK:
		return {"ok": true, "points": plain, "reason": OK, "length": path_length(plain)}
	return {"ok": false, "points": smoothed, "reason": reason2, "length": path_length(smoothed)}


static func half_width(level: Dictionary) -> float:
	return float(level.get("drawingRules", {}).get("railWidth", 6.0)) * 0.5


## Validates a committed centreline as a thick stroke. Returns "" when valid.
static func validate(pts: PackedVector2Array, level: Dictionary) -> String:
	if pts.size() > MAX_POINTS_PER_STROKE:
		return TOO_COMPLEX
	if pts.size() == 1:
		return validate_segment(pts[0], pts[0], level)
	for i in range(pts.size() - 1):
		var r := validate_segment(pts[i], pts[i + 1], level)
		if r != OK:
			return r
	return OK


## Validates one thick segment. Used incrementally while the finger moves.
static func validate_segment(a: Vector2, b: Vector2, level: Dictionary) -> String:
	var hw := half_width(level)
	var size := LevelData.board_size(level)
	for p in [a, b]:
		if p.x < hw or p.y < hw or p.x > size.x - hw or p.y > size.y - hw:
			return OUTSIDE
	for z in LevelData.protected_circles(level):
		var cp := Geometry2D.get_closest_point_to_segment(z.center, a, b)
		if cp.distance_to(z.center) < float(z.radius) + hw:
			return PROTECTED
	for r in LevelData.forbidden_rects(level):
		if _segment_hits_rect(a, b, (r as Rect2).grow(hw)):
			return NO_DRAW
	var tol := hw - TANGENCY_TOLERANCE
	var seg_rect := Rect2(a, Vector2.ZERO).expand(b).grow(hw + 1.0)
	for o in level.get("obstacles", []):
		var t := str(o.get("type", "neutral"))
		if t in ["zone", "fan", "lava", "poison"]:
			continue  # areas you may draw through (lines in lava burn away)
		var poly := LevelData.polygon_of(o)
		if t == "switch":
			# A switch wall's whole travel path is kept clear of rails.
			var moved := poly.duplicate()
			var mv := LevelData.v2(o.move)
			for i in moved.size():
				moved[i] += mv
			var swept := Rect2(poly[0], Vector2.ZERO)
			for q in poly:
				swept = swept.expand(q)
			for q in moved:
				swept = swept.expand(q)
			if _segment_hits_rect(a, b, swept.grow(hw - TANGENCY_TOLERANCE)):
				return OBSTACLE
			continue
		var prect := Rect2(poly[0], Vector2.ZERO)
		for p in poly:
			prect = prect.expand(p)
		if not prect.intersects(seg_rect):
			continue
		if Geometry2D.is_point_in_polygon(a, poly) or Geometry2D.is_point_in_polygon(b, poly):
			return OBSTACLE
		for i in poly.size():
			var c := poly[i]
			var e := poly[(i + 1) % poly.size()]
			var cps := Geometry2D.get_closest_points_between_segments(a, b, c, e)
			if cps[0].distance_to(cps[1]) < tol:
				return OBSTACLE
	return OK


static func _segment_hits_rect(a: Vector2, b: Vector2, r: Rect2) -> bool:
	if r.has_point(a) or r.has_point(b):
		return true
	var c := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in 4:
		if Geometry2D.segment_intersects_segment(a, b, c[i], c[(i + 1) % 4]) != null:
			return true
	return false


## Splits a path at a given length: [kept, rest]. Used when the pen runs dry.
static func split_at_length(pts: PackedVector2Array, max_len: float) -> Array:
	var kept := PackedVector2Array()
	var rest := PackedVector2Array()
	if pts.is_empty():
		return [kept, rest]
	kept.append(pts[0])
	var acc := 0.0
	for i in range(1, pts.size()):
		var a := pts[i - 1]
		var b := pts[i]
		var seg := a.distance_to(b)
		if acc + seg <= max_len:
			kept.append(b)
			acc += seg
			continue
		var cut := a.lerp(b, (max_len - acc) / maxf(seg, 0.0001))
		kept.append(cut)
		rest.append(cut)
		for j in range(i, pts.size()):
			rest.append(pts[j])
		break
	return [kept, rest]


## Distance from a point to a rail (for tap-to-select).
static func distance_to_rail(p: Vector2, pts: PackedVector2Array) -> float:
	if pts.size() == 1:
		return p.distance_to(pts[0])
	var best := INF
	for i in range(pts.size() - 1):
		var cp := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		best = min(best, p.distance_to(cp))
	return best
