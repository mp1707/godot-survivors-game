extends Area2D

@export var speed: float = 360.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export var visual_scale: float = 0.7
@export var pierces_enemies: bool = false

var direction: Vector2 = Vector2.RIGHT
var _life_left: float = 0.0
var _hit_enemy_ids: Dictionary[int, bool] = {}

func _ready() -> void:
	_life_left = lifetime
	body_entered.connect(_on_body_entered)
	scale = Vector2.ONE * visual_scale
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
	var enemy_id: int = body.get_instance_id()
	if _hit_enemy_ids.has(enemy_id):
		return
	_hit_enemy_ids[enemy_id] = true

	var damageable: DamageableBody2D = body as DamageableBody2D
	if damageable != null and damageable.is_in_group("enemies"):
		damageable.apply_damage(damage, global_position)
		if pierces_enemies == false:
			queue_free()

func configure(new_damage: int, new_speed: float, new_visual_scale: float, new_pierces_enemies: bool) -> void:
	damage = new_damage
	speed = new_speed
	visual_scale = new_visual_scale
	pierces_enemies = new_pierces_enemies
