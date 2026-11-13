extends CharacterBody2D
## Otto the octopus.
##  - walks, hops, swims
##  - clings to & climbs anything bark-like, ivy, pipes and ladders  (W/S)
##  - shoots a tentacle at brass rings / lamps and swings          (grab)
##  - squirts ink for a short dash                                  (ink)
##  - dries out over time; water, drips & buckets keep him going

enum St { NORMAL, CLING, SWIM, GRAPPLE, DASH, HURT, DRY, FROZEN }

const Art = preload("res://scripts/art.gd")

const RADIUS := 13.0
const RUN := 250.0
const ACC_GROUND := 2100.0
const ACC_AIR := 1350.0
const FRICTION := 2600.0
const G := 1600.0
const G_HOLD := 1000.0
const JUMP_V := 540.0
const MAX_FALL := 920.0
const CLIMB := 165.0
const SWIM := 230.0
const DASH_V := 620.0
const DASH_T := 0.14
const GRAPPLE_RANGE := 300.0
const REEL := 300.0
const SWING_ACC := 950.0
const GEYSER_V := 860.0
const ARMS := 8
const SEG := 6.5
const NPTS := 6

var world: Node2D
var st := St.NORMAL
var facing := 1.0
var moisture := 100.0
var ink := 1
var env := {}
var coyote := 0.0
var jump_buf := 0.0
var cling_cd := 0.0
var invuln := 0.0
var drop_t := 0.0
var dash_t := 0.0
var dash_dir := Vector2.RIGHT
var hurt_t := 0.0
var dry_t := 0.0
var was_on_floor := false
var fall_speed := 0.0
var step_t := 0.0
var swim_t := 0.0
var warn_t := 0.0
var in_water := false
var _froze_clinging := false

# grapple: 0 none, 1 shooting, 2 attached, 3 retracting, 4 whiff
var g_state := 0
var g_point := Vector2.ZERO
var g_tip := Vector2.ZERO
var g_len := 0.0
var g_arm := 0
var aim_target = null
var aim_dir := Vector2.UP

# animation
var t := 0.0
var body_rot := 0.0
var squash := 0.0
var blink_t := 2.0
var cam_t := 0.0
var cam_col := Art.OCTO
var flash := 0.0
var arm_pts: Array = []
var arm_tip: Array = []
var arm_plant: Array = []
var look := Vector2.RIGHT
var walk_phase := 0.0


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2
	floor_snap_length = 7.0
	floor_max_angle = deg_to_rad(50.0)
	var cs := CollisionShape2D.new()
	var sh := CircleShape2D.new()
	sh.radius = RADIUS
	cs.shape = sh
	add_child(cs)
	z_index = 0
	for i in ARMS:
		var pts := PackedVector2Array()
		for j in NPTS:
			pts.append(global_position + Vector2(0, j * SEG))
		arm_pts.append(pts)
		arm_tip.append(global_position + Vector2(0, 30))
		arm_plant.append(global_position)


func is_frozen() -> bool:
	return st == St.FROZEN


func is_dry() -> bool:
	return st == St.DRY


func is_clinging() -> bool:
	return st == St.CLING


func freeze(on: bool) -> void:
	if on:
		if st == St.FROZEN:
			return
		_froze_clinging = st == St.CLING
		if g_state != 0:
			g_state = 3
		if st == St.CLING:
			set_collision_mask_value(2, true)
		st = St.FROZEN
		velocity = Vector2.ZERO
	elif st == St.FROZEN:
		st = St.NORMAL
		if world.water_at(global_position) < global_position.y:
			st = St.SWIM
		elif _froze_clinging and world.is_climbable(global_position):
			_enter_cling()   # keep holding on after a dialogue


func respawn_at(p: Vector2) -> void:
	global_position = p
	velocity = Vector2.ZERO
	st = St.NORMAL
	moisture = 100.0
	g_state = 0
	invuln = 1.2
	ink = 1
	dry_t = 0.0
	set_collision_mask_value(2, true)
	if world and world.is_climbable(p) and world.water_at(p) == INF:
		_enter_cling()
	for i in ARMS:
		arm_tip[i] = p + Vector2(0, 30)
		var pts: PackedVector2Array = arm_pts[i]
		for j in NPTS:
			pts[j] = p + Vector2(0, j * SEG)
		arm_pts[i] = pts


# =============================================================================

