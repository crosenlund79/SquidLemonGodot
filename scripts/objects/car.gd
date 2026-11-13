extends AnimatableBody2D
## A car (or the ambulance) that drives in from the outer wall, stops near the
## shaft and reverses out again. Its roof is a safe one-way platform.

const Art = preload("res://scripts/art.gd")

var world: Node2D
var kind := "car"
var floor_y := 0.0
var x_in := 650.0
var x_out := 1330.0
var body_color := Color("e0c03a")

var L := 190.0
var H := 72.0
var state := 0       # 0 outside, 1 driving in, 2 stopped, 3 reversing
var timer := 1.5
var x := 0.0
var speed := 0.0
var t := 0.0
var engine: AudioStreamPlayer2D
var siren: AudioStreamPlayer2D
var beep: AudioStreamPlayer2D
var _honked := false


func _ready() -> void:
	sync_to_physics = true
	collision_layer = 2
	collision_mask = 0
	if kind == "ambulance":
		L = 240.0
		H = 114.0
	x = x_out
	position = Vector2(x, floor_y)
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	var roof_w := 70.0 if kind == "car" else 170.0
	sh.size = Vector2(roof_w, 10)
	cs.shape = sh
	cs.position = Vector2(4.0 if kind == "car" else 20.0, -H + 5.0)
	cs.one_way_collision = true
	cs.one_way_collision_margin = 8.0
	add_child(cs)
	engine = _loop("loop_engine", -8.0)
	if kind == "ambulance":
		siren = _loop("loop_siren", -2.0)
		timer = 2.5
	beep = _loop("loop_beep", -10.0)


func _loop(n: String, vol: float) -> AudioStreamPlayer2D:
	var p := AudioStreamPlayer2D.new()
	p.stream = Audio.stream(n)
	p.bus = "SFX"
	p.volume_db = vol
	p.max_distance = 1500.0
	p.attenuation = 1.4
	add_child(p)
	return p


func _set_playing(p: AudioStreamPlayer2D, on: bool) -> void:
	if p == null or p.stream == null:
		return
	if on and not p.playing:
		p.play()
	elif not on and p.playing:
		p.stop()


func _physics_process(dt: float) -> void:
	t += dt
	var amb := kind == "ambulance"
	var v_in := 430.0 if amb else 300.0
	var v_out := 230.0 if amb else 170.0
	match state:
		0:
			timer -= dt
			if timer <= 0.0:
				state = 1
				speed = v_in * 0.7
				_honked = false
		1:
			var dist := absf(x - x_in)
			speed = minf(v_in, sqrt(2.0 * 900.0 * dist) + 25.0)
			x = move_toward(x, x_in, speed * dt)
			if not _honked and world.player and absf(world.player.global_position.y - (floor_y - 20.0)) < 80.0 and absf(world.player.global_position.x - x) < 360.0:
				_honked = true
				Audio.play_at("horn", global_position, 0.0, 0.85 if amb else 1.0)
			if dist < 0.5:
				state = 2
				timer = 2.2 if amb else 1.6
		2:
			timer -= dt
			if timer <= 0.0:
				state = 3
		3:
			x = move_toward(x, x_out, v_out * dt)
			if absf(x - x_out) < 0.5:
				state = 0
				timer = 3.2 if amb else 2.6
	position = Vector2(x, floor_y)
	_set_playing(engine, state != 0)
	if engine and engine.playing:
		engine.pitch_scale = 0.8 + (0.5 if state == 1 else 0.25)
	_set_playing(siren, state != 0)
	_set_playing(beep, state == 3)
	_check_player()
	queue_redraw()


func _check_player() -> void:
	if state != 1 and state != 3:
		return
	var pl = world.player
	if pl == null or pl.is_frozen():
		return
	var p: Vector2 = pl.global_position
	var r := Rect2(x - L * 0.5, floor_y - H + 16.0, L, H - 16.0).grow(9.0)
	if not r.has_point(p):
		return
	if p.y + 13.0 <= floor_y - H + 10.0:
		return
	var motion := signf(x_in - x_out) if state == 1 else signf(x_out - x_in)
	pl.hurt(global_position, 30.0 if kind == "ambulance" else 22.0, Vector2(motion * 460.0, -340.0))


func _draw() -> void:
	var dir := signf(x_in - x_out)
	var lights := state == 1 or state == 2
	Art.car(self, Vector2.ZERO, dir, body_color, kind, lights, state == 3)
	if kind == "ambulance" and state != 0:
		var on := int(t * 6.0) % 2 == 0
		var a := Vector2(-10 * dir, -H - 4)
		Art.glow(self, a + Vector2(-18, 0), 60.0, Color(0.2, 0.4, 1.0, 0.55 if on else 0.15))
		Art.glow(self, a + Vector2(18, 0), 60.0, Color(0.2, 0.4, 1.0, 0.15 if on else 0.55))
		draw_rect(Rect2(a + Vector2(-26, -4), Vector2(18, 7)), Color("6fa0ff") if on else Color("2a4aa0"))
		draw_rect(Rect2(a + Vector2(8, -4), Vector2(18, 7)), Color("2a4aa0") if on else Color("6fa0ff"))
