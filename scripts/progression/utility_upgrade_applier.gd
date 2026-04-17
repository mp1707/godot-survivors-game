extends RefCounted
class_name UtilityUpgradeApplier

const ABILITY_DASH: StringName = &"dash"
const ABILITY_CHARGE_KI: StringName = &"charge_ki"

const STAT_DASH_COOLDOWN: StringName = &"dash_cooldown"
const STAT_DASH_DISTANCE: StringName = &"dash_distance"
const STAT_DASH_INVULNERABLE: StringName = &"dash_invulnerable"
const STAT_DASH_PHASE: StringName = &"dash_phase"
const STAT_CHARGE_KI_REGEN: StringName = &"charge_ki_regen"
const STAT_CHARGE_KI_KNOCKBACK: StringName = &"charge_ki_knockback"
const STAT_CHARGE_KI_AOE_DAMAGE: StringName = &"charge_ki_aoe_damage"

const HANDLER_KIND_NUMERIC: StringName = &"numeric"
const HANDLER_KIND_SET_TRUE: StringName = &"set_true"

var _player: Player
var _handlers: Dictionary = {}

func setup(player: Player) -> void:
	_player = player
	_handlers = _build_handler_registry()

func apply_upgrade(ability_id: StringName, definition: UpgradeDefinition) -> bool:
	if _player == null or definition == null or ability_id == &"":
		return false
	if definition.ability_id != &"" and definition.ability_id != ability_id:
		push_error(
			"UtilityUpgradeApplier: upgrade '%s' does not target ability '%s'."
			% [String(definition.id), String(ability_id)]
		)
		return false
	if definition.effects.is_empty():
		push_error("UtilityUpgradeApplier: upgrade '%s' has no effects." % String(definition.id))
		return false

	var planned_calls: Array[Dictionary] = []
	if not _build_planned_calls(ability_id, definition.effects, planned_calls):
		return false
	return _execute_planned_calls(planned_calls)

func _build_handler_registry() -> Dictionary:
	var dash: DashController = _player.get_dash()
	var ki_charge: KiChargeController = _player.get_ki_charge()
	return {
		_make_handler_key(ABILITY_DASH, STAT_DASH_COOLDOWN): {
			"kind": HANDLER_KIND_NUMERIC,
			"callable": Callable(dash, "adjust_cooldown")
		},
		_make_handler_key(ABILITY_DASH, STAT_DASH_DISTANCE): {
			"kind": HANDLER_KIND_NUMERIC,
			"callable": Callable(dash, "adjust_distance")
		},
		_make_handler_key(ABILITY_DASH, STAT_DASH_INVULNERABLE): {
			"kind": HANDLER_KIND_SET_TRUE,
			"callable": Callable(dash, "unlock_invulnerable")
		},
		_make_handler_key(ABILITY_DASH, STAT_DASH_PHASE): {
			"kind": HANDLER_KIND_SET_TRUE,
			"callable": Callable(dash, "unlock_phase")
		},
		_make_handler_key(ABILITY_CHARGE_KI, STAT_CHARGE_KI_REGEN): {
			"kind": HANDLER_KIND_NUMERIC,
			"callable": Callable(ki_charge, "adjust_regen")
		},
		_make_handler_key(ABILITY_CHARGE_KI, STAT_CHARGE_KI_KNOCKBACK): {
			"kind": HANDLER_KIND_NUMERIC,
			"callable": Callable(ki_charge, "adjust_release_knockback")
		},
		_make_handler_key(ABILITY_CHARGE_KI, STAT_CHARGE_KI_AOE_DAMAGE): {
			"kind": HANDLER_KIND_NUMERIC,
			"callable": Callable(ki_charge, "adjust_release_aoe")
		}
	}

func _build_planned_calls(ability_id: StringName, effects: Array[UpgradeEffect], out_calls: Array[Dictionary]) -> bool:
	for effect: UpgradeEffect in effects:
		var planned_call: Dictionary = _build_planned_call(ability_id, effect)
		if planned_call.is_empty():
			return false
		out_calls.append(planned_call)
	return true

func _build_planned_call(ability_id: StringName, effect: UpgradeEffect) -> Dictionary:
	var empty_result: Dictionary = {}
	if effect == null:
		return empty_result
	if effect.target_domain != UpgradeEffect.TARGET_PLAYER:
		return empty_result
	if effect.stat_key == &"":
		return empty_result

	var handler: Dictionary = _handlers.get(_make_handler_key(ability_id, effect.stat_key), {}) as Dictionary
	if handler.is_empty():
		return empty_result

	var handler_kind: StringName = handler.get("kind", &"") as StringName
	var handler_callable: Callable = handler.get("callable", Callable())
	if handler_callable.is_null():
		return empty_result

	if handler_kind == HANDLER_KIND_NUMERIC:
		if effect.operation != UpgradeEffect.OP_ADD and effect.operation != UpgradeEffect.OP_CLAMP_ADD:
			return empty_result
		return {
			"callable": handler_callable,
			"args": [effect.value, effect.min_value, effect.max_value]
		}

	if handler_kind == HANDLER_KIND_SET_TRUE:
		if effect.operation != UpgradeEffect.OP_SET_TRUE:
			return empty_result
		return {
			"callable": handler_callable,
			"args": []
		}

	return empty_result

func _execute_planned_calls(planned_calls: Array[Dictionary]) -> bool:
	for planned_call: Dictionary in planned_calls:
		var handler_callable: Callable = planned_call.get("callable", Callable())
		if handler_callable.is_null():
			return false
		var args: Array = planned_call.get("args", []) as Array
		if not bool(handler_callable.callv(args)):
			return false
	return true

func _make_handler_key(ability_id: StringName, stat_key: StringName) -> StringName:
	return StringName("%s::%s" % [String(ability_id), String(stat_key)])
