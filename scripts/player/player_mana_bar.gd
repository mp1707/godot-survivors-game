extends Node2D
class_name PlayerManaBar

@export var bar_width: float = 18.0
@export var bar_height: float = 2.0
@export var y_offset: float = -12.0
@export var blink_speed: float = 8.0

var _ratio: float = 1.0
var _preview_active: bool = false
var _preview_ratio: float = 0.0
var _blink_time: float = 0.0

func _ready() -> void:
	position = Vector2(0.0, y_offset)
	z_as_relative = false
	z_index = 1000
	set_process(true)

func _process(delta: float) -> void:
	if _preview_active:
		_blink_time += delta
		queue_redraw()

func set_preview(active: bool, preview_cost: int, max_mana: int) -> void:
	_preview_active = active
	_preview_ratio = clamp(float(preview_cost) / float(max_mana), 0.0, 1.0)
	if not active:
		_blink_time = 0.0
	queue_redraw()
	
func set_ratio(value: float) -> void:
	_ratio = clamp(value, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var top_left: Vector2 = Vector2(-bar_width * 0.5, 0.0)
	var fill_width: float = bar_width * _ratio

	draw_rect(Rect2(top_left, Vector2(bar_width, bar_height)), Color.BLACK)
	draw_rect(Rect2(top_left, Vector2(fill_width, bar_height)), Color.ORANGE)

	if _preview_active and fill_width > 0.0:
		var overlay_width: float = min(bar_width * _preview_ratio, fill_width)
		var overlay_x: float = top_left.x + fill_width - overlay_width
		var alpha: float = 0.45 + 0.55 * (0.5 + 0.5 * sin(_blink_time * blink_speed))
		draw_rect(Rect2(Vector2(overlay_x, top_left.y), Vector2(overlay_width, bar_height)), Color(1.0, 0.9, 0.2, alpha))
