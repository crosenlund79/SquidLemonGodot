extends Node2D
## The whole level: a cross-section through a six-storey underground car park
## under a Viennese hospital, with a 1937 horse-chestnut tree growing up the
## central light shaft. Built procedurally at runtime.
##
## Coordinates: y grows downwards. The street/ground is at y = 0. Ebene -k has
## its floor at y = 560 * k. The light shaft spans |x| < 380.

signal level_changed(k: int)
signal lemon_reached
signal radio_reached

const Art = preload("res://scripts/art.gd")
const Painter = preload("res://scripts/painter.gd")
const FX = preload("res://scripts/fx.gd")
const PlayerScript = preload("res://scripts/player.gd")
const SquidScript = preload("res://scripts/squid.gd")
const WaterScript = preload("res://scripts/water.gd")
const BucketScript = preload("res://scripts/objects/bucket.gd")
const KastanieScript = preload("res://scripts/objects/kastanie.gd")
const PigeonScript = preload("res://scripts/objects/pigeon.gd")
const CarScript = preload("res://scripts/objects/car.gd")
const DripScript = preload("res://scripts/objects/drip.gd")
const SprinklerScript = preload("res://scripts/objects/sprinkler.gd")
const VentScript = preload("res://scripts/objects/vent.gd")
const FanScript = preload("res://scripts/objects/fan.gd")
const RadioScript = preload("res://scripts/objects/radio.gd")
const LemonScript = preload("res://scripts/objects/lemon.gd")
const SkyScript = preload("res://scripts/objects/sky.gd")
const RainScript = preload("res://scripts/objects/rain.gd")
const AnchorFX = preload("res://scripts/objects/anchors.gd")

const LH := 560.0
const SLAB := 40.0
const SHAFT := 380.0
const PAR_W := 20.0
const PAR_H := 36.0
const DECK := 1100.0
const WALL := 1160.0
const WATER_Y := 3240.0
const PIT_BOTTOM := 3900.0
const FORK_Y := -600.0
const RADIO_POS := Vector2(-6, -628)
const LEMON_POS := Vector2(318, -902)
const SPAWN := Vector2(-170, 3420)

const L_SOLID := 1
const L_ONEWAY := 2
const L_PLAYER := 8

var player: CharacterBody2D
var camera: Camera2D
var squid: Node2D
var fx: Node2D
var water: Node2D
var radio: Node2D
var lemon: Node2D
var anchor_fx: Node2D
var main: Node  # set by main.gd

var climb_caps: Array = []      # {a, b, r}
var climb_rects: Array = []     # Rect2
var sleeves: Array = []         # Vector2(top, bottom)
var waters: Array = []          # Rect2 (position.y = surface)
var winds: Array = []           # objects with wind_at(p) -> Vector2
var heats: Array = []           # {rect, drain, lift, top}
var refills: Array = []         # objects with refill_at(p) -> float
var anchors: Array = []         # Vector2
var triggers: Array = []        # {rect, id, fn}
var hazards: Array = []
var buckets: Array = []
var kastanie_nodes: Array = []
var geyser_rect := Rect2(-118, 2690, 236, 560)
var geyser_on := false

var time := 0.0
var cam_mode := "follow"        # follow | free
var cam_target := Vector2.ZERO
var shake := 0.0
var current_level := 6
var _lvl_hold := 0.0
var _rng := RandomNumberGenerator.new()
var _kid := 0
var _seen := {}


func _ready() -> void:
	_rng.seed = 1937
	_build()


# =============================================================================
#  Queries used by the player and objects
# =============================================================================

func get_spawn() -> Vector2:
	return SPAWN


func floor_y(k: int) -> float:
	return LH * k


func ceil_y(k: int) -> float:
	return LH * (k - 1) + SLAB


func trunk_cx(y: float) -> float:
	return 28.0 * sin(y * 0.0021) + 6.0 * sin(y * 0.011)


func trunk_hw(y: float) -> float:
	return lerpf(30.0, 62.0, clampf((y + 700.0) / 4600.0, 0.0, 1.0))


func in_sleeve(y: float) -> bool:
	for s in sleeves:
		if y > s.x and y < s.y:
			return true
	return false


func is_trunk(p: Vector2) -> bool:
	if p.y < FORK_Y - 20.0 or p.y > PIT_BOTTOM:
		return false
	if absf(p.x - trunk_cx(p.y)) > trunk_hw(p.y) + 4.0:
		return false
	return not in_sleeve(p.y)


func is_climbable(p: Vector2) -> bool:
	if is_trunk(p):
		return true
	for c in climb_caps:
		if _seg_dist(p, c.a, c.b) <= c.r:
			return true
	for r in climb_rects:
		if r.has_point(p):
			return true
	return false


## Which kind of surface is at p (for Otto's camouflage colour).
func surface_kind(p: Vector2) -> String:
	if is_trunk(p):
		return "bark"
	for c in climb_caps:
		if _seg_dist(p, c.a, c.b) <= c.r:
			return c.get("kind", "bark")
	for r in climb_rects:
		if r.has_point(p):
			return "ivy"
	return ""


func water_at(p: Vector2) -> float:
	## Returns the water surface y if p is under water, else INF.
	for r in waters:
		if p.x >= r.position.x and p.x <= r.end.x and p.y >= r.position.y and p.y <= r.end.y:
			return r.position.y
	return INF


func sample_env(p: Vector2) -> Dictionary:
	var env := {"surface": INF, "wind": Vector2.ZERO, "lift": 0.0, "heat": 0.0, "refill": 0.0, "geyser": false}
	env.surface = water_at(p)
	for w in winds:
		env.wind += w.wind_at(p)
	for h in heats:
		var r: Rect2 = h.rect
		if r.has_point(p):
			env.heat += h.drain
			if h.lift > 0.0:
				var f := clampf((p.y - h.top) / 90.0, 0.0, 1.0)
				env.lift = maxf(env.lift, h.lift * f)
	for o in refills:
		env.refill += o.refill_at(p)
	if p.y < 20.0:
		env.refill += 2.4  # Viennese drizzle keeps Otto damp up top
	if geyser_on and geyser_rect.has_point(p):
		env.geyser = true
		env.refill += 60.0
	return env


func level_of(y: float) -> int:
	if y < 0.0:
		return 0
	return clampi(int(ceilf(y / LH)), 1, 6)


func nearest_anchor(from: Vector2, dir: Vector2, range_px: float, mouse_pos = null) -> Variant:
	var space := get_world_2d().direct_space_state
	var best = null
	var best_score := INF
	for a in anchors:
		var d: Vector2 = a - from
		var dist := d.length()
		if dist > range_px or dist < 12.0:
			continue
		var score := 0.0
		if mouse_pos != null:
			score = (a - mouse_pos).length() + dist * 0.15
			var ang := absf(d.angle_to((mouse_pos - from)))
			if ang > 1.1:
				continue
		elif dir == Vector2.ZERO:
			score = dist
		else:
			var ang2 := absf(d.angle_to(dir))
			if ang2 > 0.95:
				continue
			score = ang2 * 260.0 + dist * 0.6
		if score >= best_score:
			continue
		var q := PhysicsRayQueryParameters2D.create(from, a, L_SOLID)
		if not space.intersect_ray(q).is_empty():
			continue
		best_score = score
		best = a
	if best == null and mouse_pos == null and dir != Vector2.ZERO:
		# keyboard / gamepad: fall back to the closest reachable ring
		return nearest_anchor(from, Vector2.ZERO, range_px)
	return best


