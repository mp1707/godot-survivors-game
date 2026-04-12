extends CharacterBody2D

const LASER_SCENE: PackedScene = preload("res://scenes/abilities/laser_projectile.tscn")
const CHARGED_BLAST_SCENE: PackedScene = preload("res://scenes/abilities/charged_laser_blast.tscn")

@export var charge_max_time: float = 1.8
@export var charged_min_damage: int = 3
@export var charged_max_damage: int = 14
@export var charged_min_scale: float = 1.0
@export var charged_max_scale: float = 3.0

@export var speed: float = 150.0
@export var shoot_anim_duration: float = 0.3
@export var mouse_move_deadzone: float = 6.0

var _shoot_anim_time_left: float = 0.0
var _is_charging: bool = false
var _charge_time: float = 0.0
var _aim_direction: Vector2 = Vector2.DOWN

func _physics_process(delta: float) -> void:
	
	_handle_charge_input(delta)

	if _shoot_anim_time_left > 0.0:
		_shoot_anim_time_left -= delta
		if _shoot_anim_time_left < 0.0:
			_shoot_anim_time_left = 0.0
	
	if _is_charging:
		velocity = Vector2.ZERO
		# aim dir berechnen (z. B. nearest enemy / mouse / last dir)
		_aim_direction = _get_aim_direction()
		_set_shoot_animation(_aim_direction)
		$AnimatedSprite2D.play()
		# shooting anim auf aim dir setzen
		move_and_slide()
		return
	
	var input_vector: Vector2 = _get_movement_input_vector()

	velocity = input_vector.normalized() * speed
	
	move_and_slide()
	
	if _shoot_anim_time_left > 0.0:
		return

	if input_vector != Vector2.ZERO:
		if abs(input_vector.x) > abs(input_vector.y):
			$AnimatedSprite2D.animation = "walk_side"
			$AnimatedSprite2D.flip_h = input_vector.x > 0
		else:
			if input_vector.y > 0:
				$AnimatedSprite2D.animation = "walk_down"
			else:
				$AnimatedSprite2D.animation = "walk_up"
		$AnimatedSprite2D.play()
	else:
		if $AnimatedSprite2D.animation == "walk_side" or $AnimatedSprite2D.animation == "shoot_side":
			$AnimatedSprite2D.animation = "idle_side"
		elif $AnimatedSprite2D.animation == "walk_up" or $AnimatedSprite2D.animation == "shoot_up":
			$AnimatedSprite2D.animation = "idle_up"
		elif $AnimatedSprite2D.animation == "walk_down" or $AnimatedSprite2D.animation == "shoot_down":
			$AnimatedSprite2D.animation = "idle_down"
		$AnimatedSprite2D.play()
	
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
	
func _play_shoot_animation(dir: Vector2) -> void:
	_set_shoot_animation(dir)
	$AnimatedSprite2D.play()
	_shoot_anim_time_left = shoot_anim_duration

func _on_attack_timer_timeout() -> void:
	if _is_charging:
		return
	var target: Node2D = _get_nearest_enemy()
	if target == null:
		return

	var laser: Area2D = LASER_SCENE.instantiate() as Area2D
	laser.global_position = global_position

	var dir: Vector2 = global_position.direction_to(target.global_position)
	laser.global_position = _get_muzzle_world_position(dir)
	laser.direction = dir
	laser.rotation = dir.angle() + deg_to_rad(90.0)
	
	_play_shoot_animation(dir)

	get_tree().current_scene.add_child(laser)

func _get_nearest_enemy() -> Node2D:
	var nearest: Node2D = null
	var best_dist_sq: float = INF

	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = node as Node2D
		if enemy == null:
			continue
		var d: float = global_position.distance_squared_to(enemy.global_position)
		if d < best_dist_sq:
			best_dist_sq = d
			nearest = enemy

	return nearest

func _get_muzzle_world_position(dir: Vector2) -> Vector2:
	if abs(dir.x) > abs(dir.y):
		var local_side: Vector2 = $MuzzleSide.position
		if dir.x < 0.0:
			local_side.x *= -1.0
		return to_global(local_side)
	if dir.y < 0.0:
		return $MuzzleUp.global_position
	return $MuzzleDown.global_position
	
func _handle_charge_input(delta: float) -> void:
	if Input.is_action_just_pressed("active_ability"):
		_is_charging = true
		_charge_time = 0.0

	if _is_charging and Input.is_action_pressed("active_ability"):
		_charge_time = min(_charge_time + delta, charge_max_time)

	if _is_charging and Input.is_action_just_released("active_ability"):
		_fire_charged_blast()
		_is_charging = false
		_charge_time = 0.0
		
func _fire_charged_blast() -> void:
	var ratio: float = clamp(_charge_time / charge_max_time, 0.0, 1.0)
	var damage: int = roundi(lerpf(float(charged_min_damage), float(charged_max_damage), ratio))
	var blast_scale: float = lerpf(charged_min_scale, charged_max_scale, ratio)

	var dir: Vector2 = _aim_direction.normalized()
	if dir == Vector2.ZERO:
		dir = _get_aim_direction()
	var blast: Area2D = CHARGED_BLAST_SCENE.instantiate() as Area2D
	blast.global_position = _get_muzzle_world_position(dir)
	blast.direction = dir
	blast.rotation = dir.angle() + deg_to_rad(90.0)
	blast.configure(damage, 320.0, blast_scale, true)

	_play_shoot_animation(dir)
	get_tree().current_scene.add_child(blast)
	
func _set_shoot_animation(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		$AnimatedSprite2D.animation = "shoot_side"
		$AnimatedSprite2D.flip_h = dir.x > 0.0
	elif dir.y < 0.0:
		$AnimatedSprite2D.animation = "shoot_up"
	else:
		$AnimatedSprite2D.animation = "shoot_down"

func _get_aim_direction() -> Vector2:
	var target: Node2D = _get_nearest_enemy()
	if target != null:
		return global_position.direction_to(target.global_position)

	var to_mouse: Vector2 = get_global_mouse_position() - global_position
	if to_mouse.length_squared() > 0.0001:
		return to_mouse.normalized()

	return _aim_direction
