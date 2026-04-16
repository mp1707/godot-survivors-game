extends DamageableBody2D
class_name Ghoul

@export var definition: EnemyDefinition

var move_speed: float = 40.0
var stop_distance: float = 12.0
var attack_range: float = 18.0

var target: DamageableBody2D

var attack_damage: int = 10
var attack_interval: float = 0.8
var xp_drop_value: int = 1
var _attack_cooldown_left: float = 0.0

signal damage_taken(amount: int, world_position: Vector2)
signal died()

var max_hp: int = 1
var knockback_strength: float = 70.0
var knockback_decay: float = 650.0
var hit_flash_time: float = 0.07

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D as AnimatedSprite2D
@onready var _hit_reaction: HitReaction2D = $HitReaction as HitReaction2D

var _hp: int = 0

func _ready() -> void:
	_apply_definition()
	_hp = max_hp
	_hit_reaction.knockback_decay = knockback_decay
	_animated_sprite.play("default")
	add_to_group("enemies")

func _apply_definition() -> void:
	if definition == null:
		return
	move_speed = definition.move_speed
	stop_distance = definition.stop_distance
	attack_range = definition.attack_range
	attack_damage = definition.attack_damage
	attack_interval = definition.attack_interval
	xp_drop_value = definition.xp_drop_value
	max_hp = definition.max_hp
	knockback_strength = definition.knockback_strength
	knockback_decay = definition.knockback_decay
	hit_flash_time = definition.hit_flash_time

func _physics_process(delta: float) -> void:
	_hit_reaction.physics_step(delta)

	if target == null:
		velocity = _hit_reaction.add_to_velocity(Vector2.ZERO)
		move_and_slide()
		return

	var to_target: Vector2 = target.global_position - global_position
	var dist: float = to_target.length()

	if _attack_cooldown_left > 0.0:
		_attack_cooldown_left = max(_attack_cooldown_left - delta, 0.0)

	if dist <= stop_distance:
		velocity = Vector2.ZERO
	else:
		var dir: Vector2 = to_target / dist
		velocity = dir * move_speed
		_animated_sprite.flip_h = dir.x < 0.0

	if dist <= attack_range and _attack_cooldown_left <= 0.0:
		target.apply_damage(attack_damage, global_position)
		_attack_cooldown_left = attack_interval

	velocity = _hit_reaction.add_to_velocity(velocity)
	move_and_slide()

func apply_damage(amount: int, hit_world_position: Vector2) -> void:
	_hp -= amount
	damage_taken.emit(amount, hit_world_position)
	_hit_reaction.apply_hit(global_position, hit_world_position, knockback_strength, hit_flash_time)

	if _hp <= 0:
		died.emit()
		queue_free()

func apply_knockback(source_world_position: Vector2, knockback_distance: float) -> void:
	if knockback_distance <= 0.0:
		return
	var away_direction: Vector2 = (global_position - source_world_position).normalized()
	if away_direction == Vector2.ZERO:
		away_direction = Vector2.UP
	global_position += away_direction * knockback_distance
	_hit_reaction.apply_hit(global_position, source_world_position, knockback_distance * 2.0, 0.04)
