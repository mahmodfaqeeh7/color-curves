extends Node
## Sound and haptics.
##
## Mix: Master <- {Music, SFX, UI}. Every player routes to a bus; the Sound
## setting mutes the buses rather than skipping playback, and the Music and
## Effects sliders set bus gain (slider squared, then dB, so the whole slider
## travel is audible). Music crossfades between a menu loop and a calmer play
## loop, and ducks under the win fanfare. Cues come from the Rawan
## Studio kit (assets/audio); a few extra cues are synthesised. Repeated cues
## get small random pitch/volume offsets so they never sound machine-gunned.

const RATE := 22050
const POOL := 10
## Kit cues peak around -16 dBFS; lift them to a comfortable mobile level
## while keeping > 6 dB of headroom.
const KIT_GAIN_DB := 8.0

## name -> {stream, bus, db, pitch_jitter (semitones), vol_jitter (dB)}
var _cues := {}
var _players: Array = []
var _next := 0
var _last_play_ms := {}


func _ready() -> void:
	_setup_buses()
	for i in POOL:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)
	_kit("launch", "launch.wav", "SFX", 0.0, 0.5)
	_kit("paint", "recolor.wav", "SFX", -1.0, 1.0)
	_kit("capture", "capture.wav", "SFX", 0.0, 0.0)
	_kit("draw", "draw-confirm.wav", "UI", -2.0, 0.8)
	_kit("retry", "retry.wav", "UI", -1.0, 0.0)
	_kit("win", "win.wav", "SFX", 1.0, 0.0)
	_kit("tap", "ui-tap.wav", "UI", -4.0, 0.6)
	_kit("invalid", "invalid.wav", "UI", -2.0, 0.0)
	_synth("bounce", [196.0], 0.06, 0.35, "soft", "SFX", -6.0, 1.5)
	_synth("wrong", [220.0, 207.0], 0.12, 0.22, "soft", "SFX", -6.0, 0.5)
	_synth("lost", [330.0, 247.0], 0.14, 0.2, "soft", "SFX", -8.0, 0.5)
	_synth("fail", [392.0, 330.0, 262.0], 0.36, 0.3, "bell", "SFX", -4.0, 0.0)
	# Phase 2 pieces.
	_synth("split", [660.0, 990.0], 0.14, 0.3, "bell", "SFX", -3.0, 0.6)
	_synth("switch", [196.0, 247.0, 294.0, 392.0], 0.32, 0.3, "soft", "SFX", -2.0, 0.0)
	_synth("flip", [440.0, 554.0, 440.0], 0.16, 0.25, "soft", "SFX", -4.0, 0.0)
	_synth("boost", [330.0, 440.0, 587.0], 0.12, 0.22, "soft", "SFX", -6.0, 0.8)
	_synth("bumper", [523.0], 0.08, 0.35, "bell", "SFX", -4.0, 1.5)
	_synth("unlock", [784.0, 988.0, 1175.0], 0.3, 0.3, "bell", "SFX", -2.0, 0.0)
	_synth("heart", [392.0, 294.0], 0.18, 0.3, "soft", "SFX", -3.0, 0.0)
	# v1.2 pieces.
	_synth("portal", [523.0, 784.0, 1047.0], 0.16, 0.25, "bell", "SFX", -5.0, 0.8)
	_synth("crack", [1760.0, 1320.0], 0.06, 0.25, "bell", "SFX", -6.0, 1.5)
	_synth("shatter", [2093.0, 1568.0, 1175.0, 880.0], 0.22, 0.3, "bell", "SFX", -3.0, 0.5)
	_synth("door", [147.0, 196.0], 0.1, 0.25, "soft", "SFX", -8.0, 0.0)
	_synth("hazard", [233.0, 175.0, 131.0], 0.2, 0.25, "soft", "SFX", -6.0, 0.6)
	_synth("star", [1047.0, 1319.0, 1568.0, 2093.0], 0.32, 0.28, "bell", "SFX", -3.0, 0.0)
	Save.settings_changed.connect(_apply_settings)
	_apply_settings()


