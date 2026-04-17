extends DamageableBody2D
class_name Player

signal health_changed(current: int, max: int)
signal mana_changed(current: float, max: int)
signal mana_preview_changed(active: bool, preview_cost: int, max: int)
signal xp_changed(current: int, required: int, level: int)
signal leveled_up(new_level: int)
signal died()

const ENEMY_COLLISION_LAYER_MASK: int = 1 << 2

@export var definition: PlayerDefinition
@export var progression_catalog: ProgressionCatalog

var max_health: int = 0
var damage_invuln_time: float = 0.0
var knockback_strength: float = 0.0
var knockback_decay: float = 0.0
var hit_flash_time: float = 0.0
var ki_charge_regen_per_second: float = 0.0
var ki_release_radius: float = 0.0

var max_mana: int = 0
var mana_regen_per_second: float = 0.0
var xp_magnet_radius: float = 0.0

var speed: float = 0.0
var shoot_anim_duration: float = 0.0
var mouse_move_deadzone: float = 0.0
var dash_distance: float = 0.0
var dash_speed: float = 0.0
var dash_cooldown: float = 0.0
var dash_afterimage_interval: float = 0.0
var dash_afterimage_lifetime: float = 0.0
var dash_afterimage_alpha: float = 0.0
var dash_afterimage_tint: Color = Color.WHITE

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D as AnimatedSprite2D
@onready var _aura_sprite: AnimatedSprite2D = $AuraSprite as AnimatedSprite2D
@onready var _barrier_sprite: AnimatedSprite2D = $BarrierSprite as AnimatedSprite2D
@onready var _hit_reaction: HitReaction2D = $HitReaction as HitReaction2D
@onready var _weapon_system: PlayerWeaponSystem = $WeaponSystem as PlayerWeaponSystem
@onready var _mana_charge_loop_player: AudioStreamPlayer = $ChargeLoopPlayer as AudioStreamPlayer
@onready var _progression: PlayerProgression = $Progression as PlayerProgression
@onready var _dash_afterimage_vfx: DashAfterimageVfx = $DashAfterimageVfx as DashAfterimageVfx
@onready var _attack_timer: Timer = $AttackTimer as Timer

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

var _dash_invulnerable: bool = false
var _dash_phase_through_enemies: bool = false

var _ki_release_knockback_distance: float = 0.0
var _ki_release_aoe_damage: int = 0

var _barrier_absorption_left: int = 0
var _barrier_lifetime_left: float = 0.0
var _barrier_reflect_damage: bool = false
var _base_collision_mask: int = 0

var _progression_model: AbilityProgressionModel

func _ready() -> void:
	if not _apply_definition():
		set_physics_process(false)
		return
	_health = max_health
	_mana = float(max_mana)
	_hit_reaction.knockback_decay = knockback_decay
	health_changed.emit(_health, max_health)
	mana_changed.emit(_mana, max_mana)
	mana_preview_changed.emit(false, 0, max_mana)
	_weapon_system.shoot_animation_requested.connect(_play_shoot_animation)
	if not _setup_progression_model():
		set_physics_process(false)
		return
	if _progression != null:
		_progression.xp_changed.connect(_on_progression_xp_changed)
		_progression.leveled_up.connect(_on_progression_leveled_up)
		_progression.emit_state()
	if _attack_timer != null:
		_attack_timer.stop()
	_clear_barrier()
	_set_mana_charge_loop_playing(false)
	_base_collision_mask = collision_mask

func get_progression_model() -> AbilityProgressionModel:
	return _progression_model

func _setup_progression_model() -> bool:
	if progression_catalog == null:
		push_error("Player: progression_catalog is missing.")
		return false
	_progression_model = AbilityProgressionModel.new()
	_progression_model.initialize(PlayerWeaponSystem.SLOT_ACTIONS.size(), progression_catalog)
	var weapon_upgrade_applier: WeaponUpgradeApplier = WeaponUpgradeApplier.new()
	var utility_upgrade_applier: UtilityUpgradeApplier = UtilityUpgradeApplier.new()
	utility_upgrade_applier.setup(self)
	_progression_model.set_weapon_upgrade_applier(weapon_upgrade_applier)
	_progression_model.set_utility_upgrade_applier(utility_upgrade_applier)
	_weapon_system.attach_progression_model(_progression_model)
	return true

