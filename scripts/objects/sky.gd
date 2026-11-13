extends Node2D
## Night sky over Vienna: moon, stars, a cathedral spire and the giant wheel.

const Art = preload("res://scripts/art.gd")

var world: Node2D
var t := 0.0


func _process(dt: float) -> void:
	t += dt
	# The sky only needs animating while it is on screen.
	if world.camera and world.camera.get_screen_center_position().y < 500.0:
		queue_redraw()


func _draw() -> void:
	var r := Rect2(-1600, -1700, 3200, 1740)
	var cols := PackedColorArray([Color("070a1c"), Color("070a1c"), Color("3a2a4a"), Color("3a2a4a")])
	draw_polygon(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]), cols)
	Art.glow_rect(self, Rect2(-1600, -500, 3200, 900), Color(1.0, 0.55, 0.3, 0.18))
	for i in 140:
		var p := Vector2(-1500 + Art.hash01(i) * 3000.0, -1650 + Art.hash01(i + 300) * 1300.0)
		var a := 0.4 + 0.6 * absf(sin(t * (0.5 + Art.hash01(i + 77)) + i))
		draw_circle(p, 0.8 + Art.hash01(i + 9) * 1.4, Color(1, 1, 0.95, a))
	Art.moon(self, Vector2(-330, -1060), 34.0)
	# skyline silhouettes
	var sil := Color("141a2e")
	var far := Color("1c2340")
	for i in 16:
		var bx := -620.0 + i * 80.0
		var bh := 60.0 + Art.hash01(i * 13) * 140.0
		draw_rect(Rect2(bx, -bh - 30.0, 78.0, bh + 30.0), far)
		for w in 4:
			if Art.hash01(i * 7 + w) < 0.45:
				draw_rect(Rect2(bx + 10 + (w % 2) * 34, -bh - 10.0 + (w / 2) * 26.0, 10, 12), Color(1.0, 0.85, 0.5, 0.35))
	# St. Stephen's cathedral, roughly: steep patterned roof + tall gothic spire
	var sx := -250.0
	draw_colored_polygon(PackedVector2Array([Vector2(sx - 120, -40), Vector2(sx + 60, -40), Vector2(sx + 30, -170), Vector2(sx - 90, -170)]), sil)
	draw_colored_polygon(PackedVector2Array([Vector2(sx - 90, -170), Vector2(sx + 30, -170), Vector2(sx - 30, -250)]), sil)
	for k in 5:
		var yy := -70.0 - k * 22.0
		draw_line(Vector2(sx - 110 + k * 4, yy), Vector2(sx + 50 - k * 4, yy), Color(0.3, 0.35, 0.5, 0.35), 2.0)
	draw_colored_polygon(PackedVector2Array([Vector2(sx + 60, -40), Vector2(sx + 120, -40), Vector2(sx + 112, -300), Vector2(sx + 100, -420), Vector2(sx + 90, -560), Vector2(sx + 80, -420), Vector2(sx + 68, -300)]), sil)
	draw_line(Vector2(sx + 90, -560), Vector2(sx + 90, -600), sil, 3.0)
	# the giant Ferris wheel in the Prater
	var wc := Vector2(250, -250)
	var wr := 150.0
	draw_arc(wc, wr, 0, TAU, 64, sil, 4.0)
	draw_arc(wc, wr * 0.93, 0, TAU, 64, sil, 2.0)
	for k in 15:
		var a := TAU * k / 15.0 + t * 0.03
		draw_line(wc, wc + Vector2(cos(a), sin(a)) * wr, Color(sil, 0.8), 1.5)
		var g := wc + Vector2(cos(a), sin(a)) * wr
		draw_rect(Rect2(g + Vector2(-9, 2), Vector2(18, 11)), Color("2a2f4a"))
		draw_rect(Rect2(g + Vector2(-6, 4), Vector2(4, 4)), Color(1.0, 0.8, 0.45, 0.6))
	draw_line(wc, wc + Vector2(-90, 210), sil, 6.0)
	draw_line(wc, wc + Vector2(90, 210), sil, 6.0)
	draw_circle(wc, 10.0, sil)