static func _seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / maxf(0.0001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)


# =============================================================================
#  Frame update
# =============================================================================

func _process(dt: float) -> void:
	time += dt
	_update_camera(dt)
	if player and is_instance_valid(player):
		_check_triggers()
		var lv := level_of(player.global_position.y)
		if lv != current_level:
			_lvl_hold += dt
			if _lvl_hold > 0.35:
				current_level = lv
				_lvl_hold = 0.0
				level_changed.emit(lv)
		else:
			_lvl_hold = 0.0
	# audio: the waltz gets clearer the closer the camera is to the radio
	var cy := camera.global_position.y
	var t := clampf(1.0 - (cy - RADIO_POS.y) / (PIT_BOTTOM - 200.0 - RADIO_POS.y), 0.0, 1.0)
	var under := false
	if player and cam_mode == "follow":
		under = player.global_position.y > water_at(player.global_position) + 10.0
	Audio.set_listen(t, under, clampf((180.0 - cy) / 360.0, 0.0, 1.0))


func _update_camera(dt: float) -> void:
	var target := cam_target
	if cam_mode == "direct":
		camera.global_position = cam_target
	elif cam_mode == "follow" and player:
		var look: Vector2 = player.velocity * Vector2(0.18, 0.12)
		look = look.limit_length(110.0)
		target = player.global_position + look + Vector2(0, -30)
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-6.0 * dt))
	else:
		camera.global_position = camera.global_position.lerp(target, 1.0 - exp(-3.0 * dt))
	shake = maxf(0.0, shake - dt * 2.5)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 14.0


func add_shake(a: float) -> void:
	shake = clampf(shake + a, 0.0, 1.2)


func _check_triggers() -> void:
	var p: Vector2 = player.global_position
	for tr in triggers:
		if _seen.has(tr.id):
			continue
		if tr.rect.has_point(p):
			_seen[tr.id] = true
			tr.fn.call()


func _toast(s: String) -> void:
	if main:
		main.toast(s)


func _main_call(m: String) -> void:
	if main and main.has_method(m):
		main.call(m)


func trigger_seen(id: String) -> bool:
	return _seen.has(id)


# =============================================================================
#  Build
# =============================================================================

func _build() -> void:
	camera = Camera2D.new()
	camera.zoom = Vector2(1.4, 1.4)
	camera.limit_left = int(-WALL)
	camera.limit_right = int(WALL)
	camera.limit_top = -1250
	camera.limit_bottom = int(PIT_BOTTOM + 60.0)
	camera.position = SPAWN
	add_child(camera)
	camera.make_current()

	var sky := SkyScript.new()
	sky.z_index = -100
	sky.world = self
	add_child(sky)

	_build_structure()
	_build_tree()
	_build_levels()
	_build_surface()

	water = WaterScript.new()
	water.world = self
	water.z_index = 10
	add_child(water)
	var flood := Rect2(-DECK, WATER_Y, DECK * 2.0, PIT_BOTTOM - WATER_Y)
	waters.append(flood)
	water.bodies.append(flood)

	squid = SquidScript.new()
	squid.world = self
	squid.position = Vector2(150, 3720)
	squid.z_index = -30
	add_child(squid)

	anchor_fx = AnchorFX.new()
	anchor_fx.world = self
	anchor_fx.z_index = 6
	add_child(anchor_fx)

	player = PlayerScript.new()
	player.world = self
	player.position = SPAWN
	add_child(player)

	fx = FX.new()
	fx.z_index = 20
	add_child(fx)

	var rain := RainScript.new()
	rain.world = self
	rain.z_index = 30
	add_child(rain)

	Game.checkpoint = SPAWN
	Game.kastanien_total = kastanie_nodes.size()


# --- small builders ------------------------------------------------------------

func _painter(z: int, f: Callable, additive := false) -> Node2D:
	var p := Painter.new()
	p.paint = f
	p.z_index = z
	if additive:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		p.material = m
	add_child(p)
	return p


func _solid(r: Rect2) -> void:
	var b := StaticBody2D.new()
	b.collision_layer = L_SOLID
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = r.size
	cs.shape = sh
	b.position = r.get_center()
	b.add_child(cs)
	add_child(b)


func _oneway(a: Vector2, b: Vector2, thick := 10.0) -> void:
	if a.x > b.x:
		var t := a
		a = b
		b = t
	var body := StaticBody2D.new()
	body.collision_layer = L_ONEWAY
	body.collision_mask = 0
	body.position = (a + b) * 0.5
	body.rotation = (b - a).angle()
	var cs := CollisionShape2D.new()
	var sh := RectangleShape2D.new()
	sh.size = Vector2((b - a).length(), thick)
	cs.shape = sh
	cs.position = Vector2(0, thick * 0.5)
	cs.one_way_collision = true
	cs.one_way_collision_margin = 6.0
	body.add_child(cs)
	add_child(body)


func _climb_cap(a: Vector2, b: Vector2, r: float, kind := "bark") -> void:
	climb_caps.append({"a": a, "b": b, "r": r, "kind": kind})


func _anchor(p: Vector2) -> void:
	anchors.append(p)


func _kastanie(p: Vector2, parent: Node = null) -> Node2D:
	var k := KastanieScript.new()
	k.world = self
	k.id = _kid
	_kid += 1
	k.z_index = -8
	if parent:
		k.position = p
		parent.add_child(k)
	else:
		k.position = p
		add_child(k)
	kastanie_nodes.append(k)
	return k


func _bucket(x: float, fy: float) -> void:
	var b := BucketScript.new()
	b.world = self
	b.position = Vector2(x, fy)
	b.z_index = -12
	b.idx = buckets.size()
	add_child(b)
	buckets.append(b)


func _pipe(a: Vector2, b: Vector2, col: Color, ceil_y_v: float, climb := true) -> void:
	if climb:
		_climb_cap(a, b, 17.0, "metal")
	_painter(-55, func(ci): Art.pipe(ci, a, b, col, ceil_y_v))


func _ivy(r: Rect2) -> void:
	climb_rects.append(r)
	var s := _rng.randi()
	_painter(-22, func(ci): Art.ivy(ci, r, s))


func _sign(p: Vector2, s: String, size := 14, bg := Color("e9e4d4"), fg := Color("1d2329"), z := -60) -> void:
	_painter(z, func(ci): Art.sign_box(ci, p, s, size, bg, fg))


func _hint(p: Vector2, s: String, size := 15) -> void:
	# Stencil-painted tutorial text on the concrete.
	_painter(-58, func(ci): Art.text(ci, p, s, size, Color(0.95, 0.92, 0.75, 0.82)))


func _trigger(r: Rect2, id: String, fn: Callable) -> void:
	triggers.append({"rect": r, "id": id, "fn": fn})


func _parked_car(x: float, fy: float, dir: float, col: Color, kind := "car") -> void:
	var L := 190.0 if kind == "car" else 200.0
	var H := 72.0 if kind == "car" else 98.0
	_solid(Rect2(x - L * 0.5, fy - H * 0.62, L, H * 0.62 - 6.0))
	if kind == "car":
		_solid(Rect2(x - 38.0 * dir - 30.0, fy - H, 60.0, H * 0.38 + 2.0))
		_oneway(Vector2(x - 40.0, fy - H), Vector2(x + 30.0, fy - H), 8.0)
	else:
		_solid(Rect2(x - L * 0.5, fy - H, L * 0.75, H * 0.38 + 2.0))
	_painter(-14, func(ci): Art.car(ci, Vector2(x, fy), dir, col, kind))


