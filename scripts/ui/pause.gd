extends CanvasLayer
## Pause menu. Runs while the tree is paused.

const Art = preload("res://scripts/art.gd")

var main: Node
var ctrl: Control
var is_open := false
var sel := 0
var t := 0.0
var _opened := 0
var _rects: Array = []


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	ctrl = Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ctrl)
	ctrl.draw.connect(_draw_menu)
	visible = false


func _items() -> Array:
	return ["Resume", "Back to last bucket", "Music: " + ("on" if Game.music_on else "off"), "Quit to title"]


func open_menu() -> void:
	is_open = true
	visible = true
	sel = 0
	_opened = Engine.get_process_frames()
	get_tree().paused = true
	Audio.play("ui_move", -6.0)


func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false


func _process(dt: float) -> void:
	t += dt
	if not is_open:
		return
	if Engine.get_process_frames() - _opened < 2:
		ctrl.queue_redraw()
		return
	if Input.is_action_just_pressed("pause"):
		close()
		return
	if Input.is_action_just_pressed("ui_menu_up"):
		sel = (sel + 3) % 4
		Audio.play("ui_move", -8.0)
	if Input.is_action_just_pressed("ui_menu_down"):
		sel = (sel + 1) % 4
		Audio.play("ui_move", -8.0)
	if Input.is_action_just_pressed("ui_accept") or Input.is_action_just_pressed("jump"):
		_choose(sel)
	ctrl.queue_redraw()


func _input(e: InputEvent) -> void:
	if not is_open:
		return
	if e is InputEventMouseMotion:
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(e.position):
				sel = i
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		for i in _rects.size():
			if (_rects[i] as Rect2).has_point(e.position):
				_choose(i)
				get_viewport().set_input_as_handled()


func _choose(i: int) -> void:
	Audio.play("ui_ok", -6.0)
	match i:
		0:
			close()
		1:
			close()
			main.respawn_player(false)
		2:
			Game.music_on = not Game.music_on
			Audio.set_music_enabled(Game.music_on)
		3:
			close()
			main.back_to_title()


func _draw_menu() -> void:
	var vs := ctrl.size
	ctrl.draw_rect(Rect2(Vector2.ZERO, vs), Color(0.02, 0.03, 0.05, 0.72))
	var cx := vs.x * 0.5
	Art.text_outline(ctrl, Vector2(cx, vs.y * 0.5 - 130), "PAUSE", 54, Color(1, 1, 1), Color(0, 0, 0, 0.6), 8)
	var items := _items()
	_rects.clear()
	for i in items.size():
		var y := vs.y * 0.5 - 50 + i * 56.0
		var r := Rect2(cx - 190, y - 30, 380, 46)
		_rects.append(r)
		var on := i == sel
		Art.rrect(ctrl, r, Color(1.0, 0.55, 0.3, 0.9) if on else Color(1, 1, 1, 0.08), 12)
		Art.text(ctrl, Vector2(cx, y + 2), items[i], 24, Color(0.08, 0.04, 0.02) if on else Color(0.9, 0.92, 1.0))
	Art.text(ctrl, Vector2(cx, vs.y * 0.5 + 200), "Kastanien %d / %d   ·   %s" % [Game.kastanien.size(), Game.kastanien_total, Game.format_time(Game.run_time)], 16, Color(1, 1, 1, 0.5))
