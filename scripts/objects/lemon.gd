extends Node2D
## The blue lemon. It hums faintly and smells of the sea. It is also a little
## bit magical: when Otto swings close, it tugs on its stem towards him.

const Art = preload("res://scripts/art.gd")

var world: Node2D
var t := 0.0
var taken := false
var falling := false
var spin := 0.0
var home := Vector2.ZERO


func _ready() -> void:
	home = position


func _process(dt: float) -> void:
	t += dt
	if falling:
		spin += dt * 6.0
	if not taken and not falling:
		var pl = world.player
		if pl and not pl.is_frozen():
			var d: Vector2 = pl.global_position - global_position
			if d.length() < 96.0:
				position += d.normalized() * minf(d.length(), 240.0 * dt)
				if position.distance_to(home) > 70.0:
					position = home + (position - home).normalized() * 70.0
			else:
				position = position.move_toward(home, 140.0 * dt)
			if pl.global_position.distance_to(global_position) < 42.0:
				taken = true
				world.lemon_reached.emit()
	if world.fx and randf() < 0.12:
		world.fx.spawn(global_position + Vector2(randf_range(-20, 20), randf_range(-16, 16)), Vector2(0, -20), 0.9, 2.0, Color(0.55, 0.75, 1.0, 0.9), 0, 0.0, 0.5)
	queue_redraw()


func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	Art.glow(self, Vector2.ZERO, 70.0 + pulse * 20.0, Color(0.3, 0.55, 1.0, 0.35 + pulse * 0.15))
	if not falling:
		var stem_top := home - position + Vector2(0, -66)
		draw_line(Vector2(0, -12), stem_top, Color("4a3a24"), 2.0)
		Art.ellipse(self, Vector2(8, -16), 9, 4, Art.LEAF_LIGHT, -0.5)
	var wobble := 0.0 if falling else sin(t * 9.0) * 0.12 * clampf(position.distance_to(home) / 40.0, 0.0, 1.0)
	Art.lemon(self, Vector2.ZERO, sin(t * 1.3) * 0.15 + spin + wobble, 1.25)
