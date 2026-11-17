class_name PlanState
extends RefCounted
## The player's drawing during planning: committed rails plus undo/redo.
## Budgets measure committed rails, so undo/delete refund and redo reconsumes.

var max_strokes := 0      ## 0 = unlimited (still capped technically)
var max_ink := 0.0        ## 0 = no ink budget
var strokes: Array = []   ## Array[PackedVector2Array]
var selected := -1
var _undo: Array = []
var _redo: Array = []


func _init(level: Dictionary = {}) -> void:
	var dr: Dictionary = level.get("drawingRules", {})
	max_strokes = int(dr.get("maxStrokes", 0))
	max_ink = float(dr.get("maxInkLength", 0.0)) if dr.get("maxInkLength") != null else 0.0


func stroke_cap() -> int:
	return max_strokes if max_strokes > 0 else StrokeTools.MAX_STROKES_HARD


func used_strokes() -> int:
	return strokes.size()


func used_ink() -> float:
	var l := 0.0
	for s in strokes:
		l += StrokeTools.path_length(s)
	return l


func total_points() -> int:
	var n := 0
	for s in strokes:
		n += s.size()
	return n


## "" when the stroke may be added, otherwise a reason key.
func check_add(pts: PackedVector2Array) -> String:
	if strokes.size() >= stroke_cap():
		return "no_strokes" if max_strokes > 0 else "geometry_cap"
	if max_ink > 0.0 and used_ink() + StrokeTools.path_length(pts) > max_ink + 0.001:
		return "no_ink"
	if total_points() + pts.size() > StrokeTools.MAX_TOTAL_POINTS:
		return "geometry_cap"
	return ""


func add(pts: PackedVector2Array) -> bool:
	if check_add(pts) != "":
		return false
	strokes.append(pts)
	_undo.append({"op": "add", "index": strokes.size() - 1, "points": pts})
	_redo.clear()
	selected = -1
	return true


func delete_at(i: int) -> void:
	if i < 0 or i >= strokes.size():
		return
	var pts: PackedVector2Array = strokes[i]
	strokes.remove_at(i)
	_undo.append({"op": "delete", "index": i, "points": pts})
	_redo.clear()
	selected = -1


func clear() -> void:
	if strokes.is_empty():
		return
	_undo.append({"op": "clear", "strokes": strokes.duplicate()})
	strokes = []
	_redo.clear()
	selected = -1


func can_undo() -> bool:
	return not _undo.is_empty()


func can_redo() -> bool:
	if _redo.is_empty():
		return false
	var a: Dictionary = _redo[_redo.size() - 1]
	if a.op == "add":
		return check_add(a.points) == ""
	return true


func undo() -> void:
	if _undo.is_empty():
		return
	var a: Dictionary = _undo.pop_back()
	match a.op:
		"add":
			strokes.remove_at(a.index)
		"delete":
			strokes.insert(a.index, a.points)
		"clear":
			strokes = a.strokes.duplicate()
	_redo.append(a)
	selected = -1


func redo() -> void:
	if not can_redo():
		return
	var a: Dictionary = _redo.pop_back()
	match a.op:
		"add":
			strokes.insert(a.index, a.points)
		"delete":
			strokes.remove_at(a.index)
		"clear":
			strokes = []
	_undo.append(a)
	selected = -1


## Serialisable form for local save of planning state.
func to_data() -> Array:
	var out: Array = []
	for s in strokes:
		var arr: Array = []
		for p in s:
			arr.append([snappedf(p.x, 0.01), snappedf(p.y, 0.01)])
		out.append(arr)
	return out


static func strokes_from_data(data) -> Array:
	var out: Array = []
	if typeof(data) != TYPE_ARRAY:
		return out
	for s in data:
		if typeof(s) != TYPE_ARRAY:
			continue
		var pts := PackedVector2Array()
		for p in s:
			if typeof(p) == TYPE_ARRAY and p.size() >= 2:
				pts.append(Vector2(float(p[0]), float(p[1])))
		if pts.size() >= 1:
			out.append(pts)
	return out
