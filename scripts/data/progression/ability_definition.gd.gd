extends Resource
class_name AbilityDefinition

const DOMAIN_WEAPON: StringName = &"weapon"
const DOMAIN_PLAYER_UTILITY: StringName = &"player_utility"

const BEHAVIOR_PROJECTILE: StringName = &"projectile"
const BEHAVIOR_BARRIER: StringName = &"barrier"

const AUDIO_VARIANT_NONE: StringName = &"none"
const AUDIO_VARIANT_SMALL_LASER: StringName = &"small_laser"
const AUDIO_VARIANT_BIG_LASER: StringName = &"big_laser"
const AUDIO_VARIANT_ENERGY_BALL: StringName = &"energy_ball"

@export var id: StringName
@export var progression_domain: StringName = DOMAIN_WEAPON
@export var display_name: String

@export var action_bar_icon: Texture2D
@export var level_up_icon: Texture2D
# Optional explicit icon for ability-bound upgrades. Falls back to `level_up_icon`.
@export var upgrade_icon: Texture2D

@export var starts_unlocked: bool = false
@export var start_slot_index: int = -1
@export var unlock_level: int = 1
@export_multiline var unlock_description: String = ""

@export var behavior: StringName = BEHAVIOR_PROJECTILE
@export var is_chargeable: bool = false
@export var projectile_scene: PackedScene
@export var charge_vfx_scene: PackedScene
@export var charge_complete_animation: StringName = &""
@export var keep_projectile_upright: bool = false
@export var use_middle_muzzle_for_charged: bool = false

@export var charge_audio_variant: StringName = AUDIO_VARIANT_NONE
@export var release_audio_variant: StringName = AUDIO_VARIANT_NONE

@export var base_cost: int = 0
@export var cost_upgrade_step: int = 0
@export var min_cost: int = 1

@export var base_damage_min: int = 0
@export var base_damage_max: int = 0

@export var base_charge_time: float = 0.0
@export var charge_time_reduction_step: float = 0.0
@export var min_charge_time: float = 1.0

@export var base_speed: float = 0.0
@export var speed_upgrade_factor: float = 1.0

@export var base_size: float = 1.0
@export var size_upgrade_factor: float = 1.0

@export var base_pierce_amount: int = 0
@export var base_bounce_amount: int = 0

@export var barrier_base_absorb: int = 0
@export var barrier_absorb_upgrade_step: int = 0
@export var barrier_base_lifetime: float = 0.0
@export var barrier_lifetime_upgrade_step: float = 0.0

@export var upgrade_ids: Array[StringName] = []
