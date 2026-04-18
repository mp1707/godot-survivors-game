extends RefCounted
class_name AbilityCooldownRuntime

var _progression_model: AbilityProgressionModel
var _global_cooldown_seconds: float = 1.0
var _global_cooldown_left: float = 0.0
var _global_cooldown_duration: float = 0.0
var _ability_local_cooldown_lefts: Dictionary = {}
var _ability_local_cooldown_durations: Dictionary = {}

func setup(progression_model: AbilityProgressionModel, global_cooldown_seconds: float) -> void:
	_progression_model = progression_model
	_global_cooldown_seconds = maxf(global_cooldown_seconds, 0.0)
	_global_cooldown_left = 0.0
	_global_cooldown_duration = 0.0
	_ability_local_cooldown_lefts.clear()
	_ability_local_cooldown_durations.clear()

func tick(delta: float) -> void:
	if delta <= 0.0:
		return
	if _global_cooldown_left > 0.0:
		_global_cooldown_left = maxf(_global_cooldown_left - delta, 0.0)
	var ability_ids: Array = _ability_local_cooldown_lefts.keys()
	for ability_id_variant: Variant in ability_ids:
		var ability_id: StringName = ability_id_variant as StringName
		var remaining: float = float(_ability_local_cooldown_lefts.get(ability_id, 0.0))
		if remaining <= 0.0:
			continue
		var next_remaining: float = maxf(remaining - delta, 0.0)
		_ability_local_cooldown_lefts[ability_id] = next_remaining

func can_activate(ability_id: StringName) -> bool:
	if ability_id == &"":
		return false
	return get_effective_remaining(ability_id) <= 0.0

func commit_activation(ability_id: StringName) -> bool:
	if ability_id == &"":
		return false
	_global_cooldown_left = _global_cooldown_seconds
	_global_cooldown_duration = _global_cooldown_seconds
	var local_cooldown: float = _get_local_cooldown_seconds(ability_id)
	if local_cooldown > 0.0:
		_ability_local_cooldown_lefts[ability_id] = local_cooldown
		_ability_local_cooldown_durations[ability_id] = local_cooldown
	return true

func get_effective_remaining(ability_id: StringName) -> float:
	if ability_id == &"":
		return 0.0
	var local_remaining: float = float(_ability_local_cooldown_lefts.get(ability_id, 0.0))
	return maxf(_global_cooldown_left, local_remaining)

func get_effective_ratio(ability_id: StringName) -> float:
	if ability_id == &"":
		return 0.0
	var local_remaining: float = float(_ability_local_cooldown_lefts.get(ability_id, 0.0))
	var local_duration: float = float(_ability_local_cooldown_durations.get(ability_id, 0.0))
	if local_remaining >= _global_cooldown_left and local_duration > 0.0:
		return clampf(local_remaining / local_duration, 0.0, 1.0)
	if _global_cooldown_duration > 0.0:
		return clampf(_global_cooldown_left / _global_cooldown_duration, 0.0, 1.0)
	return 0.0

func _get_local_cooldown_seconds(ability_id: StringName) -> float:
	if _progression_model == null:
		return 0.0
	return maxf(_progression_model.get_ability_base_cooldown(ability_id), 0.0)
