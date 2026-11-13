extends CanvasLayer
## End card with the run's statistics.

signal done

const Art = preload("res://scripts/art.gd")

var ctrl: Control
var t := 0.0
var active := false
var alpha := 0.0


func _ready() -> void:
	layer = 25
	ctrl = Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ctrl)
	ctrl.draw.connect(_draw_end)
	visible = false


func show_stats() -> void:
	active = true
	visible = true
	t = 0.0


func _process(dt: float) -> void:
	t += dt
	alpha = move_toward(alpha, 1.0 if active else 0.0, dt * 1.2)
	visible = alpha > 0.0
	if active and t > 2.5 and (Input.is_action_just_pressed("accept") or Input.is_action_just_pressed("jump")):
		active = false
		Audio.play("ui_ok", -4.0)
		done.emit()
	ctrl.queue_redraw()


func _draw_end() -> void:
	var vs := ctrl.size
	var a := alpha
	var cx := vs.x * 0.5
	ctrl.draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vs.x, 0), Vector2(vs.x, 420), Vector2(0, 420)]),
		PackedColorArray([Color(0, 0, 0, 0.75 * a), Color(0, 0, 0, 0.75 * a), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
	Art.text_outline(ctrl, Vector2(cx, 110), "ENDE", 88, Color(Color("ffd9a0"), a), Color(0.1, 0.03, 0.05, a), 12)
	Art.text_outline(ctrl, Vector2(cx, 156), "Gute Besserung, Frau Hofrätin!", 28, Color(Color("ef8ab8"), a), Color(0, 0, 0, a * 0.7), 6)
	var lines := [
		"Time   %s" % Game.format_time(Game.run_time),
		"Kastanien   %d / %d" % [Game.kastanien.size(), Game.kastanien_total],
		"Dried out   %d×" % Game.dryouts,
	]
	for i in lines.size():
		Art.text_outline(ctrl, Vector2(cx, 214 + i * 36), lines[i], 24, Color(1, 1, 1, a), Color(0, 0, 0, a * 0.7), 5)
	var verdict := "Kastanienkönig! You found every chestnut in the car park." if Game.kastanien.size() >= Game.kastanien_total else "Some chestnuts are still hiding down there..."
	Art.text_outline(ctrl, Vector2(cx, 330), verdict, 18, Color(Color("b8e0ff"), a), Color(0, 0, 0, a * 0.7), 4)
	if t > 2.5 and int(t * 2.0) % 2 == 0:
		Art.text_outline(ctrl, Vector2(cx, vs.y - 40), "[Space] back to the title", 20, Color(1, 1, 1, a * 0.9), Color(0, 0, 0, a), 4)
