extends Node2D
## Frau Hofrätin Kalmar - a giant squid with a terrible cold, living in the
## flooded pit at the bottom of the light shaft. Her sneezes shoot a geyser up
## the shaft. Wears a monocle, holds a lace handkerchief.

const Art = preload("res://scripts/art.gd")

const PERIOD := 7.5
const WATER_Y := 3240.0

var world: Node2D
var t := 0.0
var enabled := false
var next_sneeze := 4.0
var phase := 0          # 0 idle, 1 "Ha...", 2 "Ha... HA...", 3 spraying
var spray_t := 0.0
var bubble := ""
var bubble_t := 0.0
var flail := 0.0
var cured := false
var cure_t := 0.0
var rise := 0.0         # 0..1 final giant tentacle rising up the shaft
var _hand_wave := 0.0


func _process(dt: float) -> void:
	t += dt
	bubble_t = maxf(0.0, bubble_t - dt)
	flail = maxf(0.0, flail - dt * 0.8)
	if cured:
		cure_t += dt
	if enabled and not cured:
		next_sneeze -= dt
		if phase == 0 and next_sneeze <= 2.4:
			phase = 1
			say("Ha...", 1.3)
			Audio.play_at("sneeze_ha", _mouth(), 2.0, 1.0, 0.05, 5200.0)
		elif phase == 1 and next_sneeze <= 1.15:
			phase = 2
			say("Ha... HA...", 1.3)
			Audio.play_at("sneeze_ha", _mouth(), 4.0, 1.18, 0.05, 5200.0)
		elif phase == 2 and next_sneeze <= 0.0:
			sneeze_now(true)
		elif phase == 3:
			spray_t -= dt
			if spray_t <= 0.0:
				phase = 0
				world.geyser_on = false
				next_sneeze = PERIOD
	queue_redraw()


func sneeze_now(with_geyser: bool) -> void:
	phase = 3 if with_geyser else 0
	spray_t = 1.75
	flail = 1.0
	say("HATSCHI!!", 1.6)
	Audio.play_at("sneeze_tschi", _mouth(), 6.0, 1.0, 0.05, 6000.0)
	if with_geyser:
		world.geyser_on = true
		Audio.play_at("geyser", Vector2(0, 3000), 4.0, 1.0, 0.05, 6000.0)
	if world.camera:
		var d: float = absf(world.camera.global_position.y - global_position.y)
		world.add_shake(clampf(1.0 - d / 3200.0, 0.05, 0.8))
	if not with_geyser:
		next_sneeze = PERIOD


func say(s: String, dur: float) -> void:
	bubble = s
	bubble_t = dur


func cure() -> void:
	cured = true
	cure_t = 0.0
	enabled = false
	world.geyser_on = false
	phase = 0


func rise_tip_y() -> float:
	return lerpf(0.0, -4420.0, ease(rise, -2.2))


func _mouth() -> Vector2:
	return global_position + Vector2(-60, -60)


# --- drawing ---------------------------------------------------------------------

func _body_col() -> Color:
	var c := Color("a63a6c")
	if cured:
		c = c.lerp(Color("6a5ad8"), clampf(cure_t * 0.5, 0.0, 0.85))
	return c