func _back_car(x: float, fy: float, dir: float, col: Color) -> void:
	_painter(-72, func(ci): Art.car(ci, Vector2(x, fy - 4.0), dir, col.darkened(0.55), "car"))


func _lamp_glow(p: Vector2, col := Color(1.0, 0.97, 0.85, 0.3), r := 120.0) -> void:
	_painter(-50, _paint_lamp_glow.bind(p, col, r), true)


func _paint_lamp_glow(ci: CanvasItem, p: Vector2, col: Color, r: float) -> void:
	ci.draw_colored_polygon(PackedVector2Array([p + Vector2(-34, 4), p + Vector2(34, 4), p + Vector2(r * 1.2, r * 2.2), p + Vector2(-r * 1.2, r * 2.2)]),
		Color(col, col.a * 0.25))
	Art.glow(ci, p, r, col)


# --- structure: slabs, walls, nets, back walls ----------------------------------

func _build_structure() -> void:
	# Slabs between storeys (k = 0 is the ground slab).
	for k in 6:
		var y := LH * k
		if k == 4:
			# Construction hole in the left deck of Ebene -4 (x -820 .. -520).
			_solid(Rect2(-WALL, y, WALL - 820.0, SLAB))
			_solid(Rect2(-520.0, y, 520.0 - SHAFT, SLAB))
		else:
			_solid(Rect2(-WALL, y, WALL - SHAFT, SLAB))
		if k == 0:
			# Hatch for the emergency ladder (x 790 .. 860).
			_solid(Rect2(SHAFT, y, 790.0 - SHAFT, SLAB))
			_solid(Rect2(860.0, y, WALL - 860.0, SLAB))
		else:
			_solid(Rect2(SHAFT, y, WALL - SHAFT, SLAB))
	# Parapets at the shaft edge for every deck floor, and the street railing.
	for k in range(0, 7):
		var fy := LH * k
		var h := PAR_H if k > 0 else 44.0
		_solid(Rect2(-SHAFT - PAR_W, fy - h, PAR_W, h))
		_solid(Rect2(SHAFT, fy - h, PAR_W, h))
	# Outer walls.
	_solid(Rect2(-WALL, 0, WALL - DECK, PIT_BOTTOM + 60.0))
	_solid(Rect2(DECK, 0, WALL - DECK, PIT_BOTTOM + 60.0))
	# Street-level invisible bounds.
	_solid(Rect2(-WALL - 80.0, -1600, 80.0, 1600.0))
	_solid(Rect2(WALL, -1600, 80.0, 1600.0))
	# Earth below Ebene -6 decks and the pit floor.
	_solid(Rect2(-WALL, LH * 6, WALL - SHAFT, PIT_BOTTOM + 60.0 - LH * 6))
	_solid(Rect2(SHAFT, LH * 6, WALL - SHAFT, PIT_BOTTOM + 60.0 - LH * 6))
	_solid(Rect2(-SHAFT, PIT_BOTTOM, SHAFT * 2.0, 60.0))

	# Safety nets across the shaft at every deck floor (gap around the trunk).
	for k in range(0, 6):
		var ny := LH * k + (12.0 if k == 0 else 0.0)
		var cx := trunk_cx(ny)
		var gap := 118.0
		_oneway(Vector2(-SHAFT, ny), Vector2(cx - gap, ny), 8.0)
		_oneway(Vector2(cx + gap, ny), Vector2(SHAFT, ny), 8.0)
		_painter(-6, _paint_net.bind(cx, gap, ny))

	# Back walls (drawn per storey so they cull well) and foreground slabs.
	for k in range(1, 7):
		_painter(-80, _paint_backwall.bind(k))
		_painter(15, _paint_slab.bind(k - 1))
	_painter(15, _paint_slab.bind(6))
	_painter(-79, _paint_pit)


func _paint_net(ci: CanvasItem, cx: float, gap: float, ny: float) -> void:
	Art.net(ci, -SHAFT, cx - gap, ny)
	Art.net(ci, cx + gap, SHAFT, ny)
	ci.draw_circle(Vector2(cx - gap, ny), 3, Color("8a8070"))
	ci.draw_circle(Vector2(cx + gap, ny), 3, Color("8a8070"))


func _paint_backwall(ci: CanvasItem, k: int) -> void:
	var top := LH * (k - 1) + SLAB
	var bot := LH * k
	var depth := float(k) / 6.0
	var wall := Art.BACKWALL.lerp(Color("1a2229"), depth * 0.6)
	var lc: Color = Art.LEVEL_COLORS[k]
	# decks
	for side: float in [-1.0, 1.0]:
		var x0 := SHAFT if side > 0 else -DECK
		var r := Rect2(x0, top, DECK - SHAFT, bot - top)
		ci.draw_rect(r, wall)
		# ceiling beams
		var bx := x0 + 60.0
		while bx < x0 + DECK - SHAFT:
			ci.draw_rect(Rect2(bx, top, 26, 18), wall.darkened(0.3))
			bx += 220.0
		# level colour band
		ci.draw_rect(Rect2(x0, bot - 230, DECK - SHAFT, 26), Color(lc, 0.55))
		ci.draw_rect(Rect2(x0, bot - 200, DECK - SHAFT, 4), Color(lc, 0.35))
		# pillars
		var px := x0 + 150.0
		while px < x0 + DECK - SHAFT - 60.0:
			ci.draw_rect(Rect2(px, top, 54, bot - top), wall.lightened(0.07))
			ci.draw_rect(Rect2(px + 46, top, 8, bot - top), wall.darkened(0.15))
			Art.hazard_band(ci, Rect2(px, bot - 60, 54, 60), Color("caa52a").darkened(depth * 0.3), Color("1d1d1d"))
			ci.draw_rect(Rect2(px, bot - 300, 54, 46), lc.darkened(0.1))
			Art.text(ci, Vector2(px + 27, bot - 266), "−%d" % k, 26, Color(1, 1, 1, 0.9))
			px += 330.0
		# floor kerb
		ci.draw_rect(Rect2(x0, bot - 8, DECK - SHAFT, 8), wall.darkened(0.25))
		# water stains
		for i in 6:
			var sx := x0 + _hash01(k * 31 + i + int(side)) * (DECK - SHAFT)
			ci.draw_rect(Rect2(sx, top, 3 + 8 * _hash01(i * 7 + k), 120 + 200 * _hash01(i + k * 3)), Color(0, 0, 0, 0.12))
	# big painted storey markers
	Art.text(ci, Vector2(-760, bot - 330), "−%d" % k, 110, Color(lc, 0.42))
	Art.text(ci, Vector2(760, bot - 330), "−%d" % k, 110, Color(lc, 0.42))
	# shaft back wall
	ci.draw_rect(Rect2(-SHAFT, LH * (k - 1), SHAFT * 2.0, LH), Art.SHAFTWALL.lerp(Color("10161b"), depth * 0.5))
	for i in 9:
		var sx2 := -SHAFT + 40.0 + i * 88.0
		ci.draw_line(Vector2(sx2, LH * (k - 1)), Vector2(sx2 + 6, LH * k), Color(0, 0, 0, 0.18), 3.0)
	ci.draw_rect(Rect2(-SHAFT, LH * k - 6, SHAFT * 2.0, 6), Color(0, 0, 0, 0.25))


