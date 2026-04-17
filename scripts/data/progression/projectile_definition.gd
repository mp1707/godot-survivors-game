extends Resource
class_name ProjectileDefinition

const ROTATION_ALIGN_TO_DIRECTION: StringName = &"align_to_direction"
const ROTATION_UPRIGHT: StringName = &"upright"

const BOUNCE_TARGET_NEAREST_NOT_HIT: StringName = &"nearest_not_hit"

@export_group("Lifetime & Shape")
@export var base_lifetime: float = 1.2
@export var collision_shape_scale: float = 1.0

@export_group("Rotation")
@export var rotation_mode: StringName = ROTATION_ALIGN_TO_DIRECTION
@export var direction_rotation_offset_degrees: float = 90.0

@export_group("Bounce")
@export var bounce_targeting_mode: StringName = BOUNCE_TARGET_NEAREST_NOT_HIT
@export var bounce_step_distance: float = 6.0

@export_group("Contact")
@export var destroy_on_non_enemy_contact: bool = true
