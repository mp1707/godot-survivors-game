extends Node
class_name PlayerAnimationController

@export var sprite_path: NodePath = NodePath("../AnimatedSprite2D")

var shoot_anim_duration: float = 0.0

var _shoot_anim_time_left: float = 0.0

@onready var _sprite: AnimatedSprite2D = get_node_or_null(sprite_path) as AnimatedSprite2D

func configure(definition: PlayerDefinition) -> void:
	shoot_anim_duration = definition.shoot_anim_duration

func tick(delta: float) -> void:
	if _shoot_anim_time_left > 0.0:
		_shoot_anim_time_left = maxf(_shoot_anim_time_left - delta, 0.0)

func is_shoot_anim_active() -> bool:
	return _shoot_anim_time_left > 0.0

func play_shoot(dir: Vector2) -> void:
	if _sprite == null:
		return
	_set_shoot_animation_name(dir)
	_sprite.play()
	_shoot_anim_time_left = shoot_anim_duration

func play_charging_aura() -> void:
	if _sprite == null:
		return
	_sprite.animation = "charging"
	_sprite.play()

func reset_from_charging_aura() -> void:
	if _sprite == null:
		return
	if _sprite.animation == "charging":
		_sprite.animation = "idle_down"
		_sprite.play()

func play_charging_weapon(dir: Vector2, is_energy_ball: bool) -> void:
	if _sprite == null:
		return
	if is_energy_ball:
		_sprite.animation = "hands_up"
	else:
		_set_shoot_animation_name(dir)
	_sprite.play()

func play_movement(input_vector: Vector2) -> void:
	if _sprite == null:
		return
	if input_vector != Vector2.ZERO:
		if absf(input_vector.x) > absf(input_vector.y):
			_sprite.animation = "walk_side"
			_sprite.flip_h = input_vector.x > 0.0
		elif input_vector.y > 0.0:
			_sprite.animation = "walk_down"
		else:
			_sprite.animation = "walk_up"
		_sprite.play()
		return

	if _sprite.animation == "walk_side" or _sprite.animation == "shoot_side":
		_sprite.animation = "idle_side"
	elif _sprite.animation == "walk_up" or _sprite.animation == "shoot_up":
		_sprite.animation = "idle_up"
	elif _sprite.animation == "walk_down" or _sprite.animation == "shoot_down":
		_sprite.animation = "idle_down"
	_sprite.play()

func _set_shoot_animation_name(dir: Vector2) -> void:
	if _sprite == null:
		return
	if absf(dir.x) > absf(dir.y):
		_sprite.animation = "shoot_side"
		_sprite.flip_h = dir.x > 0.0
	elif dir.y < 0.0:
		_sprite.animation = "shoot_up"
	else:
		_sprite.animation = "shoot_down"
