extends Node
class_name DashController

const ENEMY_COLLISION_LAYER_MASK: int = 1 << 2

var dash_distance: float = 0.0
var dash_speed: float = 0.0
var dash_cooldown: float = 0.0
var dash_afterimage_interval: float = 0.0
var dash_afterimage_lifetime: float = 0.0
var dash_afterimage_alpha: float = 0.0
var dash_afterimage_tint: Color = Color.WHITE

var _is_dashing: bool = false
var _direction: Vector2 = Vector2.ZERO
var _distance_left: float = 0.0
var _afterimage_timer: float = 0.0
var _cooldown_left: float = 0.0
var _invulnerable: bool = false
var _phase_through_enemies: bool = false
var _input_action: StringName = &"dash"

var _player: CharacterBody2D = null
var _vfx: DashAfterimageVfx = null
var _sprite: AnimatedSprite2D = null
var _base_collision_mask: int = 0

func configure(definition: PlayerDefinition) -> void:
	dash_distance = definition.dash_distance
	dash_speed = definition.dash_speed
	dash_cooldown = definition.dash_cooldown
	dash_afterimage_interval = definition.dash_afterimage_interval
	dash_afterimage_lifetime = definition.dash_afterimage_lifetime
	dash_afterimage_alpha = definition.dash_afterimage_alpha
	dash_afterimage_tint = definition.dash_afterimage_tint

func setup(player: CharacterBody2D, vfx: DashAfterimageVfx, sprite: AnimatedSprite2D) -> void:
	_player = player
	_vfx = vfx
	_sprite = sprite
	_base_collision_mask = player.collision_mask

func tick_cooldown(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - delta, 0.0)

func try_start(input_direction: Vector2) -> bool:
	if _input_action == &"" or not InputMap.has_action(_input_action):
		return false
	if not Input.is_action_just_pressed(_input_action):
		return false
	if _cooldown_left > 0.0:
		return false
	var dir: Vector2 = input_direction.normalized()
	if dir.length_squared() <= 0.0001:
		return false

	_is_dashing = true
	_direction = dir
	_distance_left = dash_distance
	_afterimage_timer = _afterimage_interval()
	_cooldown_left = dash_cooldown
	_apply_collision_mask()
	_spawn_afterimage()
	return true

func update(delta: float) -> void:
	if not _is_dashing:
		return
	if delta <= 0.0:
		finish()
		return

	var step_distance: float = minf(dash_speed * delta, _distance_left)
	if step_distance <= 0.0:
		finish()
		return

	_player.velocity = _direction * (step_distance / delta)
	_player.move_and_slide()
	if _player.get_slide_collision_count() > 0 and _player.get_last_motion().length_squared() <= 0.0001:
		_distance_left = 0.0

	_distance_left = maxf(_distance_left - step_distance, 0.0)

	_afterimage_timer -= delta
	var interval: float = _afterimage_interval()
	while _afterimage_timer <= 0.0:
		_spawn_afterimage()
		_afterimage_timer += interval

	if _distance_left <= 0.0:
		finish()

func finish() -> void:
	_is_dashing = false
	_direction = Vector2.ZERO
	_distance_left = 0.0
	_afterimage_timer = 0.0
	if _player != null:
		_player.velocity = Vector2.ZERO
		_player.collision_mask = _base_collision_mask

func is_dashing() -> bool:
	return _is_dashing

func blocks_damage() -> bool:
	return _is_dashing and _invulnerable

func phases_through_enemies() -> bool:
	return _phase_through_enemies

func adjust_cooldown(delta: float, min_value: float = -INF, max_value: float = INF) -> bool:
	dash_cooldown = _clamped_add(dash_cooldown, delta, min_value, max_value)
	return true

func adjust_distance(delta: float, min_value: float = -INF, max_value: float = INF) -> bool:
	dash_distance = _clamped_add(dash_distance, delta, min_value, max_value)
	return true

func unlock_invulnerable() -> bool:
	_invulnerable = true
	return true

func unlock_phase() -> bool:
	_phase_through_enemies = true
	if _is_dashing:
		_apply_collision_mask()
	return true

func set_input_action(action_name: StringName) -> void:
	if action_name == &"":
		return
	_input_action = action_name

func get_input_action() -> StringName:
	return _input_action

func _apply_collision_mask() -> void:
	if _player == null:
		return
	_player.collision_mask = _base_collision_mask
	if _phase_through_enemies:
		_player.collision_mask = _base_collision_mask & ~ENEMY_COLLISION_LAYER_MASK

func _afterimage_interval() -> float:
	return maxf(dash_afterimage_interval, 0.01)

func _spawn_afterimage() -> void:
	if _vfx == null or _sprite == null:
		return
	_vfx.spawn_from(_sprite, dash_afterimage_tint, dash_afterimage_alpha, dash_afterimage_lifetime)

func _clamped_add(base_value: float, delta: float, min_value: float, max_value: float) -> float:
	var result: float = base_value + delta
	if not is_inf(min_value):
		result = maxf(result, min_value)
	if not is_inf(max_value):
		result = minf(result, max_value)
	return result
