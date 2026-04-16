extends Control
class_name ActionButtonBar

const LIGHT_UP_SPEED: float = 16.0
const DIM_SPEED: float = 10.0
const MAX_LIGHT_BOOST: float = 0.1

@onready var _action_1_panel: Panel = $"ButtonRow/1Button/IconPanel" as Panel
@onready var _action_2_panel: Panel = $"ButtonRow/2Button/IconPanel" as Panel
@onready var _action_3_panel: Panel = $"ButtonRow/3Button/IconPanel" as Panel
@onready var _dash_panel: Panel = $"ButtonRow/SpaceButton/IconPanel" as Panel
@onready var _charge_panel: Panel = $"ButtonRow/RButton/IconPanel" as Panel

var _action_1_light: float = 0.0
var _action_2_light: float = 0.0
var _action_3_light: float = 0.0
var _dash_light: float = 0.0
var _charge_light: float = 0.0

func _ready() -> void:
	_center_panel_pivot(_action_1_panel)
	_center_panel_pivot(_action_2_panel)
	_center_panel_pivot(_action_3_panel)
	_center_panel_pivot(_dash_panel)
	_center_panel_pivot(_charge_panel)
	_apply_lighting()

func _process(delta: float) -> void:
	_action_1_light = _update_light(_action_1_light, _is_action_pressed("action1"), delta)
	_action_2_light = _update_light(_action_2_light, _is_action_pressed("action2"), delta)
	_action_3_light = _update_light(_action_3_light, _is_action_pressed("action3"), delta)
	_dash_light = _update_light(_dash_light, _is_action_pressed("dash"), delta)
	_charge_light = _update_light(_charge_light, _is_action_pressed("charging"), delta)
	_apply_lighting()

func _is_action_pressed(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	return Input.is_action_pressed(action)

func _update_light(current: float, pressed: bool, delta: float) -> float:
	var target: float = 1.0 if pressed else 0.0
	var speed: float = LIGHT_UP_SPEED if pressed else DIM_SPEED
	return move_toward(current, target, speed * delta)

func _apply_lighting() -> void:
	_apply_panel_light(_action_1_panel, _action_1_light)
	_apply_panel_light(_action_2_panel, _action_2_light)
	_apply_panel_light(_action_3_panel, _action_3_light)
	_apply_panel_light(_dash_panel, _dash_light)
	_apply_panel_light(_charge_panel, _charge_light)

func _apply_panel_light(panel: Panel, amount: float) -> void:
	var boost: float = amount * MAX_LIGHT_BOOST
	panel.self_modulate = Color(1.0 + boost, 1.0 + boost, 1.0 + (boost * 0.5), 1.0)

func _center_panel_pivot(panel: Panel) -> void:
	panel.pivot_offset = panel.custom_minimum_size * 0.5
