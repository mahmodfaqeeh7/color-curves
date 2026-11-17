class_name PieceInfo
extends RefCounted
## Data for the "New!" piece cards: which pieces a level introduces, and a tiny
## 400 x 225 demo level for each piece. No UI code here (tests use it too).

const KEYS := ["ink", "gate", "switch", "splitter", "rock", "power", "bumper", "booster",
	"locked", "zone", "flip", "float", "sideways", "star", "hearts",
	"poison", "lava", "fan", "conveyor", "glass", "door", "portal", "blackhole", "magnet", "mixer"]


## Which "New!" cards a level needs, in teaching order.
static func keys_in(lv: Dictionary) -> Array:
	var found := {}
	var ink = lv.get("drawingRules", {}).get("maxInkLength")
	if ink != null and float(ink) > 0.0:
		found["ink"] = true
	for o in lv.get("obstacles", []):
		var t := str(o.get("type", ""))
		if t == "zone":
			var g: Array = o.get("gravity", [0, 0])
			found["float" if float(g[0]) == 0.0 and float(g[1]) == 0.0 else "zone"] = true
		elif t in ["gate", "switch", "splitter", "bumper", "flip", "booster", "rock",
				"poison", "lava", "fan", "conveyor", "glass", "door", "portal", "blackhole", "magnet", "mixer"]:
			found[t] = true
	for l in lv.get("launchers", []):
		if l.get("power", false):
			found["power"] = true
	for c in lv.get("collectors", []):
		if c.has("after"):
			found["locked"] = true
	# v1.1 map star: introduced on the first level after the first-draw guide.
	if lv.has("star") and str(lv.get("levelId", "")) != "c1_01":
		found["star"] = true
	if HeartRules.uses_hearts(lv):
		found["hearts"] = true
	var g0: Array = lv.get("gravity", [0, 1])
	if float(g0[0]) != 0.0:
		found["sideways"] = true
	return KEYS.filter(func(k): return found.has(k))


# ------------------------------------------------------------------ demo levels

static func _rect(id: String, c: Vector2, sz: Vector2, rot := 0.0, type := "neutral", extra := {}) -> Dictionary:
	var o := {"id": id, "type": type, "shape": "rect", "center": [c.x, c.y], "size": [sz.x, sz.y], "rotation": rot}
	o.merge(extra)
	return o


static func _launcher(pos: Vector2, vel: Vector2, colors: Array, count := 5, interval := 0.7, power := false) -> Dictionary:
	var l := {"id": "L1", "pos": [pos.x, pos.y], "velocity": [vel.x, vel.y], "ballRadius": 6,
		"colors": colors, "count": count, "interval": interval, "delay": 0.2}
	if power:
		l["power"] = true
	return l


static func _goal(id: String, c: Vector2, color: String, extra := {}) -> Dictionary:
	var g := {"id": id, "center": [c.x, c.y], "innerRadius": 20, "targetColor": color, "requiredCount": 99}
	g.merge(extra)
	return g


static func _base(launchers: Array, obstacles: Array, collectors: Array, extra := {}) -> Dictionary:
	var lv := {
		"schemaVersion": 1, "levelId": "demo", "revision": 1, "rulesVersion": 2, "title": {},
		"difficulty": "intro", "board": {"width": 400, "height": 225}, "gravity": [0, 420],
		"material": {"obstacle": {"restitution": 0.5, "friction": 0.6}, "rail": {"restitution": 0.25, "friction": 0.35}},
		"runDurationLimit": 30, "ballLifetime": 8, "launchers": launchers, "obstacles": obstacles,
		"collectors": collectors,
		"drawingRules": {"maxStrokes": 5, "maxInkLength": null, "minStrokeLength": 12, "railWidth": 6, "forbiddenZones": []},
		"scoring": {"parStrokes": 1}, "tip": {}, "hint": {},
	}
	lv.merge(extra, true)
	# Demo goals ask for every ball, so the demo runs to the end instead of
	# winning (or being judged impossible) after the first capture.
	var total := 0
	for l in launchers:
		total += int(l.count)
	for o in obstacles:
		if o.get("type", "") == "splitter":
			total *= 2
	if extra.has("_delay"):
		for l in launchers:
			l["delay"] = float(extra._delay)
	for c in collectors:
		c["requiredCount"] = maxi(1, int(extra.get("_req", total)))
	return lv


const FLOOR_Y := 200.0
const V3 := {"rulesVersion": 3}


