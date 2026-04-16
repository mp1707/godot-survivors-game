extends RefCounted
class_name WeaponAbilityState

var ability_id: StringName = &""
var display_name: String = ""

var icon: Texture2D = null # action bar
var upgrade_icon: Texture2D = null # level-up/upgrades

var starts_unlocked: bool = false
var preferred_slot_index: int = -1
var unlock_level: int = 1
var unlock_description: String = ""

var behavior: StringName = AbilityDefinition.BEHAVIOR_PROJECTILE
var is_unlocked: bool = false
var is_chargeable: bool = false
var projectile_scene: PackedScene = null
var charge_vfx_scene: PackedScene = null
var charge_complete_animation: StringName = &""
var keep_projectile_upright: bool = false
var use_middle_muzzle_for_charged: bool = false
var charge_audio_variant: StringName = AbilityDefinition.AUDIO_VARIANT_NONE
var release_audio_variant: StringName = AbilityDefinition.AUDIO_VARIANT_NONE

var slot_index: int = -1

var base_cost: int = 0
var cost_upgrade_step: int = 0
var min_cost: int = 1

var base_damage_min: int = 0
var base_damage_max: int = 0

var base_charge_time: float = 0.0
var charge_time_reduction_step: float = 0.0
var min_charge_time: float = 1.0

var base_speed: float = 0.0
var speed_upgrade_factor: float = 1.0

var base_size: float = 1.0
var size_upgrade_factor: float = 1.0

var base_pierce_amount: int = 0
var base_bounce_amount: int = 0

var barrier_base_absorb: int = 0
var barrier_absorb_upgrade_step: int = 0
var barrier_base_lifetime: float = 0.0
var barrier_lifetime_upgrade_step: float = 0.0

var available_upgrade_ids: Array[StringName] = []

var cost_upgrade_count: int = 0
var damage_upgrade_count: int = 0
var pierce_upgrade_count: int = 0
var speed_upgrade_count: int = 0
var bounce_upgrade_count: int = 0
var size_upgrade_count: int = 0
var barrier_absorb_upgrade_count: int = 0
var barrier_lifetime_upgrade_count: int = 0
var barrier_reflect_unlocked: bool = false
var charge_speed_upgrade_count: int = 0

func apply_definition(definition: AbilityDefinition) -> void:
	ability_id = definition.id
	display_name = definition.display_name
	starts_unlocked = definition.starts_unlocked
	preferred_slot_index = definition.start_slot_index
	unlock_level = definition.unlock_level
	unlock_description = definition.unlock_description
	behavior = definition.behavior
	is_chargeable = definition.is_chargeable
	projectile_scene = definition.projectile_scene
	charge_vfx_scene = definition.charge_vfx_scene
	charge_complete_animation = definition.charge_complete_animation
	keep_projectile_upright = definition.keep_projectile_upright
	use_middle_muzzle_for_charged = definition.use_middle_muzzle_for_charged
	charge_audio_variant = definition.charge_audio_variant
	release_audio_variant = definition.release_audio_variant

	base_cost = definition.base_cost
	cost_upgrade_step = definition.cost_upgrade_step
	min_cost = definition.min_cost

	base_damage_min = definition.base_damage_min
	base_damage_max = definition.base_damage_max

	base_charge_time = definition.base_charge_time
	charge_time_reduction_step = definition.charge_time_reduction_step
	min_charge_time = definition.min_charge_time

	base_speed = definition.base_speed
	speed_upgrade_factor = definition.speed_upgrade_factor

	base_size = definition.base_size
	size_upgrade_factor = definition.size_upgrade_factor

	base_pierce_amount = definition.base_pierce_amount
	base_bounce_amount = definition.base_bounce_amount

	barrier_base_absorb = definition.barrier_base_absorb
	barrier_absorb_upgrade_step = definition.barrier_absorb_upgrade_step
	barrier_base_lifetime = definition.barrier_base_lifetime
	barrier_lifetime_upgrade_step = definition.barrier_lifetime_upgrade_step

	available_upgrade_ids = definition.upgrade_ids.duplicate()
