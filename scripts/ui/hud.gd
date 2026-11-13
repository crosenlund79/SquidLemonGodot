extends CanvasLayer
## Moisture meter, ink, chestnuts, timer, altimeter, storey banners and toasts.

const Art = preload("res://scripts/art.gd")

var world: Node2D
var ctrl: Control
var show_hud := false
var dialog_open := false
var banner_k := -1
var banner_t := 0.0
var toasts: Array = []
var t := 0.0
var shown_m := 100.0


func _ready() -> void:
	layer = 10
	ctrl = Control.new()
	ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ctrl)
	ctrl.draw.connect(_draw_hud)


func banner(k: int) -> void:
	banner_k = k
	banner_t = 3.4


func toast(s: String) -> void:
	for q in toasts:
		if q["s"] == s:
			return
	toasts.append({"s": s, "t": 6.0})
	if toasts.size() > 2:
		toasts.pop_front()
	Audio.play("ui_move", -10.0)


func _process(dt: float) -> void:
	t += dt
	banner_t = maxf(0.0, banner_t - dt)
	if not dialog_open:
		for q in toasts:
			q["t"] -= dt
	toasts = toasts.filter(func(q): return q["t"] > 0.0)
	ctrl.queue_redraw()


func _draw_hud() -> void:
	if not show_hud or world == null or world.player == null:
		return
	var vs := ctrl.size
	var pl = world.player
	var f := Art.font()
	# --- moisture
	shown_m = lerpf(shown_m, pl.moisture, 0.15)
	var low: bool = pl.moisture < 25.0
	var base := Vector2(28, 26)
	Art.rrect(ctrl, Rect2(base - Vector2(12, 10), Vector2(330, 62)), Color(0.04, 0.06, 0.09, 0.62), 12)
	var dc := Color("5fc3ff") if not (low and int(t * 4.0) % 2 == 0) else Color("ff6a4a")
	ctrl.draw_circle(base + Vector2(14, 26), 11.0, dc)
	ctrl.draw_colored_polygon(PackedVector2Array([base + Vector2(4, 22), base + Vector2(24, 22), base + Vector2(14, 4)]), dc)
	ctrl.draw_circle(base + Vector2(10, 24), 3.0, Color(1, 1, 1, 0.6))
	var bar := Rect2(base + Vector2(36, 14), Vector2(230, 20))
	Art.rrect(ctrl, bar, Color(0.1, 0.12, 0.16, 0.9), 8)
	var fw := bar.size.x * clampf(shown_m / 100.0, 0.0, 1.0)
	if fw > 4.0:
		var fc := Color("3aa0e8").lerp(Color("e8603a"), clampf((40.0 - shown_m) / 40.0, 0.0, 1.0))
		Art.rrect(ctrl, Rect2(bar.position, Vector2(fw, bar.size.y)), fc, 8)
		ctrl.draw_rect(Rect2(bar.position + Vector2(6, 3), Vector2(maxf(0.0, fw - 12.0), 4)), Color(1, 1, 1, 0.25))
	ctrl.draw_string(f, base + Vector2(38, 10), "MOISTURE", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(0.8, 0.9, 1.0, 0.75))
	# ink
	var ic := base + Vector2(290, 24)
	if pl.ink > 0:
		ctrl.draw_circle(ic, 9.0, Color("2b1d3c"))
		ctrl.draw_circle(ic + Vector2(-6, 5), 5.0, Color("2b1d3c"))
		ctrl.draw_circle(ic + Vector2(-3, -3), 2.5, Color(1, 1, 1, 0.5))
	else:
		ctrl.draw_arc(ic, 9.0, 0, TAU, 18, Color(0.6, 0.5, 0.8, 0.5), 2.0)
	ctrl.draw_string(f, ic + Vector2(-14, -14), "INK", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.8, 0.75, 1.0, 0.7))
	# --- chestnuts + time (top right)
	var tr := Vector2(vs.x - 210, 16)
	Art.rrect(ctrl, Rect2(tr, Vector2(186, 66)), Color(0.04, 0.06, 0.09, 0.62), 12)
	Art.kastanie(ctrl, tr + Vector2(26, 24), 1.2)
	ctrl.draw_string(f, tr + Vector2(46, 32), "%d / %d" % [Game.kastanien.size(), Game.kastanien_total], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffd9a0"))
	ctrl.draw_string(f, tr + Vector2(16, 56), Game.format_time(Game.run_time), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0.85, 0.9, 1.0, 0.8))
	# --- altimeter
	var ax := vs.x - 30.0
	var ay0 := 110.0
	var ay1 := vs.y - 120.0
	ctrl.draw_line(Vector2(ax, ay0), Vector2(ax, ay1), Color(1, 1, 1, 0.25), 3.0)
	var top_y := -900.0
	var bot_y := 3700.0
	for k in range(0, 7):
		var wy := 560.0 * k
		var sy := lerpf(ay0, ay1, (wy - top_y) / (bot_y - top_y))
		ctrl.draw_line(Vector2(ax - 7, sy), Vector2(ax + 7, sy), Art.LEVEL_COLORS[k], 3.0)
		ctrl.draw_string(f, Vector2(ax - 34, sy + 5), "0" if k == 0 else "−%d" % k, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(Art.LEVEL_COLORS[k], 0.85))
	Art.lemon(ctrl, Vector2(ax, ay0 - 14), 0.0, 0.55)
	var py: float = lerpf(ay0, ay1, clampf((pl.global_position.y - top_y) / (bot_y - top_y), 0.0, 1.0))
	ctrl.draw_circle(Vector2(ax, py), 7.0, Art.OCTO)
	ctrl.draw_circle(Vector2(ax - 2.5, py + 1), 1.6, Color.WHITE)
	ctrl.draw_circle(Vector2(ax + 2.5, py + 1), 1.6, Color.WHITE)
	# --- storey banner
	if banner_t > 0.0 and banner_k >= 0:
		var a := clampf(banner_t, 0.0, 1.0) * clampf((3.4 - banner_t) * 3.0, 0.0, 1.0)
		var lc: Color = Art.LEVEL_COLORS[banner_k]
		var cx := vs.x * 0.5
		Art.text_outline(ctrl, Vector2(cx, 150), Art.LEVEL_NAMES[banner_k], 54, Color(1, 1, 1, a), Color(0, 0, 0, a * 0.6), 8)
		ctrl.draw_rect(Rect2(cx - 160, 166, 320, 6), Color(lc, a))
		Art.text_outline(ctrl, Vector2(cx, 200), Art.LEVEL_SUBTITLES[banner_k], 20, Color(lc.lightened(0.3), a), Color(0, 0, 0, a * 0.6), 5)
	# --- toasts
	var ty := vs.y - 54.0
	for i in range(toasts.size() - 1, -1, -1):
		var q: Dictionary = toasts[i]
		var s: String = q["s"]
		var qa: float = clampf(q["t"], 0.0, 1.0) * clampf((6.0 - q["t"]) * 4.0, 0.0, 1.0)
		var sz := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18)
		var r := Rect2(Vector2(vs.x * 0.5 - sz.x * 0.5 - 18, ty - 28), Vector2(sz.x + 36, 40))
		Art.rrect(ctrl, r, Color(0.05, 0.07, 0.1, 0.8 * qa), 10, 2, Color(1.0, 0.85, 0.5, 0.5 * qa))
		ctrl.draw_string(f, Vector2(r.position.x + 18, ty - 1), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(1, 0.96, 0.88, qa))
		ty -= 48.0
