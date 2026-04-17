extends RefCounted
class_name WeaponUpgradeApplier

func apply_upgrade(state: WeaponAbilityState, definition: UpgradeDefinition) -> bool:
	if state == null or definition == null:
		return false
	if definition.effects.is_empty():
		push_error("WeaponUpgradeApplier: upgrade '%s' has no effects." % String(definition.id))
		return false
	var planned_assignments: Array[Dictionary] = []
	if not _build_planned_assignments(state, definition.effects, planned_assignments):
		return false
	_commit_assignments(state, planned_assignments)
	return true

func get_stack_count_for_upgrade(state: WeaponAbilityState, definition: UpgradeDefinition) -> int:
	if state == null or definition == null:
		return 0
	if definition.effects.is_empty():
		return 0
	return _stack_count_from_effects(state, definition.effects)

func _build_planned_assignments(
	state: WeaponAbilityState,
	effects: Array[UpgradeEffect],
	out_assignments: Array[Dictionary]
) -> bool:
	for effect: UpgradeEffect in effects:
		var assignment: Dictionary = _build_assignment(state, effect)
		if assignment.is_empty():
			return false
		out_assignments.append(assignment)
	return true

func _commit_assignments(state: WeaponAbilityState, assignments: Array[Dictionary]) -> void:
	for assignment: Dictionary in assignments:
		var key: String = assignment.get("key", "")
		if key.is_empty():
			continue
		state.set(key, assignment.get("value"))

func _build_assignment(state: WeaponAbilityState, effect: UpgradeEffect) -> Dictionary:
	var empty_result: Dictionary = {}
	if effect == null:
		return empty_result
	if effect.target_domain != UpgradeEffect.TARGET_WEAPON_STATE:
		return empty_result
	if effect.stat_key == &"":
		return empty_result

	var key: String = String(effect.stat_key)
	var current: Variant = state.get(key)
	if current == null:
		return empty_result

	match effect.operation:
		UpgradeEffect.OP_ADD, UpgradeEffect.OP_CLAMP_ADD:
			return _build_numeric_assignment(key, current, current + effect.value, effect)
		UpgradeEffect.OP_MULTIPLY:
			return _build_numeric_assignment(key, current, float(current) * effect.value, effect)
		UpgradeEffect.OP_SET_TRUE:
			if typeof(current) != TYPE_BOOL:
				return empty_result
			return {"key": key, "value": true}
		UpgradeEffect.OP_SET_VALUE:
			return _build_numeric_assignment(key, current, effect.value, effect)
		_:
			return empty_result

func _build_numeric_assignment(
	key: String,
	current: Variant,
	proposed_value: float,
	effect: UpgradeEffect
) -> Dictionary:
	var empty_result: Dictionary = {}
	var clamped: float = _apply_optional_clamp(proposed_value, effect)
	match typeof(current):
		TYPE_INT:
			return {"key": key, "value": int(round(clamped))}
		TYPE_FLOAT:
			return {"key": key, "value": clamped}
		_:
			return empty_result

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
