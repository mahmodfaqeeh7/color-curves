class_name Art
extends RefCounted
## Procedural art helpers for the richer look: generated textures (no image
## files) and shaded-polygon drawing. All shapes are still drawn from their
## exact collision geometry; shading only changes colour, never outline.

static var _ball: ImageTexture
static var _soft: ImageTexture

const LIGHT := Vector3(-0.45, -0.65, 0.62)   ## light from the upper left


## A white shaded sphere (tinted by modulate when drawn): soft body shading,
## a rim of darker colour and a small specular highlight.
static func ball_texture() -> ImageTexture:
	if _ball != null:
		return _ball
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	var l := LIGHT.normalized()
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var d := sqrt(u * u + v * v)
			if d > 1.0:
				img.set_pixel(x, y, Color(1, 1, 1, 0))
				continue
			var z := sqrt(max(0.0, 1.0 - d * d))
			var nn := Vector3(u, v, z)
			var diff: float = clamp(nn.dot(l), 0.0, 1.0)
			var shade := 0.68 + 0.36 * diff
			var spec := pow(clamp(nn.dot((l + Vector3(0, 0, 1)).normalized()), 0.0, 1.0), 40.0) * 0.55
			var c := Color(shade + spec, shade + spec, shade + spec, clamp((1.0 - d) * n * 0.5, 0.0, 1.0))
			img.set_pixel(x, y, c)
	_ball = ImageTexture.create_from_image(img)
	return _ball


## Radial soft blob (white, alpha falls to 0 at the edge) for glows and shadows.
static func soft_texture() -> ImageTexture:
	if _soft != null:
		return _soft
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var d: float = min(1.0, sqrt(u * u + v * v))
			var a := pow(1.0 - d, 2.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_soft = ImageTexture.create_from_image(img)
	return _soft


## Polygon with "gentle volume": lighter at the top, slightly darker at the
## bottom (per-vertex colours), a soft drop shadow and a highlight along the
## upward-facing edges. Outline = exactly the collision polygon.
static func shaded_polygon(ci: CanvasItem, pts: PackedVector2Array, base: Color, shadow := true) -> void:
	if pts.size() < 3:
		return
	var miny := INF
	var maxy := -INF
	for p in pts:
		miny = min(miny, p.y)
		maxy = max(maxy, p.y)
	var h: float = max(1.0, maxy - miny)
	if shadow:
		ci.draw_colored_polygon(_offset(pts, Vector2(1.5, 2.5)), Color(0, 0, 0, 0.2))
		ci.draw_colored_polygon(_offset(pts, Vector2(3.0, 5.0)), Color(0, 0, 0, 0.10))
	var cols := PackedColorArray()
	for p in pts:
		var t := (p.y - miny) / h
		cols.append(base.lerp(Color.WHITE, 0.24 * (1.0 - t)).lerp(Color.BLACK, 0.22 * t))
	ci.draw_polygon(pts, cols)
	# Highlight on edges whose outward normal points up (the lit side).
	var n := pts.size()
	var area := 0.0
	for i in n:
		area += pts[i].x * pts[(i + 1) % n].y - pts[(i + 1) % n].x * pts[i].y
	var sgn := 1.0 if area > 0.0 else -1.0
	var hl := PackedVector2Array()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var e := (b - a)
		var outward := Vector2(e.y, -e.x).normalized() * sgn
		if outward.y < -0.35:
			var inset := -outward * 1.2
			hl.append(a + inset)
			hl.append(b + inset)
	if not hl.is_empty():
		ci.draw_multiline(hl, Color(1, 1, 1, 0.42), 1.5)
	var outline := pts.duplicate()
	outline.append(pts[0])
	ci.draw_polyline(outline, base.darkened(0.35), 1.2, true)


static func _offset(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + d)
	return out


## Vertical gradient rectangle (one draw call).
static func gradient_rect(ci: CanvasItem, r: Rect2, top: Color, bottom: Color) -> void:
	ci.draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]),
		PackedColorArray([top, top, bottom, bottom]))


## Smooth ease-out-back (0..1 -> 0..~1.1 -> 1).
static func ease_back(k: float) -> float:
	k = clamp(k, 0.0, 1.0)
	var c1 := 1.70158
	var c3 := c1 + 1.0
	return 1.0 + c3 * pow(k - 1.0, 3) + c1 * pow(k - 1.0, 2)


static func ease_out(k: float) -> float:
	k = clamp(k, 0.0, 1.0)
	return 1.0 - pow(1.0 - k, 3)
