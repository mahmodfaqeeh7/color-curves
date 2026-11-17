extends Node
## Local save: settings, per-level best results/stars and planning drawings.
## No account and no network. Results are keyed by level revision + rules.
##
## Crash safety: every write goes to save.json.tmp first, the previous save is
## kept as save.json.bak, and only then is the temp file renamed into place.
## Loading tries save.json, then the backup, so a crash or power cut during a
## write can never lose more than the last change. Old save versions are
## migrated on load. Writes are batched (0.4 s) and flushed when the app is
## paused or closed.

signal settings_changed

const PATH := "user://save.json"
const VERSION := 3
const WRITE_DELAY := 0.4

var settings := {
	"sound": true,           ## master on/off
	"music_vol": 0.6,        ## 0..1 slider
	"sfx_vol": 0.9,          ## 0..1 slider
	"haptics": true,
	"trails": true,
	"ghost": true,           ## last-attempt trace
	"preview": true,         ## dotted launch arc while planning
	"reduced_motion": false,
	"lang": "en",
	"no_ads": false,         ## v1.1: "Remove ads" bought (re-checked with Google Play at start)
}
var levels := {}   ## levelId -> {revision, rulesVersion, stars, best:{...}}
var plans := {}    ## levelId -> {revision, strokes}
var seen := {}     ## onboarding flags: piece types introduced, first-draw guide shown
var hearts := {}   ## v1.2: levelId -> hearts left (only stored while below the maximum)
var path := PATH       ## overridable for tests
var loaded_from := ""   ## "main", "backup" or "" (fresh) - for tests/diagnostics

var _dirty := false
var _timer: Timer


func _ready() -> void:
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.wait_time = WRITE_DELAY
	_timer.timeout.connect(flush)
	add_child(_timer)
	load_data()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT \
			or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		flush()


func load_data() -> void:
	var d = _read(path)
	loaded_from = "main"
	if d == null:
		d = _read(path + ".bak")
		loaded_from = "backup" if d != null else ""
		if d != null:
			push_warning("Save file was damaged; restored from backup")
	if d == null:
		return
	d = migrate(d)
	if typeof(d.get("settings")) == TYPE_DICTIONARY:
		for k in settings.keys():
			if d.settings.has(k) and _same_kind(d.settings[k], settings[k]):
				settings[k] = d.settings[k]
	if typeof(d.get("levels")) == TYPE_DICTIONARY:
		levels = d.levels
	if typeof(d.get("plans")) == TYPE_DICTIONARY:
		plans = d.plans
	if typeof(d.get("seen")) == TYPE_DICTIONARY:
		seen = d.seen
	if typeof(d.get("hearts")) == TYPE_DICTIONARY:
		hearts = d.hearts


## Returns the parsed save dictionary, or null if missing or damaged.
static func _read(path: String) -> Variant:
	var d = LevelData.read_json(path)
	return d if typeof(d) == TYPE_DICTIONARY else null


static func _same_kind(a, b) -> bool:
	var num := [TYPE_INT, TYPE_FLOAT]
	return typeof(a) == typeof(b) or (typeof(a) in num and typeof(b) in num)


## Upgrades older save shapes step by step. Each step is a pure function.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 1))
	if v < 2:
		# v1 had a single "sound" switch; v2 adds music/effects volumes and
		# onboarding flags. Players who had sound off keep it off.
		var st: Dictionary = d.get("settings", {}) if typeof(d.get("settings")) == TYPE_DICTIONARY else {}
		st["music_vol"] = 0.6
		st["sfx_vol"] = 0.9
		d["settings"] = st
		d["seen"] = {}
		v = 2
	if v < 3:
		# v1.2 reworked Chapter 3 (revision 2, rules 3). Players keep the stars
		# they earned there; only their old drawings are dropped (they no longer fit).
		var lv: Dictionary = d.get("levels", {}) if typeof(d.get("levels")) == TYPE_DICTIONARY else {}
		for id in lv:
			if str(id).begins_with("c3_") and typeof(lv[id]) == TYPE_DICTIONARY:
				lv[id]["revision"] = 2
				lv[id]["rulesVersion"] = 3
		d["hearts"] = {}
		v = 3
	d["version"] = v
	return d


