extends Node
class_name KiChargeController

signal charge_state_changed(active: bool)
signal released()

@export var aura_sprite_path: NodePath = NodePath("../AuraSprite")
@export var charge_loop_player_path: NodePath = NodePath("../ChargeLoopPlayer")

var ki_charge_regen_per_second: float = 0.0
var ki_release_radius: float = 0.0

var _release_knockback_distance: float = 0.0
var _release_aoe_damage: int = 0

var _is_charging: bool = false
var _player: Node2D = null
var _vitals: PlayerVitals = null

@onready var _aura_sprite: AnimatedSprite2D = get_node_or_null(aura_sprite_path) as AnimatedSprite2D
@onready var _charge_loop_player: AudioStreamPlayer = get_node_or_null(charge_loop_player_path) as AudioStreamPlayer

func configure(definition: PlayerDefinition) -> void:
	ki_charge_regen_per_second = definition.ki_charge_regen_per_second
	ki_release_radius = definition.ki_release_radius

func setup(player: Node2D, vitals: PlayerVitals) -> void:
	_player = player
	_vitals = vitals
	_set_loop_playing(false)

func update(delta: float, can_charge: bool) -> bool:
	var was_charging: bool = _is_charging
	_is_charging = can_charge and Input.is_action_pressed("charging")

	if was_charging and not _is_charging and Input.is_action_just_released("charging"):
		_on_release()

	if was_charging != _is_charging:
		charge_state_changed.emit(_is_charging)

	if _is_charging:
		if _aura_sprite != null:
			_aura_sprite.visible = true
			_aura_sprite.play("default")
		_set_loop_playing(true)
		if _vitals != null:
			_vitals.regen_mana(delta, ki_charge_regen_per_second)
			_vitals.set_mana_preview(true, roundi(_vitals.get_mana()))
		return true

	if _aura_sprite != null:
		_aura_sprite.visible = false
	_set_loop_playing(false)
	return false

func force_cancel() -> void:
	if _is_charging:
		_is_charging = false
		charge_state_changed.emit(false)
	if _aura_sprite != null:
		_aura_sprite.visible = false
	_set_loop_playing(false)

func is_charging() -> bool:
	return _is_charging

func adjust_regen(delta: float, min_value: float = -INF, max_value: float = INF) -> bool:
	ki_charge_regen_per_second = _clamped_add(ki_charge_regen_per_second, delta, min_value, max_value)
	return true

func adjust_release_knockback(delta: float, min_value: float = -INF, max_value: float = INF) -> bool:
	_release_knockback_distance = _clamped_add(_release_knockback_distance, delta, min_value, max_value)
	return true

func adjust_release_aoe(delta: float, min_value: float = -INF, max_value: float = INF) -> bool:
	var next_value: float = _clamped_add(float(_release_aoe_damage), delta, min_value, max_value)
	_release_aoe_damage = int(round(next_value))
	return true

func _on_release() -> void:
	released.emit()
	if _release_knockback_distance <= 0.0 and _release_aoe_damage <= 0:
		return
	if _player == null:
		return
	for enemy: Enemy in EnemyRegistry.get_enemies_in_radius(_player.global_position, ki_release_radius):
		if _release_aoe_damage > 0:
			enemy.apply_damage(_release_aoe_damage, _player.global_position)
		if _release_knockback_distance > 0.0:
			enemy.apply_knockback(_player.global_position, _release_knockback_distance)

func _set_loop_playing(should_play: bool) -> void:
	if _charge_loop_player == null:
		return
	if should_play:
		if not _charge_loop_player.playing:
			_charge_loop_player.play()
		return
	if _charge_loop_player.playing:
		_charge_loop_player.stop()

func _clamped_add(base_value: float, delta: float, min_value: float, max_value: float) -> float:
	var result: float = base_value + delta
	if not is_inf(min_value):
		result = maxf(result, min_value)
	if not is_inf(max_value):
		result = minf(result, max_value)
	return result
