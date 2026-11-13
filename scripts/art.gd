extends RefCounted
## Procedural art: palette + static drawing helpers. Everything in the game is
## drawn with these vector primitives; there are no image assets.

const LEVEL_COLORS := [
	Color("f1e2b8"),  # 0 surface
	Color("d9473d"),  # -1 red
	Color("ec8a2e"),  # -2 orange
	Color("e6c13a"),  # -3 yellow
	Color("4caf5c"),  # -4 green
	Color("3d87d8"),  # -5 blue
	Color("9468d6"),  # -6 violet
]
const LEVEL_NAMES := ["OBERFLÄCHE", "EBENE −1", "EBENE −2", "EBENE −3", "EBENE −4", "EBENE −5", "EBENE −6"]
const LEVEL_SUBTITLES := [
	"Krankenhaus · Innenhof · Nacht",
	"Rettungszufahrt",
	"Haustechnik · Heizung",
	"Kurzparker",
	"Baustelle",
	"Besucherparkplatz",
	"Hochwasser · Wienfluss",
]

const CONCRETE := Color("454c55")
const CONCRETE_DARK := Color("2b3138")
const CONCRETE_LIGHT := Color("6a737d")
const BACKWALL := Color("232930")
const SHAFTWALL := Color("1a1f25")
const BARK := Color("4f3727")
const BARK_DARK := Color("33241a")
const BARK_LIGHT := Color("7a5a40")
const LEAF := Color("3f7d3a")
const LEAF_DARK := Color("2b5a2a")
const LEAF_LIGHT := Color("6aa651")
const METAL := Color("9aa7b2")
const METAL_DARK := Color("5d6872")
const PIPE_RED := Color("b8352c")
const PIPE_GRAY := Color("7c8790")
const HOT := Color("ff8a2a")
const IVY := Color("2f6b33")
const OCTO := Color("e8673c")
const LEMON := Color("2f6ff0")
const WOOD := Color("6b3d22")
const WOOD_DARK := Color("432413")

static var _glow: Texture2D
static var _font: Font


static func font() -> Font:
	if _font == null:
		_font = ThemeDB.fallback_font
	return _font


static func glow_tex() -> Texture2D:
	if _glow == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		g.add_point(0.22, Color(1, 1, 1, 0.55))
		g.add_point(0.5, Color(1, 1, 1, 0.16))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		_glow = t
	return _glow


static func glow(ci: CanvasItem, pos: Vector2, radius: float, col: Color) -> void:
	ci.draw_texture_rect(glow_tex(), Rect2(pos - Vector2(radius, radius), Vector2(radius, radius) * 2.0), false, col)


static func glow_rect(ci: CanvasItem, r: Rect2, col: Color) -> void:
	ci.draw_texture_rect(glow_tex(), r, false, col)


static func ellipse_pts(c: Vector2, rx: float, ry: float, rot := 0.0, n := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / float(n)
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry).rotated(rot))
	return pts


static func ellipse(ci: CanvasItem, c: Vector2, rx: float, ry: float, col: Color, rot := 0.0, n := 18) -> void:
	ci.draw_colored_polygon(ellipse_pts(c, rx, ry, rot, n), col)


## Thick tapered stroke drawn as quads + round joints (never fails triangulation).
static func strip(ci: CanvasItem, pts: PackedVector2Array, w0: float, w1: float, col: Color, round_joints := true) -> void:
	var n := pts.size()
	if n < 2:
		return
	for i in n - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var d := b - a
		if d.length_squared() < 0.0001:
			continue
		var t0 := float(i) / float(n - 1)
		var t1 := float(i + 1) / float(n - 1)
		var wa := lerpf(w0, w1, t0) * 0.5
		var wb := lerpf(w0, w1, t1) * 0.5
		var nrm := Vector2(-d.y, d.x).normalized()
		ci.draw_colored_polygon(PackedVector2Array([a + nrm * wa, b + nrm * wb, b - nrm * wb, a - nrm * wa]), col)
		if round_joints and i > 0:
			ci.draw_circle(a, wa, col)
	if round_joints:
		ci.draw_circle(pts[n - 1], maxf(0.5, w1 * 0.5), col)


static func bezier(a: Vector2, c: Vector2, b: Vector2, n := 10) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var t := float(i) / float(n)
		pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
	return pts


