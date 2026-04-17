extends Area2D

@export var speed: float = 360.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export var visual_scale: float = 0.7
@export var pierce_enemy_amount: int = 0
@export var bounce_amount: int = 0

var direction: Vector2 = Vector2.RIGHT
var source_body: Node2D = null
var projectile_definition: ProjectileDefinition = null

var _life_left: float = 0.0
var _remaining_hits: int = 1
var _remaining_bounces: int = 0
var _hit_enemy_ids: Dictionary = {}

var _rotation_mode: StringName = ProjectileDefinition.ROTATION_ALIGN_TO_DIRECTION
var _direction_rotation_offset_radians: float = deg_to_rad(90.0)
var _bounce_targeting_mode: StringName = ProjectileDefinition.BOUNCE_TARGET_NEAREST_NOT_HIT
var _bounce_step_distance: float = 6.0
var _destroy_on_non_enemy_contact: bool = true

@onready var _collision_shape: CollisionShape2D = $CollisionShape2D as CollisionShape2D
var _collision_shape_base_scale: Vector2 = Vector2.ONE

func _ready() -> void:
	if _collision_shape != null:
		_collision_shape_base_scale = _collision_shape.scale
	_apply_projectile_definition()

	_life_left = lifetime
	_remaining_bounces = max(bounce_amount, 0)
	if pierce_enemy_amount < 0:
		_remaining_hits = -1
	else:
		_remaining_hits = pierce_enemy_amount + 1

	body_entered.connect(_on_body_entered)
	scale = Vector2.ONE * visual_scale
	_update_visual_rotation()

	var sprite: AnimatedSprite2D = $AnimatedSprite2D as AnimatedSprite2D
	if sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"flying"):
		sprite.play("flying")
	else:
		sprite.play("default")

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body == source_body:
		return

	var damageable: DamageableBody2D = body as DamageableBody2D
	if damageable != null and damageable.is_in_group("enemies"):
		var enemy_id: int = body.get_instance_id()
		if _hit_enemy_ids.has(enemy_id):
			return
		_hit_enemy_ids[enemy_id] = true
		damageable.apply_damage(damage, global_position)

		var bounced_to_enemy: bool = false
		if _remaining_bounces > 0:
			bounced_to_enemy = _bounce_to_next_enemy(body)
			if bounced_to_enemy:
				_remaining_bounces -= 1

		if _remaining_hits >= 0:
			_remaining_hits -= 1
			if _remaining_hits <= 0:
				if bounced_to_enemy:
					# A successful bounce grants one extra contact to reach the next enemy.
					_remaining_hits = 1
				else:
					queue_free()
		return

	if _destroy_on_non_enemy_contact:
		queue_free()

func _bounce_to_next_enemy(hit_enemy: Node) -> bool:
	if _bounce_targeting_mode != ProjectileDefinition.BOUNCE_TARGET_NEAREST_NOT_HIT:
		return false

	var closest_enemy: DamageableBody2D = null
	var closest_distance_sq: float = INF

	for node: Node in get_tree().get_nodes_in_group("enemies"):
		var enemy: DamageableBody2D = node as DamageableBody2D
		if enemy == null:
			continue
		if enemy == hit_enemy:
			continue

		var enemy_id: int = enemy.get_instance_id()
		if _hit_enemy_ids.has(enemy_id):
			continue

		var distance_sq: float = global_position.distance_squared_to(enemy.global_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_enemy = enemy

	if closest_enemy == null:
		return false

	var to_enemy: Vector2 = closest_enemy.global_position - global_position
	if to_enemy.length_squared() <= 0.0001:
		return false

	direction = to_enemy.normalized()
	_update_visual_rotation()
	global_position += direction * _bounce_step_distance
	return true

func _update_visual_rotation() -> void:
	if _rotation_mode == ProjectileDefinition.ROTATION_UPRIGHT:
		rotation = 0.0
		return
	rotation = direction.angle() + _direction_rotation_offset_radians

func _apply_projectile_definition() -> void:
	if projectile_definition == null:
		return

	lifetime = maxf(projectile_definition.base_lifetime, 0.01)
	_rotation_mode = projectile_definition.rotation_mode
	_direction_rotation_offset_radians = deg_to_rad(projectile_definition.direction_rotation_offset_degrees)
	_bounce_targeting_mode = projectile_definition.bounce_targeting_mode
	_bounce_step_distance = maxf(projectile_definition.bounce_step_distance, 0.0)
	_destroy_on_non_enemy_contact = projectile_definition.destroy_on_non_enemy_contact

	if _collision_shape != null:
		var safe_scale: float = maxf(projectile_definition.collision_shape_scale, 0.01)
		_collision_shape.scale = _collision_shape_base_scale * safe_scale

func configure(
	new_damage: int,
	new_speed: float,
	new_visual_scale: float,
	new_pierce_enemy_amount: int,
	new_bounce_amount: int,
	new_source_body: Node2D,
	new_projectile_definition: ProjectileDefinition = null
) -> void:
	damage = new_damage
	speed = new_speed
	visual_scale = new_visual_scale
	pierce_enemy_amount = new_pierce_enemy_amount
	bounce_amount = new_bounce_amount
	source_body = new_source_body
	projectile_definition = new_projectile_definition
