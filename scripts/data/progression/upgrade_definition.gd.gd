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
