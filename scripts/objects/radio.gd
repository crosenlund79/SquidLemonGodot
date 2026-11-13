extends Node2D
## F. Hofbauer's 1937 tube radio, hung in the fork of the tree. Still playing.

const Art = preload("res://scripts/art.gd")

var world: Node2D
var t := 0.0
var note_t := 0.0


func _process(dt: float) -> void:
	t += dt
	note_t -= dt
	if note_t <= 0.0 and world.fx:
		note_t = randf_range(0.5, 0.9)
		world.fx.spawn(global_position + Vector2(randf_range(-14, 14), -50), Vector2(randf_range(-30, 30), -45), 2.2, 1.0, Color(1.0, 0.85, 0.55, 0.9), 6, -8.0, 0.3)
	queue_redraw()


func _draw() -> void:
	# wire to the branch above
	draw_line(Vector2(-10, -58), Vector2(-4, -110), Color("6a6a60"), 1.5)
	draw_line(Vector2(10, -58), Vector2(4, -110), Color("6a6a60"), 1.5)
	Art.glow(self, Vector2(0, -24), 90.0, Color(1.0, 0.7, 0.35, 0.22 + 0.05 * sin(t * 3.0)))
	Art.radio(self, Vector2.ZERO, t, 1.0)
	for i in 3:
		var r := 30.0 + fmod(t * 30.0 + i * 20.0, 60.0)
		var a := 1.0 - (r - 30.0) / 60.0
		draw_arc(Vector2(0, -34), r, -PI * 0.85, -PI * 0.15, 16, Color(1.0, 0.85, 0.6, a * 0.35), 2.0)
	Art.rrect(self, Rect2(-20, 2, 40, 9), Color("c9a24a"), 2)
	Art.text(self, Vector2(0, 10), "1937", 8, Color("3a2410"))