func _physics_process(dt: float) -> void:
	t += dt
	coyote = maxf(0.0, coyote - dt)
	jump_buf = maxf(0.0, jump_buf - dt)
	cling_cd = maxf(0.0, cling_cd - dt)
	invuln = maxf(0.0, invuln - dt)
	flash = maxf(0.0, flash - dt * 3.0)
	if drop_t > 0.0:
		drop_t -= dt
		if drop_t <= 0.0 and st != St.CLING:
			set_collision_mask_value(2, true)

	if st == St.FROZEN:
		velocity = Vector2.ZERO
		_animate(dt)
		queue_redraw()
		return

	var ix := Input.get_axis("left", "right")
	var iy := Input.get_axis("up", "down")
	var p := global_position
	env = world.sample_env(p)
	in_water = p.y > env.surface + 2.0
	_moisture(dt)
	if st == St.DRY:
		_st_dry(dt)
		_update_grapple_tip(dt)
		_animate(dt)
		queue_redraw()
		return

	if Input.is_action_just_pressed("jump"):
		jump_buf = 0.13
	_update_aim(ix, iy)
	if Input.is_action_just_pressed("grab") and st != St.HURT:
		_fire()
	if g_state == 1 and not Input.is_action_pressed("grab"):
		g_state = 3
	if Input.is_action_just_pressed("ink"):
		_try_dash(ix, iy)

	match st:
		St.NORMAL:
			_st_normal(dt, ix, iy)
		St.CLING:
			_st_cling(dt, ix, iy)
		St.SWIM:
			_st_swim(dt, ix, iy)
		St.GRAPPLE:
			_st_grapple(dt, ix, iy)
		St.DASH:
			_st_dash(dt)
		St.HURT:
			_st_hurt(dt)

	_update_grapple_tip(dt)
	_post_move(dt)
	_animate(dt)
	queue_redraw()


func _moisture(dt: float) -> void:
	var rate := -1.1
	if st == St.CLING:
		rate = -1.8
	if in_water or world.water_at(global_position + Vector2(0, RADIUS - 1.0)) < INF:
		rate = 50.0
	rate += env.refill
	rate -= env.heat
	moisture = clampf(moisture + rate * dt, 0.0, 100.0)
	if moisture < 25.0 and st != St.DRY:
		warn_t -= dt
		if warn_t <= 0.0:
			warn_t = 1.1
			Audio.play("drip", -10.0, 0.7)
	if moisture <= 0.0 and st != St.DRY:
		_start_dry()


# --- states -----------------------------------------------------------------------

