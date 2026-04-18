extends Resource
class_name ProgressionCatalog

@export var abilities: Array[AbilityDefinition] = []
@export var upgrades: Array[UpgradeDefinition] = []

var _last_validation_errors: PackedStringArray = PackedStringArray()

func validate() -> bool:
	_last_validation_errors = PackedStringArray()

	var ability_ids: Dictionary = {}
	var upgrade_ids: Dictionary = {}
	var utility_slot_indices: Dictionary = {}

	for ability: AbilityDefinition in abilities:
		if ability == null:
			_record_error("ProgressionCatalog: null ability entry.")
			continue
		if ability.id == &"":
			_record_error("ProgressionCatalog: ability with empty id.")
			continue
		if ability_ids.has(ability.id):
			_record_error("ProgressionCatalog: duplicate ability id '%s'." % String(ability.id))
			continue
		ability_ids[ability.id] = ability
		_validate_ability_icons(ability)
		_validate_ability_activation(ability, utility_slot_indices)
		_validate_ability_cooldown(ability)

	for upgrade: UpgradeDefinition in upgrades:
		if upgrade == null:
			_record_error("ProgressionCatalog: null upgrade entry.")
			continue
		if upgrade.id == &"":
			_record_error("ProgressionCatalog: upgrade with empty id.")
			continue
		if upgrade_ids.has(upgrade.id):
			_record_error("ProgressionCatalog: duplicate upgrade id '%s'." % String(upgrade.id))
			continue
		upgrade_ids[upgrade.id] = upgrade

	for ability: AbilityDefinition in abilities:
		if ability == null or ability.id == &"":
			continue
		for upgrade_id: StringName in ability.upgrade_ids:
			if upgrade_id == &"":
				_record_error("ProgressionCatalog: ability '%s' references empty upgrade id." % String(ability.id))
				continue
			if not upgrade_ids.has(upgrade_id):
				_record_error(
					"ProgressionCatalog: ability '%s' references unknown upgrade '%s'."
					% [String(ability.id), String(upgrade_id)]
				)
				continue
			var definition: UpgradeDefinition = upgrade_ids[upgrade_id] as UpgradeDefinition
			if definition == null:
				_record_error(
					"ProgressionCatalog: ability '%s' references invalid upgrade '%s'."
					% [String(ability.id), String(upgrade_id)]
				)
				continue
			_validate_ability_upgrade_link(ability, definition)

	return _last_validation_errors.is_empty()

func get_validation_errors() -> PackedStringArray:
	return _last_validation_errors.duplicate()

func _record_error(message: String) -> void:
	_last_validation_errors.append(message)
	push_error(message)

func _validate_ability_icons(ability: AbilityDefinition) -> void:
	if ability.display_name.strip_edges().is_empty():
		_record_error("ProgressionCatalog: ability '%s' has empty display_name." % String(ability.id))
	if not ProgressionCatalog.is_valid_icon(ability.action_bar_icon):
		_record_error("ProgressionCatalog: ability '%s' has invalid action_bar_icon." % String(ability.id))
	if not ProgressionCatalog.is_valid_icon(ability.upgrade_icon):
		_record_error("ProgressionCatalog: ability '%s' has invalid upgrade_icon." % String(ability.id))

func _validate_ability_activation(ability: AbilityDefinition, utility_slot_indices: Dictionary) -> void:
	if ability.activation_channel == AbilityDefinition.ACTIVATION_CHANNEL_WEAPON_SLOT:
		return
	if ability.activation_channel != AbilityDefinition.ACTIVATION_CHANNEL_UTILITY:
		_record_error(
			"ProgressionCatalog: ability '%s' has invalid activation_channel '%s'."
			% [String(ability.id), String(ability.activation_channel)]
		)
		return
	if ability.utility_slot_index < 0:
		_record_error("ProgressionCatalog: utility ability '%s' has invalid utility_slot_index." % String(ability.id))
	else:
		if utility_slot_indices.has(ability.utility_slot_index):
			_record_error(
				"ProgressionCatalog: utility slot %d used by '%s' and '%s'."
				% [ability.utility_slot_index, String(utility_slot_indices[ability.utility_slot_index]), String(ability.id)]
			)
		else:
			utility_slot_indices[ability.utility_slot_index] = ability.id
	if ability.input_action == &"":
		_record_error("ProgressionCatalog: utility ability '%s' has empty input_action." % String(ability.id))
	elif not InputMap.has_action(ability.input_action):
		_record_error(
			"ProgressionCatalog: utility ability '%s' references unknown input action '%s'."
			% [String(ability.id), String(ability.input_action)]
		)

func _validate_ability_cooldown(ability: AbilityDefinition) -> void:
	if ability.base_cooldown_seconds < 0.0:
		_record_error(
			"ProgressionCatalog: ability '%s' has invalid base_cooldown_seconds %.3f."
			% [String(ability.id), ability.base_cooldown_seconds]
		)

func _validate_ability_upgrade_link(ability: AbilityDefinition, definition: UpgradeDefinition) -> void:
	if ability.activation_channel == AbilityDefinition.ACTIVATION_CHANNEL_UTILITY:
		if definition.get_domain() != UpgradeDefinition.DOMAIN_UTILITY:
			_record_error(
				"ProgressionCatalog: utility ability '%s' references non-utility upgrade '%s'."
				% [String(ability.id), String(definition.id)]
			)
		if definition.ability_id != ability.id:
			_record_error(
				"ProgressionCatalog: utility ability '%s' requires ability-bound upgrade '%s'."
				% [String(ability.id), String(definition.id)]
			)
		return

	if definition.get_domain() != UpgradeDefinition.DOMAIN_WEAPON:
		_record_error(
			"ProgressionCatalog: weapon ability '%s' references non-weapon upgrade '%s'."
			% [String(ability.id), String(definition.id)]
		)
	if definition.ability_id != &"" and definition.ability_id != ability.id:
		_record_error(
			"ProgressionCatalog: weapon ability '%s' references upgrade '%s' bound to '%s'."
			% [String(ability.id), String(definition.id), String(definition.ability_id)]
		)

static func is_valid_icon(icon: Texture2D) -> bool:
	if icon == null:
		return false
	var atlas_icon: AtlasTexture = icon as AtlasTexture
	if atlas_icon != null and atlas_icon.atlas == null:
		return false
	return true
