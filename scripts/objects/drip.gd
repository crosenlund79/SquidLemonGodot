extends Node2D
## A leaky pipe joint. Standing under the drips keeps Otto moist.

var world: Node2D
var floor_y := 0.0
var drops: Array = []
var timer := 0.0


func refill_at(p: Vector2) -> float:
	if absf(p.x - global_position.x) < 18.0 and p.y > global_position.y and p.y < floor_y + 4.0:
		return 28.0
	return 0.0


func _process(dt: float) -> void:
	timer -= dt
	if timer <= 0.0:
		timer = randf_range(0.35, 0.6)
		drops.append({"y": 6.0, "v": 0.0})
	var fall := floor_y - global_position.y
	var i := drops.size() - 1
	while i >= 0:
		var d: Dictionary = drops[i]
		d["v"] += 1500.0 * dt
		d["y"] += d["v"] * dt
		if d["y"] >= fall:
			drops.remove_at(i)
			if world.fx:
				world.fx.burst(Vector2(global_position.x, floor_y - 2.0), 3, 90.0, Color(0.7, 0.9, 1.0, 0.7), 0.3, 1.8, 600.0, -PI / 2, 2.0)
			if randf() < 0.25:
				Audio.play_at("drip", Vector2(global_position.x, floor_y), -14.0, 1.0, 0.2, 600.0)
		i -= 1
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2(0, 4), 3.0, Color(0.7, 0.9, 1.0, 0.8))
	for d in drops:
		var y: float = d["y"]
		draw_colored_polygon(PackedVector2Array([Vector2(0, y - 5), Vector2(2.4, y), Vector2(0, y + 2.6), Vector2(-2.4, y)]), Color(0.7, 0.9, 1.0, 0.85))
	var fy := floor_y - global_position.y
	draw_rect(Rect2(-20, fy - 3, 40, 3), Color(0.3, 0.45, 0.55, 0.5))