func _paint_pit(ci: CanvasItem) -> void:
	var r := Rect2(-SHAFT, LH * 6, SHAFT * 2.0, PIT_BOTTOM - LH * 6)
	ci.draw_rect(r, Color("0d1418"))
	for i in 12:
		var y := LH * 6 + i * 50.0
		ci.draw_line(Vector2(-SHAFT, y), Vector2(SHAFT, y + 8), Color(0, 0, 0, 0.2), 2.0)
	# roots
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 9:
		var a := Vector2(trunk_cx(PIT_BOTTOM - 40) + rng.randf_range(-40, 40), PIT_BOTTOM - 30)
		var b := a + Vector2(rng.randf_range(-320, 320), rng.randf_range(-10, 30))
		var c := (a + b) * 0.5 + Vector2(0, rng.randf_range(-60, -10))
		Art.strip(ci, Art.bezier(a, c, b, 10), 22.0, 4.0, Art.BARK_DARK)


func _paint_slab(ci: CanvasItem, k: int) -> void:
	var y := LH * k
	var lc: Color = Art.LEVEL_COLORS[k]
	if k == 6:
		for side: float in [-1.0, 1.0]:
			var x0 := SHAFT if side > 0 else -WALL
			ci.draw_rect(Rect2(x0, y, WALL - SHAFT, PIT_BOTTOM + 60 - y), Color("171c20"))
			ci.draw_rect(Rect2(x0, y, WALL - SHAFT, 10), Art.CONCRETE_DARK)
		ci.draw_rect(Rect2(-SHAFT, PIT_BOTTOM, SHAFT * 2.0, 60), Color("0e1215"))
	else:
		for side: float in [-1.0, 1.0]:
			var x0 := SHAFT if side > 0 else -WALL
			var w := WALL - SHAFT
			ci.draw_rect(Rect2(x0, y, w, SLAB), Art.CONCRETE)
			ci.draw_rect(Rect2(x0, y, w, 4), Art.CONCRETE_LIGHT)
			ci.draw_rect(Rect2(x0, y + SLAB - 5, w, 5), Art.CONCRETE_DARK)
			if k > 0:
				ci.draw_rect(Rect2(x0, y + 14, w, 8), Color(lc, 0.75))
		if k == 0:
			# hatch hole for the emergency ladder
			ci.draw_rect(Rect2(790, 0, 70, SLAB), Color("101418"))
		if k == 4:
			# construction hole
			ci.draw_rect(Rect2(-820, y, 300, SLAB), Color("0e1215"))
			ci.draw_rect(Rect2(-820, y - 2, 300, 4), Color("3a3020"))
	# parapets
	var h := PAR_H if k > 0 else 44.0
	for side: float in [-1.0, 1.0]:
		var x := SHAFT if side > 0 else -SHAFT - PAR_W
		ci.draw_rect(Rect2(x, y - h, PAR_W, h), Art.CONCRETE.lightened(0.05))
		ci.draw_rect(Rect2(x, y - h, PAR_W, 3), Art.CONCRETE_LIGHT)
		ci.draw_line(Vector2(x + PAR_W * 0.5, y - h), Vector2(x + PAR_W * 0.5, y - h - 26), Color("d8b22a"), 3.0)
		var rx0 := x + PAR_W * 0.5
		var rx1 := rx0 + 70.0 * side
		ci.draw_line(Vector2(rx0, y - h - 26), Vector2(rx1, y - h - 26), Color("d8b22a"), 3.0)
	# outer walls
	if k < 6:
		for side: float in [-1.0, 1.0]:
			var x0 := DECK if side > 0 else -WALL
			ci.draw_rect(Rect2(x0, y, WALL - DECK, LH), Art.CONCRETE_DARK)
			ci.draw_rect(Rect2(x0 + (0 if side > 0 else WALL - DECK - 6), y, 6, LH), Art.CONCRETE)


static func _hash01(i: int) -> float:
	var x := sin(float(i) * 12.9898) * 43758.5453
	return x - floorf(x)


# --- the tree -------------------------------------------------------------------

func _build_tree() -> void:
	sleeves = [Vector2(2880, 3140), Vector2(2330, 2680), Vector2(1790, 2140),
		Vector2(1255, 1580), Vector2(650, 1015), Vector2(-320, 440)]
	# Trunk drawn in chunks.
	var y := PIT_BOTTOM
	while y > FORK_Y - 40.0:
		var y0 := maxf(FORK_Y - 40.0, y - 400.0)
		_painter(-40, _paint_trunk.bind(y0, y))
		y -= 400.0
	for s in sleeves:
		_painter(-38, _paint_sleeve.bind(s.x, s.y))


func _paint_trunk(ci: CanvasItem, y0: float, y1: float) -> void:
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	var cols := PackedColorArray()
	var y := y0
	while y <= y1 + 0.1:
		var cx := trunk_cx(y)
		var hw := trunk_hw(y)
		left.append(Vector2(cx - hw, y))
		right.append(Vector2(cx + hw, y))
		y += 20.0
	var poly := PackedVector2Array()
	for p in left:
		poly.append(p)
		cols.append(Art.BARK.lightened(0.12))
	for i in range(right.size() - 1, -1, -1):
		poly.append(right[i])
		cols.append(Art.BARK_DARK)
	ci.draw_polygon(poly, cols)
	# bark ridges
	for r in 7:
		var f := -0.8 + r * 0.27
		var pts := PackedVector2Array()
		var yy := y0
		while yy <= y1 + 0.1:
			pts.append(Vector2(trunk_cx(yy) + f * trunk_hw(yy) + sin(yy * 0.03 + r * 1.7) * 3.0, yy))
			yy += 20.0
		ci.draw_polyline(pts, Color(Art.BARK_DARK, 0.65), 2.0 + (r % 3))
	# highlight from the grow lights
	var hl := PackedVector2Array()
	var y2 := y0
	while y2 <= y1 + 0.1:
		hl.append(Vector2(trunk_cx(y2) - trunk_hw(y2) + 4.0, y2))
		y2 += 20.0
	ci.draw_polyline(hl, Color(0.9, 0.55, 0.9, 0.25), 3.0)
	# knots
	var ky := ceilf(y0 / 170.0) * 170.0
	while ky < y1:
		var kx := trunk_cx(ky) + sin(ky) * trunk_hw(ky) * 0.5
		Art.ellipse(ci, Vector2(kx, ky), 7, 10, Art.BARK_DARK)
		Art.ellipse(ci, Vector2(kx, ky), 3, 5, Color("23170f"))
		ky += 170.0


