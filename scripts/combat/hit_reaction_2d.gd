extends Node
class_name HitReaction2D

@export var knockback_decay: float = 700.0
@export var sprite_path: NodePath = NodePath("../AnimatedSprite2D")
@export var flash_color: Color = Color(2.0, 2.0, 2.0, 1.0)

var _knockback_velocity: Vector2 = Vector2.ZERO
@onready var _sprite: AnimatedSprite2D = get_node_or_null(sprite_path) as AnimatedSprite2D

func physics_step(delta: float) -> void:
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * delta)

func add_to_velocity(base_velocity: Vector2) -> Vector2:
	return base_velocity + _knockback_velocity

func apply_hit(owner_global_position: Vector2, hit_world_position: Vector2, knockback_strength: float, flash_time: float) -> void:
	var dir: Vector2 = (owner_global_position - hit_world_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	_knockback_velocity = dir * knockback_strength
	_play_hit_flash(flash_time)

func _play_hit_flash(flash_time: float) -> void:
	if _sprite == null:
		return
	_sprite.modulate = flash_color
	var tw: Tween = create_tween()
	tw.tween_property(_sprite, "modulate", Color(1.0, 1.0, 1.0, 1.0), flash_time)
