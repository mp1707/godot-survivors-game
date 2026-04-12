extends Node2D
class_name PlayerHealthBar

@export var bar_width: float = 18.0
@export var bar_height: float = 2.0
@export var y_offset: float = -12.0

var _ratio: float = 1.0

func _ready() -> void:
	position = Vector2(0.0, y_offset)
	z_as_relative = false
	z_index = 1000
	visible = false

func set_ratio(value: float) -> void:
	_ratio = clamp(value, 0.0, 1.0)
	visible = _ratio < 0.999
	queue_redraw()

func _draw() -> void:
	var top_left: Vector2 = Vector2(-bar_width * 0.5, 0.0)
	draw_rect(Rect2(top_left, Vector2(bar_width, bar_height)), Color.BLACK)
	draw_rect(Rect2(top_left, Vector2(bar_width * _ratio, bar_height)), Color.RED)
