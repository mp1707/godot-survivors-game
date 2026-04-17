extends RefCounted
class_name WeaponUpgradeApplier

func apply_upgrade(state: WeaponAbilityState, definition: UpgradeDefinition, fallback_upgrade_id: StringName) -> bool:
	if state == null:
		return false
	if definition != null and not definition.effects.is_empty():
		return _apply_effects(state, definition.effects)
	return _apply_legacy_upgrade(state, _resolve_upgrade_type(definition, fallback_upgrade_id))

func get_stack_count_for_upgrade(state: WeaponAbilityState, definition: UpgradeDefinition, fallback_upgrade_id: StringName) -> int:
	if state == null:
		return 0
	if definition != null and not definition.effects.is_empty():
		return _stack_count_from_effects(state, definition.effects)
	return _legacy_stack_count(state, _resolve_upgrade_type(definition, fallback_upgrade_id))

func _apply_effects(state: WeaponAbilityState, effects: Array[UpgradeEffect]) -> bool:
	for effect: UpgradeEffect in effects:
		if not _apply_effect(state, effect):
			return false
	return true

func _apply_effect(state: WeaponAbilityState, effect: UpgradeEffect) -> bool:
	if effect == null:
		return false
	if effect.target_domain != UpgradeEffect.TARGET_WEAPON_STATE:
		return false
	if effect.stat_key == &"":
		return false

	var key: String = String(effect.stat_key)
	var current: Variant = state.get(key)
	if current == null:
		return false

	match effect.operation:
		UpgradeEffect.OP_ADD, UpgradeEffect.OP_CLAMP_ADD:
			return _apply_numeric(state, key, current, current + effect.value, effect)
		UpgradeEffect.OP_MULTIPLY:
			return _apply_numeric(state, key, current, float(current) * effect.value, effect)
		UpgradeEffect.OP_SET_TRUE:
			if typeof(current) != TYPE_BOOL:
				return false
			state.set(key, true)
			return true
		UpgradeEffect.OP_SET_VALUE:
			return _apply_numeric(state, key, current, effect.value, effect)
		_:
			return false

func _apply_numeric(state: WeaponAbilityState, key: String, current: Variant, proposed_value: float, effect: UpgradeEffect) -> bool:
	var clamped: float = _apply_optional_clamp(proposed_value, effect)
	match typeof(current):
		TYPE_INT:
			state.set(key, int(round(clamped)))
			return true
		TYPE_FLOAT:
			state.set(key, clamped)
			return true
		_:
			return false

func _apply_optional_clamp(value: float, effect: UpgradeEffect) -> float:
	var result: float = value
	if not is_inf(effect.min_value):
		result = maxf(result, effect.min_value)
	if not is_inf(effect.max_value):
		result = minf(result, effect.max_value)
	return result

func _stack_count_from_effects(state: WeaponAbilityState, effects: Array[UpgradeEffect]) -> int:
	for effect: UpgradeEffect in effects:
		if effect == null:
			continue
		if effect.target_domain != UpgradeEffect.TARGET_WEAPON_STATE:
			continue
		if effect.stat_key == &"":
			continue
		var key: String = String(effect.stat_key)
		var current: Variant = state.get(key)
		match typeof(current):
			TYPE_BOOL:
				return 1 if current else 0
			TYPE_INT:
				return maxi(int(current), 0)
			TYPE_FLOAT:
				return maxi(int(round(float(current))), 0)
	return 0

func _apply_legacy_upgrade(state: WeaponAbilityState, upgrade_type: StringName) -> bool:
	match upgrade_type:
		&"cost":
			state.cost_upgrade_count += 1
		&"damage":
			state.damage_upgrade_count += 1
		&"pierce":
			state.pierce_upgrade_count += 1
		&"speed":
			state.speed_upgrade_count += 1
		&"bounce":
			state.bounce_upgrade_count += 1
		&"size":
			state.size_upgrade_count += 1
		&"absorb":
			state.barrier_absorb_upgrade_count += 1
		&"lifetime":
			state.barrier_lifetime_upgrade_count += 1
		&"reflect":
			state.barrier_reflect_unlocked = true
		&"charge_speed":
			state.charge_speed_upgrade_count += 1
		_:
			return false
	return true

func _legacy_stack_count(state: WeaponAbilityState, upgrade_type: StringName) -> int:
	match upgrade_type:
		&"cost":
			return state.cost_upgrade_count
		&"damage":
			return state.damage_upgrade_count
		&"pierce":
			return state.pierce_upgrade_count
		&"speed":
			return state.speed_upgrade_count
		&"bounce":
			return state.bounce_upgrade_count
		&"size":
			return state.size_upgrade_count
		&"absorb":
			return state.barrier_absorb_upgrade_count
		&"lifetime":
			return state.barrier_lifetime_upgrade_count
		&"reflect":
			return 1 if state.barrier_reflect_unlocked else 0
		&"charge_speed":
			return state.charge_speed_upgrade_count
		_:
			return 0

func _resolve_upgrade_type(definition: UpgradeDefinition, fallback_upgrade_id: StringName) -> StringName:
	if definition != null and definition.upgrade_type != &"":
		return definition.upgrade_type
	return fallback_upgrade_id
