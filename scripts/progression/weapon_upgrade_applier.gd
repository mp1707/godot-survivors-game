extends RefCounted
class_name WeaponUpgradeApplier

func apply_upgrade(state: WeaponAbilityState, definition: UpgradeDefinition) -> bool:
	if state == null or definition == null:
		return false
	if definition.effects.is_empty():
		push_error("WeaponUpgradeApplier: upgrade '%s' has no effects." % String(definition.id))
		return false
	return _apply_effects(state, definition.effects)

func get_stack_count_for_upgrade(state: WeaponAbilityState, definition: UpgradeDefinition) -> int:
	if state == null or definition == null:
		return 0
	if definition.effects.is_empty():
		return 0
	return _stack_count_from_effects(state, definition.effects)

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