static func text(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, width := -1.0) -> void:
	var f := font()
	var w := width
	var p := pos
	if align == HORIZONTAL_ALIGNMENT_CENTER and width < 0.0:
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		p.x -= sz.x * 0.5
		align = HORIZONTAL_ALIGNMENT_LEFT
	ci.draw_string(f, p, s, align, w, size, col)


static func text_outline(ci: CanvasItem, pos: Vector2, s: String, size: int, col: Color, outline: Color, ow := 4) -> void:
	var f := font()
	var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var p := pos - Vector2(sz.x * 0.5, 0)
	ci.draw_string_outline(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ow, outline)
	ci.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


static func rrect(ci: CanvasItem, r: Rect2, col: Color, radius := 6.0, border := 0.0, border_col := Color.BLACK) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(int(radius))
	sb.anti_aliasing = true
	if border > 0.0:
		sb.set_border_width_all(int(border))
		sb.border_color = border_col
	ci.draw_style_box(sb, r)


static func hazard_band(ci: CanvasItem, r: Rect2, a := Color("e8c02c"), b := Color("1b1b1b"), w := 12.0) -> void:
	ci.draw_rect(r, a)
	var x := r.position.x - r.size.y
	var i := 0
	while x < r.end.x:
		if i % 2 == 0:
			var poly := PackedVector2Array([
				Vector2(x, r.end.y), Vector2(x + w, r.end.y),
				Vector2(x + w + r.size.y, r.position.y), Vector2(x + r.size.y, r.position.y)])
			var clip := Geometry2D.intersect_polygons(poly, PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
			for c in clip:
				ci.draw_colored_polygon(c, b)
		x += w
		i += 1


# --- Garage props -------------------------------------------------------------

## Side-view car. pos = floor contact at the car's centre. dir = facing (+1 right).
static func car(ci: CanvasItem, pos: Vector2, dir: float, col: Color, kind := "car", lights := false, reverse := false) -> void:
	ci.draw_set_transform(pos, 0.0, Vector2(dir, 1.0))
	var dark := col.darkened(0.35)
	var glass := Color("8fb3c4").darkened(0.35)
	match kind:
		"van":
			var body := PackedVector2Array([Vector2(-100, -14), Vector2(-100, -92), Vector2(-92, -98), Vector2(50, -98),
				Vector2(70, -86), Vector2(90, -56), Vector2(100, -50), Vector2(100, -14)])
			ci.draw_colored_polygon(body, col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(56, -90), Vector2(70, -84), Vector2(86, -58), Vector2(56, -58)]), glass)
			ci.draw_rect(Rect2(-90, -88, 120, 30), col.lightened(0.08))
			ci.draw_line(Vector2(-100, -40), Vector2(100, -40), dark, 2.0)
			ci.draw_line(Vector2(40, -96), Vector2(40, -16), dark, 1.5)
			_wheel(ci, Vector2(-62, -15), 16)
			_wheel(ci, Vector2(62, -15), 16)
			ci.draw_rect(Rect2(95, -48, 6, 8), Color("ffe9a8"))
			ci.draw_rect(Rect2(-102, -60, 5, 12), Color("c42a22"))
		"ambulance":
			var body2 := PackedVector2Array([Vector2(-120, -14), Vector2(-120, -108), Vector2(-112, -114), Vector2(60, -114),
				Vector2(66, -108), Vector2(66, -76), Vector2(100, -68), Vector2(118, -48), Vector2(120, -14)])
			ci.draw_colored_polygon(body2, Color("f2f2ee"))
			ci.draw_rect(Rect2(-120, -58, 240, 12), Color("e04a1f"))
			ci.draw_rect(Rect2(-120, -44, 240, 5), Color("2a64c8"))
			ci.draw_colored_polygon(PackedVector2Array([Vector2(70, -104), Vector2(70, -74), Vector2(98, -68), Vector2(84, -100)]), glass)
			ci.draw_rect(Rect2(-60, -104, 36, 36), Color("2a64c8"))
			ci.draw_rect(Rect2(-49, -100, 14, 28), Color.WHITE)
			ci.draw_rect(Rect2(-56, -93, 28, 14), Color.WHITE)
			ci.draw_line(Vector2(-10, -112), Vector2(-10, -16), Color("c8c8c4"), 1.5)
			ci.draw_rect(Rect2(-30, -122, 70, 8), Color("2b2f36"))
			_wheel(ci, Vector2(-75, -16), 18)
			_wheel(ci, Vector2(75, -16), 18)
			ci.draw_rect(Rect2(114, -54, 7, 9), Color("ffe9a8"))
			text(ci, Vector2(-100, -66), "RETTUNG", 18, Color("e04a1f"), HORIZONTAL_ALIGNMENT_LEFT)
		_:
			var b := PackedVector2Array([Vector2(-95, -14), Vector2(-95, -42), Vector2(-82, -48), Vector2(-55, -50),
				Vector2(-36, -71), Vector2(24, -72), Vector2(46, -51), Vector2(84, -46), Vector2(95, -36), Vector2(95, -14)])
			ci.draw_colored_polygon(b, col)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(-33, -67), Vector2(-4, -67), Vector2(-4, -51), Vector2(-48, -51)]), glass)
			ci.draw_colored_polygon(PackedVector2Array([Vector2(0, -67), Vector2(21, -68), Vector2(39, -51), Vector2(0, -51)]), glass)
			ci.draw_line(Vector2(-95, -30), Vector2(95, -30), dark, 1.5)
			ci.draw_line(Vector2(-2, -50), Vector2(-2, -16), dark, 1.2)
			ci.draw_rect(Rect2(8, -44, 10, 3), dark)
			_wheel(ci, Vector2(-58, -15), 15)
			_wheel(ci, Vector2(58, -15), 15)
			ci.draw_rect(Rect2(90, -42, 6, 7), Color("ffe9a8"))
			ci.draw_rect(Rect2(-97, -44, 5, 9), Color("c42a22"))
	if lights:
		var front := 95.0 if kind == "car" else (120.0 if kind == "ambulance" else 100.0)
		var hy := -38.0 if kind == "car" else -48.0
		ci.draw_colored_polygon(PackedVector2Array([Vector2(front, hy - 3), Vector2(front + 170, hy - 34), Vector2(front + 170, hy + 30), Vector2(front, hy + 4)]),
			Color(1.0, 0.95, 0.7, 0.13))
	if reverse:
		var back := -95.0 if kind == "car" else (-120.0 if kind == "ambulance" else -100.0)
		ci.draw_circle(Vector2(back - 2, -40), 5, Color(1, 1, 1, 0.9))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _wheel(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, Color("16181b"))
	ci.draw_circle(c, r * 0.55, Color("8a929a"))
	ci.draw_circle(c, r * 0.2, Color("3a3f45"))