func _st_normal(dt: float, ix: float, iy: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		coyote = 0.1
		ink = 1
	var target := ix * RUN
	var acc := ACC_GROUND if on_floor else ACC_AIR
	if ix == 0.0 and on_floor:
		acc = FRICTION
	velocity.x = move_toward(velocity.x, target, acc * dt)
	if ix != 0.0:
		facing = signf(ix)
	var g := G_HOLD if (velocity.y < 0.0 and Input.is_action_pressed("jump")) else G
	velocity.y = minf(velocity.y + g * dt, MAX_FALL)
	if env.wind != Vector2.ZERO:
		velocity += env.wind * dt * (0.3 if on_floor else 1.0)
	if env.lift > 0.0:
		velocity.y = move_toward(velocity.y, -env.lift, 2700.0 * dt)
	if env.geyser:
		velocity.y = move_toward(velocity.y, -GEYSER_V, 5200.0 * dt)
		velocity.x = move_toward(velocity.x, (world.geyser_rect.get_center().x - global_position.x) * 2.0, 500.0 * dt)
	if jump_buf > 0.0 and coyote > 0.0:
		if iy > 0.5 and _floor_is_oneway():
			set_collision_mask_value(2, false)
			drop_t = 0.3
			global_position.y += 2.0
		else:
			velocity.y = -JUMP_V
			Audio.play("jump", -6.0)
			squash = -0.25
		jump_buf = 0.0
		coyote = 0.0
	var p := global_position
	if cling_cd <= 0.0 and (iy < -0.3 or (iy > 0.3 and not on_floor)):
		if world.is_climbable(p):
			_enter_cling()
			return
		if not on_floor and iy < -0.3:
			var snap = _near_climbable(16.0)
			if snap != null:
				global_position = snap
				_enter_cling()
				return
	if in_water:
		_enter_swim(true)
		return
	move_and_slide()


func _st_cling(dt: float, ix: float, iy: float) -> void:
	ink = 1
	var want := Vector2(ix, iy)
	if want.length() > 1.0:
		want = want.normalized()
	var v: Vector2 = want * CLIMB
	var p := global_position
	var leaving := false
	if v.length_squared() > 1.0:
		var d := v * dt
		if not world.is_climbable(p + d + d.normalized() * 3.0):
			# Slide along the surface (curved trunk, sloped limbs) if possible.
			var angs: Array = [0.3, -0.3, 0.62, -0.62]
			if absf(iy) <= 0.3:
				angs = [0.3, -0.3, 0.62, -0.62, 0.75, -0.75]       # sideways: follow slopes
			elif absf(ix) > 0.3:
				angs = [0.3, -0.3, 0.62, -0.62, 0.95, -0.95, 1.25, -1.25]  # diagonal
			var found := false
			for ang: float in angs:
				var d2 := d.rotated(ang)
				if absf(iy) > 0.3 and d2.y * iy <= 0.0:
					continue   # never turn "up" into "down" (or vice versa)
				if world.is_climbable(p + d2 + d2.normalized() * 3.0):
					v = d2 / dt
					found = true
					break
			if not found and d.x != 0.0 and d.y != 0.0:
				# diagonal input: try each axis on its own (gets round corners)
				for d3: Vector2 in [Vector2(d.x, 0), Vector2(0, d.y)]:
					if world.is_climbable(p + d3 + d3.normalized() * 3.0):
						v = d3.normalized() * CLIMB   # keep full speed along the edge
						found = true
						break
			if not found and absf(iy) > 0.3:
				# up/down blocked: shuffle sideways if that lets us keep climbing
				# (prefer the pressed side, then towards the trunk)
				var tdir := signf(world.trunk_cx(p.y) - p.x)
				var first := signf(ix) if absf(ix) > 0.3 else tdir
				for off: float in [8.0, 16.0, 26.0]:
					for sx: float in [first, -first]:
						var hp := p + Vector2(sx * off, 0)
						if world.is_climbable(hp) and world.is_climbable(p + Vector2(sx * off * 0.5, 0)) \
								and world.is_climbable(hp + Vector2(0, d.y + signf(d.y) * 3.0)):
							v = Vector2(sx * CLIMB * 0.8, 0)
							found = true
							break
					if found:
						break
			if not found:
				if absf(iy) <= 0.3 and v.x != 0.0:
					leaving = true   # pushing sideways off the edge: let go
				else:
					v = Vector2.ZERO   # climbing diagonally: stop at the edge
	var lx: float = world.ladder_center_x(p)
	if not is_nan(lx) and absf(iy) > 0.3:
		v.x = clampf((lx - p.x) * 8.0, -CLIMB, CLIMB)
		if world.is_climbable(p + Vector2(0, signf(iy) * (CLIMB * dt + 3.0))):
			v.y = signf(iy) * CLIMB
	# Wind only pushes a moving octopus; holding still, Otto grips tight.
	var drift: Vector2 = env.wind * 0.14 if want.length() > 0.2 else Vector2.ZERO
	if drift != Vector2.ZERO and world.is_climbable(p + (v + drift) * dt * 2.0):
		v += drift
	if jump_buf > 0.0:
		jump_buf = 0.0
		_exit_cling()
		cling_cd = 0.22
		if iy > 0.4:
			velocity = Vector2(ix * 140.0, 80.0)
		else:
			velocity = Vector2(ix * 330.0, -480.0)
			Audio.play("jump", -7.0, 1.1)
		if ix != 0.0:
			facing = signf(ix)
		return
	if env.geyser:
		_exit_cling()
		cling_cd = 0.4
		return
	if not world.is_climbable(p):
		_exit_cling()
		return
	velocity = v
	if v.length() > 20.0:
		step_t -= dt
		if step_t <= 0.0:
			step_t = 0.24
			Audio.play("climb", -14.0, 1.0, 0.15)
	move_and_slide()
	if leaving:
		_exit_cling()
		cling_cd = 0.12
		velocity = Vector2(ix * 120.0, 0.0)
	elif iy > 0.3 and is_on_floor():
		_exit_cling()
	elif in_water and global_position.y > env.surface + 24.0:
		_exit_cling()
		_enter_swim(false)


func _st_swim(dt: float, ix: float, iy: float) -> void:
	ink = 1
	var want := Vector2(ix, iy)
	if want.length() > 1.0:
		want = want.normalized()
	var target := want * SWIM if want != Vector2.ZERO else Vector2(0, 26)
	velocity = velocity.move_toward(target, 950.0 * dt)
	if ix != 0.0:
		facing = signf(ix)
	var surf: float = env.surface
	var y := global_position.y
	if y < surf + 12.0 and velocity.y < 0.0:
		velocity.y = maxf(velocity.y, -30.0)
	if want.length() > 0.2:
		swim_t -= dt
		if swim_t <= 0.0:
			swim_t = 0.5
			Audio.play("swim", -12.0)
			world.fx.spawn(global_position + Vector2(randf_range(-6, 6), 8), Vector2(randf_range(-10, 10), -60), 1.2, 2.5, Color(0.8, 0.95, 1.0, 0.6), 0, -40.0, 0.5)
	if env.geyser:
		st = St.NORMAL
		velocity.y = -GEYSER_V
		world.fx.splash(global_position, 1.2)
		return
	if y < surf + 30.0:
		if jump_buf > 0.0:
			jump_buf = 0.0
			st = St.NORMAL
			velocity.y = -JUMP_V * 1.02
			Audio.play("splash", -6.0, 1.2)
			world.fx.splash(Vector2(global_position.x, surf), 0.8)
			return
		if iy < -0.3 and cling_cd <= 0.0 and world.is_climbable(global_position):
			_enter_cling()
			return
	if not in_water:
		st = St.NORMAL
		return
	move_and_slide()


func _st_grapple(dt: float, ix: float, iy: float) -> void:
	velocity.y += G * dt
	velocity.x += ix * SWING_ACC * dt
	if ix != 0.0:
		facing = signf(ix)
	if iy != 0.0:
		g_len = clampf(g_len + iy * REEL * dt, 22.0, GRAPPLE_RANGE + 30.0)
	velocity += env.wind * dt
	var next := global_position + velocity * dt
	var d := next - g_point
	if d.length() > g_len:
		next = g_point + d.normalized() * g_len
		velocity = (next - global_position) / dt
	velocity = velocity.limit_length(1150.0)
	velocity *= (1.0 - 0.12 * dt)
	if not Input.is_action_pressed("grab"):
		_release(false)
		return
	if jump_buf > 0.0:
		jump_buf = 0.0
		_release(true)
		return
	if iy < -0.3 and cling_cd <= 0.0:
		var snap = _near_climbable(22.0)
		if snap != null:
			_release(false)
			global_position = snap
			_enter_cling()
			return
	move_and_slide()
	if in_water:
		_release(false)
		_enter_swim(true)


func _st_dash(dt: float) -> void:
	dash_t -= dt
	velocity = dash_dir * DASH_V
	world.fx.ink(global_position - dash_dir * 10.0, velocity)
	move_and_slide()
	if dash_t <= 0.0:
		velocity *= 0.5
		st = St.SWIM if in_water else St.NORMAL


func _st_hurt(dt: float) -> void:
	hurt_t -= dt
	velocity.y = minf(velocity.y + G * dt, MAX_FALL)
	velocity.x = move_toward(velocity.x, 0.0, 500.0 * dt)
	move_and_slide()
	if hurt_t <= 0.0:
		st = St.NORMAL


func _st_dry(dt: float) -> void:
	dry_t += dt
	velocity.y = minf(velocity.y + G * dt, MAX_FALL)
	velocity.x = move_toward(velocity.x, 0.0, 900.0 * dt)
	move_and_slide()
	if dry_t > 1.7 and dry_t - dt <= 1.7:
		if world.main:
			world.main.respawn_player()


# --- transitions -----------------------------------------------------------------

func _enter_cling() -> void:
	st = St.CLING
	velocity = Vector2.ZERO
	set_collision_mask_value(2, false)
	ink = 1
	for i in ARMS:
		arm_plant[i] = global_position + _arm_dir(i) * 20.0
	Audio.play("climb", -10.0, 0.9)


func _exit_cling() -> void:
	if st == St.CLING:
		st = St.NORMAL
	if drop_t <= 0.0:
		set_collision_mask_value(2, true)


func _enter_swim(splash: bool) -> void:
	st = St.SWIM
	if splash and fall_speed > 250.0:
		Audio.play("splash", lerpf(-12.0, -2.0, clampf(fall_speed / 900.0, 0.0, 1.0)))
		world.fx.splash(Vector2(global_position.x, env.surface), clampf(fall_speed / 600.0, 0.4, 1.6))
	velocity.y *= 0.4


func _try_dash(ix: float, iy: float) -> void:
	if st in [St.DASH, St.HURT, St.DRY, St.FROZEN]:
		return
	if ink <= 0 and not in_water:
		world.fx.burst(global_position, 4, 60.0, Color(0.1, 0.05, 0.15, 0.6), 0.4, 3.0, 0.0)
		return
	var d := Vector2(ix, iy)
	if d.length() < 0.2:
		if Game.using_mouse():
			d = get_global_mouse_position() - global_position
		else:
			d = Vector2(facing, 0)
	dash_dir = d.normalized()
	if st == St.GRAPPLE:
		_release(false)
	if st == St.CLING:
		_exit_cling()
	st = St.DASH
	dash_t = DASH_T
	if not in_water:
		ink = 0
	velocity = dash_dir * DASH_V
	Audio.play("ink", -3.0)
	world.add_shake(0.12)
	for i in 6:
		world.fx.ink(global_position, -velocity)


func _fire() -> void:
	if g_state != 0 and g_state != 3:
		return
	g_tip = global_position
	if aim_target == null:
		g_state = 4
		g_point = global_position + aim_dir * 90.0
		Audio.play("shoot", -10.0, 0.8)
		return
	g_point = aim_target
	g_state = 1
	Audio.play("shoot", -4.0)
	var best := 0
	var bd := -2.0
	var dirv := (g_point - global_position).normalized()
	for i in ARMS:
		var dd := _arm_dir(i).dot(dirv)
		if dd > bd:
			bd = dd
			best = i
	g_arm = best


func _attach() -> void:
	if st in [St.HURT, St.DRY, St.FROZEN]:
		g_state = 3
		return
	if st == St.CLING:
		_exit_cling()
	g_state = 2
	st = St.GRAPPLE
	g_len = maxf(24.0, global_position.distance_to(g_point))
	ink = 1
	Audio.play("attach", -4.0)
	world.fx.spawn(g_point, Vector2.ZERO, 0.35, 4.0, Color(1, 0.9, 0.6, 0.9), 5, 0.0, 0.0, 60.0)


func _release(jumped: bool) -> void:
	if g_state != 0:
		g_state = 3
	if st == St.GRAPPLE:
		st = St.NORMAL
	cling_cd = maxf(cling_cd, 0.08)
	if jumped:
		velocity.y = minf(velocity.y, 0.0) - 280.0
		Audio.play("jump", -8.0, 1.2)


func _update_grapple_tip(dt: float) -> void:
	match g_state:
		1:
			g_tip = g_tip.move_toward(g_point, 2700.0 * dt)
			if g_tip.distance_to(g_point) < 1.0:
				_attach()
		2:
			g_tip = g_point
		3:
			g_tip = g_tip.move_toward(global_position, 3200.0 * dt)
			if g_tip.distance_to(global_position) < 12.0:
				g_state = 0
		4:
			g_tip = g_tip.move_toward(g_point, 2400.0 * dt)
			if g_tip.distance_to(g_point) < 2.0:
				g_state = 3


func _update_aim(ix: float, iy: float) -> void:
	var rs := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if Game.using_mouse():
		var m := get_global_mouse_position()
		aim_dir = (m - global_position).normalized()
		aim_target = world.nearest_anchor(global_position, aim_dir, GRAPPLE_RANGE, m)
		return
	if rs.length() > 0.35:
		aim_dir = rs.normalized()
	elif Vector2(ix, iy).length() > 0.2:
		aim_dir = Vector2(ix, iy).normalized()
		if aim_dir.y > 0.3 and st != St.GRAPPLE:
			aim_dir = Vector2(facing * 0.6, -0.8).normalized()
	else:
		aim_dir = Vector2(facing * 0.55, -0.85).normalized()
	aim_target = world.nearest_anchor(global_position, aim_dir, GRAPPLE_RANGE)


## Finds a climbable point within r pixels (for forgiving grabs mid-air).
func _near_climbable(r: float) -> Variant:
	var p := global_position
	if world.is_climbable(p):
		return p
	for ring in [r * 0.5, r]:
		for k in 12:
			var q: Vector2 = p + Vector2.from_angle(TAU * k / 12.0) * ring
			if world.is_climbable(q):
				var hit := move_and_collide(q - p, true)
				if hit == null:
					return q
	return null


func _floor_is_oneway() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if c.get_normal().y < -0.5:
			var o := c.get_collider()
			if o is CollisionObject2D and (o.collision_layer & 2) != 0:
				return true
	return false


func _post_move(dt: float) -> void:
	var on_floor := is_on_floor()
	if on_floor and not was_on_floor and st in [St.NORMAL, St.HURT]:
		if fall_speed > 260.0:
			squash = clampf(fall_speed / 1400.0, 0.1, 0.45)
			Audio.play("land", lerpf(-14.0, -3.0, clampf(fall_speed / 900.0, 0.0, 1.0)))
			world.fx.burst(global_position + Vector2(0, RADIUS), 6, 120.0, Color(0.85, 0.85, 0.9, 0.5), 0.35, 2.5, 300.0, -PI / 2, PI)
			if fall_speed > 820.0:
				world.add_shake(0.25)
				Game.falls += 1
	was_on_floor = on_floor
	if not on_floor:
		fall_speed = maxf(0.0, velocity.y)
	if on_floor and st == St.NORMAL and absf(velocity.x) > 60.0:
		step_t -= dt
		if step_t <= 0.0:
			step_t = 0.2
			Audio.play("step", -15.0, 1.0, 0.2)
	if world.fx and moisture > 50.0 and st == St.NORMAL and randf() < 0.02:
		world.fx.spawn(global_position + Vector2(randf_range(-8, 8), 6), Vector2(0, 40), 0.6, 1.8, Color(0.7, 0.9, 1.0, 0.7), 0, 500.0)


# --- damage & drying ---------------------------------------------------------------

func hurt(from: Vector2, amount: float, knock: Vector2) -> void:
	if invuln > 0.0 or st in [St.DRY, St.FROZEN]:
		return
	if st == St.GRAPPLE:
		_release(false)
	if st == St.CLING:
		_exit_cling()
	if g_state != 0:
		g_state = 3
	moisture = maxf(0.0, moisture - amount)
	invuln = 1.3
	hurt_t = 0.38
	flash = 1.0
	st = St.HURT
	velocity = knock
	Audio.play("hurt", -2.0)
	world.add_shake(0.45)
	world.fx.burst(global_position, 10, 220.0, Color(0.7, 0.9, 1.0, 0.8), 0.5, 3.0, 500.0)
	var _f := from
	if moisture <= 0.0:
		_start_dry()


func _start_dry() -> void:
	st = St.DRY
	dry_t = 0.0
	if g_state != 0:
		g_state = 3
	set_collision_mask_value(2, true)
	Audio.play("dry", -2.0)
	Game.dryouts += 1


# --- animation -----------------------------------------------------------------------

func _arm_dir(i: int) -> Vector2:
	var a := TAU * float(i) / float(ARMS) + 0.39
	return Vector2(cos(a), sin(a))


func _animate(dt: float) -> void:
	var pos := global_position
	var target_rot := 0.0
	if st in [St.SWIM, St.DASH] and velocity.length() > 70.0:
		target_rot = velocity.angle() + PI / 2.0
	elif st == St.GRAPPLE:
		target_rot = (pos - g_point).angle() - PI / 2.0
		target_rot = clampf(wrapf(target_rot, -PI, PI), -0.9, 0.9)
	elif st == St.NORMAL and not is_on_floor():
		target_rot = clampf(velocity.x * 0.0009, -0.35, 0.35)
	elif st == St.DRY:
		target_rot = 0.0
	body_rot = lerp_angle(body_rot, target_rot, 1.0 - exp(-10.0 * dt))
	squash = lerpf(squash, 0.0, 1.0 - exp(-9.0 * dt))
	blink_t -= dt
	if blink_t < -0.12:
		blink_t = randf_range(1.8, 4.5)
	# where the eyes look
	var lk := Vector2(facing, 0.1)
	if aim_target != null and g_state == 0 and st != St.FROZEN:
		lk = (aim_target - pos).normalized()
	elif velocity.length() > 40.0:
		lk = velocity.normalized()
	look = look.lerp(lk, 1.0 - exp(-8.0 * dt))
	# camouflage
	var kind: String = world.surface_kind(pos) if st == St.CLING else ""
	var want := Art.OCTO
	match kind:
		"bark":
			want = Color("6e4a33")
		"metal":
			want = Color("8c97a1")
		"ivy":
			want = Color("4e7d3a")
	if st == St.CLING and velocity.length() < 10.0:
		cam_t = minf(1.0, cam_t + dt * 0.8)
	else:
		cam_t = maxf(0.0, cam_t - dt * 1.5)
	cam_col = cam_col.lerp(want, 1.0 - exp(-3.0 * dt))
	walk_phase += absf(velocity.x) * dt * 0.09
	# arms
	var vel := velocity
	for i in ARMS:
		var root := _arm_root(i)
		var tip: Vector2
		match st:
			St.CLING:
				var pl: Vector2 = arm_plant[i]
				if pl.distance_to(root) > 30.0 or randf() < 0.002:
					var nd := _arm_dir(i)
					pl = pos + nd * 20.0 + (vel.normalized() * 10.0 if vel.length() > 5.0 else Vector2.ZERO)
					arm_plant[i] = pl
				tip = pl
			St.SWIM, St.DASH:
				var vd := vel.normalized() if vel.length() > 30.0 else Vector2(0, -1)
				var perp := Vector2(-vd.y, vd.x)
				var spread := float(i) - 3.5
				tip = pos - vd * 36.0 + perp * (spread * 3.2 + sin(t * 9.0 + i) * 3.0)
			St.DRY:
				tip = pos + Vector2((float(i) - 3.5) * 4.0, 12.0 + sin(i * 2.0) * 3.0)
			_:
				if is_on_floor() and st != St.FROZEN:
					var spread2 := (float(i) - 3.5) * 6.5
					var wob := sin(walk_phase + i * 1.3) * 5.0 * clampf(absf(vel.x) / 120.0, 0.0, 1.0)
					tip = pos + Vector2(spread2 + wob + facing * 2.0, RADIUS + 1.0 - absf(sin(walk_phase + i)) * 4.0 * clampf(absf(vel.x) / 120.0, 0.0, 1.0))
				elif st == St.FROZEN:
					tip = pos + Vector2((float(i) - 3.5) * 6.0 + sin(t * 1.5 + i) * 2.0, RADIUS + 2.0)
				else:
					var trail := (-vel * 0.03).limit_length(22.0)
					tip = root + Vector2((float(i) - 3.5) * 5.0, 24.0) + trail + Vector2(sin(t * 6.0 + i) * 3.0, 0)
		if (st == St.GRAPPLE or g_state == 1 or g_state == 3 or g_state == 4) and i == g_arm and g_state != 0:
			tip = g_tip
		var cur: Vector2 = arm_tip[i]
		var k := 26.0 if st == St.CLING else 16.0
		cur = cur.lerp(tip, 1.0 - exp(-k * dt))
		if i == g_arm and g_state != 0:
			cur = g_tip
		arm_tip[i] = cur
		var pts: PackedVector2Array = arm_pts[i]
		if i == g_arm and g_state != 0:
			for j in NPTS:
				var f := float(j) / float(NPTS - 1)
				var sag := sin(f * PI) * 6.0 * (1.0 if g_state != 2 else 0.2)
				pts[j] = root.lerp(cur, f) + Vector2(0, sag)
		else:
			pts = _solve(root, cur, pts)
		arm_pts[i] = pts


func _arm_root(i: int) -> Vector2:
	var a := PI * 0.12 + PI * 0.76 * float(i) / float(ARMS - 1)
	var off := Vector2(cos(a) * 8.0, 5.0 + sin(a) * 4.0)
	return global_position + off.rotated(body_rot)


func _solve(root: Vector2, target: Vector2, pts: PackedVector2Array) -> PackedVector2Array:
	var n := pts.size()
	var total := SEG * float(n - 1)
	if root.distance_to(target) >= total:
		var d := (target - root).normalized()
		for j in n:
			pts[j] = root + d * SEG * j
		return pts
	for it in 2:
		pts[n - 1] = target
		for j in range(n - 2, -1, -1):
			var dv := pts[j] - pts[j + 1]
			if dv.length_squared() < 0.0001:
				dv = Vector2.UP
			pts[j] = pts[j + 1] + dv.normalized() * SEG
		pts[0] = root
		for j in range(1, n):
			var dv2 := pts[j] - pts[j - 1]
			if dv2.length_squared() < 0.0001:
				dv2 = Vector2.DOWN
			pts[j] = pts[j - 1] + dv2.normalized() * SEG
	return pts


func _body_color() -> Color:
	var c := Art.OCTO.lerp(cam_col, 0.25 + cam_t * 0.55) if cam_col != Art.OCTO else Art.OCTO
	if moisture < 35.0:
		c = c.lerp(Color("d6c4ac"), (35.0 - moisture) / 35.0 * 0.75)
	if st == St.DRY:
		c = c.lerp(Color("cbb89c"), clampf(dry_t, 0.0, 1.0))
	if flash > 0.0:
		c = c.lerp(Color.WHITE, flash * 0.8)
	return c


func _draw() -> void:
	if invuln > 0.0 and st != St.DRY and int(t * 16.0) % 2 == 0:
		modulate.a = 0.55
	else:
		modulate.a = 1.0
	var col := _body_color()
	var dark := col.darkened(0.28)
	var o := global_position
	var shrink := 1.0 - clampf(dry_t * 0.25, 0.0, 0.3) if st == St.DRY else 1.0
	# arms (back to front)
	var order := [0, 7, 1, 6, 2, 5, 3, 4]
	for idx in order:
		var i: int = idx
		var pts: PackedVector2Array = arm_pts[i]
		var lp := PackedVector2Array()
		for q in pts:
			lp.append(q - o)
		var ac := dark if i in [0, 7, 1, 6] else col
		var w0 := 6.5 * shrink
		if i == g_arm and g_state != 0:
			Art.strip(self, lp, 5.5, 3.0, ac.darkened(0.05))
			draw_circle(lp[lp.size() - 1], 4.0, ac.lightened(0.2))
		else:
			Art.strip(self, lp, w0, 1.6, ac)
		for j in range(1, lp.size() - 1, 1):
			var seg_d := lp[j + 1] - lp[j - 1]
			var nrm := Vector2(-seg_d.y, seg_d.x).normalized()
			draw_circle(lp[j] + nrm * 1.6, 1.3 * (1.0 - float(j) / lp.size()) + 0.4, Color(1.0, 0.85, 0.75, 0.75))
	# mantle
	var sx := (1.0 + squash * 0.6) * shrink
	var sy := (1.0 - squash * 0.5) * shrink
	var mantle_c := Vector2(0, -7).rotated(body_rot)
	var pts2 := PackedVector2Array()
	for k in 22:
		var a := TAU * k / 22.0
		var r := Vector2(cos(a) * 13.5 * sx, sin(a) * 16.5 * sy)
		if sin(a) < 0.0:
			r.y *= 1.08
		pts2.append(mantle_c + r.rotated(body_rot))
	draw_colored_polygon(pts2, col)
	# spots + highlight
	draw_circle(mantle_c + Vector2(-5, -6).rotated(body_rot) * sx, 2.2, dark)
	draw_circle(mantle_c + Vector2(4, -10).rotated(body_rot) * sx, 1.8, dark)
	draw_circle(mantle_c + Vector2(6, -2).rotated(body_rot) * sx, 1.5, dark)
	Art.ellipse(self, mantle_c + Vector2(-5, -9).rotated(body_rot), 3.5, 5.5, Color(1, 1, 1, 0.22), body_rot - 0.4)
	# eyes
	var eye_open := 0.15 if blink_t < 0.0 else 1.0
	if st == St.DRY:
		eye_open = 0.25
	for side: float in [-1.0, 1.0]:
		var ec := Vector2(side * 6.5, 3.0).rotated(body_rot)
		Art.ellipse(self, ec, 5.0, 5.2 * eye_open, Color("fbf6ea"))
		if eye_open > 0.5:
			var pp := ec + look * 1.8
			draw_rect(Rect2(pp - Vector2(2.6, 1.0), Vector2(5.2, 2.0)), Color("17141c"))
			draw_circle(pp + Vector2(-1.4, -1.6), 0.9, Color(1, 1, 1, 0.9))
		draw_arc(ec, 5.4, PI + 0.4, TAU - 0.4, 8, dark, 1.4)
	# blush
	draw_circle(Vector2(-10, 9).rotated(body_rot), 2.4, Color(1.0, 0.45, 0.45, 0.35))
	draw_circle(Vector2(10, 9).rotated(body_rot), 2.4, Color(1.0, 0.45, 0.45, 0.35))
	if st == St.DRY and dry_t > 0.6:
		draw_line(Vector2(-6, -16), Vector2(-2, -10), Color(0.4, 0.3, 0.2, 0.6), 1.0)
		draw_line(Vector2(4, -18), Vector2(7, -12), Color(0.4, 0.3, 0.2, 0.6), 1.0)
