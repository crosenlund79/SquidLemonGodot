extends Node
## Global run state (autoload "Game"): stats, checkpoint, settings and input map.

signal kastanie_collected(total: int)

var kastanien_total := 20

var run_time := 0.0
var timing := false
var dryouts := 0
var falls := 0
var kastanien := {}            # id -> true
var checkpoint := Vector2.ZERO
var checkpoint_id := -1
var music_on := true
var mouse_recent := 999.0      # seconds since the mouse last moved (counts up)
var debug := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	debug = OS.get_cmdline_user_args().has("--debug")


func reset_run() -> void:
	run_time = 0.0
	dryouts = 0
	falls = 0
	kastanien.clear()
	checkpoint_id = -1
	timing = false


func collect_kastanie(id: int) -> void:
	if kastanien.has(id):
		return
	kastanien[id] = true
	kastanie_collected.emit(kastanien.size())


func format_time(t: float) -> String:
	var m := int(t) / 60
	var s := int(t) % 60
	var cs := int((t - floorf(t)) * 100.0)
	return "%d:%02d.%02d" % [m, s, cs]


func _process(dt: float) -> void:
	mouse_recent += dt
	if timing and not get_tree().paused:
		run_time += dt


func _input(e: InputEvent) -> void:
	if e is InputEventMouseMotion and e.relative.length() > 1.5:
		mouse_recent = 0.0
	elif e is InputEventMouseButton and e.pressed:
		mouse_recent = 0.0


func using_mouse() -> bool:
	return mouse_recent < 4.0


# --- Input map --------------------------------------------------------------

func _setup_input() -> void:
	_add("left", [_key(KEY_A), _key(KEY_LEFT), _jb(JOY_BUTTON_DPAD_LEFT), _ja(JOY_AXIS_LEFT_X, -1.0)])
	_add("right", [_key(KEY_D), _key(KEY_RIGHT), _jb(JOY_BUTTON_DPAD_RIGHT), _ja(JOY_AXIS_LEFT_X, 1.0)])
	_add("up", [_key(KEY_W), _key(KEY_UP), _jb(JOY_BUTTON_DPAD_UP), _ja(JOY_AXIS_LEFT_Y, -1.0)])
	_add("down", [_key(KEY_S), _key(KEY_DOWN), _jb(JOY_BUTTON_DPAD_DOWN), _ja(JOY_AXIS_LEFT_Y, 1.0)])
	_add("jump", [_key(KEY_SPACE), _key(KEY_C), _jb(JOY_BUTTON_A)])
	_add("grab", [_mb(MOUSE_BUTTON_LEFT), _key(KEY_J), _key(KEY_X), _jb(JOY_BUTTON_X), _jb(JOY_BUTTON_RIGHT_SHOULDER)])
	_add("ink", [_mb(MOUSE_BUTTON_RIGHT), _key(KEY_K), _key(KEY_SHIFT), _jb(JOY_BUTTON_B), _jb(JOY_BUTTON_LEFT_SHOULDER)])
	_add("pause", [_key(KEY_ESCAPE), _key(KEY_P), _jb(JOY_BUTTON_START)])
	_add("accept", [_key(KEY_ENTER), _key(KEY_KP_ENTER), _key(KEY_SPACE), _key(KEY_E), _jb(JOY_BUTTON_A), _mb(MOUSE_BUTTON_LEFT)])
	_add("ui_menu_up", [_key(KEY_W), _key(KEY_UP), _jb(JOY_BUTTON_DPAD_UP)])
	_add("ui_menu_down", [_key(KEY_S), _key(KEY_DOWN), _jb(JOY_BUTTON_DPAD_DOWN)])


func _add(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.3)
	for ev in events:
		InputMap.action_add_event(action, ev)


func _key(k: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = k
	return e


func _mb(b: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = b
	return e


func _jb(b: JoyButton) -> InputEventJoypadButton:
	var e := InputEventJoypadButton.new()
	e.button_index = b
	return e


func _ja(axis: JoyAxis, v: float) -> InputEventJoypadMotion:
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = v
	return e