static func bucket(ci: CanvasItem, pos: Vector2, active: bool, t: float) -> void:
	# Yellow cleaning trolley bucket with a mop. pos = floor contact.
	var body := PackedVector2Array([pos + Vector2(-22, -40), pos + Vector2(22, -40), pos + Vector2(17, -6), pos + Vector2(-17, -6)])
	ci.draw_colored_polygon(body, Color("e8b52a") if active else Color("b98e2a"))
	ci.draw_rect(Rect2(pos + Vector2(-22, -43), Vector2(44, 5)), Color("f5cf4a") if active else Color("c9a03a"))
	ci.draw_colored_polygon(PackedVector2Array([pos + Vector2(-19, -40), pos + Vector2(19, -40), pos + Vector2(18, -34), pos + Vector2(-18, -34)]),
		Color("4fb3d9") if active else Color("3b7d96"))
	if active:
		ci.draw_line(pos + Vector2(-14, -38 + sin(t * 3.0) * 0.8), pos + Vector2(14, -38 - sin(t * 3.0) * 0.8), Color(1, 1, 1, 0.6), 1.5)
	ci.draw_circle(pos + Vector2(-13, -4), 4, Color("222"))
	ci.draw_circle(pos + Vector2(13, -4), 4, Color("222"))
	ci.draw_line(pos + Vector2(8, -40), pos + Vector2(26, -92), Color("c9c2b0"), 3.0)
	ci.draw_line(pos + Vector2(-22, -30), pos + Vector2(22, -30), Color(0, 0, 0, 0.2), 2.0)
	text(ci, pos + Vector2(0, -15), "WC", 10, Color(0, 0, 0, 0.45))


