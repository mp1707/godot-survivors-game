extends Control
class_name ActionButtonBar

const LIGHT_UP_SPEED: float = 16.0
const DIM_SPEED: float = 10.0
const MAX_LIGHT_BOOST: float = 0.1
const DISABLED_PANEL_BRIGHTNESS: float = 0.55

@onready var _action_1_panel: Panel = $"ButtonRow/1Button/IconPanel" as Panel
@onready var _action_2_panel: Panel = $"ButtonRow/2Button/IconPanel" as Panel
@onready var _action_3_panel: Panel = $"ButtonRow/3Button/IconPanel" as Panel
@onready var _dash_panel: Panel = $"ButtonRow/SpaceButton/IconPanel" as Panel
@onready var _charge_panel: Panel = $"ButtonRow/RButton/IconPanel" as Panel

@onready var _action_1_icon: TextureRect = $"ButtonRow/1Button/IconPanel/CenterContainer/Icon" as TextureRect
@onready var _action_2_icon: TextureRect = $"ButtonRow/2Button/IconPanel/CenterContainer/Icon" as TextureRect
@onready var _action_3_icon: TextureRect = $"ButtonRow/3Button/IconPanel/CenterContainer/Icon" as TextureRect
@onready var _dash_icon: TextureRect = $"ButtonRow/SpaceButton/IconPanel/CenterContainer/Icon" as TextureRect
@onready var _charge_icon: TextureRect = $"ButtonRow/RButton/IconPanel/CenterContainer/Icon" as TextureRect

var _action_1_light: float = 0.0
var _action_2_light: float = 0.0
var _action_3_light: float = 0.0
var _dash_light: float = 0.0
var _charge_light: float = 0.0

var _slot_enabled: Array[bool] = [true, false, false]
var _utility_slot_enabled: Array[bool] = [false, false]
var _utility_slot_actions: Array[StringName] = [&"", &""]

func _ready() -> void:
	_center_panel_pivot(_action_1_panel)
	_center_panel_pivot(_action_2_panel)
	_center_panel_pivot(_action_3_panel)
	_center_panel_pivot(_dash_panel)
	_center_panel_pivot(_charge_panel)
	_apply_slot_icon_state(_action_1_icon, _slot_enabled[0])
	_apply_slot_icon_state(_action_2_icon, _slot_enabled[1])
	_apply_slot_icon_state(_action_3_icon, _slot_enabled[2])
	set_utility_slot(0, null, &"")
	set_utility_slot(1, null, &"")
	_apply_lighting()

func _process(delta: float) -> void:
	_action_1_light = _update_light(_action_1_light, _slot_enabled[0] and _is_action_pressed("action1"), delta)
	_action_2_light = _update_light(_action_2_light, _slot_enabled[1] and _is_action_pressed("action2"), delta)
	_action_3_light = _update_light(_action_3_light, _slot_enabled[2] and _is_action_pressed("action3"), delta)
	_dash_light = _update_light(
		_dash_light,
		_utility_slot_enabled[0] and _utility_slot_actions[0] != &"" and _is_action_pressed(_utility_slot_actions[0]),
		delta
	)
	_charge_light = _update_light(
		_charge_light,
		_utility_slot_enabled[1] and _utility_slot_actions[1] != &"" and _is_action_pressed(_utility_slot_actions[1]),
		delta
	)
	_apply_lighting()

func set_weapon_slot_icon(slot_index: int, icon: Texture2D) -> void:
	match slot_index:
		0:
			_action_1_icon.texture = icon
			_slot_enabled[0] = icon != null
			_apply_slot_icon_state(_action_1_icon, _slot_enabled[0])
		1:
			_action_2_icon.texture = icon
			_slot_enabled[1] = icon != null
			_apply_slot_icon_state(_action_2_icon, _slot_enabled[1])
		2:
			_action_3_icon.texture = icon
			_slot_enabled[2] = icon != null
			_apply_slot_icon_state(_action_3_icon, _slot_enabled[2])
		_:
			return
	_apply_lighting()

func set_dash_icon(icon: Texture2D) -> void:
	set_utility_slot(0, icon, _utility_slot_actions[0])

func set_charge_icon(icon: Texture2D) -> void:
	set_utility_slot(1, icon, _utility_slot_actions[1])

func set_utility_icons(dash_icon: Texture2D, charge_icon: Texture2D) -> void:
	set_utility_slot(0, dash_icon, _utility_slot_actions[0])
	set_utility_slot(1, charge_icon, _utility_slot_actions[1])

func set_utility_slot(slot_index: int, icon: Texture2D, action_name: StringName) -> void:
	var target_icon: TextureRect = null
	match slot_index:
		0:
			target_icon = _dash_icon
		1:
			target_icon = _charge_icon
		_:
			return
	if target_icon == null:
		return
	target_icon.texture = icon
	var is_enabled: bool = _is_valid_icon(icon)
	target_icon.visible = is_enabled
	_utility_slot_enabled[slot_index] = is_enabled
	_utility_slot_actions[slot_index] = action_name
	_apply_lighting()

func _apply_slot_icon_state(icon: TextureRect, enabled: bool) -> void:
	if icon == null:
		return
	icon.visible = enabled

func _is_valid_icon(icon: Texture2D) -> bool:
	if icon == null:
		return false
	var atlas_icon: AtlasTexture = icon as AtlasTexture
	if atlas_icon != null and atlas_icon.atlas == null:
		return false
	return true

func _is_action_pressed(action: StringName) -> bool:
	if not InputMap.has_action(action):
		return false
	return Input.is_action_pressed(action)

func _update_light(current: float, pressed: bool, delta: float) -> float:
	var target: float = 1.0 if pressed else 0.0
	var speed: float = LIGHT_UP_SPEED if pressed else DIM_SPEED
	return move_toward(current, target, speed * delta)

func _apply_lighting() -> void:
	_apply_panel_light(_action_1_panel, _action_1_light, _slot_enabled[0])
	_apply_panel_light(_action_2_panel, _action_2_light, _slot_enabled[1])
	_apply_panel_light(_action_3_panel, _action_3_light, _slot_enabled[2])
	_apply_panel_light(_dash_panel, _dash_light, _utility_slot_enabled[0])
	_apply_panel_light(_charge_panel, _charge_light, _utility_slot_enabled[1])

func _apply_panel_light(panel: Panel, amount: float, enabled: bool) -> void:
	var boost: float = amount * MAX_LIGHT_BOOST
	var base: float = 1.0 if enabled else DISABLED_PANEL_BRIGHTNESS
	panel.self_modulate = Color(base + boost, base + boost, base + (boost * 0.5), 1.0)

func _center_panel_pivot(panel: Panel) -> void:
	panel.pivot_offset = panel.custom_minimum_size * 0.5
