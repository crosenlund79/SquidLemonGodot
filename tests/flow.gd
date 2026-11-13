extends Node
## Dev tool: plays through title -> intro -> play -> ending -> title, pressing
## "accept" like an impatient player, and saves screenshots along the way.
##   godot --path . -- --dev-test=res://tests/flow.gd --shots-dir=/tmp/flow

var main: Node
var out_dir := "user://flow"
var _n := 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots-dir="):
			out_dir = a.substr(12)
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run()


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	get_viewport().get_texture().get_image().save_png("%s/%02d_%s.png" % [out_dir, _n, name])
	print("shot ", name, "  state=", main.state)


func _tap(action: String) -> void:
	# press right before a frame's _process so both _process and
	# _physics_process see it as "just pressed"
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release(action)


func _until(state: String, timeout: float, press_every := 0.0) -> bool:
	var t := 0.0
	var acc := 0.0
	while main.state != state and t < timeout:
		await get_tree().process_frame
		var dt := get_process_delta_time()
		t += dt
		acc += dt
		if press_every > 0.0 and acc >= press_every:
			acc = 0.0
			await _tap("accept")
	print("until ", state, " -> ", main.state, " after ", snappedf(t, 0.1), "s")
	return main.state == state


func _run() -> void:
	await get_tree().create_timer(2.0).timeout
	await _shot("title")
	await _tap("accept")
	await get_tree().create_timer(3.0).timeout
	await _shot("intro_pan")
	await get_tree().create_timer(5.0).timeout
	await _shot("intro_dialogue")
	await _until("play", 60.0, 0.35)
	await get_tree().create_timer(1.0).timeout
	await _shot("play_start")
	# pause menu
	await _tap("pause")
	await get_tree().create_timer(0.3).timeout
	await _shot("pause")
	await _tap("pause")
	await get_tree().create_timer(0.3).timeout
	# dry out on purpose
	main.world.player.moisture = 0.5
	await get_tree().create_timer(0.6).timeout
	await _shot("drying")
	await get_tree().create_timer(2.5).timeout
	await _shot("respawned")
	# jump to the radio and the lemon
	main.world.player.respawn_at(Vector2(10, -600))
	await get_tree().create_timer(0.8).timeout
	await _shot("radio_dialogue")
	await _until("play", 30.0, 0.35)
	main.world.player.respawn_at(Vector2(318, -870))
	await get_tree().create_timer(0.6).timeout
	await _shot("lemon_dialogue")
	await _until("ending_drop", 30.0, 0.35)
	await get_tree().create_timer(2.5).timeout
	await _shot("lemon_falling")
	await _until("ending_rise", 40.0, 0.5)
	await get_tree().create_timer(3.5).timeout
	await _shot("tentacle_rising")
	await _until("credits", 30.0)
	await get_tree().create_timer(3.0).timeout
	await _shot("credits")
	await _tap("accept")
	await get_tree().create_timer(2.5).timeout
	await _shot("back_to_title")
	print("FLOW DONE state=", main.state)
	get_tree().quit()
