extends DamageableBody2D
class_name Player

signal health_changed(current: int, max: int)
signal died()

@export var max_health: int = 100
@export var damage_invuln_time: float = 0.25
@export var knockback_strength: float = 90.0
@export var knockback_decay: float = 700.0
@export var hit_flash_time: float = 0.08

@export var speed: float = 150.0
@export var shoot_anim_duration: float = 0.3
@export var mouse_move_deadzone: float = 6.0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D as AnimatedSprite2D
@onready var _health_bar: PlayerHealthBar = $HealthBar as PlayerHealthBar
@onready var _hit_reaction: HitReaction2D = $HitReaction as HitReaction2D
@onready var _weapon_system: PlayerWeaponSystem = $WeaponSystem as PlayerWeaponSystem

var _shoot_anim_time_left: float = 0.0
var _health: int = 0
var _damage_invuln_left: float = 0.0
var _is_dead: bool = false

func _ready() -> void:
	_health = max_health
	_hit_reaction.knockback_decay = knockback_decay
	health_changed.connect(_on_health_changed)
	health_changed.emit(_health, max_health)
	_weapon_system.shoot_animation_requested.connect(_play_shoot_animation)

func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _damage_invuln_left > 0.0:
		_damage_invuln_left = max(_damage_invuln_left - delta, 0.0)

	_weapon_system.physics_update(delta)
	_hit_reaction.physics_step(delta)
	_update_shoot_anim_timer(delta)

	if _weapon_system.is_charging():
		velocity = _hit_reaction.add_to_velocity(Vector2.ZERO)
		_set_shoot_animation(_weapon_system.get_aim_direction())
		_animated_sprite.play()
		move_and_slide()
		return

	var input_vector: Vector2 = _get_movement_input_vector()
	velocity = input_vector.normalized() * speed
	velocity = _hit_reaction.add_to_velocity(velocity)
	move_and_slide()

	if _shoot_anim_time_left > 0.0:
		return
	_update_movement_animation(input_vector)

func _update_shoot_anim_timer(delta: float) -> void:
	if _shoot_anim_time_left > 0.0:
		_shoot_anim_time_left = max(_shoot_anim_time_left - delta, 0.0)

func _update_movement_animation(input_vector: Vector2) -> void:
	if input_vector != Vector2.ZERO:
		if abs(input_vector.x) > abs(input_vector.y):
			_animated_sprite.animation = "walk_side"
			_animated_sprite.flip_h = input_vector.x > 0.0
		elif input_vector.y > 0.0:
			_animated_sprite.animation = "walk_down"
		else:
			_animated_sprite.animation = "walk_up"
		_animated_sprite.play()
		return

	if _animated_sprite.animation == "walk_side" or _animated_sprite.animation == "shoot_side":
		_animated_sprite.animation = "idle_side"
	elif _animated_sprite.animation == "walk_up" or _animated_sprite.animation == "shoot_up":
		_animated_sprite.animation = "idle_up"
	elif _animated_sprite.animation == "walk_down" or _animated_sprite.animation == "shoot_down":
		_animated_sprite.animation = "idle_down"
	_animated_sprite.play()

func _get_keyboard_input_vector() -> Vector2:
	var input_vector: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1.0
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1.0
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1.0
	return input_vector

func _get_movement_input_vector() -> Vector2:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		if to_mouse.length_squared() > mouse_move_deadzone * mouse_move_deadzone:
			return to_mouse.normalized()
	return _get_keyboard_input_vector()

func apply_damage(amount: int, source_world_position: Vector2) -> void:
	if amount <= 0:
		return
	if _damage_invuln_left > 0.0:
		return

	_health = maxi(_health - amount, 0)
	_damage_invuln_left = damage_invuln_time
	health_changed.emit(_health, max_health)

	if _health == 0:
		_is_dead = true
		var attack_timer: Timer = $AttackTimer as Timer
		if attack_timer != null:
			attack_timer.stop()
		died.emit()

	_hit_reaction.apply_hit(global_position, source_world_position, knockback_strength, hit_flash_time)

func _on_health_changed(current: int, max_value: int) -> void:
	var ratio: float = float(current) / float(max_value)
	_health_bar.set_ratio(ratio)

func _play_shoot_animation(dir: Vector2) -> void:
	_set_shoot_animation(dir)
	_animated_sprite.play()
	_shoot_anim_time_left = shoot_anim_duration

func _set_shoot_animation(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		_animated_sprite.animation = "shoot_side"
		_animated_sprite.flip_h = dir.x > 0.0
	elif dir.y < 0.0:
		_animated_sprite.animation = "shoot_up"
	else:
		_animated_sprite.animation = "shoot_down"

func _on_attack_timer_timeout() -> void:
	_weapon_system.fire_basic_attack()
