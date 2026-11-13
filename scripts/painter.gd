extends Node2D
## A static drawing node. The world hands it a Callable that receives this
## CanvasItem; it is drawn once (and again only when queue_redraw() is called).

var paint: Callable


func _draw() -> void:
	if paint.is_valid():
		paint.call(self)