static func _v3(extra: Dictionary) -> Dictionary:
	var d := extra.duplicate()
	d["rulesVersion"] = 3
	return d

static func _floor() -> Dictionary:
	return _rect("F", Vector2(200, FLOOR_Y), Vector2(390, 12), 4.0)


static func level_for(k: String) -> Dictionary:
	var drop := _launcher(Vector2(30, 40), Vector2(90, 0), ["red"], 4)
	match k:
		"gate":
			return _base([_launcher(Vector2(30, 40), Vector2(90, 0), ["red", "blue"], 6, 0.6)],
				[_floor(), _rect("G", Vector2(250, 168), Vector2(12, 52), 0.0, "gate", {"color": "red"})],
				[_goal("C", Vector2(350, 182), "red")])
		"switch":
			return _base([drop],
				[_floor(), _rect("S", Vector2(250, 140), Vector2(12, 112), 0.0, "switch",
					{"color": "red", "move": [0, -120], "speed": 300})],
				[_goal("C", Vector2(350, 182), "red")])
		"splitter":
			return _base([_launcher(Vector2(30, 40), Vector2(160, 0), ["blue"], 3, 1.0)],
				[_floor(), {"id": "X", "type": "splitter", "shape": "regular", "center": [150, 150], "radius": 18, "sides": 3, "rotation": 90}],
				[_goal("C", Vector2(350, 182), "blue")])
		"bumper":
			return _base([_launcher(Vector2(30, 40), Vector2(130, 0), ["red"], 3, 1.2)],
				[{"id": "B", "type": "bumper", "shape": "regular", "center": [133, 197], "radius": 16, "sides": 16, "rotation": 0},
				 _rect("F", Vector2(310, 205), Vector2(170, 12), 4.0)],
				[_goal("C", Vector2(360, 186), "red")])
		"flip":
			return _base([_launcher(Vector2(30, 40), Vector2(90, 0), ["green"], 3, 1.2)],
				[{"id": "K", "type": "rock", "shape": "poly", "points": [[0, 0], [400, 0], [400, 12], [0, 12]]},
				 _rect("P", Vector2(120, 196), Vector2(110, 10), 0.0, "flip")],
				[_goal("C", Vector2(350, 30), "green")])
		"booster":
			return _base([drop],
				[_floor(), _rect("U", Vector2(215, 186), Vector2(80, 26), 4.0, "booster", {"push": [380, -950]})],
				[_goal("C", Vector2(360, 120), "red")])
		"zone":
			return _base([drop],
				[_floor(), {"id": "K", "type": "rock", "shape": "poly", "points": [[0, 0], [400, 0], [400, 12], [0, 12]]},
				 _rect("Z", Vector2(260, 112), Vector2(140, 225), 0.0, "zone", {"gravity": [0, -420], "drag": 0.0})],
				[_goal("C", Vector2(370, 182), "red")])
		"float":
			return _base([_launcher(Vector2(30, 60), Vector2(260, -60), ["red"], 3, 1.2)],
				[_rect("Z", Vector2(270, 112), Vector2(260, 225), 0.0, "zone", {"gravity": [0, 0], "drag": 0.0}),
				 _rect("R", Vector2(318, 150), Vector2(10, 100), 35.0)],
				[_goal("C", Vector2(360, 50), "red")])
		"rock":
			return _base([drop],
				[{"id": "K", "type": "rock", "shape": "poly", "points": [[80, 225], [190, 150], [300, 225]]}],
				[_goal("C", Vector2(360, 200), "red")])
		"power":
			return _base([_launcher(Vector2(30, 200), Vector2(215, -320), ["blue"], 3, 1.2, true)],
				[_rect("F", Vector2(330, FLOOR_Y + 8), Vector2(130, 12), 0.0)],
				[_goal("C", Vector2(360, 180), "blue")], {"maxSpeed": 1200})
		"locked":
			return _base([], [_floor()],
				[_goal("C1", Vector2(150, 140), "red"), _goal("C2", Vector2(270, 140), "blue", {"after": "C1"})])
		"ink":
			return _base([_launcher(Vector2(40, 40), Vector2(70, 0), ["blue"], 3, 1.0)],
				[], [_goal("C", Vector2(345, 178), "blue")],
				{"_demo_rails": [[[50, 75], [120, 105], [200, 135], [270, 155], [320, 165]]]})
		"star":
			return _base([drop], [_floor()], [_goal("C", Vector2(360, 182), "red")],
				{"star": {"pos": [210, 176]}})
		"hearts":
			# A ball that misses: this launch fails and would cost a heart.
			return _base([_launcher(Vector2(30, 60), Vector2(150, 0), ["red"], 3, 1.0)],
				[_rect("F", Vector2(120, 205), Vector2(200, 12), 4.0)],
				[_goal("C", Vector2(350, 120), "red")], {"_req": 1})
		# ---- v1.2 pieces (rules 3)
		"poison":
			return _base([_launcher(Vector2(30, 150), Vector2(150, -60), ["red"], 4, 1.0)],
				[_floor(), _rect("P", Vector2(220, 186), Vector2(90, 16), 4.0, "poison")],
				[_goal("C", Vector2(360, 182), "red")], _v3({"_req": 1}))
		"lava":
			return _base([_launcher(Vector2(40, 40), Vector2(70, 0), ["blue"], 6, 0.7)],
				[_rect("L", Vector2(200, 205), Vector2(150, 40), 0.0, "lava")],
				[_goal("C", Vector2(350, 178), "blue")],
				_v3({"_req": 1, "_delay": 1.1, "_demo_rails": [[[50, 75], [120, 120], [200, 168], [280, 170], [320, 168]]]}))
		"fan":
			return _base([drop],
				[_floor(), _rect("F", Vector2(150, 110), Vector2(120, 200), 0.0, "fan", {"push": [520, 0]})],
				[_goal("C", Vector2(360, 182), "red")], V3)
		"conveyor":
			return _base([_launcher(Vector2(60, 40), Vector2(0, 0), ["green"], 4, 1.0)],
				[_rect("B", Vector2(170, 170), Vector2(260, 14), 0.0, "conveyor", {"speed": 220})],
				[_goal("C", Vector2(350, 190), "green")], V3)
		"glass":
			return _base([_launcher(Vector2(30, 182), Vector2(220, 0), ["yellow"], 5, 0.8)],
				[_floor(), _rect("G", Vector2(230, 150), Vector2(14, 90), 0.0, "glass", {"hits": 2})],
				[_goal("C", Vector2(350, 182), "yellow")], V3)
		"door":
			return _base([_launcher(Vector2(30, 182), Vector2(160, 0), ["red"], 6, 0.6)],
				[_floor(), _rect("D", Vector2(230, 150), Vector2(14, 90), 0.0, "door", {"period": 2.0, "open": 1.0})],
				[_goal("C", Vector2(350, 182), "red")], V3)
		"portal":
			return _base([_launcher(Vector2(40, 40), Vector2(40, 0), ["blue"], 4, 1.0)],
				[{"id": "T", "type": "portal", "shape": "regular", "center": [60, 160], "radius": 18, "sides": 16, "rotation": 0, "to": [300, 60]}],
				[_goal("C", Vector2(305, 182), "blue")], V3)
		"blackhole":
			return _base([_launcher(Vector2(30, 60), Vector2(200, 0), ["green"], 5, 0.8)],
				[{"id": "H", "type": "blackhole", "shape": "regular", "center": [210, 150], "radius": 12, "sides": 16, "rotation": 0, "reach": 90}],
				[_goal("C", Vector2(360, 190), "green")], _v3({"_req": 1}))
		"magnet":
			return _base([_launcher(Vector2(30, 40), Vector2(170, 0), ["red", "blue"], 6, 0.7)],
				[{"id": "M", "type": "magnet", "shape": "regular", "center": [250, 150], "radius": 11, "sides": 16, "rotation": 0, "reach": 120, "color": "red"}],
				[_goal("C", Vector2(255, 185), "red")], _v3({"_req": 2}))
		"mixer":
			return _base([_launcher(Vector2(30, 40), Vector2(120, 0), ["red"], 5, 0.8)],
				[_rect("X", Vector2(170, 150), Vector2(110, 14), 12.0, "mixer", {"color": "yellow"})],
				[_goal("C", Vector2(330, 190), "orange")], V3)
		"sideways":
			return _base([_launcher(Vector2(40, 40), Vector2(0, 60), ["yellow"], 3, 1.2)],
				[_rect("W", Vector2(392, 112), Vector2(12, 225), 0.0)],
				[_goal("C", Vector2(360, 150), "yellow")], {"gravity": [420, 0]})
	return _base([], [_floor()], [])
