@tool
extends Control
## Draw a centered tetromino in an authored hold or next-piece slot.
@export var cells: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]:
	set(value):
		cells = value
		queue_redraw()
@export var tint: Color = Color("#b49afa")
@export var cell_size: float = 24.0

func _draw() -> void:
	if cells.is_empty():
		return
	var center: Vector2 = Vector2.ZERO
	for cell: Vector2i in cells:
		center += Vector2(cell)
	center /= cells.size()
	for cell: Vector2i in cells:
		var point: Vector2 = size * 0.5 + (Vector2(cell) - center - Vector2(0.5, 0.5)) * cell_size
		draw_rect(Rect2(point, Vector2.ONE * (cell_size - 2.0)), tint)