func _physics_process(delta: float) -> void:
	if _is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if _damage_invuln_left > 0.0:
		_damage_invuln_left = max(_damage_invuln_left - delta, 0.0)
	if _dash_cooldown_left > 0.0:
		_dash_cooldown_left = max(_dash_cooldown_left - delta, 0.0)
	if _barrier_lifetime_left > 0.0:
		_barrier_lifetime_left = max(_barrier_lifetime_left - delta, 0.0)
		if _barrier_lifetime_left <= 0.0:
			_clear_barrier()

	_hit_reaction.physics_step(delta)
	if not _is_dashing:
		_try_start_dash()

	var was_ki_charging: bool = _is_ki_charging
	_is_ki_charging = (not _is_dashing) and Input.is_action_pressed("charging") and not _weapon_system.is_charging()

	if was_ki_charging and not _is_ki_charging and Input.is_action_just_released("charging"):
		_on_ki_charge_released()

	if _is_ki_charging:
		_aura_sprite.visible = true
		_aura_sprite.play("default")
		_set_mana_charge_loop_playing(true)

		_animated_sprite.animation = "charging"
		_animated_sprite.play()

		var old_mana_charging: float = _mana
		_mana = min(_mana + ki_charge_regen_per_second * delta, float(max_mana))
		if _mana != old_mana_charging:
			mana_changed.emit(_mana, max_mana)
		mana_preview_changed.emit(true, roundi(_mana), max_mana)

		velocity = _hit_reaction.add_to_velocity(Vector2.ZERO)
		move_and_slide()
		return

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
	_apply_dash_collision_mask()
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
	if get_slide_collision_count() > 0 and get_last_motion().length_squared() <= 0.0001:
		_dash_distance_left = 0.0

	_dash_distance_left = max(_dash_distance_left - step_distance, 0.0)

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
	collision_mask = _base_collision_mask

func _apply_dash_collision_mask() -> void:
	collision_mask = _base_collision_mask
	if _dash_phase_through_enemies:
		collision_mask = _base_collision_mask & ~ENEMY_COLLISION_LAYER_MASK

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
	if _is_dashing and _dash_invulnerable:
		return
	if _damage_invuln_left > 0.0:
		return

	var remaining_damage: int = amount
	if _barrier_absorption_left > 0:
		var absorbed_damage: int = min(remaining_damage, _barrier_absorption_left)
		_barrier_absorption_left -= absorbed_damage
		remaining_damage -= absorbed_damage
		if _barrier_reflect_damage and absorbed_damage > 0:
			_reflect_absorbed_damage(absorbed_damage, source_world_position)
		if _barrier_absorption_left <= 0:
			_clear_barrier()
		if remaining_damage <= 0:
			return

	_health = maxi(_health - remaining_damage, 0)
	_damage_invuln_left = damage_invuln_time
	health_changed.emit(_health, max_health)

	if _health == 0:
		_is_dead = true
		_finish_dash()
		_set_mana_charge_loop_playing(false)
		_weapon_system.cancel_charge()
		if _attack_timer != null:
			_attack_timer.stop()
		died.emit()

	_hit_reaction.apply_hit(global_position, source_world_position, knockback_strength, hit_flash_time)

func _reflect_absorbed_damage(amount: int, source_world_position: Vector2) -> void:
	var closest_enemy: Enemy = EnemyRegistry.find_nearest_enemy(source_world_position)
	if closest_enemy != null:
		closest_enemy.apply_damage(amount, global_position)

func _on_ki_charge_released() -> void:
	if _ki_release_knockback_distance <= 0.0 and _ki_release_aoe_damage <= 0:
		return

	for enemy: Enemy in EnemyRegistry.get_enemies_in_radius(global_position, ki_release_radius):
		if _ki_release_aoe_damage > 0:
			enemy.apply_damage(_ki_release_aoe_damage, global_position)
		if _ki_release_knockback_distance > 0.0:
			enemy.apply_knockback(global_position, _ki_release_knockback_distance)

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
	return

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

	_mana -= amount
	mana_changed.emit(_mana, max_mana)
	return true

