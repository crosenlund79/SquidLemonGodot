extends Node
## Dev tool: drives Otto with scripted inputs to verify that route sections are
## actually climbable.
##   godot --path . --headless -- --dev-test=res://tests/route.gd --route=e6
## Steps:  ["at", x, y]  ["hold", seconds, [actions...]]  ["tap", action]
##         ["wait", seconds]  ["log", label]  ["expect_above", y]  ["shot", name]

var main: Node
var route := "e6"
var out_dir := "/tmp"
var ok := true
var trace := false
var _tt := 0.0

const ROUTES := {
	"amb1b": [
		["at", 450, 530],
		["wait_vehicle", 560.0, 0],
		["log", "go"],
		["hold", 1.3, ["right"]],
		["log", "at ladder"],
		["hold", 4.2, ["up", "right"]],
		["log", "end"],
	],
	"showcase": [
		["intro"],
		["hold", 1.2, ["right", "up"]],
		["hold", 2.5, ["up"]],
		["hold", 12.0, ["up"]],
		["hold", 1.0, ["up"]],
		["log", "e6 done"],
		["at", 0, 2760],
		["hold", 0.6, ["up"]],
		["hold", 2.8, ["right"]],
		["tap", "jump"],
		["hold", 1.5, ["right"]],
		["hold", 2.4, ["right"]],
		["tap", "jump"],
		["hold", 1.2, ["right"]],
		["hold", 4.0, ["up", "right"]],
		["hold", 2.0, ["left", "up"]],
		["press", "grab"],
		["hold", 0.75, ["left"]],
		["hold", 0.3, ["up", "left"]],
		["release", "grab"],
		["hold", 0.3, ["up", "left"]],
		["hold", 3.4, ["left"]],
		["hold", 1.5, ["up"]],
		["log", "e5 done"],
		["at", -480, 2220],
		["hold", 0.3, ["left"]],
		["hold", 0.45, ["left", "jump"]],
		["tap", "ink"],
		["hold", 0.5, ["left"]],
		["hold", 0.5, ["left", "jump"]],
		["wait", 0.6],
		["hold", 0.22, ["jump", "right", "up"]],
		["press", "grab"],
		["hold", 0.15, ["right", "up"]],
		["hold", 0.85, ["right"]],
		["hold", 0.35, ["right", "up"]],
		["release", "grab"],
		["hold", 0.4, ["right", "up"]],
		["hold", 4.0, ["right", "up"]],
		["log", "e4 done"],
		["at", 455, 1650],
		["wait_vehicle", 1680.0, 0],
		["hold", 1.75, ["right"]],
		["hold", 3.4, ["up"]],
		["hold", 2.6, ["left"]],
		["hold", 0.2, ["down"]],
		["hold", 2.5, ["left"]],
		["hold", 1.5, ["up"]],
		["log", "e3 done"],
		["at", -930, 1090],
		["hold", 2.5, ["up"]],
		["hold", 1.3, ["right"]],
		["press", "grab"],
		["wait", 0.1],
		["hold", 0.65, ["right"]],
		["hold", 0.3, ["up", "right"]],
		["release", "grab"],
		["hold", 0.5, ["up", "right"]],
		["hold", 3.0, ["right"]],
		["hold", 1.0, ["up"]],
		["log", "e2 done"],
		["at", 450, 530],
		["wait_vehicle", 560.0, 0],
		["hold", 1.3, ["right"]],
		["hold", 4.2, ["up", "right"]],
		["hold", 0.5, ["left", "jump"]],
		["hold", 0.3, ["left"]],
		["log", "street"],
		["press", "grab"],
		["hold", 0.35, ["up"]],
		["hold", 0.7, ["left"]],
		["hold", 0.3, ["up", "left"]],
		["release", "grab"],
		["hold", 0.4, ["up", "left"]],
		["hold", 2.9, ["left", "up"]],
		["hold_until_dialogue", 6.0, ["up"]],
		["until_no_dialogue", 40.0],
		["hold", 2.5, ["up", "right"]],
		["log", "limb tip"],
		["press", "grab"],
		["hold", 0.5, ["right"]],
		["hold", 1.0, ["up"]],
		["release", "grab"],
		["log", "crown done"],
		["until_state", "credits", 70.0],
		["wait", 4.0],
	],
	"e6": [
		["at", -170, 3420],
		["hold", 1.2, ["right", "up"]],
		["hold", 2.5, ["up"]],
		["log", "below sleeve"],
		["hold", 12.0, ["up"]],
		["log", "after geyser"],
		["expect_above", 2880],
		["hold", 1.0, ["up"]],
		["log", "end"],
	],
	"e5": [
		["at", 0, 2760],
		["hold", 0.6, ["up"]],
		["log", "on trunk"],
		["hold", 1.2, ["right"]],
		["log", "walked along branch"],
		["hold", 1.6, ["right"]],
		["tap", "jump"],
		["hold", 1.5, ["right"]],
		["log", "deck"],
		["hold", 2.4, ["right"]],
		["tap", "jump"],
		["hold", 1.2, ["right"]],
		["log", "past car"],
		["hold", 4.0, ["up", "right"]],
		["log", "ivy top"],
		["hold", 2.0, ["left", "up"]],
		["log", "on pipe"],
		["hold", 0.1, ["left"]],
		["log", "end of P5a"],
	],
	"grapple5": [
		["at", 818, 2306],
		["hold", 0.3, ["up"]],
		["log", "on P5a end"],
		["press", "grab"],
		["hold", 0.75, ["left"]],
		["log", "swinging"],
		["hold", 0.3, ["up", "left"]],
		["log", "reeled"],
		["release", "grab"],
		["hold", 0.3, ["up", "left"]],
		["log", "on P5b?"],
		["hold", 5.0, ["left"]],
		["log", "crawl to trunk"],
		["hold", 1.5, ["up"]],
		["log", "end"],
		["expect_above", 2300],
	],
	"dash4": [
		["at", -480, 2220],
		["hold", 0.3, ["left"]],
		["hold", 0.45, ["left", "jump"]],
		["tap", "ink"],
		["hold", 0.8, ["left"]],
		["log", "after hole"],
		["expect_above", 2250],
	],
	"van4": [
		["at", -960, 2100],
		["wait", 0.6],
		["log", "on van"],
		["hold", 0.22, ["jump", "right", "up"]],
		["press", "grab"],
		["hold", 0.15, ["right", "up"]],
		["log", "fired"],
		["hold", 0.85, ["right"]],
		["log", "swing L2"],
		["hold", 0.35, ["right", "up"]],
		["log", "grab limb?"],
		["release", "grab"],
		["hold", 0.4, ["right", "up"]],
		["log", "after"],
		["hold", 4.0, ["right", "up"]],
		["log", "end"],
		["expect_above", 1790],
	],
	"car3": [
		["at", 455, 1650],
		["wait", 5.6],
		["log", "start"],
		["hold", 1.75, ["right"]],
		["hold", 3.4, ["up"]],
		["log", "ivy top"],
		["hold", 2.6, ["left"]],
		["log", "pipe end"],
		["hold", 0.2, ["down"]],
		["hold", 2.5, ["left"]],
		["log", "on limb"],
		["hold", 2.5, ["up"]],
		["log", "end"],
		["expect_above", 1240],
	],
	"vent2": [
		["at", -930, 1090],
		["hold", 2.5, ["up"]],
		["log", "pipe?"],
		["hold", 1.3, ["right"]],
		["log", "hot edge"],
		["press", "grab"],
		["wait", 0.1],
		["hold", 0.65, ["right"]],
		["log", "swing"],
		["hold", 0.3, ["up", "right"]],
		["release", "grab"],
		["hold", 0.5, ["up", "right"]],
		["log", "past hot"],
		["hold", 3.0, ["right"]],
		["hold", 2.0, ["up"]],
		["log", "end"],
		["expect_above", 620],
	],
	"amb1": [
		["at", 450, 530],
		["wait", 6.0],
		["log", "waited"],
		["hold", 3.0, ["right", "up"]],
		["log", "ladder?"],
		["hold", 4.0, ["up"]],
		["log", "surface"],
		["hold", 1.0, ["left"]],
		["expect_above", 0],
	],
	"crown": [
		["at", 470, -14],
		["wait", 0.3],
		["hold", 0.42, ["jump"]],
		["press", "up"],
		["tap", "ink"],
		["hold", 0.5, ["up"]],
		["release", "up"],
		["log", "on limb?"],
		["hold", 2.9, ["left", "up"]],
		["log", "trunk?"],
		["hold", 3.0, ["up"]],
		["log", "end"],
		["expect_above", -560],
	],
	"crown_lamp": [
		["at", 620, -14],
		["wait", 0.4],
		["press", "grab"],
		["hold", 0.35, ["up"]],
		["log", "on lamp"],
		["hold", 0.7, ["left"]],
		["log", "swung"],
		["hold", 0.3, ["up", "left"]],
		["release", "grab"],
		["hold", 0.4, ["up", "left"]],
		["log", "on limb?"],
		["hold", 4.0, ["left", "up"]],
		["log", "end"],
		["expect_above", -300],
	],
	"lemon": [
		["at", 150, -820],
		["hold", 0.5, ["up"]],
		["log", "limb"],
		["hold", 0.8, ["up", "right"]],
		["log", "tip"],
		["press", "grab"],
		["hold", 0.5, ["right"]],
		["log", "swing"],
		["hold", 1.0, ["up"]],
		["log", "reeled"],
		["release", "grab"],
		["log", "end"],
		["expect_lemon"],
	],
}


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--route="):
			route = a.substr(8)
		if a.begins_with("--out="):
			out_dir = a.substr(6)
		if a == "--trace":
			trace = true
	_run()


