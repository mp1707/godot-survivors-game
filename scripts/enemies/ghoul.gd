extends CharacterBody2D
class_name Ghoul

@export var move_speed: float = 40.0
@export var stop_distance: float = 12.0
var target: Node2D

signal damage_taken(amount: int, world_position: Vector2)

@export var max_hp: int = 3
var _hp: int = 0

func _ready() -> void:
	_hp = max_hp
	$AnimatedSprite2D.play("default")
	add_to_group("enemies")

func _physics_process(_delta: float) -> void:
	if target == null:
		velocity = Vector2.ZERO
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()

	if dist <= stop_distance:
		velocity = Vector2.ZERO
	else:
		var dir: Vector2 = to_target / dist
		velocity = dir * move_speed
		# target links vom ghoul -> nach links schauen
		$AnimatedSprite2D.flip_h = dir.x < 0.0
	
	move_and_slide()

func apply_damage(amount: int, hit_world_position: Vector2) -> void:
	_hp -= amount
	damage_taken.emit(amount, hit_world_position)
	if _hp <= 0:
		queue_free()