static func kastanie(ci: CanvasItem, c: Vector2, s := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var r := 9.0 * s * (1.0 + 0.12 * sin(a) - 0.05 * cos(2 * a))
		pts.append(c + Vector2(cos(a) * r * 1.05, sin(a) * r * 0.95))
	ci.draw_colored_polygon(pts, Color("7a3a16"))
	ellipse(ci, c + Vector2(0, 5.5 * s), 6.5 * s, 3.2 * s, Color("cdb38a"))
	ellipse(ci, c + Vector2(-3.5 * s, -3.5 * s), 3.2 * s, 2.0 * s, Color(1, 0.85, 0.7, 0.55), -0.6)
	ci.draw_circle(c + Vector2(-4 * s, -4 * s), 1.2 * s, Color(1, 1, 1, 0.9))


static func pipe(ci: CanvasItem, a: Vector2, b: Vector2, col: Color, ceil_y := -99999.0) -> void:
	if ceil_y > -99999.0:
		var x := minf(a.x, b.x) + 40.0
		while x < maxf(a.x, b.x) - 20.0:
			ci.draw_line(Vector2(x, ceil_y), Vector2(x, a.y - 4), Color("5b636b"), 2.0)
			ci.draw_rect(Rect2(x - 5, a.y - 8, 10, 4), Color("5b636b"))
			x += 140.0
	ci.draw_line(a, b, col.darkened(0.45), 12.0)
	ci.draw_line(a, b, col, 9.0)
	ci.draw_line(a + Vector2(0, -2.5), b + Vector2(0, -2.5), col.lightened(0.35), 2.0)
	var d := (b - a)
	var L := d.length()
	if L > 1.0:
		var u := d / L
		var s := 60.0
		while s < L:
			var p := a + u * s
			ci.draw_rect(Rect2(p - Vector2(3, 7), Vector2(6, 14)), col.darkened(0.25))
			s += 180.0


static func hook(ci: CanvasItem, p: Vector2, ceil_y: float) -> void:
	ci.draw_line(Vector2(p.x, ceil_y), p + Vector2(0, -8), Color("6b7178"), 3.0)
	ci.draw_arc(p, 8.0, 0, TAU, 20, Color("c7a04a"), 3.0)
	ci.draw_arc(p, 8.0, -2.4, -1.6, 6, Color("fff0b0"), 1.5)


static func lamp(ci: CanvasItem, p: Vector2, ceil_y: float, on := true) -> void:
	ci.draw_line(Vector2(p.x - 24, ceil_y), Vector2(p.x - 24, p.y - 5), Color("4c535a"), 1.5)
	ci.draw_line(Vector2(p.x + 24, ceil_y), Vector2(p.x + 24, p.y - 5), Color("4c535a"), 1.5)
	ci.draw_rect(Rect2(p + Vector2(-34, -6), Vector2(68, 9)), Color("8c949b"))
	ci.draw_rect(Rect2(p + Vector2(-31, 1), Vector2(62, 4)), Color("fffbe8") if on else Color("6a6e70"))
	ci.draw_arc(p + Vector2(0, -10), 5.0, 0, TAU, 14, Color("c7a04a"), 2.5)


static func street_lamp(ci: CanvasItem, base: Vector2, top: Vector2) -> void:
	ci.draw_line(base, Vector2(base.x, top.y + 16), Color("2c3a36"), 6.0)
	ci.draw_line(Vector2(base.x, top.y + 16), top + Vector2(0, 2), Color("2c3a36"), 4.0)
	ci.draw_colored_polygon(PackedVector2Array([top + Vector2(-16, 2), top + Vector2(16, 2), top + Vector2(9, -10), top + Vector2(-9, -10)]), Color("2c3a36"))
	ci.draw_rect(Rect2(top + Vector2(-11, 2), Vector2(22, 5)), Color("ffe7a6"))
	ci.draw_arc(top + Vector2(0, -14), 5.0, 0, TAU, 14, Color("c7a04a"), 2.5)


static func ivy(ci: CanvasItem, r: Rect2, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var vines := int(r.size.x / 14.0) + 1
	for v in vines:
		var x := r.position.x + (float(v) + 0.5) * r.size.x / float(vines)
		var pts := PackedVector2Array()
		var y := r.end.y
		while y > r.position.y:
			pts.append(Vector2(x + sin(y * 0.05 + v) * 4.0, y))
			y -= 12.0
		if pts.size() > 1:
			ci.draw_polyline(pts, Color("3a4a22"), 1.5)
	var n := int(r.size.x * r.size.y / 110.0)
	for i in n:
		var p := Vector2(rng.randf_range(r.position.x, r.end.x), rng.randf_range(r.position.y, r.end.y))
		var c := IVY.lerp(LEAF_LIGHT, rng.randf_range(0.0, 0.6)).darkened(rng.randf_range(0.0, 0.3))
		var s := rng.randf_range(3.5, 6.0)
		var rot := rng.randf_range(-0.6, 0.6)
		ci.draw_circle(p + Vector2(-s * 0.6, 0).rotated(rot), s * 0.62, c)
		ci.draw_circle(p + Vector2(s * 0.6, 0).rotated(rot), s * 0.62, c)
		ci.draw_circle(p + Vector2(0, -s * 0.7).rotated(rot), s * 0.7, c)


static func ladder(ci: CanvasItem, r: Rect2) -> void:
	ci.draw_line(Vector2(r.position.x + 6, r.position.y), Vector2(r.position.x + 6, r.end.y), Color("9aa2a8"), 4.0)
	ci.draw_line(Vector2(r.end.x - 6, r.position.y), Vector2(r.end.x - 6, r.end.y), Color("9aa2a8"), 4.0)
	var y := r.end.y - 14.0
	while y > r.position.y:
		ci.draw_line(Vector2(r.position.x + 6, y), Vector2(r.end.x - 6, y), Color("7d868d"), 3.0)
		y -= 22.0


static func sign_box(ci: CanvasItem, center: Vector2, s: String, size: int, bg: Color, fg: Color, pad := Vector2(12, 7)) -> void:
	var f := font()
	var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var r := Rect2(center - Vector2(sz.x * 0.5 + pad.x, size * 0.5 + pad.y), Vector2(sz.x + pad.x * 2, size + pad.y * 2))
	rrect(ci, r, bg, 4.0, 2.0, bg.darkened(0.4))
	ci.draw_string(f, Vector2(r.position.x + pad.x, center.y + size * 0.36), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, fg)


static func net(ci: CanvasItem, x0: float, x1: float, y: float) -> void:
	var col := Color(0.75, 0.72, 0.62, 0.55)
	var pts := PackedVector2Array()
	var x := x0
	while x <= x1 + 0.1:
		var t := (x - x0) / maxf(1.0, x1 - x0)
		pts.append(Vector2(x, y + sin(t * PI) * 6.0))
		x += 12.0
	ci.draw_polyline(pts, col, 2.0)
	for i in range(pts.size() - 1):
		var p := pts[i]
		ci.draw_line(p, p + Vector2(6, 9), Color(col, 0.35), 1.0)
		ci.draw_line(pts[i + 1], pts[i + 1] + Vector2(-6, 9), Color(col, 0.35), 1.0)
	ci.draw_line(Vector2(x0, y + 9), Vector2(x1, y + 9), Color(col, 0.3), 1.0)


static func leaf_cluster(ci: CanvasItem, c: Vector2, size: float, rot: float, rng: RandomNumberGenerator, tint: Color) -> void:
	var leaflets := 5 + rng.randi() % 3
	var spread := 2.3
	var base := LEAF.lerp(LEAF_LIGHT, rng.randf_range(0.0, 0.7)).lerp(tint, 0.25)
	for i in leaflets:
		var a := rot - spread * 0.5 + spread * float(i) / float(leaflets - 1)
		var l := size * (0.75 + 0.3 * (1.0 - absf(float(i) - (leaflets - 1) * 0.5) / (leaflets * 0.5)))
		var col := base.darkened(rng.randf_range(0.0, 0.25))
		ellipse(ci, c + Vector2(cos(a), sin(a)) * l * 0.55, l * 0.55, l * 0.2, col, a, 12)
		ci.draw_line(c + Vector2(cos(a), sin(a)) * l * 0.1, c + Vector2(cos(a), sin(a)) * l * 0.95, col.darkened(0.3), 1.0)


static func radio(ci: CanvasItem, c: Vector2, t: float, s := 1.0) -> void:
	# A 1937 "cathedral" tube radio. c = bottom centre.
	var w := 46.0 * s
	var h := 60.0 * s
	var pts := PackedVector2Array()
	pts.append(c + Vector2(-w * 0.5, 0))
	for i in 17:
		var a := PI + PI * float(i) / 16.0
		pts.append(c + Vector2(cos(a) * w * 0.5, -h * 0.55 + sin(a) * h * 0.45))
	pts.append(c + Vector2(w * 0.5, 0))
	ci.draw_colored_polygon(pts, WOOD)
	# inner arch speaker cloth
	var inner := PackedVector2Array()
	inner.append(c + Vector2(-w * 0.34, -h * 0.36))
	for i in 13:
		var a := PI + PI * float(i) / 12.0
		inner.append(c + Vector2(cos(a) * w * 0.34, -h * 0.58 + sin(a) * h * 0.32))
	inner.append(c + Vector2(w * 0.34, -h * 0.36))
	ci.draw_colored_polygon(inner, Color("c9a66b"))
	# fretwork sunburst
	for i in 7:
		var a := PI + PI * (float(i) + 0.5) / 7.0
		ci.draw_line(c + Vector2(0, -h * 0.38), c + Vector2(cos(a) * w * 0.32, -h * 0.58 + sin(a) * h * 0.3), WOOD_DARK, 2.0 * s)
	ci.draw_line(c + Vector2(-w * 0.34, -h * 0.37), c + Vector2(w * 0.34, -h * 0.37), WOOD_DARK, 2.0 * s)
	# dial
	var glow_a := 0.75 + 0.25 * sin(t * 7.0) * sin(t * 3.1)
	ellipse(ci, c + Vector2(0, -h * 0.22), w * 0.2, h * 0.07, Color(1.0, 0.72, 0.3, glow_a))
	ci.draw_line(c + Vector2(-w * 0.04 + sin(t * 0.3) * 4.0 * s, -h * 0.28), c + Vector2(-w * 0.04 + sin(t * 0.3) * 4.0 * s, -h * 0.16), Color("5a1d0c"), 1.5)
	ci.draw_circle(c + Vector2(-w * 0.3, -h * 0.1), 4.0 * s, WOOD_DARK)
	ci.draw_circle(c + Vector2(w * 0.3, -h * 0.1), 4.0 * s, WOOD_DARK)
	ci.draw_circle(c + Vector2(-w * 0.3, -h * 0.1), 1.6 * s, Color("d8b27a"))
	ci.draw_circle(c + Vector2(w * 0.3, -h * 0.1), 1.6 * s, Color("d8b27a"))
	ci.draw_rect(Rect2(c + Vector2(-w * 0.5, -3 * s), Vector2(w, 3 * s)), WOOD_DARK)


static func lemon(ci: CanvasItem, c: Vector2, rot: float, s := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		var r := 1.0 + 0.22 * pow(absf(cos(a)), 6.0)
		pts.append(c + Vector2(cos(a) * 15.0 * r * s, sin(a) * 11.0 * s).rotated(rot))
	ci.draw_colored_polygon(pts, LEMON)
	ellipse(ci, c + Vector2(-3, -3).rotated(rot) * s, 7.0 * s, 4.0 * s, Color("7fb0ff"), rot - 0.3)
	ci.draw_circle(c + Vector2(-6, -5).rotated(rot) * s, 1.8 * s, Color(1, 1, 1, 0.9))
	ci.draw_circle(c + Vector2(17, 0).rotated(rot) * s, 2.0 * s, Color("1d4bb0"))


static func music_note(ci: CanvasItem, p: Vector2, col: Color, s := 1.0) -> void:
	ellipse(ci, p, 4.5 * s, 3.3 * s, col, -0.4)
	ci.draw_line(p + Vector2(4.0, -1.0) * s, p + Vector2(4.0, -17.0) * s, col, 1.6 * s)
	ci.draw_line(p + Vector2(4.0, -17.0) * s, p + Vector2(10.0, -12.0) * s, col, 2.2 * s)


static func pigeon(ci: CanvasItem, p: Vector2, dir: float, flap: float, s := 1.0) -> void:
	ci.draw_set_transform(p, 0.0, Vector2(dir * s, s))
	var body := Color("8a8f99")
	ellipse(ci, Vector2(0, 0), 13, 8, body, -0.15)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-10, -2), Vector2(-22, 3), Vector2(-21, 7), Vector2(-9, 4)]), Color("5d626b"))
	ci.draw_circle(Vector2(10, -7), 6.0, Color("7d828c"))
	ellipse(ci, Vector2(7, -1), 5, 4, Color("4f8f78"), 0.3)
	ellipse(ci, Vector2(8, 2), 4, 3, Color("8a5a9a"), 0.3)
	ci.draw_circle(Vector2(12, -8), 1.8, Color("ff9a2a"))
	ci.draw_circle(Vector2(12.4, -8), 0.8, Color.BLACK)
	ci.draw_colored_polygon(PackedVector2Array([Vector2(15, -7), Vector2(20, -6), Vector2(15, -5)]), Color("3a3030"))
	var wy := -14.0 * flap
	ci.draw_colored_polygon(PackedVector2Array([Vector2(-7, -2), Vector2(6, -3), Vector2(-5, wy - 7)]), Color("6f747e"))
	ci.draw_line(Vector2(-1, 7), Vector2(-1, 12), Color("d0705a"), 1.5)
	ci.draw_line(Vector2(3, 7), Vector2(3, 12), Color("d0705a"), 1.5)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func bench(ci: CanvasItem, base: Vector2) -> void:
	ci.draw_rect(Rect2(base + Vector2(-50, -26), Vector2(100, 6)), Color("5a3b22"))
	ci.draw_rect(Rect2(base + Vector2(-50, -44), Vector2(100, 5)), Color("5a3b22"))
	ci.draw_rect(Rect2(base + Vector2(-50, -36), Vector2(100, 5)), Color("5a3b22"))
	ci.draw_line(base + Vector2(-42, 0), base + Vector2(-42, -44), Color("2a2a2a"), 3.0)
	ci.draw_line(base + Vector2(42, 0), base + Vector2(42, -44), Color("2a2a2a"), 3.0)