func _physics_process(dt: float) -> void:
	if not trace or main == null or main.world == null:
		return
	_tt += dt
	if _tt >= 0.15:
		_tt = 0.0
		var p := _pl()
		print("   t pos=(%.0f, %.0f) vel=(%.0f, %.0f) st=%d floor=%s clim=%s" % [p.global_position.x, p.global_position.y,
			p.velocity.x, p.velocity.y, p.st, p.is_on_floor(), main.world.is_climbable(p.global_position)])


func _tap(action: String) -> void:
	await get_tree().process_frame
	Input.action_press(action)
	await get_tree().physics_frame
	await get_tree().process_frame
	Input.action_release(action)


## Showcase only: advance dialogues like a (fast) reader would.
func _auto_accept() -> void:
	while true:
		await get_tree().create_timer(1.6).timeout
		if main.dlg.active or main.state == "intro":
			await _tap("accept")


func _pl() -> CharacterBody2D:
	return main.world.player


func _log(label: String) -> void:
	var p := _pl()
	print("    aim_target=", p.aim_target, " aim_dir=", p.aim_dir, " g_point=", p.g_point)
	print("[%s] %-20s pos=(%.0f, %.0f) vel=(%.0f, %.0f) st=%d moist=%.0f lvl=%d ink=%d g=%d" % [
		route, label, p.global_position.x, p.global_position.y, p.velocity.x, p.velocity.y, p.st, p.moisture,
		main.world.level_of(p.global_position.y), p.ink, p.g_state])


