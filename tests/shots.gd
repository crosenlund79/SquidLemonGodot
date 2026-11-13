extends Node
## Dev tool: renders screenshots at a series of places in the level.
##   godot --path . --rendering-driver opengl3 -- --dev-test=res://tests/shots.gd --shots-dir=/tmp/shots

var main: Node
var out_dir := "user://shots"

const SPOTS := [
	["title", Vector2.ZERO],
	["e6_pit", Vector2(-170, 3420)],
	["e6_trunk", Vector2(0, 3100)],
	["e5_right", Vector2(620, 2760)],
	["e5_pipes", Vector2(760, 2330)],
	["e5_left", Vector2(-760, 2760)],
	["e4_left", Vector2(-640, 2200)],
	["e4_lamps", Vector2(-860, 1960)],
	["e3_right", Vector2(560, 1640)],
	["e3_fan", Vector2(760, 1200)],
	["e2_left", Vector2(-640, 1080)],
	["e2_pipe", Vector2(-760, 640)],
	["e1_right", Vector2(600, 520)],
	["surface", Vector2(560, -20)],
	["crown", Vector2(0, -420)],
	["top", Vector2(120, -760)],
]


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out_dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _run() -> void:
	await get_tree().create_timer(2.5).timeout
	for s in SPOTS:
		var name: String = s[0]
		var p: Vector2 = s[1]
		if name != "title":
			main._dev_start(p)
			main.world.camera.global_position = p + Vector2(0, -30)
			await get_tree().create_timer(0.7).timeout
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		img.save_png(out_dir + "/" + name + ".png")
		print("shot ", name)
	get_tree().quit()
