extends Resource
class_name EnemyDefinition

@export var id: StringName
@export var scene: PackedScene

@export_group("Combat")
@export var max_hp: int = 1
@export var attack_damage: int = 10
@export var attack_range: float = 18.0
@export var attack_interval: float = 0.8

@export_group("Movement")
@export var move_speed: float = 40.0
@export var stop_distance: float = 12.0

@export_group("Hit Reaction")
@export var knockback_strength: float = 70.0
@export var knockback_decay: float = 650.0
@export var hit_flash_time: float = 0.07

@export_group("Rewards")
@export var xp_drop_value: int = 1
