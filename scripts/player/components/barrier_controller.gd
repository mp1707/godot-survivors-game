extends Node
class_name BarrierController

@export var sprite_path: NodePath = NodePath("../BarrierSprite")

var _absorption_left: int = 0
var _lifetime_left: float = 0.0
var _reflect_damage: bool = false

@onready var _sprite: AnimatedSprite2D = get_node_or_null(sprite_path) as AnimatedSprite2D

func _ready() -> void:
	_clear()

func activate(lifetime_seconds: float, absorb_amount: int, reflect_damage: bool) -> void:
	_lifetime_left = maxf(lifetime_seconds, 0.0)
	_absorption_left = maxi(absorb_amount, 0)
	_reflect_damage = reflect_damage
	if _absorption_left <= 0 or _lifetime_left <= 0.0:
		_clear()
		return
	if _sprite != null:
		_sprite.visible = true
		_play_active_animation()

func tick(delta: float) -> void:
	if _lifetime_left <= 0.0:
		return
	_lifetime_left = maxf(_lifetime_left - delta, 0.0)
	if _lifetime_left <= 0.0:
		_clear()

func is_active() -> bool:
	return _absorption_left > 0

func try_absorb(amount: int, source_world_position: Vector2, owner_global_position: Vector2) -> int:
	if amount <= 0 or _absorption_left <= 0:
		return amount
	var absorbed: int = mini(amount, _absorption_left)
	_absorption_left -= absorbed
	var remaining: int = amount - absorbed
	if _reflect_damage and absorbed > 0:
		_reflect(absorbed, source_world_position, owner_global_position)
	if _absorption_left <= 0:
		_clear()
	return remaining

func _reflect(amount: int, source_world_position: Vector2, owner_global_position: Vector2) -> void:
	var closest_enemy: Enemy = EnemyRegistry.find_nearest_enemy(source_world_position)
	if closest_enemy != null:
		closest_enemy.apply_damage(amount, owner_global_position)

func _play_active_animation() -> void:
	if _sprite == null or _sprite.sprite_frames == null:
		return
	if _sprite.sprite_frames.has_animation(&"active"):
		_sprite.play(&"active")
		return
	if _sprite.sprite_frames.has_animation(&"default"):
		_sprite.play(&"default")
		return
	var animation_names: PackedStringArray = _sprite.sprite_frames.get_animation_names()
	if not animation_names.is_empty():
		_sprite.play(StringName(animation_names[0]))

func _clear() -> void:
	_absorption_left = 0
	_lifetime_left = 0.0
	_reflect_damage = false
	if _sprite != null:
		_sprite.stop()
		_sprite.visible = false
