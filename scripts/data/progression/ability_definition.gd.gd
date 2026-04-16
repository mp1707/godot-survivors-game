extends Resource
class_name AbilityDefinition

@export var id: StringName
@export var display_name: String
@export var action_bar_icon: Texture2D
@export var level_up_icon: Texture2D
# Optional explicit icon for ability-bound upgrades. Falls back to `level_up_icon`.
@export var upgrade_icon: Texture2D
@export var upgrade_ids: Array[StringName] = []
