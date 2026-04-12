extends CharacterBody2D
class_name DamageableBody2D

func apply_damage(_amount: int, _source_world_position: Vector2) -> void:
	push_warning("apply_damage() should be overridden by subclasses.")