func activate_barrier(lifetime_seconds: float, absorb_amount: int, reflect_damage: bool) -> void:
	_barrier_lifetime_left = max(lifetime_seconds, 0.0)
	_barrier_absorption_left = max(absorb_amount, 0)
	_barrier_reflect_damage = reflect_damage
	if _barrier_absorption_left <= 0 or _barrier_lifetime_left <= 0.0:
		_clear_barrier()
		return
	if _barrier_sprite != null:
		_barrier_sprite.visible = true
		_play_barrier_animation()

func _play_barrier_animation() -> void:
	if _barrier_sprite == null:
		return
	if _barrier_sprite.sprite_frames == null:
		return

	if _barrier_sprite.sprite_frames.has_animation(&"active"):
		_barrier_sprite.play(&"active")
		return
	if _barrier_sprite.sprite_frames.has_animation(&"default"):
		_barrier_sprite.play(&"default")
		return

	var animation_names: PackedStringArray = _barrier_sprite.sprite_frames.get_animation_names()
	if not animation_names.is_empty():
		_barrier_sprite.play(StringName(animation_names[0]))

func _clear_barrier() -> void:
	_barrier_absorption_left = 0
	_barrier_lifetime_left = 0.0
	_barrier_reflect_damage = false
	if _barrier_sprite != null:
		_barrier_sprite.stop()
		_barrier_sprite.visible = false

func adjust_dash_cooldown(delta: float, min_value: float = -INF, max_value: float = INF) -> bool:
	dash_cooldown = _apply_clamped_float_add(dash_cooldown, delta, min_value, max_value)
	return true

func adjust_dash_distance(delta: float, min_value: float = -INF, max_value: float = INF) -> bool:
	dash_distance = _apply_clamped_float_add(dash_distance, delta, min_value, max_value)
	return true

func unlock_dash_invulnerable() -> bool:
	_dash_invulnerable = true
	return true

func unlock_dash_phase() -> bool:
	_dash_phase_through_enemies = true
	if _is_dashing:
		_apply_dash_collision_mask()
	return true

func adjust_charge_ki_regen(delta: float, min_value: float = -INF, max_value: float = INF) -> bool:
	ki_charge_regen_per_second = _apply_clamped_float_add(ki_charge_regen_per_second, delta, min_value, max_value)
	return true

func adjust_ki_release_knockback(delta: float, min_value: float = -INF, max_value: float = INF) -> bool:
	_ki_release_knockback_distance = _apply_clamped_float_add(_ki_release_knockback_distance, delta, min_value, max_value)
	return true

func adjust_ki_release_aoe_damage(delta: float, min_value: float = -INF, max_value: float = INF) -> bool:
	var next_value: float = _apply_clamped_float_add(float(_ki_release_aoe_damage), delta, min_value, max_value)
	_ki_release_aoe_damage = int(round(next_value))
	return true

func _apply_clamped_float_add(base_value: float, delta: float, min_value: float, max_value: float) -> float:
	var result: float = base_value + delta
	if not is_inf(min_value):
		result = maxf(result, min_value)
	if not is_inf(max_value):
		result = minf(result, max_value)
	return result

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

func _apply_definition() -> bool:
	if definition == null:
		push_error("Player: PlayerDefinition is missing.")
		return false
	max_health = definition.max_health
	damage_invuln_time = definition.damage_invuln_time
	knockback_strength = definition.knockback_strength
	knockback_decay = definition.knockback_decay
	hit_flash_time = definition.hit_flash_time
	ki_charge_regen_per_second = definition.ki_charge_regen_per_second
	ki_release_radius = definition.ki_release_radius
	max_mana = definition.max_mana
	mana_regen_per_second = definition.mana_regen_per_second
	xp_magnet_radius = definition.xp_magnet_radius
	speed = definition.speed
	shoot_anim_duration = definition.shoot_anim_duration
	mouse_move_deadzone = definition.mouse_move_deadzone
	dash_distance = definition.dash_distance
	dash_speed = definition.dash_speed
	dash_cooldown = definition.dash_cooldown
	dash_afterimage_interval = definition.dash_afterimage_interval
	dash_afterimage_lifetime = definition.dash_afterimage_lifetime
	dash_afterimage_alpha = definition.dash_afterimage_alpha
	dash_afterimage_tint = definition.dash_afterimage_tint
	return true
