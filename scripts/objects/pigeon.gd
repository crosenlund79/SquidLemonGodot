extends Node2D
## A Viennese pigeon on patrol. Bumping into it knocks Otto off course.

const Art = preload("res://scripts/art.gd")

var world: Node2D
var center := Vector2.ZERO
var amp := Vector2(80, 30)
var speed := 1.0
var t := 0.0
var ft := 0.0
var dir := 1.0
var coo_t := 3.0


func _ready() -> void:
	t = absf(center.x) * 0.013 + absf(center.y) * 0.007
	position = center


func _physics_process(dt: float) -> void:
	t += dt * speed
	ft += dt
	var np := center + Vector2(sin(t) * amp.x, sin(t * 2.0) * amp.y)
	if absf(np.x - position.x) > 0.05:
		dir = signf(np.x - position.x)
	position = np
	var pl = world.player
	if pl and not pl.is_frozen() and position.distance_to(pl.global_position) < 24.0:
		var k: Vector2 = (pl.global_position - position).normalized()
		pl.hurt(position, 14.0, Vector2(k.x * 320.0 + dir * 120.0, -220.0 + k.y * 80.0))
		Audio.play_at("flap", position, -2.0)
	coo_t -= dt
	if coo_t <= 0.0:
		coo_t = randf_range(3.0, 7.0)
		Audio.play_at("coo", position, -10.0, 1.0, 0.1, 700.0)
	queue_redraw()


func _draw() -> void:
	Art.pigeon(self, Vector2.ZERO, dir, absf(sin(ft * 16.0)), 1.15)