static func mistkuebel(ci: CanvasItem, base: Vector2) -> void:
	# The orange Viennese litter bin.
	ci.draw_line(base, base + Vector2(0, -20), Color("333"), 4.0)
	var body := PackedVector2Array([base + Vector2(-17, -56), base + Vector2(17, -56), base + Vector2(14, -22), base + Vector2(-14, -22)])
	ci.draw_colored_polygon(body, Color("f07a1a"))
	ci.draw_rect(Rect2(base + Vector2(-19, -60), Vector2(38, 6)), Color("d0620e"))
	text(ci, base + Vector2(0, -34), "MIST", 9, Color(1, 1, 1, 0.85))


static func maroni_stand(ci: CanvasItem, base: Vector2, t: float) -> void:
	ci.draw_rect(Rect2(base + Vector2(-60, -70), Vector2(120, 70)), Color("4a2a1a"))
	ci.draw_rect(Rect2(base + Vector2(-66, -78), Vector2(132, 10)), Color("6a3a20"))
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-72, -78), base + Vector2(72, -78), base + Vector2(56, -128), base + Vector2(-56, -128)]), Color("7a2a1e"))
	for i in 6:
		ci.draw_line(base + Vector2(-72 + i * 28.8, -78), base + Vector2(-56 + i * 22.4, -128), Color("e8dccb"), 6.0)
	ci.draw_line(base + Vector2(30, -78), base + Vector2(30, -160), Color("333"), 5.0)
	glow(ci, base + Vector2(-20, -70), 46.0, Color(1.0, 0.45, 0.1, 0.35 + 0.08 * sin(t * 9.0)))
	text(ci, base + Vector2(0, -36), "HEISSE MARONI", 12, Color("ffd38a"))


static func moon(ci: CanvasItem, c: Vector2, r: float) -> void:
	glow(ci, c, r * 5.0, Color(0.7, 0.8, 1.0, 0.25))
	ci.draw_circle(c, r, Color("f2eed8"))
	ci.draw_circle(c + Vector2(-r * 0.3, -r * 0.2), r * 0.22, Color("dcd6b8"))
	ci.draw_circle(c + Vector2(r * 0.25, r * 0.3), r * 0.15, Color("dcd6b8"))


static func hash01(i: int) -> float:
	var x := sin(float(i) * 12.9898) * 43758.5453
	return x - floorf(x)
