extends DamageableBody2D
class_name Player

signal health_changed(current: int, max: int)
signal mana_changed(current: float, max: int)
signal mana_preview_changed(active: bool, preview_cost: int, max: int)
signal xp_changed(current: int, required: int, level: int)
signal leveled_up(new_level: int)
signal died()


@export var max_health: int = 100
@export var damage_invuln_time: float = 0.25
@export var knockback_strength: float = 90.0
@export var knockback_decay: float = 700.0
@export var hit_flash_time: float = 0.08
@export var ki_charge_regen_per_second: float = 15.0

@export var max_mana: int = 100
@export var mana_regen_per_second: float = 1.0
@export var xp_magnet_radius: float = 80.0

@export var speed: float = 150.0
@export var shoot_anim_duration: float = 0.3
@export var mouse_move_deadzone: float = 6.0
@export var dash_distance: float = 60.0
@export var dash_speed: float = 700.0
@export var dash_cooldown: float = 0.4
@export var dash_afterimage_interval: float = 0.02
@export var dash_afterimage_lifetime: float = 0.12
@export var dash_afterimage_alpha: float = 0.6
@export var dash_afterimage_tint: Color = Color(0.8, 0.9, 1.0, 1.0)

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D as AnimatedSprite2D
@onready var _aura_sprite: AnimatedSprite2D = $AuraSprite as AnimatedSprite2D
@onready var _hit_reaction: HitReaction2D = $HitReaction as HitReaction2D
@onready var _weapon_system: PlayerWeaponSystem = $WeaponSystem as PlayerWeaponSystem
@onready var _mana_charge_loop_player: AudioStreamPlayer = $ChargeLoopPlayer as AudioStreamPlayer
@onready var _progression: PlayerProgression = $Progression as PlayerProgression
@onready var _dash_afterimage_vfx: DashAfterimageVfx = $DashAfterimageVfx as DashAfterimageVfx

var _shoot_anim_time_left: float = 0.0
var _health: int = 0
var _damage_invuln_left: float = 0.0
var _mana: float = 0.0
var _is_dead: bool = false
var _is_ki_charging: bool = false
var _dash_cooldown_left: float = 0.0
var _is_dashing: bool = false
var _dash_direction: Vector2 = Vector2.ZERO
var _dash_distance_left: float = 0.0
var _dash_afterimage_timer: float = 0.0

func _ready() -> void:
	_health = max_health
	_mana = float(max_mana)
	_hit_reaction.knockback_decay = knockback_decay
	health_changed.emit(_health, max_health)
	mana_changed.emit(_mana, max_mana)
	mana_preview_changed.emit(false, 0, max_mana)
	_weapon_system.shoot_animation_requested.connect(_play_shoot_animation)
	if _progression != null:
		_progression.xp_changed.connect(_on_progression_xp_changed)
		_progression.leveled_up.connect(_on_progression_leveled_up)
		_progression.emit_state()
	_set_mana_charge_loop_playing(false)
	
func _physics_process(delta: float) -> void:
		
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
		
	if _damage_invuln_left > 0.0:
		_damage_invuln_left = max(_damage_invuln_left - delta, 0.0)
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = max(_dash_cooldown_left - delta, 0.0)

	_hit_reaction.physics_step(delta)
	if not _is_dashing:
		_try_start_dash()

	_is_ki_charging = (not _is_dashing) and Input.is_action_pressed("charging") and not _weapon_system.is_charging()
	
	if _is_ki_charging:
		_aura_sprite.visible = true
		_aura_sprite.play("default")
		_set_mana_charge_loop_playing(true)

		_animated_sprite.animation = "charging"
		_animated_sprite.play()

		var old_mana: float = _mana
		_mana = min(_mana + ki_charge_regen_per_second * delta, float(max_mana))
		
		if _mana != old_mana:
			mana_changed.emit(_mana, max_mana)
		mana_preview_changed.emit(true, roundi(_mana), max_mana)

		velocity = _hit_reaction.add_to_velocity(Vector2.ZERO)
		move_and_slide()
		return
	else:
		_aura_sprite.visible = false
		_set_mana_charge_loop_playing(false)
		if not _weapon_system.is_charging():
			mana_preview_changed.emit(false, 0, max_mana)
		
		if _animated_sprite.animation == "charging":
			_animated_sprite.animation = "idle_down"
			_animated_sprite.play()
		
		var old_mana: float = _mana
		_mana = min(_mana + mana_regen_per_second * delta, float(max_mana))
		if _mana != old_mana:
			mana_changed.emit(_mana, max_mana)
	

	if not _is_ki_charging:
		_weapon_system.physics_update(delta)
	_update_shoot_anim_timer(delta)

	if _weapon_system.is_charging() and not _is_dashing:
		velocity = _hit_reaction.add_to_velocity(Vector2.ZERO)
		if _weapon_system.is_charging_energy_ball():
			_animated_sprite.animation = "hands_up"
			_animated_sprite.play()
		else:
			_set_shoot_animation(_weapon_system.get_aim_direction())
			_animated_sprite.play()
		move_and_slide()
		return

	if _is_dashing:
		_update_dash(delta)
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

