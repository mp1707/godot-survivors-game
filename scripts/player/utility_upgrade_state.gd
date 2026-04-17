extends RefCounted
class_name UtilityUpgradeState

var upgrade_id: StringName = &""
var stack_count: int = 0
var definition: UpgradeDefinition

func is_max_stacked() -> bool:
	if definition == null:
		return false
	if definition.max_stacks < 0:
		return false
	return stack_count >= definition.max_stacks
