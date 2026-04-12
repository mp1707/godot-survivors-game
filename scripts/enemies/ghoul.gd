extends CharacterBody2D
class_name Ghoul

@export var move_speed: float = 40.0
@export var stop_distance: float = 12.0
@export var attack_range: float = 18.0

var target: Node2D

@export var attack_damage: int = 10
@export var attack_interval: float = 0.8
var _attack_cooldown_left: float = 0.0

signal damage_taken(amount: int, world_position: Vector2)

@export var max_hp: int = 3
@export var knockback_strength: float = 70.0
@export var knockback_decay: float = 650.0
@export var hit_flash_time: float = 0.07

var _hp: int = 0
var _knockback_velocity: Vector2 = Vector2.ZERO

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
	
	if _attack_cooldown_left > 0.0:
		_attack_cooldown_left = max(_attack_cooldown_left - _delta, 0.0)

	if dist <= stop_distance:
		velocity = Vector2.ZERO
	else:
		var dir: Vector2 = to_target / dist
		velocity = dir * move_speed
		# target links vom ghoul -> nach links schauen
		$AnimatedSprite2D.flip_h = dir.x < 0.0
	
	if dist <= attack_range and _attack_cooldown_left <= 0.0 and target.has_method("apply_damage"):
		target.apply_damage(attack_damage, global_position)
		_attack_cooldown_left = attack_interval
		
	_knockback_velocity = _knockback_velocity.move_toward(Vector2.ZERO, knockback_decay * _delta)
	velocity += _knockback_velocity
	
	move_and_slide()

func apply_damage(amount: int, hit_world_position: Vector2) -> void:
	_hp -= amount
	damage_taken.emit(amount, hit_world_position)
	
	var dir: Vector2 = (global_position - hit_world_position).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.UP
	_knockback_velocity = dir * knockback_strength
	_play_hit_flash()
	
	if _hp <= 0:
		queue_free()

func _play_hit_flash() -> void:
	var sprite: AnimatedSprite2D = $AnimatedSprite2D
	sprite.modulate = Color(2.0, 2.0, 2.0, 1.0)
	var tw: Tween = create_tween()
	tw.tween_property(sprite, "modulate", Color(1, 1, 1, 1), hit_flash_time)
