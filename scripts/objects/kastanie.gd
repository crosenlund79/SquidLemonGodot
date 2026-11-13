extends Node2D
## A shiny horse chestnut. Every Viennese kid collects them in autumn.

const Art = preload("res://scripts/art.gd")

var world: Node2D
var id := 0
var t := 0.0


func _ready() -> void:
	t = id * 0.7
	if Game.kastanien.has(id):
		queue_free()


func _process(dt: float) -> void:
	t += dt
	var pl = world.player
	if pl and pl.visible and not pl.is_frozen() and pl.global_position.distance_to(global_position) < 28.0:
		Game.collect_kastanie(id)
		Audio.play("kastanie", -3.0, 1.0 + Game.kastanien.size() * 0.015, 0.0)
		world.fx.burst(global_position, 14, 180.0, Color(1.0, 0.8, 0.4, 0.9), 0.6, 3.0, 200.0)
		world.fx.text(global_position + Vector2(0, -24), "Kastanie %d/%d" % [Game.kastanien.size(), Game.kastanien_total], Color("ffcf80"), 16.0)
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var bob := sin(t * 3.0) * 3.0
	Art.glow(self, Vector2(0, bob), 26.0, Color(1.0, 0.7, 0.3, 0.28))
	Art.kastanie(self, Vector2(0, bob), 1.0)
	var s := fmod(t * 0.8, 1.0)
	if s < 0.25:
		var a := 1.0 - s * 4.0
		var c := Vector2(6, -6 + bob)
		draw_line(c + Vector2(-5, 0), c + Vector2(5, 0), Color(1, 1, 1, a), 1.5)
		draw_line(c + Vector2(0, -5), c + Vector2(0, 5), Color(1, 1, 1, a), 1.5)