## Marks the save dirty and writes it shortly (batches rapid changes).
func save_data() -> void:
	_dirty = true
	if _timer != null and _timer.is_inside_tree():
		_timer.start()
	else:
		flush()


## Writes now if anything changed. Atomic: temp file, keep backup, rename.
func flush() -> void:
	if not _dirty:
		return
	_dirty = false
	write_atomic(path, JSON.stringify({
		"version": VERSION, "settings": settings, "levels": levels, "plans": plans, "seen": seen,
		"hearts": hearts,
	}))


static func write_atomic(path: String, text: String) -> bool:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file")
		return false
	f.store_string(text)
	f.flush()
	var err := f.get_error()
	f.close()
	if err != OK or LevelData.read_json(tmp) == null:
		push_warning("Save write failed verification; keeping the previous save")
		DirAccess.remove_absolute(tmp)
		return false
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path + ".bak"):
			DirAccess.remove_absolute(path + ".bak")
		DirAccess.rename_absolute(path, path + ".bak")
	return DirAccess.rename_absolute(tmp, path) == OK


func set_setting(key: String, value) -> void:
	settings[key] = value
	save_data()
	settings_changed.emit()


func get_setting(key: String):
	return settings.get(key)


## v1.2 hearts: remembered per level until a win or a refill.
func hearts_left(level: Dictionary) -> int:
	return clampi(int(hearts.get(level.levelId, HeartRules.MAX)), 0, HeartRules.MAX)


func set_hearts(level: Dictionary, n: int) -> void:
	if n >= HeartRules.MAX:
		hearts.erase(level.levelId)
	else:
		hearts[level.levelId] = maxi(0, n)
	save_data()


func has_seen(key: String) -> bool:
	return bool(seen.get(key, false))


func mark_seen(key: String) -> void:
	if not has_seen(key):
		seen[key] = true
		save_data()


func _record_key(level: Dictionary) -> bool:
	var rec: Dictionary = levels.get(level.levelId, {})
	return int(rec.get("revision", -1)) == int(level.revision) \
		and int(rec.get("rulesVersion", -1)) == int(level.get("rulesVersion", 1))


func stars(level: Dictionary) -> int:
	if not _record_key(level):
		return 0
	return int(levels[level.levelId].get("stars", 0))


func is_completed(level: Dictionary) -> bool:
	return levels.has(level.levelId) and int(levels[level.levelId].get("stars", 0)) > 0


func best(level: Dictionary) -> Dictionary:
	if not _record_key(level):
		return {}
	return levels[level.levelId].get("best", {})


## Ranked ordering: fewer strokes, then shorter rails (0.01 board widths),
## then fewer balls launched, then fewer ticks.
static func better(a: Dictionary, b: Dictionary) -> bool:
	if b.is_empty():
		return true
	for k in ["strokes", "ink", "launched", "ticks"]:
		if a[k] != b[k]:
			return a[k] < b[k]
	return false


## Stores a winning result. Returns {new_best, stars}.
func record_win(level: Dictionary, result: Dictionary, star_count: int) -> Dictionary:
	var id: String = level.levelId
	if not _record_key(level):
		levels[id] = {"revision": int(level.revision), "rulesVersion": int(level.get("rulesVersion", 1)), "stars": 0, "best": {}}
	var rec: Dictionary = levels[id]
	rec.stars = max(int(rec.stars), star_count)
	var entry := {
		"strokes": int(result.strokes), "ink": int(result.ink_q),
		"launched": int(result.launched), "ticks": int(result.ticks),
	}
	var nb := better(entry, rec.best)
	if nb:
		rec.best = entry
	levels[id] = rec
	save_data()
	return {"new_best": nb, "stars": rec.stars}


func store_plan(level: Dictionary, data: Array) -> void:
	plans[level.levelId] = {"revision": int(level.revision), "strokes": data}
	save_data()


func load_plan(level: Dictionary) -> Array:
	var p = plans.get(level.levelId)
	if typeof(p) != TYPE_DICTIONARY or int(p.get("revision", -1)) != int(level.revision):
		return []
	return PlanState.strokes_from_data(p.get("strokes", []))


func reset_progress() -> void:
	levels = {}
	plans = {}
	seen = {}
	hearts = {}
	save_data()
