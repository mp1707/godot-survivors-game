extends Control
class_name ActionButtonBar

const LIGHT_UP_SPEED: float = 16.0
const DIM_SPEED: float = 10.0
const MAX_LIGHT_BOOST: float = 0.1

@onready var _e_panel: Panel = $ButtonRow/EButton/IconPanel as Panel
@onready var _q_panel: Panel = $ButtonRow/QButton/IconPanel as Panel
@onready var _f_panel: Panel = $ButtonRow/FButton/IconPanel as Panel
@onready var _space_panel: Panel = $ButtonRow/SpaceButton/IconPanel as Panel
@onready var _r_panel: Panel = $ButtonRow/RButton/IconPanel as Panel

var _e_light: float = 0.0
var _q_light: float = 0.0
var _f_light: float = 0.0
var _space_light: float = 0.0
var _r_light: float = 0.0

func _ready() -> void:
	_center_panel_pivot(_e_panel)
	_center_panel_pivot(_q_panel)
	_center_panel_pivot(_f_panel)
	_center_panel_pivot(_space_panel)
	_center_panel_pivot(_r_panel)
	_apply_lighting()

func _process(delta: float) -> void:
	_e_light = _update_light(_e_light, Input.is_physical_key_pressed(KEY_E), delta)
	_q_light = _update_light(_q_light, Input.is_physical_key_pressed(KEY_Q), delta)
	_f_light = _update_light(_f_light, Input.is_physical_key_pressed(KEY_F), delta)
	_space_light = _update_light(_space_light, Input.is_physical_key_pressed(KEY_SPACE), delta)
	_r_light = _update_light(_r_light, Input.is_physical_key_pressed(KEY_R), delta)
	_apply_lighting()

func _update_light(current: float, pressed: bool, delta: float) -> float:
	var target: float = 1.0 if pressed else 0.0
	var speed: float = LIGHT_UP_SPEED if pressed else DIM_SPEED
	return move_toward(current, target, speed * delta)

func _apply_lighting() -> void:
	_apply_panel_light(_e_panel, _e_light)
	_apply_panel_light(_q_panel, _q_light)
	_apply_panel_light(_f_panel, _f_light)
	_apply_panel_light(_space_panel, _space_light)
	_apply_panel_light(_r_panel, _r_light)

func _apply_panel_light(panel: Panel, amount: float) -> void:
	var boost: float = amount * MAX_LIGHT_BOOST
	panel.self_modulate = Color(1.0 + boost, 1.0 + boost, 1.0 + (boost * 0.5), 1.0)

func _center_panel_pivot(panel: Panel) -> void:
	panel.pivot_offset = panel.custom_minimum_size * 0.5
