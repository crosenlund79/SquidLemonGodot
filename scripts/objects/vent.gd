extends Node2D
## A floor vent blowing hot air from the hospital's boiler room. Lifts Otto up
## like an elevator - and dries him out fast.

var world: Node2D
var top := 600.0
var half_w := 32.0
var t := 0.0
var snd: AudioStreamPlayer2D


func _ready() -> void:
	snd = AudioStreamPlayer2D.new()
	snd.stream = Audio.stream("loop_vent")
	snd.bus = "SFX"
	snd.volume_db = -8.0
	snd.max_distance = 800.0
	add_child(snd)
	if snd.stream:
		snd.play()


func _process(dt: float) -> void:
	t += dt
	if world.fx and randf() < 0.25:
		world.fx.spawn(global_position + Vector2(randf_range(-half_w, half_w), -6), Vector2(randf_range(-10, 10), -320), 1.2, 3.0, Color(1.0, 0.6, 0.3, 0.25), 0, -100.0, 0.2, 6.0)
	queue_redraw()


func _draw() -> void:
	var h := global_position.y - top
	draw_colored_polygon(PackedVector2Array([Vector2(-half_w, 0), Vector2(half_w, 0), Vector2(half_w * 1.3, -h), Vector2(-half_w * 1.3, -h)]), Color(1.0, 0.55, 0.2, 0.07))
	for i in 5:
		var x := -half_w + (i + 0.5) * half_w * 2.0 / 5.0
		var pts := PackedVector2Array()
		var y := 0.0
		while y > -h:
			pts.append(Vector2(x + sin(y * 0.05 + t * 6.0 + i) * 5.0, y))
			y -= 16.0
		draw_polyline(pts, Color(1.0, 0.7, 0.4, 0.13), 2.0)
	draw_rect(Rect2(-half_w - 4, -8, half_w * 2.0 + 8, 8), Color("3a3f45"))
	for i in 6:
		draw_line(Vector2(-half_w + i * half_w * 2.0 / 5.0, -7), Vector2(-half_w + i * half_w * 2.0 / 5.0, -1), Color("ff8a3a"), 2.0)
