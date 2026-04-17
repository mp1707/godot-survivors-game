extends Node
class_name PlayerWeaponSystem

signal shoot_animation_requested(dir: Vector2)
signal charging_state_changed(is_charging: bool)

const SLOT_ACTIONS: Array[StringName] = [&"action1", &"action2", &"action3"]

var _progression_model: AbilityProgressionModel
var _projectiles_parent: Node = null

var _charging_ability_id: StringName = &""
var _charge_time: float = 0.0
var _aim_direction: Vector2 = Vector2.DOWN
var _charge_vfx: Area2D = null
var _charge_vfx_sprite: AnimatedSprite2D = null

@onready var _player: Player = get_parent() as Player
@onready var _muzzle_up: Marker2D = $"../MuzzleUp" as Marker2D
@onready var _muzzle_up_middle: Marker2D = $"../MuzzleUpMiddle" as Marker2D
@onready var _muzzle_down: Marker2D = $"../MuzzleDown" as Marker2D
@onready var _muzzle_side: Marker2D = $"../MuzzleSide" as Marker2D
@onready var _weapon_charge_loop_player: AudioStreamPlayer = $"../WeaponChargeLoopPlayer" as AudioStreamPlayer
@onready var _energy_ball_charge_loop_player: AudioStreamPlayer = $"../EnergyBallChargeLoopPlayer" as AudioStreamPlayer
@onready var _small_laser_shot_player: AudioStreamPlayer = $"../SmallLaserShotPlayer" as AudioStreamPlayer
@onready var _big_laser_shot_player: AudioStreamPlayer = $"../BigLaserShotPlayer" as AudioStreamPlayer
@onready var _energy_ball_release_player: AudioStreamPlayer = $"../EnergyBallReleasePlayer" as AudioStreamPlayer

func attach_progression_model(model: AbilityProgressionModel) -> void:
	_progression_model = model

func attach_projectile_parent(parent: Node) -> void:
	_projectiles_parent = parent

func physics_update(delta: float) -> void:
	if _progression_model == null:
		return
	_handle_weapon_input(delta)

func cancel_charge() -> void:
	if not is_charging():
		return
	_finish_charge()

func is_charging() -> bool:
	return _charging_ability_id != &""

func is_charging_energy_ball() -> bool:
	if not is_charging() or _progression_model == null:
		return false
	var state: WeaponAbilityState = _progression_model.get_ability_state(_charging_ability_id)
	return state != null and state.use_middle_muzzle_for_charged

func get_aim_direction() -> Vector2:
	return _aim_direction

func get_current_charge_mana_cost() -> int:
	if not is_charging() or _progression_model == null:
		return 0
	var state: WeaponAbilityState = _progression_model.get_ability_state(_charging_ability_id)
	if state == null:
		return 0
	return _progression_model.get_current_cost(state)

func _handle_weapon_input(delta: float) -> void:
	if is_charging():
		_update_charge_flow(delta)
		return

	for slot_index: int in range(SLOT_ACTIONS.size()):
		var action_name: StringName = SLOT_ACTIONS[slot_index]
		if not Input.is_action_just_pressed(action_name):
			continue

		var ability_id: StringName = _progression_model.get_slot_ability_id(slot_index)
		if ability_id == &"":
			continue

		var state: WeaponAbilityState = _progression_model.get_ability_state(ability_id)
		if state == null:
			continue

		if state.is_chargeable:
			var charge_cost: int = _progression_model.get_current_cost(state)
			if not _player.has_mana(charge_cost):
				continue
			_begin_charge(state)
			return

		_activate_instant_weapon(state)
		return

