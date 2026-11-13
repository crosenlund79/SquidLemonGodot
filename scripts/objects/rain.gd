extends Node2D
## Viennese drizzle at street level, also falling down into the light shaft.

var world: Node2D
var t := 0.0


func _process(dt: float) -> void:
	t += dt
	queue_redraw()


func _draw() -> void:
	var cam: Camera2D = world.camera
	var vs := get_viewport_rect().size / cam.zoom
	var c := cam.get_screen_center_position()
	var view := Rect2(c - vs * 0.5, vs)
	if view.position.y > 900.0:
		return
	var n := 170
	for i in n:
		var hx := _h(i)
		var x := view.position.x + hx * view.size.x
		var fall := fmod(_h(i + 500) * 1000.0 + t * 820.0, view.size.y + 40.0)
		var y := view.position.y - 20.0 + fall
		var a := 0.28
		if y > 0.0:
			if absf(x) > 380.0:
				continue
			a *= clampf(1.0 - y / 900.0, 0.0, 1.0)
		if a <= 0.01:
			continue
		draw_line(Vector2(x, y), Vector2(x - 3.0, y + 14.0), Color(0.75, 0.85, 1.0, a), 1.0)


func _h(i: int) -> float:
	var x := sin(float(i) * 12.9898 + 4.1) * 43758.5453
	return x - floorf(x)