func _draw() -> void:
	var col := _body_col()
	var dark := col.darkened(0.35)
	var light := col.lightened(0.3)
	var sq := 1.0 + flail * 0.08 * sin(t * 30.0)
	# mantle, pointing down-right into the corner of the pit
	var axis := Vector2(1, 0.62).normalized()
	var perp := Vector2(-axis.y, axis.x)
	var mantle := PackedVector2Array()
	for i in 15:
		var f := float(i) / 14.0
		var w := lerpf(78.0, 18.0, pow(f, 1.4)) * sq
		mantle.append(Vector2(30, 10) + axis * f * 300.0 + perp * w)
	for i in range(14, -1, -1):
		var f2 := float(i) / 14.0
		var w2 := lerpf(78.0, 18.0, pow(f2, 1.4)) * sq
		mantle.append(Vector2(30, 10) + axis * f2 * 300.0 - perp * w2)
	draw_colored_polygon(mantle, col)
	# fins
	var tip := Vector2(30, 10) + axis * 300.0
	draw_colored_polygon(PackedVector2Array([tip - axis * 70.0 + perp * 16.0, tip + perp * 60.0 + axis * 10.0, tip + axis * 20.0, tip - perp * 60.0 + axis * 10.0, tip - axis * 70.0 - perp * 16.0]), dark)
	# spots
	for i in 16:
		var f3 := 0.1 + 0.8 * Art.hash01(i * 3)
		var s := (Art.hash01(i * 7 + 1) - 0.5) * 1.4
		var p := Vector2(30, 10) + axis * f3 * 300.0 + perp * s * lerpf(70.0, 16.0, f3)
		draw_circle(p, 5.0 + 6.0 * Art.hash01(i), light)
	# bioluminescent dots
	for i in 10:
		var f4 := 0.15 + 0.75 * Art.hash01(i * 11 + 5)
		var p2 := Vector2(30, 10) + axis * f4 * 300.0 + perp * (Art.hash01(i + 40) - 0.5) * 90.0 * (1.0 - f4)
		var a := 0.35 + 0.35 * sin(t * 2.0 + i)
		Art.glow(self, p2, 16.0, Color(0.4, 0.9, 1.0, a * 0.6))
		draw_circle(p2, 2.2, Color(0.6, 1.0, 1.0, a + 0.3))
	# head
	Art.ellipse(self, Vector2(-10, -20), 70.0 * sq, 58.0 * sq, col, -0.5)
	# arms
	for i in 8:
		var base_a := -PI * 0.5 - 1.0 + float(i) * 0.26
		var length := 170.0 + 40.0 * sin(i * 1.7) + flail * 40.0
		_draw_arm(Vector2(-50, -40) + Vector2(cos(base_a), sin(base_a)) * 20.0, base_a, length, 24.0, i, col, dark)
	# two long feeding tentacles reaching for the surface
	for j in 2:
		var ba := -PI * 0.5 - 0.35 + j * 0.5
		_draw_arm(Vector2(-40, -50), ba, 410.0 + flail * 50.0, 16.0, 10 + j, col, dark, true)
	# the giant eye + monocle
	var ec := Vector2(-6, -36)
	draw_circle(ec, 37.0, Color("f4ecd0"))
	draw_circle(ec, 37.0, Color(0, 0, 0, 0.0))
	var look := Vector2.ZERO
	if world and world.player:
		look = (world.player.global_position - (global_position + ec)).normalized()
	var iris_c := ec + look * 9.0
	draw_circle(iris_c, 24.0, Color("d9a12a") if not cured else Color("7fd0ff"))
	draw_circle(iris_c, 12.0 if phase < 3 else 6.0, Color("17101a"))
	draw_circle(iris_c + Vector2(-8, -9), 5.0, Color(1, 1, 1, 0.85))
	if cured and cure_t > 0.4:
		draw_arc(ec + Vector2(0, 6), 26.0, PI + 0.5, TAU - 0.5, 16, dark, 6.0)
	# eyelid (sleepy / sneezy)
	var lid := 0.0
	if phase == 1:
		lid = 0.35
	elif phase == 2:
		lid = 0.6
	elif phase == 3:
		lid = 0.95 if spray_t > 1.2 else 0.3
	if lid > 0.0:
		var lp := PackedVector2Array()
		for k in 13:
			var a2 := PI + PI * float(k) / 12.0
			lp.append(ec + Vector2(cos(a2) * 38.0, sin(a2) * 38.0))
		for k in range(11, 0, -1):
			var a3 := PI + PI * float(k) / 12.0
			lp.append(ec + Vector2(cos(a3) * 38.0, -sin(a3) * 38.0 * (lid * 2.0 - 1.0)))
		draw_colored_polygon(lp, dark)
	draw_arc(ec, 41.0, 0, TAU, 40, Color("d8b04a"), 4.0)
	draw_arc(ec, 41.0, -2.4, -1.7, 8, Color("fff1b5"), 2.0)
	var chain := PackedVector2Array()
	for k in 12:
		var f5 := float(k) / 11.0
		chain.append(ec + Vector2(38, 14) + Vector2(f5 * 60.0, sin(f5 * PI) * 50.0 + sin(t + f5 * 4.0) * 3.0))
	draw_polyline(chain, Color("d8b04a"), 2.0)
	# the final giant tentacle that rises up the whole shaft
	if rise > 0.0:
		_draw_rise()
	# speech bubble above the water
	if bubble_t > 0.0 and world:
		var bp: Vector2 = Vector2(-120, WATER_Y - 70.0) - global_position
		var f: Font = Art.font()
		var size := 26 if bubble.length() < 10 else 22
		var sz := f.get_string_size(bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var r := Rect2(bp - Vector2(sz.x * 0.5 + 14, sz.y * 0.5 + 8), Vector2(sz.x + 28, sz.y + 16))
		var a4 := clampf(bubble_t * 3.0, 0.0, 1.0)
		Art.rrect(self, r, Color(1, 1, 1, 0.92 * a4), 14, 3, Color(0.3, 0.1, 0.2, a4))
		draw_colored_polygon(PackedVector2Array([bp + Vector2(10, sz.y * 0.5 + 6), bp + Vector2(36, sz.y * 0.5 + 6), bp + Vector2(40, sz.y * 0.5 + 30)]), Color(1, 1, 1, 0.92 * a4))
		draw_string(f, Vector2(r.position.x + 14, bp.y + size * 0.36), bubble, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.35, 0.05, 0.2, a4))