func _update_charge_flow(delta: float) -> void:
	var state: WeaponAbilityState = _progression_model.get_ability_state(_charging_ability_id)
	if state == null:
		_finish_charge()
		return

	var action_name: StringName = _action_for_slot(state.slot_index)
	var max_charge_time: float = _progression_model.get_current_charge_time(state)

	if Input.is_action_pressed(action_name):
		_charge_time = min(_charge_time + delta, max_charge_time)
		_aim_direction = _get_mouse_aim_direction()
		_update_charge_vfx()

	if Input.is_action_just_released(action_name):
		var mana_cost: int = _progression_model.get_current_cost(state)
		if not _player.consume_mana(mana_cost):
			_finish_charge()
			return

		_fire_charge_weapon(state)
		_finish_charge()

func _activate_instant_weapon(state: WeaponAbilityState) -> void:
	var mana_cost: int = _progression_model.get_current_cost(state)
	if not _player.consume_mana(mana_cost):
		return

	match state.behavior:
		AbilityDefinition.BEHAVIOR_PROJECTILE:
			_fire_projectile_weapon(state, _progression_model.get_current_min_damage(state), false)
			_play_release_audio_for_state(state)
		AbilityDefinition.BEHAVIOR_BARRIER:
			_player.activate_barrier(
				_progression_model.get_current_barrier_lifetime(state),
				_progression_model.get_current_barrier_absorb(state),
				state.barrier_reflect_unlocked
			)

func _fire_charge_weapon(state: WeaponAbilityState) -> void:
	if state.behavior != AbilityDefinition.BEHAVIOR_PROJECTILE:
		return

	var damage: int = _progression_model.get_charged_damage(state, _charge_time)
	_fire_projectile_weapon(state, damage, true)
	_play_release_audio_for_state(state)

func _fire_projectile_weapon(state: WeaponAbilityState, damage: int, from_charge: bool) -> void:
	if state.projectile_scene == null:
		return

	var dir: Vector2 = _get_mouse_aim_direction()
	if dir == Vector2.ZERO:
		dir = _aim_direction
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	_aim_direction = dir

	var projectile: Area2D = state.projectile_scene.instantiate() as Area2D
	if projectile == null:
		return

	projectile.global_position = _get_spawn_position(state, dir, from_charge)
	projectile.direction = dir
	if _is_projectile_upright(state):
		projectile.rotation = 0.0
	else:
		projectile.rotation = dir.angle() + deg_to_rad(90.0)

	projectile.configure(
		damage,
		_progression_model.get_current_speed(state),
		_progression_model.get_current_size(state),
		_progression_model.get_current_pierce_amount(state),
		_progression_model.get_current_bounce_amount(state),
		_player,
		state.projectile_definition
	)

	shoot_animation_requested.emit(dir)
	if _projectiles_parent == null:
		push_error("PlayerWeaponSystem: projectile parent is not attached.")
		projectile.queue_free()
		return
	_projectiles_parent.add_child(projectile)

func _begin_charge(state: WeaponAbilityState) -> void:
	_charging_ability_id = state.ability_id
	charging_state_changed.emit(true)
	_charge_time = 0.0
	_aim_direction = _get_mouse_aim_direction()
	_start_charge_vfx(state)

func _finish_charge() -> void:
	_charging_ability_id = &""
	_charge_time = 0.0
	_stop_charge_vfx()
	charging_state_changed.emit(false)

func _start_charge_vfx(state: WeaponAbilityState) -> void:
	if _charge_vfx != null:
		return
	if state.charge_vfx_scene == null:
		return

	_charge_vfx = state.charge_vfx_scene.instantiate() as Area2D
	_player.add_child(_charge_vfx)
	_charge_vfx_sprite = _charge_vfx.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _charge_vfx_sprite != null:
		_charge_vfx_sprite.play("charging")
		if not _charge_vfx_sprite.animation_finished.is_connected(_on_charge_vfx_anim_finished):
			_charge_vfx_sprite.animation_finished.connect(_on_charge_vfx_anim_finished)
	_update_charge_vfx()
	_play_charge_audio_for_state(state)

