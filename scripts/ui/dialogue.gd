extends CanvasLayer
## Typewriter dialogue box with little blips per speaker.
## start([[speaker, text], [speaker, text, callable_on_start], ...])

signal finished

const Art = preload("res://scripts/art.gd")
const SPEAKERS := {
	"squid": {"name": "Frau Hofrätin Kalmar", "col": Color("ef8ab8"), "blip": "blip_squid"},
	"otto": {"name": "Otto", "col": Color("ff9a6a"), "blip": "blip_otto"},
	"radio": {"name": "Radio Wien · 1937", "col": Color("ffcf80"), "blip": "blip_radio"},
	"": {"name": "", "col": Color("c8d0e0"), "blip": ""},
}

var ctrl: Control
var lines: Array = []
var idx := 0
var shown := 0.0
var active := false
var t := 0.0
var _blip_acc := 0.0
var _started := -1
var _open_frame := 0


func _ready() -> void:
	layer = 20
	ctrl = Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ctrl)
	ctrl.draw.connect(_draw_box)
	visible = false


func start(l: Array) -> void:
	lines = l
	idx = 0
	shown = 0.0
	_started = -1
	active = true
	visible = true
	_open_frame = Engine.get_process_frames()


func _process(dt: float) -> void:
	t += dt
	if not active:
		return
	var line: Array = lines[idx]
	if _started != idx:
		_started = idx
		if line.size() > 2 and line[2] is Callable:
			(line[2] as Callable).call()
	var text: String = line[1]
	if shown < text.length():
		shown = minf(text.length(), shown + dt * 52.0)
		_blip_acc += dt
		var sp: Dictionary = SPEAKERS.get(line[0], SPEAKERS[""])
		if _blip_acc > 0.075 and sp["blip"] != "":
			_blip_acc = 0.0
			var ch := text.substr(int(shown) - 1, 1)
			if ch != " ":
				Audio.play(sp["blip"], -9.0, 1.0, 0.12)
	var fresh := Engine.get_process_frames() - _open_frame < 2
	if not fresh and Input.is_action_just_pressed("accept"):
		if shown < text.length():
			shown = text.length()
		else:
			idx += 1
			shown = 0.0
			Audio.play("ui_move", -12.0, 1.2)
			if idx >= lines.size():
				_close()
				return
	if not fresh and Input.is_action_just_pressed("pause"):
		# skip the rest, but still run any pending line callbacks
		for j in range(idx + 1, lines.size()):
			var l2: Array = lines[j]
			if l2.size() > 2 and l2[2] is Callable:
				(l2[2] as Callable).call()
		_close()
		return
	ctrl.queue_redraw()


func _close() -> void:
	active = false
	visible = false
	finished.emit()


func _draw_box() -> void:
	if not active:
		return
	var vs := ctrl.size
	var line: Array = lines[idx]
	var sp: Dictionary = SPEAKERS.get(line[0], SPEAKERS[""])
	var w := minf(980.0, vs.x - 60.0)
	var r := Rect2(Vector2((vs.x - w) * 0.5, vs.y - 196), Vector2(w, 166))
	Art.rrect(ctrl, r, Color(0.05, 0.06, 0.09, 0.9), 16, 3, Color(sp["col"], 0.8))
	var tx := r.position.x + 28.0
	if line[0] != "":
		var pc := r.position + Vector2(76, 83)
		ctrl.draw_circle(pc, 52.0, Color(sp["col"], 0.25))
		_portrait(line[0], pc)
		tx = r.position.x + 150.0
		ctrl.draw_string(Art.font(), Vector2(tx, r.position.y + 36), sp["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, sp["col"])
	var text: String = line[1]
	var shown_text := text.substr(0, int(shown))
	var col := Color(0.93, 0.93, 0.9) if line[0] != "" else Color(0.8, 0.86, 0.95)
	ctrl.draw_multiline_string(Art.font(), Vector2(tx, r.position.y + (70.0 if line[0] != "" else 50.0)), shown_text,
		HORIZONTAL_ALIGNMENT_LEFT, r.end.x - tx - 30.0, 21, -1, col)
	if shown >= text.length():
		var by := r.end.y - 22.0 + sin(t * 6.0) * 3.0
		ctrl.draw_colored_polygon(PackedVector2Array([Vector2(r.end.x - 34, by - 6), Vector2(r.end.x - 20, by - 6), Vector2(r.end.x - 27, by + 2)]), Color(1, 1, 1, 0.8))
	ctrl.draw_string(Art.font(), Vector2(r.position.x + 18, r.end.y + 20), "[Space] / [Enter] / Click  ·  [Esc] skip", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1, 0.35))


func _portrait(who: String, c: Vector2) -> void:
	match who:
		"squid":
			ctrl.draw_circle(c + Vector2(0, 10), 40.0, Color("a63a6c"))
			ctrl.draw_circle(c + Vector2(4, 0), 22.0, Color("f4ecd0"))
			ctrl.draw_circle(c + Vector2(8, 2), 14.0, Color("d9a12a"))
			ctrl.draw_circle(c + Vector2(8, 2), 7.0, Color("17101a"))
			ctrl.draw_arc(c + Vector2(4, 0), 25.0, 0, TAU, 24, Color("d8b04a"), 3.0)
			ctrl.draw_line(c + Vector2(26, 10), c + Vector2(40, 40), Color("d8b04a"), 1.5)
		"otto":
			ctrl.draw_circle(c + Vector2(0, -4), 34.0, Art.OCTO)
			for s in [-1.0, 1.0]:
				ctrl.draw_circle(c + Vector2(14 * s, 10), 10.0, Color("fbf6ea"))
				ctrl.draw_rect(Rect2(c + Vector2(14 * s - 5, 8), Vector2(10, 4)), Color("17141c"))
			ctrl.draw_circle(c + Vector2(-8, -20), 4.0, Art.OCTO.darkened(0.3))
		"radio":
			Art.radio(ctrl, c + Vector2(0, 38), t, 1.3)
