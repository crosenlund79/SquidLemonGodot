extends Node2D
## A cleaning trolley's mop bucket: checkpoint + full refill.

const Art = preload("res://scripts/art.gd")

var world: Node2D
var idx := 0
var t := 0.0
var cd := 0.0


func _process(dt: float) -> void:
	t += dt
	cd -= dt
	var pl = world.player
	if pl and not pl.is_frozen() and not pl.is_dry():
		if pl.global_position.distance_to(global_position + Vector2(0, -22)) < 40.0:
			if Game.checkpoint_id != idx:
				Game.checkpoint = global_position + Vector2(0, -26)
				Game.checkpoint_id = idx
				Audio.play("checkpoint", -2.0)
				world.fx.splash(global_position + Vector2(0, -40), 0.7)
				world.fx.text(global_position + Vector2(0, -70), "GESPEICHERT", Color("ffe28a"), 18.0, 1.6)
				pl.moisture = 100.0
				cd = 1.0
			elif pl.moisture < 98.0 and cd <= 0.0:
				pl.moisture = 100.0
				cd = 1.2
				Audio.play("splash", -12.0, 1.3)
				world.fx.splash(global_position + Vector2(0, -40), 0.4)
	queue_redraw()


func _draw() -> void:
	var active := Game.checkpoint_id == idx
	if active:
		Art.glow(self, Vector2(0, -24), 50.0, Color(0.5, 0.8, 1.0, 0.25))
	Art.bucket(self, Vector2.ZERO, active, t)
	if active:
		draw_line(Vector2(-20, -44), Vector2(-20, -74), Color("dddddd"), 2.0)
		draw_colored_polygon(PackedVector2Array([Vector2(-20, -74), Vector2(0, -68 + sin(t * 5.0) * 2.0), Vector2(-20, -62)]), Color("ffd23a"))
