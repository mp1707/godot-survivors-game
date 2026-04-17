extends Resource
class_name ProgressionCatalog

@export var abilities: Array[AbilityDefinition] = []
@export var upgrades: Array[UpgradeDefinition] = []

var _last_validation_errors: PackedStringArray = PackedStringArray()

func validate() -> bool:
	_last_validation_errors = PackedStringArray()

	var ability_ids: Dictionary = {}
	var upgrade_ids: Dictionary = {}

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
			if definition.get_domain() != UpgradeDefinition.DOMAIN_WEAPON:
				_record_error(
					"ProgressionCatalog: ability '%s' references non-weapon upgrade '%s'."
					% [String(ability.id), String(upgrade_id)]
				)

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

static func is_valid_icon(icon: Texture2D) -> bool:
	if icon == null:
		return false
	var atlas_icon: AtlasTexture = icon as AtlasTexture
	if atlas_icon != null and atlas_icon.atlas == null:
		return false
	return true
