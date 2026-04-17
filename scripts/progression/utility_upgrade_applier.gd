extends RefCounted
class_name UtilityUpgradeApplier

const STAT_DASH_COOLDOWN: StringName = &"dash_cooldown"
const STAT_DASH_DISTANCE: StringName = &"dash_distance"
const STAT_DASH_INVULNERABLE: StringName = &"dash_invulnerable"
const STAT_DASH_PHASE: StringName = &"dash_phase"
const STAT_CHARGE_KI_REGEN: StringName = &"charge_ki_regen"
const STAT_CHARGE_KI_KNOCKBACK: StringName = &"charge_ki_knockback"
const STAT_CHARGE_KI_AOE_DAMAGE: StringName = &"charge_ki_aoe_damage"

var _player: Player

func setup(player: Player) -> void:
	_player = player

func apply_upgrade(definition: UpgradeDefinition) -> bool:
	if _player == null or definition == null:
		return false

	if not definition.effects.is_empty():
		for effect: UpgradeEffect in definition.effects:
			if not _apply_effect(effect):
				return false
		return true

	return _apply_legacy_upgrade(definition)

func _apply_effect(effect: UpgradeEffect) -> bool:
	if effect == null:
		return false
	if effect.target_domain != UpgradeEffect.TARGET_PLAYER:
		return false

	match effect.stat_key:
		STAT_DASH_COOLDOWN:
			if effect.operation != UpgradeEffect.OP_ADD and effect.operation != UpgradeEffect.OP_CLAMP_ADD:
				return false
			return _player.adjust_dash_cooldown(effect.value, effect.min_value, effect.max_value)
		STAT_DASH_DISTANCE:
			if effect.operation != UpgradeEffect.OP_ADD and effect.operation != UpgradeEffect.OP_CLAMP_ADD:
				return false
			return _player.adjust_dash_distance(effect.value, effect.min_value, effect.max_value)
		STAT_DASH_INVULNERABLE:
			if effect.operation != UpgradeEffect.OP_SET_TRUE:
				return false
			return _player.unlock_dash_invulnerable()
		STAT_DASH_PHASE:
			if effect.operation != UpgradeEffect.OP_SET_TRUE:
				return false
			return _player.unlock_dash_phase()
		STAT_CHARGE_KI_REGEN:
			if effect.operation != UpgradeEffect.OP_ADD and effect.operation != UpgradeEffect.OP_CLAMP_ADD:
				return false
			return _player.adjust_charge_ki_regen(effect.value, effect.min_value, effect.max_value)
		STAT_CHARGE_KI_KNOCKBACK:
			if effect.operation != UpgradeEffect.OP_ADD and effect.operation != UpgradeEffect.OP_CLAMP_ADD:
				return false
			return _player.adjust_ki_release_knockback(effect.value, effect.min_value, effect.max_value)
		STAT_CHARGE_KI_AOE_DAMAGE:
			if effect.operation != UpgradeEffect.OP_ADD and effect.operation != UpgradeEffect.OP_CLAMP_ADD:
				return false
			return _player.adjust_ki_release_aoe_damage(effect.value, effect.min_value, effect.max_value)
		_:
			return false

func _apply_legacy_upgrade(definition: UpgradeDefinition) -> bool:
	match definition.id:
		STAT_DASH_COOLDOWN:
			return _player.adjust_dash_cooldown(definition.numeric_value, definition.min_clamp, definition.max_clamp)
		STAT_DASH_DISTANCE:
			return _player.adjust_dash_distance(definition.numeric_value, definition.min_clamp, definition.max_clamp)
		STAT_DASH_INVULNERABLE:
			return _player.unlock_dash_invulnerable()
		STAT_DASH_PHASE:
			return _player.unlock_dash_phase()
		STAT_CHARGE_KI_REGEN:
			return _player.adjust_charge_ki_regen(definition.numeric_value, definition.min_clamp, definition.max_clamp)
		STAT_CHARGE_KI_KNOCKBACK:
			return _player.adjust_ki_release_knockback(definition.numeric_value, definition.min_clamp, definition.max_clamp)
		STAT_CHARGE_KI_AOE_DAMAGE:
			return _player.adjust_ki_release_aoe_damage(definition.numeric_value, definition.min_clamp, definition.max_clamp)
		_:
			return false