func _paint_sleeve(ci: CanvasItem, top: float, bot: float) -> void:
	var poly := PackedVector2Array()
	var cols := PackedColorArray()
	var y := top
	var left := PackedVector2Array()
	var right := PackedVector2Array()
	while y <= bot + 0.1:
		left.append(Vector2(trunk_cx(y) - trunk_hw(y) - 5.0, y))
		right.append(Vector2(trunk_cx(y) + trunk_hw(y) + 5.0, y))
		y += 20.0
	for p in left:
		poly.append(p)
		cols.append(Art.METAL.lightened(0.15))
	for i in range(right.size() - 1, -1, -1):
		poly.append(right[i])
		cols.append(Art.METAL_DARK)
	ci.draw_polygon(poly, cols)
	var ry := top + 6.0
	while ry < bot:
		var cx := trunk_cx(ry)
		var hw := trunk_hw(ry) + 5.0
		ci.draw_line(Vector2(cx - hw, ry), Vector2(cx + hw, ry), Color(1, 1, 1, 0.22), 2.0)
		ci.draw_line(Vector2(cx - hw, ry + 3), Vector2(cx + hw, ry + 3), Color(0, 0, 0, 0.18), 1.0)
		ci.draw_circle(Vector2(cx - hw + 8, ry + 14), 2.0, Color("4a535b"))
		ci.draw_circle(Vector2(cx + hw - 8, ry + 14), 2.0, Color("4a535b"))
		ry += 46.0
	var mid := (top + bot) * 0.5
	ci.draw_set_transform(Vector2(trunk_cx(mid) + 6.0, mid), -PI / 2.0, Vector2.ONE)
	Art.text(ci, Vector2(0, 0), "BAUMSCHUTZ", 15, Color(0.15, 0.17, 0.2, 0.65))
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Adds a horizontal-ish branch growing from the trunk. Returns the tip.
func _branch(y: float, side: float, length: float, angle_deg: float, thick := 22.0, standable := true, leaves := true, droop := 0.0) -> Vector2:
	var base := Vector2(trunk_cx(y) + side * trunk_hw(y) * 0.45, y)
	var a := deg_to_rad(angle_deg)
	var dir := Vector2(side * cos(a), -sin(a))
	var tip := base + dir * length
	if standable:
		_oneway(base + Vector2(0, -thick * 0.32), tip + Vector2(0, -3), 10.0)
	_climb_cap(base, tip, thick * 0.5 + 12.0, "bark")
	var seed_v := _rng.randi()
	var ctrl := (base + tip) * 0.5 + Vector2(0, droop)
	_painter(-41, _paint_branch.bind(base, ctrl, tip, thick, leaves, seed_v))
	return tip