func _on_charge_vfx_anim_finished() -> void:
	if not is_charging() or _charge_vfx_sprite == null:
		return
	if _charge_vfx_sprite.animation != "charging":
		return

	var state: WeaponAbilityState = _progression_model.get_ability_state(_charging_ability_id)
	if state == null:
		return

	var target_animation: StringName = state.charge_complete_animation
	if target_animation == &"":
		target_animation = &"max_charge"

	if _charge_vfx_sprite.sprite_frames != null and _charge_vfx_sprite.sprite_frames.has_animation(target_animation):
		_charge_vfx_sprite.play(target_animation)

func _update_charge_vfx() -> void:
	if _charge_vfx == null:
		return
	var state: WeaponAbilityState = _progression_model.get_ability_state(_charging_ability_id)
	if state == null:
		return
	var dir: Vector2 = _get_mouse_aim_direction()
	if dir == Vector2.ZERO:
		dir = _aim_direction
	_charge_vfx.global_position = _get_spawn_position(state, dir, true)

func _stop_charge_vfx() -> void:
	_stop_if_playing(_weapon_charge_loop_player)
	_stop_if_playing(_energy_ball_charge_loop_player)
	if _charge_vfx == null:
		return
	_charge_vfx.queue_free()
	_charge_vfx = null
	_charge_vfx_sprite = null

func _play_charge_audio_for_state(state: WeaponAbilityState) -> void:
	match state.charge_audio_variant:
		AbilityDefinition.AUDIO_VARIANT_ENERGY_BALL:
			_play_loop_if_stopped(_energy_ball_charge_loop_player)
		AbilityDefinition.AUDIO_VARIANT_SMALL_LASER, AbilityDefinition.AUDIO_VARIANT_BIG_LASER:
			_play_loop_if_stopped(_weapon_charge_loop_player)

func _play_release_audio_for_state(state: WeaponAbilityState) -> void:
	match state.release_audio_variant:
		AbilityDefinition.AUDIO_VARIANT_SMALL_LASER:
			_play_if_available(_small_laser_shot_player)
		AbilityDefinition.AUDIO_VARIANT_BIG_LASER:
			_play_if_available(_big_laser_shot_player)
		AbilityDefinition.AUDIO_VARIANT_ENERGY_BALL:
			_play_if_available(_energy_ball_release_player)

func _get_spawn_position(state: WeaponAbilityState, dir: Vector2, from_charge: bool) -> Vector2:
	if from_charge and state.use_middle_muzzle_for_charged and _muzzle_up_middle != null:
		return _muzzle_up_middle.global_position
	return _get_muzzle_world_position(dir)

func _get_muzzle_world_position(dir: Vector2) -> Vector2:
	if abs(dir.x) > abs(dir.y):
		var local_side: Vector2 = _muzzle_side.position
		if dir.x < 0.0:
			local_side.x *= -1.0
		return _player.to_global(local_side)
	if dir.y < 0.0:
		return _muzzle_up.global_position
	return _muzzle_down.global_position

func _get_mouse_aim_direction() -> Vector2:
	var to_mouse: Vector2 = _player.get_global_mouse_position() - _player.global_position
	if to_mouse.length_squared() > 0.0001:
		return to_mouse.normalized()
	return _aim_direction

func _action_for_slot(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= SLOT_ACTIONS.size():
		return &""
	return SLOT_ACTIONS[slot_index]

func _is_projectile_upright(state: WeaponAbilityState) -> bool:
	if state.projectile_definition != null:
		return state.projectile_definition.rotation_mode == ProjectileDefinition.ROTATION_UPRIGHT
	return state.keep_projectile_upright

func _play_if_available(player: AudioStreamPlayer) -> void:
	if player != null:
		player.play()

func _play_loop_if_stopped(player: AudioStreamPlayer) -> void:
	if player != null and not player.playing:
		player.play()

func _stop_if_playing(player: AudioStreamPlayer) -> void:
	if player != null and player.playing:
		player.stop()
