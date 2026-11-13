extends Node2D
## Flood water (the Wien river came in through the drains), puddles and the
## squid's sneeze geyser. Only the part inside the camera view is drawn.

const Art = preload("res://scripts/art.gd")

var world: Node2D
var bodies: Array = []
var t := 0.0
var _spray_t := 0.0


func _process(dt: float) -> void:
	t += dt
	if world.geyser_on:
		_spray_t -= dt
		if _spray_t <= 0.0:
			_spray_t = 0.03
			var r: Rect2 = world.geyser_rect
			var x := randf_range(r.position.x + 30.0, r.end.x - 30.0)
			world.fx.spawn(Vector2(x, r.position.y + randf_range(0, 60)), Vector2(randf_range(-160, 160), randf_range(-260, -60)), 0.8, 2.5, Color(0.8, 0.95, 1.0, 0.8), 0, 700.0, 0.5)
			world.fx.spawn(Vector2(x, randf_range(r.position.y, r.end.y)), Vector2(randf_range(-20, 20), -900), 0.35, 2.0, Color(1, 1, 1, 0.55), 4, 0.0, 0.0)
	elif world.squid and world.squid.phase == 2 and randf() < 0.4:
		world.fx.spawn(Vector2(randf_range(-90, 90), 3244.0), Vector2(0, -60), 0.5, 3.0, Color(0.85, 0.95, 1.0, 0.7), 5, 0.0, 0.0, 10.0)
	queue_redraw()


func _view() -> Rect2:
	var cam: Camera2D = world.camera
	var vs := get_viewport_rect().size / cam.zoom
	var c := cam.get_screen_center_position()
	return Rect2(c - vs * 0.5, vs).grow(80.0)


func _draw() -> void:
	var view := _view()
	for r in bodies:
		var rr: Rect2 = r
		if not rr.intersects(view):
			continue
		var x0 := maxf(rr.position.x, view.position.x)
		var x1 := minf(rr.end.x, view.end.x)
		var y_bot := maxf(minf(rr.end.y, view.end.y), rr.position.y + 14.0)
		var surf := rr.position.y
		var top := PackedVector2Array()
		var x := floorf(x0 / 14.0) * 14.0
		while x <= x1 + 14.0:
			top.append(Vector2(x, surf + 3.0 * sin(x * 0.03 + t * 2.0) + 2.0 * sin(x * 0.071 - t * 2.7)))
			x += 14.0
		var poly := PackedVector2Array(top)
		var cols := PackedColorArray()
		for i in top.size():
			cols.append(Color(0.2, 0.55, 0.62, 0.42))
		var bottom_col := Color(0.03, 0.12, 0.16, 0.86)
		poly.append(Vector2(top[top.size() - 1].x, y_bot))
		cols.append(bottom_col if y_bot - surf > 300.0 else Color(0.08, 0.3, 0.38, 0.6))
		poly.append(Vector2(top[0].x, y_bot))
		cols.append(bottom_col if y_bot - surf > 300.0 else Color(0.08, 0.3, 0.38, 0.6))
		draw_polygon(poly, cols)
		draw_polyline(top, Color(0.75, 0.95, 1.0, 0.65), 2.0)
		# light shafts & bubbles in the deep pit
		if rr.size.y > 200.0:
			for i in 5:
				var lx := -300.0 + i * 150.0 + sin(t * 0.3 + i) * 30.0
				draw_colored_polygon(PackedVector2Array([Vector2(lx, surf + 4), Vector2(lx + 40, surf + 4), Vector2(lx + 110, surf + 420), Vector2(lx + 50, surf + 420)]),
					Color(0.6, 0.9, 1.0, 0.04))
			for i in 14:
				var bx := -360.0 + Art.hash01(i * 5) * 720.0
				var span := rr.end.y - surf - 30.0
				var by := rr.end.y - fmod(t * (30.0 + 40.0 * Art.hash01(i)) + Art.hash01(i * 9) * span, span)
				draw_arc(Vector2(bx + sin(t * 2.0 + i) * 6.0, by), 2.0 + 3.0 * Art.hash01(i * 2), 0, TAU, 10, Color(0.8, 0.95, 1.0, 0.4), 1.0)
	# puddles
	for r2 in world.waters:
		var pr: Rect2 = r2
		if pr.size.y > 40.0 or not pr.intersects(view):
			continue
		Art.ellipse(self, pr.get_center() + Vector2(0, 2), pr.size.x * 0.5, 5.0, Color(0.35, 0.6, 0.75, 0.55))
		draw_line(Vector2(pr.position.x + 10, pr.position.y + 4), Vector2(pr.end.x - 14, pr.position.y + 4), Color(0.85, 0.95, 1.0, 0.5), 1.5)
	# the sneeze geyser
	if world.geyser_on:
		var g: Rect2 = world.geyser_rect
		var gp := PackedVector2Array()
		var n := 24
		for i in n + 1:
			var f := float(i) / n
			var y := lerpf(g.end.y, g.position.y, f)
			gp.append(Vector2(g.get_center().x - g.size.x * 0.5 * (1.0 - f * 0.4) + sin(t * 20.0 + f * 9.0) * 8.0, y))
		for i in range(n, -1, -1):
			var f2 := float(i) / n
			var y2 := lerpf(g.end.y, g.position.y, f2)
			gp.append(Vector2(g.get_center().x + g.size.x * 0.5 * (1.0 - f2 * 0.4) + sin(t * 23.0 + f2 * 7.0) * 8.0, y2))
		draw_colored_polygon(gp, Color(0.75, 0.93, 1.0, 0.38))
		for i in 6:
			var sx := g.position.x + 20.0 + i * 36.0
			var yy := g.end.y - fmod(t * 1600.0 + i * 140.0, g.size.y)
			draw_line(Vector2(sx, yy), Vector2(sx, yy + 90), Color(1, 1, 1, 0.45), 3.0)
