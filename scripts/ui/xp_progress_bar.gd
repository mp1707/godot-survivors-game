extends Control
class_name XPProgressBar

@onready var _fill: ColorRect = $Fill as ColorRect
var _ratio: float = 0.0

func _ready() -> void:
	_apply_ratio()

func set_ratio(value: float) -> void:
	_ratio = clampf(value, 0.0, 1.0)
	_apply_ratio()

func _apply_ratio() -> void:
	if _fill == null:
		return
	_fill.anchor_right = _ratio
