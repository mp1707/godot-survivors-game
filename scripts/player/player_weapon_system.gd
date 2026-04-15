extends Node
class_name PlayerWeaponSystem

signal shoot_animation_requested(dir: Vector2)
signal charging_state_changed(is_charging: bool)

const LASER_SCENE: PackedScene = preload("res://scenes/abilities/laser_projectile.tscn")
const CHARGED_BLAST_SCENE: PackedScene = preload("res://scenes/abilities/charged_laser_blast.tscn")
const ENERGY_BALL_SCENE: PackedScene = preload("res://scenes/abilities/energy_ball_projectile.tscn")
const CHARGING_LASER_BALL_SCENE: PackedScene = preload("res://scenes/abilities/charging_laser_ball.tscn")
const CHARGING_ENERGY_BALL_SCENE: PackedScene = preload("res://scenes/abilities/charging_energy_ball.tscn")

enum ChargeWeaponType {
	NONE,
	LASER,
	ENERGY_BALL
}

@export var charge_max_time: float = 1.8
@export var charged_min_damage: int = 3
@export var charged_max_damage: int = 14
@export var charged_min_scale: float = 1.0
@export var charged_max_scale: float = 3.0
@export var charged_mana_cost: int = 30
@export var energy_ball_charge_max_time: float = 3.2
@export var energy_ball_min_damage: int = 4
@export var energy_ball_max_damage: int = 25
@export var energy_ball_min_scale: float = 0.9
@export var energy_ball_max_scale: float = 1.8
@export var energy_ball_speed: float = 70.0
@export var energy_ball_mana_cost: int = 50

var _charging_weapon: int = ChargeWeaponType.NONE
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

func physics_update(delta: float) -> void:
	_handle_charge_input(delta)

func cancel_charge() -> void:
	if not is_charging():
		return
	_finish_charge()

func is_charging() -> bool:
	return _charging_weapon != ChargeWeaponType.NONE

func is_charging_energy_ball() -> bool:
	return _charging_weapon == ChargeWeaponType.ENERGY_BALL

func get_aim_direction() -> Vector2:
	return _aim_direction

func get_current_charge_mana_cost() -> int:
	match _charging_weapon:
		ChargeWeaponType.LASER:
			return charged_mana_cost
		ChargeWeaponType.ENERGY_BALL:
			return energy_ball_mana_cost
		_:
			return 0

func fire_basic_attack() -> void:
	if is_charging():
		return

	var target: DamageableBody2D = _get_nearest_enemy()
	if target == null:
		return

	var dir: Vector2 = _player.global_position.direction_to(target.global_position)
	var laser: Area2D = LASER_SCENE.instantiate() as Area2D
	laser.global_position = _get_muzzle_world_position(dir)
	laser.direction = dir
	laser.rotation = dir.angle() + deg_to_rad(90.0)

	shoot_animation_requested.emit(dir)
	get_tree().current_scene.add_child(laser)
	_play_if_available(_small_laser_shot_player)

func _get_nearest_enemy() -> DamageableBody2D:
	var nearest: DamageableBody2D = null
	var best_dist_sq: float = INF

	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: DamageableBody2D = node as DamageableBody2D
		if enemy == null:
			continue
		var dist_sq: float = _player.global_position.distance_squared_to(enemy.global_position)
		if dist_sq < best_dist_sq:
			best_dist_sq = dist_sq
			nearest = enemy

	return nearest

func _get_muzzle_world_position(dir: Vector2) -> Vector2:
	if abs(dir.x) > abs(dir.y):
		var local_side: Vector2 = _muzzle_side.position
		if dir.x < 0.0:
			local_side.x *= -1.0
		return _player.to_global(local_side)
	if dir.y < 0.0:
		return _muzzle_up.global_position
	return _muzzle_down.global_position

func _handle_charge_input(delta: float) -> void:
	if _charging_weapon == ChargeWeaponType.NONE:
		if Input.is_action_just_pressed("active_ability"):
			if not _player.has_mana(charged_mana_cost):
				return
			_begin_charge(ChargeWeaponType.LASER)
		elif Input.is_action_just_pressed("charging_2"):
			if not _player.has_mana(energy_ball_mana_cost):
				return
			_begin_charge(ChargeWeaponType.ENERGY_BALL)
		return

	var max_charge_time: float = _get_current_charge_max_time()
	if _is_active_charge_pressed():
		_charge_time = min(_charge_time + delta, max_charge_time)
		_aim_direction = _get_mouse_aim_direction()
		_update_charge_vfx()

	if _is_active_charge_just_released():
		var mana_cost: int = get_current_charge_mana_cost()
		if not _player.consume_mana(mana_cost):
			_finish_charge()
			return

		if _charging_weapon == ChargeWeaponType.LASER:
			_fire_charged_blast()
		elif _charging_weapon == ChargeWeaponType.ENERGY_BALL:
			_fire_energy_ball()
		_finish_charge()