func _setup_buses() -> void:
	for bus in ["Music", "SFX", "UI"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	# Safety net against summed peaks: a limiter on Master (not the mixer itself).
	var master := AudioServer.get_bus_index("Master")
	if AudioServer.get_bus_effect_count(master) == 0:
		var lim := AudioEffectHardLimiter.new()
		lim.ceiling_db = -1.0
		AudioServer.add_bus_effect(master, lim)


## Slider 0..1 -> bus gain in dB (squared first; 0 is silent).
static func slider_db(v: float) -> float:
	return linear_to_db(maxf(v * v, 0.0001))


func _apply_settings() -> void:
	var on: bool = Save.get_setting("sound")
	var mv := float(Save.get_setting("music_vol"))
	var sv := float(Save.get_setting("sfx_vol"))
	var mi := AudioServer.get_bus_index("Music")
	AudioServer.set_bus_volume_db(mi, slider_db(mv))
	AudioServer.set_bus_mute(mi, not on or mv <= 0.001)
	for bus in ["SFX", "UI"]:
		var i := AudioServer.get_bus_index(bus)
		AudioServer.set_bus_volume_db(i, slider_db(sv))
		AudioServer.set_bus_mute(i, not on or sv <= 0.001)


# ------------------------------------------------------------------ music

const MUSIC := {"menu": "res://assets/audio/music_menu.ogg", "play": "res://assets/audio/music_play.ogg"}
const MUSIC_DB := -8.0          ## loops are mastered at -6 dBFS peak; sit under the effects
const FADE := 1.2
var _music_players: Array = []
var _music_on := 0
var _music_track := ""
var _duck_tw: Tween


func music(track: String) -> void:
	if track == _music_track:
		return
	_music_track = track
	if _music_players.is_empty():
		for i in 2:
			var mp := AudioStreamPlayer.new()
			mp.bus = "Music"
			add_child(mp)
			_music_players.append(mp)
	var old: AudioStreamPlayer = _music_players[_music_on]
	_music_on = 1 - _music_on
	var cur: AudioStreamPlayer = _music_players[_music_on]
	if old.playing:
		var tw_out := old.create_tween()
		tw_out.tween_property(old, "volume_db", -40.0, FADE)
		tw_out.tween_callback(old.stop)
	if track == "" or not MUSIC.has(track):
		return
	var stream = load(MUSIC[track])
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	cur.stream = stream
	cur.volume_db = -40.0
	cur.play()
	cur.create_tween().tween_property(cur, "volume_db", MUSIC_DB, FADE)


## Dips the music for a moment (e.g. under the win fanfare), then restores it.
func duck(seconds := 2.2, depth_db := 10.0) -> void:
	if _music_players.is_empty():
		return
	var cur: AudioStreamPlayer = _music_players[_music_on]
	if not cur.playing:
		return
	if _duck_tw != null and _duck_tw.is_valid():
		_duck_tw.kill()
	_duck_tw = cur.create_tween()
	_duck_tw.tween_property(cur, "volume_db", MUSIC_DB - depth_db, 0.15)
	_duck_tw.tween_interval(seconds)
	_duck_tw.tween_property(cur, "volume_db", MUSIC_DB, 0.8)


func _kit(name: String, file: String, bus: String, db: float, pitch_jitter: float) -> void:
	var stream = load("res://assets/audio/" + file)
	if stream == null:
		push_warning("missing audio " + file)
		return
	_cues[name] = {"stream": stream, "bus": bus, "db": db + KIT_GAIN_DB, "pj": pitch_jitter, "vj": 1.0}


func _synth(name: String, freqs: Array, dur: float, vol: float, kind: String, bus: String, db: float, pj: float) -> void:
	_cues[name] = {"stream": _tone(freqs, dur, vol, kind), "bus": bus, "db": db, "pj": pj, "vj": 1.5}


func _tone(freqs: Array, dur: float, vol: float, kind: String) -> AudioStreamWAV:
	var n := int(RATE * dur)
	var data := PackedByteArray()
	data.resize(n * 2)
	var seg := float(n) / freqs.size()
	var phase := 0.0
	for i in n:
		var fi := mini(int(i / seg), freqs.size() - 1)
		var f: float = freqs[fi]
		var t := float(i) / RATE
		phase += TAU * f / RATE
		var env: float
		var local := fmod(float(i), seg) / seg
		if kind == "bell":
			env = exp(-local * 4.0) * min(1.0, local * 60.0)
		else:
			env = exp(-t / dur * 5.0) * min(1.0, t * 400.0)
		var s := sin(phase)
		if kind == "bell":
			s = s * 0.8 + sin(phase * 2.0) * 0.2
		data.encode_s16(i * 2, int(clamp(s * env * vol, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	return w


## pitch: base pitch multiplier (e.g. rising capture notes). A per-cue random
## offset is added on top unless jitter is disabled for that cue.
func play(name: String, pitch: float = 1.0, min_gap_ms: int = 0) -> void:
	if not _cues.has(name):
		return
	var now := Time.get_ticks_msec()
	if min_gap_ms > 0 and now - int(_last_play_ms.get(name, -100000)) < min_gap_ms:
		return
	_last_play_ms[name] = now
	var c: Dictionary = _cues[name]
	var p: AudioStreamPlayer = _players[_next]
	_next = (_next + 1) % POOL
	p.stream = c.stream
	p.bus = c.bus
	var semis := randf_range(-c.pj, c.pj)
	p.pitch_scale = pitch * pow(2.0, semis / 12.0)
	p.volume_db = c.db + randf_range(-c.vj, c.vj) * 0.5
	p.play()


func buzz(ms: int = 18) -> void:
	if Save.get_setting("haptics"):
		Input.vibrate_handheld(ms)
