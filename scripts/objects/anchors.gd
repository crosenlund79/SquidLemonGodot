extends Node2D
## Highlights the brass ring / lamp Otto would grab, plus a crosshair.

var world: Node2D
var t := 0.0


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var pl = world.player
	if pl == null or not pl.visible or pl.is_frozen():
		return
	var pp: Vector2 = pl.global_position
	for a in world.anchors:
		var d: float = pp.distance_to(a)
		if d < 300.0:
			draw_arc(a, 11.0 + sin(t * 4.0) * 1.5, 0, TAU, 18, Color(1.0, 0.9, 0.5, 0.35), 1.5)
	if pl.aim_target != null and pl.g_state == 0:
		var tg: Vector2 = pl.aim_target
		var dir := (tg - pp)
		var L := dir.length()
		var u := dir / maxf(1.0, L)
		var s := 22.0
		while s < L - 14.0:
			draw_circle(pp + u * s, 1.6, Color(1.0, 0.95, 0.7, 0.45))
			s += 14.0
		draw_arc(tg, 15.0 + sin(t * 8.0) * 2.0, 0, TAU, 24, Color(1.0, 0.9, 0.4, 0.9), 2.5)
	if Game.using_mouse():
		var m := get_global_mouse_position()
		var c := Color(1, 1, 1, 0.7)
		draw_arc(m, 7.0, 0, TAU, 16, c, 1.5)
		draw_line(m + Vector2(-12, 0), m + Vector2(-5, 0), c, 1.5)
		draw_line(m + Vector2(12, 0), m + Vector2(5, 0), c, 1.5)
		draw_line(m + Vector2(0, -12), m + Vector2(0, -5), c, 1.5)
		draw_line(m + Vector2(0, 12), m + Vector2(0, 5), c, 1.5)