func _fire_charged_blast() -> void:
	var ratio: float = clamp(_charge_time / charge_max_time, 0.0, 1.0)
	var damage: int = roundi(lerpf(float(charged_min_damage), float(charged_max_damage), ratio))
	var blast_scale: float = lerpf(charged_min_scale, charged_max_scale, ratio)

	var dir: Vector2 = _aim_direction.normalized()
	if dir == Vector2.ZERO:
		dir = _get_mouse_aim_direction()

	var blast: Area2D = CHARGED_BLAST_SCENE.instantiate() as Area2D
	blast.global_position = _get_muzzle_world_position(dir)
	blast.direction = dir
	blast.rotation = dir.angle() + deg_to_rad(90.0)
	blast.configure(damage, 320.0, blast_scale, true)

	shoot_animation_requested.emit(dir)
	get_tree().current_scene.add_child(blast)
	_play_if_available(_big_laser_shot_player)

func _fire_energy_ball() -> void:
	var ratio: float = clamp(_charge_time / energy_ball_charge_max_time, 0.0, 1.0)
	var damage: int = roundi(lerpf(float(energy_ball_min_damage), float(energy_ball_max_damage), ratio))
	var blast_scale: float = lerpf(energy_ball_min_scale, energy_ball_max_scale, ratio)

	var dir: Vector2 = _aim_direction.normalized()
	if dir == Vector2.ZERO:
		dir = _get_mouse_aim_direction()

	var blast: Area2D = ENERGY_BALL_SCENE.instantiate() as Area2D
	blast.global_position = _get_charge_muzzle_world_position(dir)
	blast.direction = dir
	blast.rotation = 0.0
	blast.configure(damage, energy_ball_speed, blast_scale, true)

	shoot_animation_requested.emit(dir)
	get_tree().current_scene.add_child(blast)
	_play_if_available(_energy_ball_release_player)

func _get_mouse_aim_direction() -> Vector2:
	var to_mouse: Vector2 = _player.get_global_mouse_position() - _player.global_position
	if to_mouse.length_squared() > 0.0001:
		return to_mouse.normalized()
	return _aim_direction

func _start_charge_vfx() -> void:
	if _charge_vfx != null:
		return
	var charge_vfx_scene: PackedScene = CHARGING_LASER_BALL_SCENE
	if _charging_weapon == ChargeWeaponType.ENERGY_BALL:
		charge_vfx_scene = CHARGING_ENERGY_BALL_SCENE
	_charge_vfx = charge_vfx_scene.instantiate() as Area2D
	_player.add_child(_charge_vfx)
	_charge_vfx_sprite = _charge_vfx.get_node("AnimatedSprite2D") as AnimatedSprite2D
	_charge_vfx_sprite.play("charging")
	_charge_vfx_sprite.animation_finished.connect(_on_charge_vfx_anim_finished)
	if _charging_weapon == ChargeWeaponType.ENERGY_BALL:
		_play_loop_if_stopped(_energy_ball_charge_loop_player)
	else:
		_play_loop_if_stopped(_weapon_charge_loop_player)

func _on_charge_vfx_anim_finished() -> void:
	if is_charging() and _charge_vfx_sprite != null and _charge_vfx_sprite.animation == "charging":
		_charge_vfx_sprite.play(_get_charge_loop_animation_name())

func _update_charge_vfx() -> void:
	if _charge_vfx == null:
		return
	var dir: Vector2 = _aim_direction.normalized()
	if dir == Vector2.ZERO:
		dir = _get_mouse_aim_direction()
	_charge_vfx.global_position = _get_charge_muzzle_world_position(dir)

func _stop_charge_vfx() -> void:
	_stop_if_playing(_weapon_charge_loop_player)
	_stop_if_playing(_energy_ball_charge_loop_player)
	if _charge_vfx == null:
		return
	_charge_vfx.queue_free()
	_charge_vfx = null
	_charge_vfx_sprite = null

func _begin_charge(charge_weapon: int) -> void:
	_charging_weapon = charge_weapon
	charging_state_changed.emit(is_charging())
	_charge_time = 0.0
	_start_charge_vfx()

func _finish_charge() -> void:
	_charging_weapon = ChargeWeaponType.NONE
	charging_state_changed.emit(is_charging())
	_charge_time = 0.0
	_stop_charge_vfx()

func _get_current_charge_max_time() -> float:
	if _charging_weapon == ChargeWeaponType.ENERGY_BALL:
		return energy_ball_charge_max_time
	return charge_max_time

func _is_active_charge_pressed() -> bool:
	if _charging_weapon == ChargeWeaponType.ENERGY_BALL:
		return Input.is_action_pressed("charging_2")
	return Input.is_action_pressed("active_ability")

func _is_active_charge_just_released() -> bool:
	if _charging_weapon == ChargeWeaponType.ENERGY_BALL:
		return Input.is_action_just_released("charging_2")
	return Input.is_action_just_released("active_ability")

func _get_charge_loop_animation_name() -> StringName:
	if _charging_weapon == ChargeWeaponType.ENERGY_BALL:
		return &"fully_charged"
	return &"max_charge"

func _get_charge_muzzle_world_position(dir: Vector2) -> Vector2:
	if _charging_weapon == ChargeWeaponType.ENERGY_BALL:
		if _muzzle_up_middle != null:
			return _muzzle_up_middle.global_position
		return _muzzle_up.global_position
	return _get_muzzle_world_position(dir)

func _play_if_available(player: AudioStreamPlayer) -> void:
	if player != null:
		player.play()

func _play_loop_if_stopped(player: AudioStreamPlayer) -> void:
	if player != null and not player.playing:
		player.play()

func _stop_if_playing(player: AudioStreamPlayer) -> void:
	if player != null and player.playing:
		player.stop()