func _draw_arm(root: Vector2, ang: float, length: float, width: float, idx: int, col: Color, dark: Color, club := false) -> void:
	var pts := PackedVector2Array()
	var n := 16
	var speed := 1.2 + flail * 6.0
	for j in n:
		var f := float(j) / float(n - 1)
		var a := ang + sin(t * speed + idx * 1.3 + f * 3.0) * 0.35 * f + sin(t * 0.7 + idx) * 0.2
		if j == 0:
			pts.append(root)
		else:
			pts.append(pts[j - 1] + Vector2(cos(a), sin(a)) * (length / float(n - 1)))
	Art.strip(self, pts, width, width * 0.18, col)
	for j in range(2, n - 1, 2):
		var d := pts[j + 1] - pts[j - 1]
		var nrm := Vector2(-d.y, d.x).normalized()
		draw_circle(pts[j] + nrm * width * 0.25 * (1.0 - float(j) / n), maxf(1.5, width * 0.16 * (1.0 - float(j) / n)), Color("f2c7d8"))
	if club:
		Art.ellipse(self, pts[n - 1], 16.0, 9.0, dark, (pts[n - 1] - pts[n - 2]).angle())
	if idx == 2:
		# lace handkerchief
		var hp := pts[n - 1]
		var hr := sin(t * 1.5) * 0.3
		var hk := PackedVector2Array([hp + Vector2(-14, -4).rotated(hr), hp + Vector2(14, -8).rotated(hr), hp + Vector2(18, 18).rotated(hr), hp + Vector2(-10, 22).rotated(hr)])
		draw_colored_polygon(hk, Color("fbfbf4"))
		for k in 4:
			draw_circle(hk[k], 3.0, Color("fbfbf4"))
		draw_polyline(PackedVector2Array([hk[0], hk[1], hk[2], hk[3], hk[0]]), Color("d9d0e0"), 1.0)


func _draw_rise() -> void:
	# One enormous arm rising from the pit all the way up next to the tree.
	var top_y := rise_tip_y()
	var pts := PackedVector2Array()
	var n := 70
	for j in n:
		var f := float(j) / float(n - 1)
		var y := lerpf(-80.0, top_y, f)
		var x := -60.0 + 120.0 * f + sin(t * 1.2 + f * 9.0) * 26.0 * f
		pts.append(Vector2(x, y))
	var col := _body_col()
	Art.strip(self, pts, 76.0, 20.0, col.darkened(0.4))
	Art.strip(self, pts, 66.0, 15.0, col)
	var belly := PackedVector2Array()
	for q in pts:
		belly.append(q + Vector2(-14, 0))
	Art.strip(self, belly, 22.0, 5.0, col.lightened(0.25))
	for j in range(3, n - 1, 2):
		var f := float(j) / n
		draw_circle(pts[j] + Vector2(-22.0 * (1.0 - f) - 6.0, 0), 7.0 * (1.0 - f) + 2.0, Color("f2c7d8"))
		draw_circle(pts[j] + Vector2(-22.0 * (1.0 - f) - 6.0, 0), 3.0 * (1.0 - f) + 1.0, col.darkened(0.2))
	if rise > 0.95:
		var hp := pts[n - 1]
		var wave := sin(t * 4.0) * 0.5
		var hk := PackedVector2Array([hp + Vector2(-18, -6).rotated(wave), hp + Vector2(18, -12).rotated(wave), hp + Vector2(24, 24).rotated(wave), hp + Vector2(-14, 30).rotated(wave)])
		draw_colored_polygon(hk, Color("fbfbf4"))