func _try_start_dash() -> bool:
	if not Input.is_action_just_pressed("dash"):
		return false
	if _dash_cooldown_left > 0.0:
		return false
	if _weapon_system.is_charging() or Input.is_action_pressed("charging"):
		return false

	var dash_dir: Vector2 = _get_dash_direction()
	if dash_dir == Vector2.ZERO:
		return false

	_is_dashing = true
	_dash_direction = dash_dir
	_dash_distance_left = dash_distance
	_dash_afterimage_timer = _get_dash_afterimage_interval()
	_dash_cooldown_left = dash_cooldown
	_spawn_dash_afterimage()
	return true

func _get_dash_direction() -> Vector2:
	var input_direction: Vector2 = _get_movement_input_vector().normalized()
	if input_direction.length_squared() > 0.0001:
		return input_direction
	return Vector2.ZERO

func _update_dash(delta: float) -> void:
	if not _is_dashing:
		return
	if delta <= 0.0:
		_finish_dash()
		return

	var step_distance: float = min(dash_speed * delta, _dash_distance_left)
	if step_distance <= 0.0:
		_finish_dash()
		return

	velocity = _dash_direction * (step_distance / delta)
	move_and_slide()

	_dash_distance_left = max(_dash_distance_left - step_distance, 0.0)
	if get_slide_collision_count() > 0 and get_last_motion().length_squared() <= 0.0001:
		_dash_distance_left = 0.0

	_dash_afterimage_timer -= delta
	var interval: float = _get_dash_afterimage_interval()
	while _dash_afterimage_timer <= 0.0:
		_spawn_dash_afterimage()
		_dash_afterimage_timer += interval

	if _dash_distance_left <= 0.0:
		_finish_dash()

func _finish_dash() -> void:
	_is_dashing = false
	_dash_direction = Vector2.ZERO
	_dash_distance_left = 0.0
	_dash_afterimage_timer = 0.0
	velocity = Vector2.ZERO

func _get_dash_afterimage_interval() -> float:
	return max(dash_afterimage_interval, 0.01)

func _spawn_dash_afterimage() -> void:
	if _dash_afterimage_vfx == null:
		return
	_dash_afterimage_vfx.spawn_from(
		_animated_sprite,
		dash_afterimage_tint,
		dash_afterimage_alpha,
		dash_afterimage_lifetime
	)

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
		_finish_dash()
		_set_mana_charge_loop_playing(false)
		_weapon_system.cancel_charge()
		var attack_timer: Timer = $AttackTimer as Timer
		if attack_timer != null:
			attack_timer.stop()
		died.emit()

	_hit_reaction.apply_hit(global_position, source_world_position, knockback_strength, hit_flash_time)

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
	if _is_ki_charging:
		return
	_weapon_system.fire_basic_attack()

func _set_mana_charge_loop_playing(should_play: bool) -> void:
	if _mana_charge_loop_player == null:
		return
	if should_play:
		if not _mana_charge_loop_player.playing:
			_mana_charge_loop_player.play()
		return
	if _mana_charge_loop_player.playing:
		_mana_charge_loop_player.stop()
	
func has_mana(amount: int) -> bool:
	return amount <= _mana

func consume_mana(amount: int) -> bool:
	if not has_mana(amount):
		return false
	
	_mana = _mana - amount
	mana_changed.emit(_mana, max_mana)
	return true

func collect_xp(amount: int) -> void:
	if _progression == null:
		return
	_progression.add_xp(amount)

func get_power_level() -> int:
	if _progression == null:
		return 1
	return _progression.get_level()

func get_current_xp() -> int:
	if _progression == null:
		return 0
	return _progression.get_current_xp()

func get_xp_to_next_level() -> int:
	if _progression == null:
		return 1
	return _progression.get_xp_to_next_level()

func get_xp_magnet_radius() -> float:
	return xp_magnet_radius

func set_xp_magnet_radius(new_radius: float) -> void:
	xp_magnet_radius = max(new_radius, 0.0)

func _on_progression_xp_changed(current: int, required: int, level: int) -> void:
	xp_changed.emit(current, required, level)

func _on_progression_leveled_up(new_level: int) -> void:
	leveled_up.emit(new_level)
