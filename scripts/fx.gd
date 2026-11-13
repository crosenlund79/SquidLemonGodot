extends Node2D
## Lightweight particle + floating-text system, drawn in world space.

const MAX := 700

# kind: 0 dot, 1 ink puff, 2 leaf, 3 text, 4 streak, 5 ring, 6 note
var parts: Array = []


func spawn(pos: Vector2, vel: Vector2, life: float, size: float, col: Color, kind := 0, grav := 0.0, drag := 0.0, grow := 0.0) -> void:
	if parts.size() >= MAX:
		parts.pop_front()
	parts.append({"p": pos, "v": vel, "life": life, "max": life, "s": size, "c": col, "k": kind,
		"g": grav, "d": drag, "gr": grow, "r": randf() * TAU, "rv": randf_range(-4.0, 4.0), "txt": ""})


func burst(pos: Vector2, n: int, speed: float, col: Color, life := 0.6, size := 3.0, grav := 600.0, dir := 0.0, spread := TAU, kind := 0, drag := 1.0) -> void:
	for i in n:
		var a := dir + randf_range(-spread * 0.5, spread * 0.5)
		var v := Vector2(cos(a), sin(a)) * speed * randf_range(0.4, 1.0)
		spawn(pos, v, life * randf_range(0.6, 1.1), size * randf_range(0.6, 1.2), col, kind, grav, drag)


func splash(pos: Vector2, strength := 1.0) -> void:
	burst(pos, int(14 * strength), 260.0 * strength, Color(0.7, 0.9, 1.0, 0.9), 0.7, 3.0, 900.0, -PI / 2, 2.2)
	spawn(pos, Vector2.ZERO, 0.45, 6.0, Color(0.8, 0.95, 1.0, 0.7), 5, 0.0, 0.0, 70.0)


func ink(pos: Vector2, vel: Vector2) -> void:
	spawn(pos + Vector2(randf_range(-6, 6), randf_range(-6, 6)), vel * 0.15 + Vector2(randf_range(-30, 30), randf_range(-30, 30)),
		randf_range(0.9, 1.6), randf_range(6, 11), Color(0.08, 0.05, 0.14, 0.75), 1, -20.0, 1.5, 14.0)


func text(pos: Vector2, s: String, col := Color.WHITE, size := 18.0, life := 1.4) -> void:
	spawn(pos, Vector2(0, -40), life, size, col, 3, 0.0, 0.8)
	parts[-1]["txt"] = s


func _process(dt: float) -> void:
	var i := parts.size() - 1
	while i >= 0:
		var p: Dictionary = parts[i]
		p["life"] -= dt
		if p["life"] <= 0.0:
			parts.remove_at(i)
		else:
			p["v"] += Vector2(0, p["g"]) * dt
			p["v"] *= maxf(0.0, 1.0 - p["d"] * dt)
			p["p"] += p["v"] * dt
			p["s"] += p["gr"] * dt
			p["r"] += p["rv"] * dt
		i -= 1
	queue_redraw()


func _draw() -> void:
	var f: Font = ThemeDB.fallback_font
	for p in parts:
		var t: float = p["life"] / p["max"]
		var c: Color = p["c"]
		match int(p["k"]):
			0:
				draw_circle(p["p"], p["s"] * (0.4 + 0.6 * t), Color(c, c.a * minf(1.0, t * 2.0)))
			1:
				draw_circle(p["p"], p["s"], Color(c, c.a * t))
			2:
				var pts := PackedVector2Array()
				for k in 8:
					var a := TAU * k / 8.0
					pts.append(p["p"] + Vector2(cos(a) * p["s"], sin(a) * p["s"] * 0.4).rotated(p["r"]))
				draw_colored_polygon(pts, Color(c, c.a * minf(1.0, t * 3.0)))
			3:
				var s: String = p["txt"]
				var size := int(p["s"])
				var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
				var pos: Vector2 = p["p"] - Vector2(sz.x * 0.5, 0)
				var a := minf(1.0, t * 3.0)
				draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color(0, 0, 0, 0.7 * a))
				draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(c, a))
			4:
				var v: Vector2 = p["v"]
				draw_line(p["p"], p["p"] - v * 0.03, Color(c, c.a * t), p["s"])
			5:
				draw_arc(p["p"], p["s"], 0, TAU, 24, Color(c, c.a * t), 2.0)
			6:
				var col := Color(c, c.a * minf(1.0, t * 2.0))
				var q: Vector2 = p["p"]
				draw_set_transform(q, sin(p["r"]) * 0.3, Vector2.ONE * p["s"])
				draw_circle(Vector2.ZERO, 4.0, col)
				draw_line(Vector2(3.5, -1), Vector2(3.5, -15), col, 1.6)
				draw_line(Vector2(3.5, -15), Vector2(9, -11), col, 2.0)
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
