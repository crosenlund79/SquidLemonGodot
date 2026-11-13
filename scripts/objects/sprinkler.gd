extends Node2D
## A sprinkler head on a test cycle ("Probelauf"). Sprays water on and off.

var world: Node2D
var floor_y := 0.0
var on := false
var timer := 1.0
var on_time := 2.8
var off_time := 2.4
var t := 0.0
var snd: AudioStreamPlayer2D


func _ready() -> void:
	snd = AudioStreamPlayer2D.new()
	snd.stream = Audio.stream("loop_sprinkler")
	snd.bus = "SFX"
	snd.volume_db = -10.0
	snd.max_distance = 900.0
	add_child(snd)


func refill_at(p: Vector2) -> float:
	if not on:
		return 0.0
	var dy := p.y - global_position.y
	if dy < -20.0 or p.y > floor_y:
		return 0.0
	if absf(p.x - global_position.x) < 40.0 + maxf(0.0, dy) * 0.3:
		return 36.0
	return 0.0


func _process(dt: float) -> void:
	t += dt
	timer -= dt
	if timer <= 0.0:
		on = not on
		timer = on_time if on else off_time
		if snd.stream:
			if on:
				snd.play()
			else:
				snd.stop()
	if on and world.fx:
		for i in 3:
			var a := PI / 2.0 + randf_range(-0.7, 0.7)
			world.fx.spawn(global_position + Vector2(0, 8), Vector2(cos(a), sin(a)) * randf_range(200, 380), 0.8, 2.0, Color(0.75, 0.92, 1.0, 0.75), 4, 500.0, 0.2)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-4, 0, 8, 8), Color("b8352c"))
	draw_colored_polygon(PackedVector2Array([Vector2(-9, 12), Vector2(9, 12), Vector2(5, 8), Vector2(-5, 8)]), Color("c9a24a"))
	if on:
		draw_colored_polygon(PackedVector2Array([Vector2(-4, 12), Vector2(4, 12), Vector2(110, 230), Vector2(-110, 230)]), Color(0.75, 0.92, 1.0, 0.12))
