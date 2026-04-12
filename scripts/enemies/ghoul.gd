extends CharacterBody2D

@export var move_speed: float = 40.0
var target: Node2D

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
	var dir: Vector2 = global_position.direction_to(target.global_position)
	velocity = dir * move_speed
	
	# target links vom ghoul -> nach links schauen
	$AnimatedSprite2D.flip_h = dir.x < 0.0
	
	move_and_slide()

func apply_damage(amount: int) -> void:
	_hp -= amount
	if _hp <= 0:
		queue_free()
