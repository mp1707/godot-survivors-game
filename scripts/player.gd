extends CharacterBody2D

const LASER_SCENE: PackedScene = preload("res://scenes/abilities/laser_projectile.tscn")

@export var speed: float = 150.0
@export var shoot_anim_duration: float = 0.3
var _shoot_anim_time_left: float = 0.0

func _physics_process(delta: float) -> void:
	
	if _shoot_anim_time_left > 0.0:
		_shoot_anim_time_left -= delta
		if _shoot_anim_time_left < 0.0:
			_shoot_anim_time_left = 0.0
		move_and_slide()
		return
	
	var input_vector := Vector2.ZERO
	
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1

	velocity = input_vector.normalized() * speed

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
	
	
	move_and_slide()
	
func _play_shoot_animation(dir: Vector2) -> void:
	if abs(dir.x) > abs(dir.y):
		$AnimatedSprite2D.animation = "shoot_side"
		$AnimatedSprite2D.flip_h = dir.x > 0.0
	elif dir.y < 0.0:
		$AnimatedSprite2D.animation = "shoot_up"
	else:
		$AnimatedSprite2D.animation = "shoot_down"
	$AnimatedSprite2D.play()
	_shoot_anim_time_left = shoot_anim_duration

func _on_attack_timer_timeout() -> void:
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
