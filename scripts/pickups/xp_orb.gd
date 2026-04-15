extends Node2D
class_name XPOrb

@export var xp_value: int = 1
@export var collect_radius: float = 10.0
@export var magnet_speed: float = 210.0
@export var magnet_acceleration: float = 900.0
@export var idle_drag: float = 800.0

var _player: Player
var _velocity: Vector2 = Vector2.ZERO

func setup(player: Player, value: int = 1) -> void:
	_player = player
	xp_value = maxi(value, 1)

func _physics_process(delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		return

	var to_player: Vector2 = _player.global_position - global_position
	var distance: float = to_player.length()

	if distance <= collect_radius:
		_player.collect_xp(xp_value)
		queue_free()
		return

	var magnet_radius: float = _player.get_xp_magnet_radius()
	if magnet_radius > 0.0 and distance <= magnet_radius and distance > 0.001:
		var direction: Vector2 = to_player / distance
		var proximity: float = 1.0 - (distance / magnet_radius)
		var desired_speed: float = magnet_speed * (0.35 + proximity * 0.65)
		var desired_velocity: Vector2 = direction * desired_speed
		_velocity = _velocity.move_toward(desired_velocity, magnet_acceleration * delta)
	else:
		_velocity = _velocity.move_toward(Vector2.ZERO, idle_drag * delta)

	global_position += _velocity * delta