func _run() -> void:
	await get_tree().create_timer(0.5).timeout
	if route == "showcase":
		_auto_accept()
	else:
		main.dlg.set_process(false)
	for step in ROUTES[route]:
		match step[0]:
			"at":
				main._dev_start(Vector2(step[1], step[2]))
				if route != "showcase":
					# skip any dialogue triggered on the way
					main.world._seen["sleeve6"] = true
					main.world._seen["radio"] = true
				await get_tree().physics_frame
			"hold":
				for a in step[2]:
					Input.action_press(a)
				await get_tree().create_timer(step[1]).timeout
				for a in step[2]:
					Input.action_release(a)
			"press":
				Input.action_press(step[1])
				await get_tree().physics_frame
			"release":
				Input.action_release(step[1])
				await get_tree().physics_frame
			"tap":
				await get_tree().process_frame
				Input.action_press(step[1])
				await get_tree().physics_frame
				await get_tree().process_frame
				Input.action_release(step[1])
			"wait":
				await get_tree().create_timer(step[1]).timeout
			"intro":
				await get_tree().create_timer(2.0).timeout
				await _tap("accept")
				while main.state != "play":
					await get_tree().process_frame
			"wait_vehicle":
				for h in main.world.hazards:
					if h.get("floor_y") == step[1]:
						# wait for a fresh start of the requested phase
						while h.state == step[2]:
							await get_tree().process_frame
						while h.state != step[2]:
							await get_tree().process_frame
			"hold_until_dialogue":
				for a2 in step[2]:
					Input.action_press(a2)
				var t3 := 0.0
				while not main.dlg.active and t3 < step[1]:
					await get_tree().process_frame
					t3 += get_process_delta_time()
				for a2 in step[2]:
					Input.action_release(a2)
			"until_no_dialogue":
				await get_tree().create_timer(0.3).timeout
				var t2 := 0.0
				while main.dlg.active and t2 < step[1]:
					await get_tree().process_frame
					t2 += get_process_delta_time()
				await get_tree().create_timer(0.4).timeout
			"until_state":
				var tt := 0.0
				while main.state != step[1] and tt < step[2]:
					await get_tree().process_frame
					tt += get_process_delta_time()
			"log":
				_log(step[1])
			"expect_above":
				var y: float = _pl().global_position.y
				if y < float(step[1]):
					print("[%s] PASS  y=%.0f < %s" % [route, y, step[1]])
				else:
					print("[%s] FAIL  y=%.0f >= %s" % [route, y, step[1]])
					ok = false
			"expect_lemon":
				var got: bool = main.world.lemon.taken
				print("[%s] %s  lemon taken=%s" % [route, "PASS" if got else "FAIL", got])
				ok = ok and got
			"shot":
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png(out_dir + "/" + step[1] + ".png")
	print("[%s] DONE %s  state=%s lemon=%s kastanien=%d" % [route, "OK" if ok else "FAILED", main.state, main.world.lemon.taken, Game.kastanien.size()])
	get_tree().quit()
