class_name GameColors
extends RefCounted
## Stable gameplay color IDs, their display colors and their non-hue symbols.
## Logic always uses the string IDs ("blue", "red", ...), never hex or names.

const IDS := ["blue", "red", "green", "yellow", "orange", "purple"]   ## orange/purple: v1.2 mixers

const HEX := {
	"blue": Color("#69AEFF"),
	"red": Color("#FF767E"),
	"green": Color("#7ED6A3"),
	"yellow": Color("#FFD379"),
	"orange": Color("#FFA45C"),
	"purple": Color("#D88CFF"),
}

## v1.2 mixers: a ball touching a mixer takes the mix of its colour and the
## mixer's. Pairs not listed (same colour, or an unrelated mix) simply take
## the mixer's colour, like a painter.
const MIXES := {
	"red+yellow": "orange", "yellow+red": "orange",
	"blue+red": "purple", "red+blue": "purple",
	"blue+yellow": "green", "yellow+blue": "green",
	# A mixed colour stays mixed when it touches one of its own ingredients
	# again (a ball often bounces twice on the same mixer).
	"orange+red": "orange", "orange+yellow": "orange",
	"purple+red": "purple", "purple+blue": "purple",
	"green+blue": "green", "green+yellow": "green",
}


static func mix(ball: String, mixer: String) -> String:
	return MIXES.get(ball + "+" + mixer, mixer)

const BG := Color("#191622")
const PANEL := Color("#292334")
const PANEL_LIGHT := Color("#3A3248")
const IVORY := Color("#F4EFE6")
const SLATE := Color("#797486")
const ACCENT := Color("#B9A0E5")
const INVALID := Color("#FF4D5A")
const BOARD := Color("#211C2C")


static func is_valid(id: String) -> bool:
	return HEX.has(id)


static func of(id: String) -> Color:
	return HEX.get(id, IVORY)


## Draws the symbol that identifies a color channel without relying on hue.
## blue = dot, red = triangle, green = plus, yellow = diamond,
## orange = square, purple = ring (v1.2).
static func draw_symbol(ci: CanvasItem, id: String, center: Vector2, size: float, col: Color) -> void:
	match id:
		"blue":
			ci.draw_circle(center, size * 0.42, col)
		"red":
			var h := size * 0.5
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -h),
				center + Vector2(h * 0.95, h * 0.72),
				center + Vector2(-h * 0.95, h * 0.72),
			]), col)
		"green":
			var a := size * 0.5
			var t := size * 0.17
			ci.draw_rect(Rect2(center.x - a, center.y - t, a * 2, t * 2), col)
			ci.draw_rect(Rect2(center.x - t, center.y - a, t * 2, a * 2), col)
		"yellow":
			var d := size * 0.55
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -d), center + Vector2(d, 0),
				center + Vector2(0, d), center + Vector2(-d, 0),
			]), col)
		"orange":
			var q := size * 0.4
			ci.draw_rect(Rect2(center.x - q, center.y - q, q * 2, q * 2), col)
		"purple":
			ci.draw_arc(center, size * 0.38, 0, TAU, 20, col, size * 0.2, true)
		_:
			pass
