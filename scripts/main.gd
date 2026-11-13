extends Node
## Game flow: title -> intro pan -> squid's briefing -> climb -> radio -> lemon
## -> the lemon drops down the shaft -> the squid is cured -> end card.

const WorldScript = preload("res://scripts/world.gd")
const HudScript = preload("res://scripts/ui/hud.gd")
const DialogueScript = preload("res://scripts/ui/dialogue.gd")
const TitleScript = preload("res://scripts/ui/title.gd")
const PauseScript = preload("res://scripts/ui/pause.gd")
const EndingScript = preload("res://scripts/ui/ending.gd")

var world: Node2D
var hud: CanvasLayer
var dlg: CanvasLayer
var title: CanvasLayer
var pause_menu: CanvasLayer
var ending: CanvasLayer
var fade_rect: ColorRect
var state := "boot"
var t := 0.0
var _pan_tween: Tween
var _radio_done := false
var _dev_test: Node


func _ready() -> void:
	randomize()
	var fl := CanvasLayer.new()
	fl.layer = 50
	add_child(fl)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(fade_rect)
	hud = HudScript.new()
	add_child(hud)
	dlg = DialogueScript.new()
	add_child(dlg)
	title = TitleScript.new()
	add_child(title)
	title.start_pressed.connect(_on_start)
	ending = EndingScript.new()
	add_child(ending)
	ending.done.connect(back_to_title)
	pause_menu = PauseScript.new()
	pause_menu.main = self
	add_child(pause_menu)
	_new_world()
	Audio.start_music()
	_enter_title()
	_fade_to(0.0, 1.4)
	_dev_hooks()


func _new_world() -> void:
	if world:
		remove_child(world)
		world.queue_free()
	world = WorldScript.new()
	world.main = self
	add_child(world)
	move_child(world, 0)
	world.level_changed.connect(_on_level_changed)
	world.radio_reached.connect(_on_radio)
	world.lemon_reached.connect(_on_lemon)
	hud.world = world
	_radio_done = false


func _enter_title() -> void:
	state = "title"
	Game.reset_run()
	world.cam_mode = "free"
	world.player.freeze(true)
	world.player.visible = false
	world.camera.global_position = Vector2(0, -520)
	world.cam_target = world.camera.global_position
	hud.show_hud = false
	title.show_title()


func _process(dt: float) -> void:
	t += dt
	match state:
		"title":
			world.cam_target = Vector2(sin(t * 0.13) * 150.0, -480.0 + sin(t * 0.09) * 190.0)
		"intro":
			if _pan_tween and _pan_tween.is_running() and Input.is_action_just_pressed("accept"):
				_pan_tween.custom_step(100.0)
		"play":
			if Input.is_action_just_pressed("pause") and not dlg.active and not get_tree().paused:
				pause_menu.open_menu()
		"ending_drop":
			world.cam_target = world.lemon.global_position
		"ending_rise":
			world.cam_target = Vector2(90, maxf(-700.0, world.squid.global_position.y + world.squid.rise_tip_y() + 160.0))


# --- flow ---------------------------------------------------------------------------

func _on_start() -> void:
	if state != "title":
		return
	state = "intro"
	Game.reset_run()
	title.hide_title()
	var p = world.player
	p.respawn_at(world.get_spawn())
	p.freeze(true)
	p.visible = true
	await _pan(world.camera.global_position, p.global_position + Vector2(0, -60), 7.5)
	world.cam_mode = "follow"
	await get_tree().create_timer(0.3).timeout
	await say([
		["squid", "Ah — Otto! Servus, mein Lieber. Come closer, I don't bite. ...Much."],
		["squid", "Ha... ha... HATSCHI!!", func(): world.squid.sneeze_now(false)],
		["squid", "Pardon. Ever since the Wien river came in through the drains, Ebene −6 is my private bath. And my Schnupfen gets worse by the hour."],
		["squid", "The doctors upstairs won't come down. Something about this not being a veterinary clinic. Pfff. Unerhört!"],
		["squid", "But listen. That chestnut tree was planted in 1937. They built this whole car park around it."],
		["squid", "And at the very top, under the open sky, grows a lemon. A BLUE one. My grandmother swore by them."],
		["otto", "Blub?"],
		["squid", "Bring it down to me, Schatzi. And can you hear that waltz? Somebody's old radio, way up there. Follow the music."],
		["squid", "Oh — and don't dry out. You're an octopus, not a Dörrpflaume. Puddles, drips and the cleaners' mop buckets keep you fresh."],
	])
	world.squid.enabled = true
	world.squid.next_sneeze = 9.0
	_begin_play()


