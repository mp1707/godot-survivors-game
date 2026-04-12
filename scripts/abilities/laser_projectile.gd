extends Area2D

@export var speed: float = 360.0
@export var damage: int = 1
@export var lifetime: float = 1.2
@export var visual_scale: float = 0.7

var direction: Vector2 = Vector2.RIGHT
var _life_left: float = 0.0

func _ready() -> void:
	_life_left = lifetime
	body_entered.connect(_on_body_entered)
	scale = Vector2.ONE * visual_scale
	$AnimatedSprite2D.play("default")

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life_left -= delta
	if _life_left <= 0.0:
		queue_free()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("enemies") and body.has_method("apply_damage"):
		body.apply_damage(damage)
		queue_free()
