extends Resource
class_name PlayerDefinition

@export_group("Vitals")
@export var max_health: int = 100
@export var damage_invuln_time: float = 0.25
@export var knockback_strength: float = 90.0
@export var knockback_decay: float = 700.0
@export var hit_flash_time: float = 0.08

@export_group("Ki & Mana")
@export var max_mana: int = 100
@export var mana_regen_per_second: float = 1.0
@export var ki_charge_regen_per_second: float = 10.0
@export var ki_release_radius: float = 72.0

@export_group("Movement")
@export var speed: float = 150.0
@export var mouse_move_deadzone: float = 6.0
@export var shoot_anim_duration: float = 0.3

@export_group("Dash")
@export var dash_distance: float = 40.0
@export var dash_speed: float = 700.0
@export var dash_cooldown: float = 5.0
@export var dash_afterimage_interval: float = 0.02
@export var dash_afterimage_lifetime: float = 0.12
@export var dash_afterimage_alpha: float = 0.6
@export var dash_afterimage_tint: Color = Color(0.8, 0.9, 1.0, 1.0)

@export_group("Pickups")
@export var xp_magnet_radius: float = 80.0

@export_group("Utility Upgrades")
@export var utility_upgrades: Array[UpgradeDefinition] = []