func _paint_branch(ci: CanvasItem, base: Vector2, ctrl: Vector2, tip: Vector2, thick: float, leaves: bool, seed_v: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v
	var pts := Art.bezier(base, ctrl, tip, 12)
	Art.strip(ci, pts, thick, thick * 0.32, Art.BARK)
	var top := PackedVector2Array()
	for i in pts.size():
		var t := float(i) / float(pts.size() - 1)
		top.append(pts[i] + Vector2(0, -lerpf(thick, thick * 0.32, t) * 0.32))
	ci.draw_polyline(top, Color(Art.BARK_LIGHT, 0.6), 2.0)
	if not leaves:
		return
	var tint := Color(0.85, 0.4, 0.85) if base.y > 0.0 else Color(0.5, 0.65, 0.9)
	var L := base.distance_to(tip)
	var n := int(L / 55.0) + 2
	for i in n:
		var t := 0.35 + 0.65 * float(i) / float(n - 1)
		var p := pts[int(t * (pts.size() - 1))]
		var up := rng.randf_range(-34.0, -10.0) if i % 2 == 0 else rng.randf_range(8.0, 26.0)
		var twig_end := p + Vector2(rng.randf_range(-22, 22), up)
		ci.draw_line(p, twig_end, Art.BARK_DARK, 2.0)
		Art.leaf_cluster(ci, twig_end, rng.randf_range(20.0, 28.0), (twig_end - p).angle(), rng, tint)
	Art.leaf_cluster(ci, tip + (tip - base).normalized() * 6.0, 26.0, (tip - base).angle(), rng, tint)


## A long climbable limb between two arbitrary points (crown).
func _limb(a: Vector2, b: Vector2, thick: float, standable := false) -> void:
	if standable:
		_oneway(a + Vector2(0, -thick * 0.3), b + Vector2(0, -3), 10.0)
	_climb_cap(a, b, thick * 0.5 + 12.0, "bark")
	var seed_v := _rng.randi()
	var ctrl := (a + b) * 0.5 + (b - a).orthogonal().normalized() * 14.0
	_painter(-41, _paint_branch.bind(a, ctrl, b, thick, true, seed_v))


# --- the storeys ------------------------------------------------------------------

func _build_levels() -> void:
	_build_ebene6()
	_build_ebene5()
	_build_ebene4()
	_build_ebene3()
	_build_ebene2()
	_build_ebene1()


func _deck_lights(k: int, xs: Array, flicker_idx := -1) -> void:
	var cy := ceil_y(k)
	for i in xs.size():
		var x: float = xs[i]
		var p := Vector2(x, cy + 14.0)
		_painter(-56, _paint_tube.bind(p))
		if i != flicker_idx:
			_lamp_glow(p, Color(0.95, 0.97, 1.0, 0.22), 110.0)


func _paint_tube(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_rect(Rect2(p + Vector2(-36, -6), Vector2(72, 8)), Color("6d757c"))
	ci.draw_rect(Rect2(p + Vector2(-33, 0), Vector2(66, 4)), Color("f6f3e0"))


func _grow_light(p: Vector2) -> void:
	_painter(-57, _paint_grow_fixture.bind(p))
	_painter(-50, func(ci): Art.glow(ci, p + Vector2(0, 30), 190.0, Color(0.85, 0.25, 0.75, 0.22)), true)


func _paint_grow_fixture(ci: CanvasItem, p: Vector2) -> void:
	ci.draw_rect(Rect2(p + Vector2(-18, -4), Vector2(36, 8)), Color("2a2a30"))
	ci.draw_rect(Rect2(p + Vector2(-15, 2), Vector2(30, 3)), Color("ff7ae0"))


func _build_ebene6() -> void:
	var k := 6
	var fy := floor_y(k)
	# submerged cars and junk
	_back_car(-850, fy, 1, Color("2d5d7c"))
	_back_car(820, fy, -1, Color("7c2d2d"))
	_painter(-14, func(ci): Art.car(ci, Vector2(-640, fy), 1, Color("6c7a3a")))
	_painter(-14, func(ci): Art.car(ci, Vector2(700, fy), -1, Color("a0a4a8")))
	_deck_lights(k, [-900, -560, 560, 900], 1)
	_grow_light(Vector2(-300, ceil_y(k) - 30))
	_grow_light(Vector2(300, ceil_y(k) - 30))
	_sign(Vector2(-560, fy - 330), "ACHTUNG HOCHWASSER", 14, Color("e8c02c"), Color("1d1d1d"))
	_sign(Vector2(600, fy - 340), "← AUSFAHRT", 14, Color("2f6e3a"), Color.WHITE)
	_painter(-60, _paint_plaque)
	# a low branch above the water (rest spot + chestnut)
	var tip := _branch(3222, 1, 250, 4, 20)
	_kastanie(tip + Vector2(-20, -24))
	_kastanie(Vector2(-300, 3840))
	_kastanie(Vector2(-930, 3330))
	_hint(Vector2(-250, 3050), "[A] [D] [W] [S]  swim", 14)
	_hint(Vector2(-250, 3074), "[W] on bark = climb", 14)
	_trigger(Rect2(-120, 3130, 240, 60), "sleeve6", _main_call.bind("on_first_sleeve"))


func _paint_plaque(ci: CanvasItem) -> void:
	Art.rrect(ci, Rect2(-340, 3140, 200, 70), Color("2b3a2e"), 4, 2, Color("8a9a6a"))
	Art.text(ci, Vector2(-240, 3164), "NATURDENKMAL", 15, Color("e6e2c4"))
	Art.text(ci, Vector2(-240, 3183), "Rosskastanie · gepflanzt 1937", 11, Color("c8c4a4"))
	Art.text(ci, Vector2(-240, 3199), "Bitte nicht beklettern.", 11, Color("c8c4a4"))


func _build_ebene5() -> void:
	var k := 5
	var fy := floor_y(k)
	var cy := ceil_y(k)
	var tip := _branch(2716, 1, 300, 5, 24)
	_bucket(480, fy)
	_parked_car(780, fy, 1, Color("3a6ea5"))
	_kastanie(Vector2(770, fy - 92))
	_back_car(620, fy, -1, Color("8a4a8a"))
	# puddle + drip
	waters.append(Rect2(900, fy - 9, 80, 9))
	var drip := DripScript.new()
	drip.world = self
	drip.position = Vector2(605, 2306)
	drip.floor_y = fy
	drip.z_index = -9
	add_child(drip)
	refills.append(drip)
	# ivy up the right outer wall
	_ivy(Rect2(1046, 2296, 54, fy - 2296))
	# pipes: P5a (deck) and P5b (crosses the whole shaft to the left deck)
	_pipe(Vector2(810, 2306), Vector2(1084, 2306), Art.PIPE_RED, cy)
	_pipe(Vector2(-1084, 2306), Vector2(640, 2306), Art.PIPE_RED, cy)
	_anchor(Vector2(725, 2298))
	_painter(-54, func(ci): Art.hook(ci, Vector2(725, 2298), cy))
	_kastanie(Vector2(725, 2392))
	# left deck (optional) with ivy back up and a chestnut
	_ivy(Rect2(-DECK, 2296, 54, fy - 2296))
	_kastanie(Vector2(-960, fy - 26))
	_back_car(-700, fy, 1, Color("c9b23a"))
	_parked_car(-560, fy, -1, Color("8a8f96"))
	_deck_lights(k, [-940, -620, 560, 880])
	_grow_light(Vector2(-300, cy - 30))
	_grow_light(Vector2(300, cy - 30))
	_sign(Vector2(700, fy - 330), "BESUCHER  P", 15, Color("1f5fae"), Color.WHITE)
	_sign(Vector2(-700, fy - 330), "KASSA · LIFT →", 14, Color("e9e4d4"), Color("1d2329"))
	_hint(Vector2(560, fy - 120), "MOP BUCKET = checkpoint + full of water", 14)
	_hint(Vector2(860, fy - 170), "Don't dry out! Puddles and drips help.", 13)
	_hint(Vector2(960, 2380), "Ivy, pipes, branches: hold [W] to climb", 13)
	_hint(Vector2(725, 2440), "Brass ring: [Left click] / [J] — HOLD to swing", 13)
	_trigger(Rect2(400, fy - 160, 200, 160), "deck5", _toast.bind("A cleaner's mop bucket! Touch it to save and soak up water."))
	_trigger(Rect2(600, 2290, 230, 120), "grapple5", _toast.bind("A brass ring! Aim, then HOLD [Left click] or [J] to swing. [W]/[S] reel in/out."))


func _build_ebene4() -> void:
	var k := 4
	var fy := floor_y(k)
	var cy := ceil_y(k)
	# left slab: default slab was built full; carve the hole by replacing.
	_branch(2186, -1, 330, 6, 22)
	_branch(2200, 1, 300, 3, 20)
	_bucket(-470, fy)
	# construction hole (the slab under it is removed in _build_structure via k==4 special)
	_painter(-13, _paint_barrier.bind(fy))
	_sign(Vector2(-670, fy - 200), "BAUSTELLE", 16, Color("e8c02c"), Color("1d1d1d"))
	_hint(Vector2(-670, fy - 150), "Jump, then [Right click] / [K] / [Shift] = ink dash!", 13)
	_parked_car(-970, fy, 1, Color("d0d4d8"), "van")
	_kastanie(Vector2(-985, fy - 118))
	_kastanie(Vector2(-670, fy - 150 + 60))
	# lamps (anchors)
	for lp in [Vector2(-1010, 1880), Vector2(-770, 1885)]:
		var lpv: Vector2 = lp
		_anchor(lpv + Vector2(0, -10))
		_painter(-54, func(ci): Art.lamp(ci, lpv, cy))
		_lamp_glow(lpv + Vector2(0, 6), Color(1.0, 0.95, 0.8, 0.25), 100.0)
	# the long return limb into the left deck, with a drooping twig to swing onto
	_branch(1776, -1, 480, 3, 26)
	_limb(Vector2(-470, 1752), Vector2(-630, 1880), 14)
	var pg := PigeonScript.new()
	pg.world = self
	pg.center = Vector2(-670, 2110)
	pg.amp = Vector2(110, 26)
	pg.speed = 0.9
	pg.z_index = 5
	add_child(pg)
	hazards.append(pg)
	# right deck (optional): puddle, drip and a chestnut
	waters.append(Rect2(700, fy - 9, 120, 9))
	_parked_car(940, fy, -1, Color("b0352c"))
	_kastanie(Vector2(1050, fy - 26))
	_back_car(560, fy, 1, Color("2d7c5d"))
	_deck_lights(k, [-940, -640, 600, 900], 2)
	_grow_light(Vector2(-300, cy - 30))
	_grow_light(Vector2(300, cy - 30))
	_sign(Vector2(800, fy - 330), "KINDERKLINIK →", 14, Color("e9e4d4"), Color("1d2329"))
	_trigger(Rect2(-600, fy - 150, 120, 150), "hole4", _toast.bind("Too far to jump! Mid-air, squirt ink: [Right click] / [K] / [Shift]."))


func _paint_barrier(ci: CanvasItem, fy: float) -> void:
	for x: float in [-830.0, -510.0]:
		ci.draw_line(Vector2(x, fy), Vector2(x, fy - 46), Color("d8d8d8"), 3.0)
		ci.draw_line(Vector2(x - 12, fy), Vector2(x + 12, fy), Color("d8d8d8"), 3.0)
	for i in 2:
		var yy := fy - 40.0 + i * 16.0
		ci.draw_line(Vector2(-830, yy), Vector2(-510, yy + 4), Color("e23a2a"), 3.0)
		ci.draw_line(Vector2(-830, yy + 2), Vector2(-510, yy + 6), Color("f2f2f2"), 1.5)


func _paint_gate(ci: CanvasItem, fy: float, h: float) -> void:
	ci.draw_rect(Rect2(1100 - 8, fy - h, 16, h), Color("0a0c0e"))
	Art.hazard_band(ci, Rect2(1050, fy - h - 8, 56, 10), Color("e8c02c"), Color("1d1d1d"), 8)


func _build_ebene3() -> void:
	var k := 3
	var fy := floor_y(k)
	var cy := ceil_y(k)
	_branch(1612, 1, 310, 4, 22)
	_branch(1650, -1, 290, 3, 20)
	_bucket(455, fy)
	var car := CarScript.new()
	car.world = self
	car.kind = "car"
	car.floor_y = fy
	car.x_in = 650.0
	car.x_out = 1330.0
	car.body_color = Color("e0c03a")
	car.z_index = -5
	add_child(car)
	hazards.append(car)
	_kastanie(Vector2(0, -92), car)
	# ivy on a pillar, pipe along the ceiling, fan
	_painter(-60, func(ci): ci.draw_rect(Rect2(876, cy, 58, fy - cy), Color("323a42")))
	_ivy(Rect2(880, 1186, 50, fy - 1186))
	_pipe(Vector2(560, 1186), Vector2(1084, 1186), Art.PIPE_GRAY, cy)
	var fan := FanScript.new()
	fan.world = self
	fan.position = Vector2(780, cy + 30)
	fan.zone = Rect2(560, 1164, 300, 110)
	fan.force = Vector2(1150, 0)
	fan.z_index = -20
	add_child(fan)
	winds.append(fan)
	_kastanie(Vector2(690, 1214))
	var drip := DripScript.new()
	drip.world = self
	drip.position = Vector2(1000, 1186)
	drip.floor_y = fy
	drip.z_index = -9
	add_child(drip)
	refills.append(drip)
	# return limb reaching into the right deck under the ceiling
	_branch(1226, 1, 520, 2, 26)
	# left deck (optional)
	_kastanie(Vector2(-1000, fy - 26))
	_parked_car(-760, fy, 1, Color("4a4f8a"))
	_back_car(-520, fy, -1, Color("6a3a2a"))
	_deck_lights(k, [-900, -560, 620, 960])
	_grow_light(Vector2(-300, cy - 30))
	_grow_light(Vector2(300, cy - 30))
	_painter(16, _paint_gate.bind(fy, 120.0))
	_sign(Vector2(800, fy - 330), "KURZPARKER  max. 30 min", 13, Color("e9e4d4"), Color("1d2329"))
	_hint(Vector2(600, fy - 150), "Cars! Wait for them — or hop on the roof.", 13)
	_trigger(Rect2(400, fy - 160, 150, 160), "car3", _toast.bind("Traffic! Cars knock the water out of you. Their roofs are safe."))


func _build_ebene2() -> void:
	var k := 2
	var fy := floor_y(k)
	var cy := ceil_y(k)
	_branch(1052, -1, 300, 5, 22)
	_bucket(-470, fy)
	# boilers (background)
	_painter(-62, _paint_boilers.bind(fy))
	_painter(-50, func(ci): Art.glow(ci, Vector2(-760, fy - 60), 220, Color(1.0, 0.45, 0.15, 0.18)), true)
	# vent (lift) far left
	var v := VentScript.new()
	v.world = self
	v.position = Vector2(-930, fy)
	v.top = 612.0
	v.half_w = 34.0
	v.z_index = -19
	add_child(v)
	heats.append({"rect": Rect2(-964, 612, 68, fy - 612), "drain": 16.0, "lift": 420.0, "top": 612.0})
	# a second, gentler vent next to a cable tray (optional chestnut)
	var v2 := VentScript.new()
	v2.world = self
	v2.position = Vector2(-640, fy)
	v2.top = 800.0
	v2.half_w = 28.0
	v2.z_index = -19
	add_child(v2)
	heats.append({"rect": Rect2(-668, 800, 56, fy - 800), "drain": 16.0, "lift": 380.0, "top": 800.0})
	_oneway(Vector2(-800, 850), Vector2(-690, 850), 8.0)
	_painter(-18, _paint_tray.bind(cy))
	_kastanie(Vector2(-750, 826))
	# the pipe: cold - HOT - cold
	_pipe(Vector2(-1084, 626), Vector2(-700, 626), Art.PIPE_GRAY, cy)
	_pipe(Vector2(-540, 626), Vector2(-4, 626), Art.PIPE_GRAY, cy)
	_painter(-55, _paint_hot_pipe)
	_painter(-50, func(ci): Art.glow(ci, Vector2(-620, 626), 110, Color(1.0, 0.4, 0.1, 0.35)), true)
	heats.append({"rect": Rect2(-704, 590, 168, 80), "drain": 30.0, "lift": 0.0, "top": 0.0})
	_anchor(Vector2(-620, 614))
	_painter(-54, func(ci): Art.hook(ci, Vector2(-620, 614), cy))
	_kastanie(Vector2(-620, 712))
	_kastanie(Vector2(-1050, 655))
	var sp := SprinklerScript.new()
	sp.world = self
	sp.position = Vector2(-820, 626)
	sp.floor_y = fy
	sp.z_index = 8
	add_child(sp)
	refills.append(sp)
	_deck_lights(k, [-1000, -560, 600, 940], 0)
	_grow_light(Vector2(-300, cy - 30))
	_grow_light(Vector2(300, cy - 30))
	# right deck decor
	_parked_car(700, fy, -1, Color("2a2f35"))
	_back_car(960, fy, 1, Color("8a7a5a"))
	_sign(Vector2(800, fy - 330), "BLUTSPENDE ↑", 14, Color("b8352c"), Color.WHITE)
	_hint(Vector2(-900, fy - 140), "Hot air lifts you up — and dries you out!", 13)
	_trigger(Rect2(-1000, fy - 200, 140, 200), "vent2", _toast.bind("Warm exhaust air carries you up. It also dries you out — be quick!"))


func _paint_boilers(ci: CanvasItem, fy: float) -> void:
	for bx: float in [-1000.0, -760.0]:
		Art.rrect(ci, Rect2(bx, fy - 210, 120, 210), Color("5a3a2a"), 14, 3, Color("2a1a12"))
		ci.draw_circle(Vector2(bx + 60, fy - 150), 18, Color("c8b080"))
		ci.draw_line(Vector2(bx + 60, fy - 150), Vector2(bx + 70, fy - 160), Color("2a1a12"), 2.0)
		ci.draw_rect(Rect2(bx + 30, fy - 90, 60, 30), Color(1.0, 0.45, 0.1, 0.5))
	Art.text(ci, Vector2(-820, fy - 250), "HAUSTECHNIK", 22, Color(1, 0.8, 0.5, 0.5))


func _paint_tray(ci: CanvasItem, cy: float) -> void:
	ci.draw_rect(Rect2(-800, 850, 110, 6), Color("8a929a"))
	for i in 6:
		ci.draw_line(Vector2(-796 + i * 20, 850), Vector2(-796 + i * 20, 856), Color("50585e"), 2.0)
	ci.draw_line(Vector2(-795, 856), Vector2(-795, cy), Color("50585e"), 2.0)


func _paint_hot_pipe(ci: CanvasItem) -> void:
	ci.draw_line(Vector2(-700, 626), Vector2(-540, 626), Color("5a2a12"), 12.0)
	ci.draw_line(Vector2(-700, 626), Vector2(-540, 626), Art.HOT, 9.0)
	ci.draw_line(Vector2(-700, 623), Vector2(-540, 623), Color("ffd08a"), 2.0)
	Art.text(ci, Vector2(-620, 660), "HEISS!", 14, Color("ff9a4a"))


func _paint_ladder_shaft(ci: CanvasItem, cy: float, fy: float) -> void:
	ci.draw_rect(Rect2(786, cy, 80, fy - cy), Color("20262c"))
	Art.ladder(ci, Rect2(798, -30, 56, fy + 30))


func _build_ebene1() -> void:
	var k := 1
	var fy := floor_y(k)
	var cy := ceil_y(k)
	_branch(482, 1, 300, 5, 22)
	_bucket(450, fy)
	var amb := CarScript.new()
	amb.world = self
	amb.kind = "ambulance"
	amb.floor_y = fy
	amb.x_in = 650.0
	amb.x_out = 1420.0
	amb.z_index = -5
	add_child(amb)
	hazards.append(amb)
	_kastanie(Vector2(10, -128), amb)
	# emergency ladder to the street
	var lr := Rect2(798, -30, 56, fy + 30)
	climb_rects.append(lr)
	_painter(-23, _paint_ladder_shaft.bind(cy, fy))
	_sign(Vector2(826, cy + 40), "NOTAUSSTIEG", 13, Color("2f8a46"), Color.WHITE, -21)
	_painter(16, _paint_gate.bind(fy, 150.0))
	_sign(Vector2(640, fy - 330), "RETTUNGSZUFAHRT — FREIHALTEN!", 14, Color("e9e4d4"), Color("b8352c"))
	_hint(Vector2(600, fy - 170), "Blue lights? Get out of the way!", 14)
	_deck_lights(k, [-900, -560, 560, 960])
	_grow_light(Vector2(-300, cy + 10))
	_grow_light(Vector2(300, cy + 10))
	# left deck: parked cars & a chestnut on a roof
	_parked_car(-620, fy, 1, Color("5a8a3a"))
	_parked_car(-900, fy, 1, Color("2a4a7a"))
	_kastanie(Vector2(-610, fy - 94))
	_sign(Vector2(-760, fy - 330), "AMBULANZ · HAUPTEINGANG ↑", 14, Color("e9e4d4"), Color("1d2329"))
	_trigger(Rect2(400, fy - 160, 150, 160), "amb1", _toast.bind("The ambulance! Wait until it backs out, then run for the ladder."))


# --- the surface and the crown ---------------------------------------------------

func _build_surface() -> void:
	# Hospital buildings, lamp, bin, maroni stand.
	_painter(-90, func(ci): _paint_hospital(ci))
	_painter(-24, _paint_street_props)
	_painter(-25, func(ci): Art.maroni_stand(ci, Vector2(-960, 0), 0.0))
	_solid(Rect2(673, -56, 34, 56))
	_bucket(930, 0)
	_oneway(Vector2(-750, -26), Vector2(-650, -26), 6.0)
	_painter(-50, func(ci): Art.glow(ci, Vector2(565, -205), 150, Color(1.0, 0.85, 0.5, 0.35)), true)
	_painter(-50, func(ci): Art.glow(ci, Vector2(-540, -205), 150, Color(1.0, 0.85, 0.5, 0.35)), true)
	_anchor(Vector2(565, -230))
	_anchor(Vector2(-540, -230))
	# street-level paving
	_painter(14, _paint_paving)

	# Crown: the first big branch reaches out over the courtyard.
	_limb(Vector2(trunk_cx(-362) + 10, -362), Vector2(522, -206), 24, true)
	_branch(-450, -1, 300, 12, 20)
	_kastanie(Vector2(260, -312))
	_kastanie(Vector2(-300, -540))
	# The fork: two limbs.
	var fork := Vector2(trunk_cx(FORK_Y), FORK_Y)
	var lt := Vector2(-250, -880)
	var rt := Vector2(186, -842)
	_limb(fork + Vector2(-6, 10), lt, 30)
	_limb(fork + Vector2(6, 10), rt, 30)
	_kastanie(lt + Vector2(-10, -30))
	# thin twig holding the blue lemon
	var twig_a := Vector2(232, -960)
	var twig_b := Vector2(380, -978)
	_painter(-41, _paint_twig.bind(rt, twig_a, twig_b))
	_anchor(Vector2(330, -968))
	_painter(-40, func(ci): ci.draw_arc(Vector2(330, -968), 6.0, 0, TAU, 14, Color("c7a04a"), 2.0))
	# Wind gusts in the crown ("Wiener Wind").
	var gust := FanScript.new()
	gust.world = self
	gust.is_gust = true
	gust.zone = Rect2(-700, -1100, 1400, 760)
	gust.force = Vector2(780, 0)
	gust.on_time = 2.2
	gust.off_time = 3.4
	add_child(gust)
	winds.append(gust)
	for c in [[Vector2(0, -470), Vector2(150, 40), 0.9], [Vector2(80, -760), Vector2(110, 30), 1.3]]:
		var pg := PigeonScript.new()
		pg.world = self
		pg.center = c[0]
		pg.amp = c[1]
		pg.speed = c[2]
		pg.z_index = 5
		add_child(pg)
		hazards.append(pg)
	# Radio and lemon.
	radio = RadioScript.new()
	radio.world = self
	radio.position = RADIO_POS
	radio.z_index = -9
	add_child(radio)
	lemon = LemonScript.new()
	lemon.world = self
	lemon.position = LEMON_POS
	lemon.z_index = -8
	add_child(lemon)
	_trigger(Rect2(RADIO_POS.x - 110, RADIO_POS.y - 120, 220, 220), "radio", func(): radio_reached.emit())
	_trigger(Rect2(300, -20, 500, 40), "surface", _toast.bind("Fresh air! The drizzle keeps you damp. Up into the crown!"))
	_hint(Vector2(560, -330), "Grab the lamp — or jump + ink dash up!", 13)


func _paint_street_props(ci: CanvasItem) -> void:
	Art.bench(ci, Vector2(-700, 0))
	Art.mistkuebel(ci, Vector2(690, 0))
	Art.street_lamp(ci, Vector2(585, 0), Vector2(565, -216))
	Art.street_lamp(ci, Vector2(-560, 0), Vector2(-540, -216))
	ci.draw_rect(Rect2(780, -48, 90, 48), Color("2f3a33"))
	ci.draw_rect(Rect2(784, -44, 82, 6), Color("3f8a52"))
	Art.text(ci, Vector2(825, -22), "AUSSTIEG", 10, Color(1, 1, 1, 0.8))


func _paint_paving(ci: CanvasItem) -> void:
	for side: float in [-1.0, 1.0]:
		var x0 := SHAFT if side > 0 else -WALL
		ci.draw_rect(Rect2(x0, 0, WALL - SHAFT, 6), Color("5a5f63"))
	ci.draw_rect(Rect2(790, 0, 70, 8), Color("101418"))


func _paint_twig(ci: CanvasItem, rt: Vector2, twig_a: Vector2, twig_b: Vector2) -> void:
	ci.draw_line(rt, twig_a + Vector2(10, 10), Art.BARK, 7.0)
	Art.strip(ci, PackedVector2Array([twig_a, twig_b]), 6.0, 2.5, Art.BARK)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	Art.leaf_cluster(ci, twig_b, 22, -0.2, rng, Color(0.5, 0.6, 0.9))


func _paint_hospital(ci: CanvasItem) -> void:
	# Night courtyard backdrop between the two hospital wings.
	for side: float in [-1.0, 1.0]:
		var x0 := 560.0 if side > 0 else -WALL - 300.0
		var w := WALL + 300.0 - 560.0
		var r := Rect2(x0, -760, w, 760)
		ci.draw_rect(r, Color("2b3140"))
		ci.draw_rect(Rect2(x0, -770, w, 14), Color("39404f"))
		var rng := RandomNumberGenerator.new()
		rng.seed = 11 + int(side)
		var y := -730.0
		while y < -60.0:
			var x := x0 + 30.0
			while x < x0 + w - 40.0:
				var lit := rng.randf() < 0.38
				var c := Color("ffd98a") if rng.randf() < 0.75 else Color("bfe0ff")
				ci.draw_rect(Rect2(x, y, 34, 44), c.darkened(0.15) if lit else Color("1b2029"))
				if lit:
					ci.draw_rect(Rect2(x, y + 30, 34, 14), Color(0, 0, 0, 0.15))
				x += 62.0
			y += 76.0
	# blue H sign and entrance
	Art.rrect(ci, Rect2(870, -620, 70, 70), Color("1f5fae"), 6, 3, Color.WHITE)
	Art.text(ci, Vector2(905, -567), "H", 54, Color.WHITE)
	Art.text(ci, Vector2(-860, -520), "KRANKENHAUS", 30, Color(1, 1, 1, 0.55))
	Art.text(ci, Vector2(-860, -488), "Haupteingang · Ambulanz", 16, Color(1, 1, 1, 0.45))
	# shaft wall above ground (dark well opening)
	ci.draw_rect(Rect2(-SHAFT, -40, SHAFT * 2.0, 40), Color("10151a"))