func _begin_play() -> void:
	state = "play"
	Game.timing = true
	hud.show_hud = true
	world.cam_mode = "follow"
	world.player.freeze(false)
	hud.banner(world.level_of(world.player.global_position.y))
	toast("Swim up with [W]. On bark, hold [W] to climb.")


func _pan(from: Vector2, to: Vector2, dur: float) -> void:
	world.cam_mode = "direct"
	world.cam_target = from
	_pan_tween = create_tween()
	_pan_tween.tween_method(_set_cam_target, from, to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _pan_tween.finished


func _set_cam_target(v: Vector2) -> void:
	world.cam_target = v


func say(lines: Array) -> void:
	var p = world.player
	var was_frozen: bool = p.is_frozen()
	p.freeze(true)
	var was_timing := Game.timing
	Game.timing = false
	hud.dialog_open = true
	dlg.start(lines)
	await dlg.finished
	await get_tree().create_timer(0.15).timeout
	hud.dialog_open = false
	Game.timing = was_timing
	if not was_frozen and state == "play":
		p.freeze(false)


func toast(s: String) -> void:
	hud.toast(s)


func on_first_sleeve() -> void:
	if state != "play":
		return
	await say([
		["squid", "Oh dear — the Baumschutz! A metal sleeve. Nothing for your suckers to hold on to."],
		["squid", "Stay in the shaft and wait for my next sneeze... let it carry you up. Keep holding [W]!"],
	])
	world.squid.next_sneeze = minf(world.squid.next_sneeze, 3.2)


func _on_level_changed(k: int) -> void:
	if state == "play":
		hud.banner(k)


func _on_radio() -> void:
	if _radio_done or state != "play":
		return
	_radio_done = true
	Audio.play("radio_tune", -4.0)
	Game.checkpoint = world.player.global_position
	Game.checkpoint_id = 100
	world.fx.text(world.radio.global_position + Vector2(0, -80), "GESPEICHERT", Color("ffe28a"), 18.0, 1.6)
	await say([
		["radio", "...krrrzzz... Hier ist Radio Wien. Meine Damen und Herren — and any octopus who happens to be listening..."],
		["radio", "...the next waltz goes out to Frau Hofrätin Kalmar, Ebene minus sechs. Gute Besserung!"],
		["", "A brass plate on the walnut case reads: »F. Hofbauer, Gärtner, 1937 — damit der Baum nicht allein ist.«  (So the tree is never lonely.)"],
		["otto", "Blub."],
	])
	toast("The blue lemon hangs just above! Up the right limb — then swing.")


func respawn_player(dried := true) -> void:
	if state != "play":
		return
	state = "respawn"
	await _fade_to(1.0, 0.35)
	world.player.respawn_at(Game.checkpoint)
	world.camera.global_position = Game.checkpoint
	Audio.play("respawn", -4.0)
	state = "play"
	await _fade_to(0.0, 0.35)
	if dried:
		var msgs := [
			"Hofrätin Kalmar: »Otto! You look like a Dörrpflaume!«",
			"»Back to the bucket, Schatzi. Octopuses are meant to be wet.«",
			"»Pfff. Drink something, mein Lieber!«",
		]
		toast(msgs[randi() % msgs.size()])


func _on_lemon() -> void:
	if state != "play":
		return
	state = "ending"
	Game.timing = false
	hud.show_hud = false
	var p = world.player
	p.freeze(true)
	Audio.play("lemon", -2.0)
	var lem = world.lemon
	world.fx.burst(lem.global_position, 30, 260.0, Color(0.5, 0.7, 1.0, 0.9), 1.0, 4.0, 100.0)
	await say([
		["", "Otto found the BLUE LEMON. It is as cold as the sea and hums like a tuning fork."],
		["otto", "BLUB!!"],
		["", "Far, far below, somebody sneezes."],
		["", "Otto takes careful aim down the light shaft..."],
	])
	lem.falling = true
	var tw := create_tween()
	tw.tween_property(lem, "global_position", p.global_position + Vector2(0, -36), 0.5)
	await tw.finished
	await get_tree().create_timer(0.5).timeout
	world.cam_mode = "free"
	state = "ending_drop"
	Audio.play("shoot", -2.0, 0.7)
	var ft := create_tween()
	ft.tween_property(lem, "global_position", Vector2(lem.global_position.x - 60.0, lem.global_position.y - 110.0), 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	ft.tween_property(lem, "global_position", Vector2(30, 3262), 4.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await ft.finished
	state = "ending_splash"
	Audio.play("splash", 2.0, 0.8)
	world.fx.splash(Vector2(30, 3240), 2.2)
	world.add_shake(0.6)
	lem.visible = false
	await get_tree().create_timer(0.6).timeout
	# look down at the squid while she eats it
	var ct := create_tween()
	ct.tween_method(_set_cam_target, world.cam_target, world.squid.global_position + Vector2(-60, -150), 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await ct.finished
	Audio.play("gulp", 0.0)
	world.squid.cure()
	world.squid.flail = 0.8
	await get_tree().create_timer(1.4).timeout
	await say([
		["squid", "Mmmmh...  SAUER!"],
		["squid", "Oh. OH! My siphon — it's clear! I can smell the Danube again!"],
		["squid", "Otto, du bist ein Schatz. A true Wiener. Wait right there — I'm coming up to give you a proper hug!"],
	])
	state = "ending_rise"
	world.cam_mode = "free"
	p.global_position = Vector2(46, -676)
	p.respawn_at(p.global_position)
	p.freeze(true)
	var rt := create_tween()
	rt.tween_property(world.squid, "rise", 1.0, 7.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await rt.finished
	Audio.play("fanfare", -2.0)
	await get_tree().create_timer(1.5).timeout
	state = "credits"
	ending.show_stats()


func back_to_title() -> void:
	get_tree().paused = false
	await _fade_to(1.0, 0.6)
	ending.active = false
	_new_world()
	_enter_title()
	await _fade_to(0.0, 0.8)


func _fade_to(a: float, dur: float) -> void:
	var tw := create_tween()
	tw.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tw.tween_property(fade_rect, "color:a", a, dur)
	await tw.finished


# --- developer hooks ---------------------------------------------------------------
#   godot --path . -- --dev-start=x,y          start playing at a position
#   godot --path . -- --dev-test=res://tests/x.gd   run a scripted test

func _dev_hooks() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--dev-start="):
			var v := arg.substr(12).split(",")
			_dev_start(Vector2(float(v[0]), float(v[1])))
		elif arg.begins_with("--dev-test="):
			var scr = load(arg.substr(11))
			_dev_test = scr.new()
			_dev_test.set("main", self)
			add_child(_dev_test)


func _dev_start(p: Vector2, reset := true) -> void:
	title.hide_title()
	title.alpha = 0.0
	fade_rect.color.a = 0.0
	if reset:
		Game.reset_run()
	world.player.visible = true
	world.player.respawn_at(p)
	world.camera.global_position = p
	Game.checkpoint = p
	world.squid.enabled = true
	_begin_play()
