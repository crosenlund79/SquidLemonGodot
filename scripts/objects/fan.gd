extends Node2D
## A car-park jet fan (or, with is_gust, the Viennese wind up in the crown).
## Pushes Otto while switched on.

const Art = preload("res://scripts/art.gd")

var world: Node2D
var zone := Rect2()
var force := Vector2(1000, 0)
var on_time := 2.6
var off_time := 2.2
var is_gust := false
var on := false
var timer := 1.5
var strength := 0.0
var gust_dir := 1.0
var blade := 0.0
var snd: AudioStreamPlayer2D


func _ready() -> void:
	if not is_gust:
		snd = AudioStreamPlayer2D.new()
		snd.stream = Audio.stream("loop_fan")
		snd.bus = "SFX"
		snd.volume_db = -6.0
		snd.max_distance = 900.0
		add_child(snd)


func wind_at(p: Vector2) -> Vector2:
	if strength <= 0.01 or not zone.has_point(p):
		return Vector2.ZERO
	return force * gust_dir * strength


func _process(dt: float) -> void:
	timer -= dt
	if timer <= 0.0:
		on = not on
		timer = on_time if on else off_time
		if on and is_gust:
			gust_dir = -gust_dir
			if world.player and zone.has_point(world.player.global_position):
				Audio.play("gust", -6.0)
		if snd and snd.stream:
			if on:
				snd.play()
			else:
				snd.stop()
	strength = move_toward(strength, 1.0 if on else 0.0, dt * 2.5)
	blade += dt * (30.0 * strength + 0.5)
	if strength > 0.3 and world.fx and world.camera:
		var view: Rect2 = Rect2(world.camera.get_screen_center_position() - Vector2(500, 300), Vector2(1000, 600))
		var r := zone.intersection(view)
		if r.size.x > 0.0 and randf() < (0.8 if is_gust else 0.6):
			var p := Vector2(randf_range(r.position.x, r.end.x), randf_range(r.position.y, r.end.y))
			world.fx.spawn(p, force.normalized() * gust_dir * 700.0, 0.5, 1.5, Color(1, 1, 1, 0.22 if is_gust else 0.3), 4, 0.0, 0.0)
			if is_gust and randf() < 0.3:
				world.fx.spawn(p, force.normalized() * gust_dir * 260.0 + Vector2(0, 40), 2.0, 5.0, Color(0.35, 0.6, 0.3, 0.8), 2, 30.0, 0.3)
	if not is_gust:
		queue_redraw()


func _draw() -> void:
	if is_gust:
		return
	var d := signf(force.x)
	draw_line(Vector2(-40, -30), Vector2(-40, -18), Color("50585e"), 3.0)
	draw_line(Vector2(40, -30), Vector2(40, -18), Color("50585e"), 3.0)
	Art.rrect(self, Rect2(-62, -18, 124, 40), Color("8c959c"), 10, 2, Color("4a5258"))
	draw_rect(Rect2(-62, -14, 10, 32), Color("5e676e"))
	var cx := 60.0 * d
	Art.ellipse(self, Vector2(cx, 2), 6, 19, Color("2d3237"))
	for i in 3:
		var a := blade + i * TAU / 3.0
		draw_line(Vector2(cx, 2), Vector2(cx, 2) + Vector2(0, sin(a) * 17.0), Color("aab3ba"), 3.0)
	Art.text(self, Vector2(0, 8), "→" if d > 0 else "←", 16, Color(0.1, 0.1, 0.1, 0.6))
