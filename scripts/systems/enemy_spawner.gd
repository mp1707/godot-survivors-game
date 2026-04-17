extends Node
class_name EnemySpawner

signal enemy_damage_taken(amount: int, world_position: Vector2)
signal enemy_died(enemy: Enemy)

@export var wave: WaveDefinition

var _player: Player
var _rng: RandomNumberGenerator
var _enemies_parent: Node
var _spawned_enemies: int = 0
var _wave_index: int = 0

func setup(player: Player, wave_definition: WaveDefinition, rng: RandomNumberGenerator, enemies_parent: Node) -> void:
	_player = player
	wave = wave_definition
	_rng = rng
	_enemies_parent = enemies_parent

func on_wave_tick() -> bool:
	if wave == null or _player == null or _enemies_parent == null:
		return false
	var total: int = wave.get_total_enemy_count()
	if _spawned_enemies >= total:
		return false

	var wave_size: int = wave.get_wave_size(_wave_index)
	var remaining: int = total - _spawned_enemies
	var spawn_count: int = mini(wave_size, remaining)
	var spawned_this_tick: int = 0

	for _i: int in range(spawn_count):
		if _spawn_enemy():
			_spawned_enemies += 1
			spawned_this_tick += 1

	if spawned_this_tick == 0:
		push_error("EnemySpawner: failed to spawn any enemies on wave tick. Stopping spawn timer to avoid empty-loop retries.")
		return false

	_wave_index += 1
	return _spawned_enemies < total

func clear_all_targets() -> void:
	if _enemies_parent == null:
		return
	for child: Node in _enemies_parent.get_children():
		var enemy: Enemy = child as Enemy
		if enemy != null:
			enemy.target = null

func _spawn_enemy() -> bool:
	var enemy_def: EnemyDefinition = wave.pick_enemy_for_spawn(_rng, _spawned_enemies)
	if enemy_def == null or enemy_def.scene == null:
		push_error("WaveDefinition has no valid enemy to spawn.")
		return false

	var enemy: Enemy = enemy_def.scene.instantiate() as Enemy
	if enemy == null:
		push_error("Failed to instantiate enemy as Enemy.")
		return false

	enemy.definition = enemy_def

	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(wave.spawn_radius_min, wave.spawn_radius_max)
	var offset: Vector2 = Vector2.RIGHT.rotated(angle) * radius

	enemy.global_position = _player.global_position + offset
	enemy.damage_taken.connect(_on_enemy_damage_taken)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.target = _player
	_enemies_parent.add_child(enemy)
	return true

func _on_enemy_damage_taken(amount: int, world_position: Vector2) -> void:
	enemy_damage_taken.emit(amount, world_position)

func _on_enemy_died(enemy: Enemy) -> void:
	enemy_died.emit(enemy)
