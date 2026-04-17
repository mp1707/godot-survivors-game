extends Resource
class_name UpgradeEffect

const TARGET_WEAPON_STATE: StringName = &"weapon_state"
const TARGET_PLAYER: StringName = &"player"

const OP_ADD: StringName = &"add"
const OP_MULTIPLY: StringName = &"multiply"
const OP_SET_TRUE: StringName = &"set_true"
const OP_SET_VALUE: StringName = &"set_value"
const OP_CLAMP_ADD: StringName = &"clamp_add"

@export var target_domain: StringName = TARGET_WEAPON_STATE
@export var stat_key: StringName = &""
@export var operation: StringName = OP_ADD
@export var value: float = 0.0
@export var min_value: float = -INF
@export var max_value: float = INF
