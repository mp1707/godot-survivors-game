extends Resource
class_name UpgradeDefinition

const DOMAIN_WEAPON: StringName = &"weapon"
const DOMAIN_UTILITY: StringName = &"utility"

@export var id: StringName
@export var ability_id: StringName
@export var max_stacks: int = -1
@export var title: String
@export_multiline var description: String
# Optional override. If empty, UI uses ability upgrade icon.
@export var icon: Texture2D
@export var effects: Array[UpgradeEffect] = []

func get_domain() -> StringName:
	var has_player_target: bool = false
	var has_weapon_target: bool = false

	for effect: UpgradeEffect in effects:
		if effect == null:
			continue
		if effect.target_domain == UpgradeEffect.TARGET_PLAYER:
			has_player_target = true
		elif effect.target_domain == UpgradeEffect.TARGET_WEAPON_STATE:
			has_weapon_target = true

	if has_player_target and has_weapon_target:
		push_error("UpgradeDefinition '%s' mixes player and weapon effects. Split into separate upgrades." % String(id))
		return &""
	if has_player_target:
		return DOMAIN_UTILITY
	if has_weapon_target:
		return DOMAIN_WEAPON

	push_error("UpgradeDefinition '%s' has no valid effects." % String(id))
	return &""
