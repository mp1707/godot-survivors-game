extends Resource
class_name UpgradeDefinition

@export var id: StringName
@export var ability_id: StringName
@export var upgrade_type: StringName
@export var max_stacks: int = -1
@export var title: String
@export_multiline var description: String
# Optional override. If empty, UI uses ability upgrade icon.
@export var icon: Texture2D

# Numeric payload for data-driven utility upgrades.
# Ignored by weapon-upgrade pipeline, which uses dedicated step fields on AbilityDefinition.
@export_group("Numeric Payload")
@export var numeric_value: float = 0.0
@export var min_clamp: float = -INF
@export var max_clamp: float = INF
