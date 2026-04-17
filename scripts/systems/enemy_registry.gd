extends Node

var _enemies_by_id: Dictionary = {}

func register_enemy(enemy: Enemy) -> void:
	if enemy == null:
		return
	_enemies_by_id[enemy.get_instance_id()] = enemy

func unregister_enemy(enemy: Enemy) -> void:
	if enemy == null:
		return
	_enemies_by_id.erase(enemy.get_instance_id())

func find_nearest_enemy(world_position: Vector2, excluded_enemy_ids: Dictionary = {}) -> Enemy:
	var closest_enemy: Enemy = null
	var closest_distance_sq: float = INF

	for enemy: Enemy in _iterate_alive_enemies():
		if enemy == null:
			continue
		if excluded_enemy_ids.has(enemy.get_instance_id()):
			continue
		var distance_sq: float = world_position.distance_squared_to(enemy.global_position)
		if distance_sq < closest_distance_sq:
			closest_distance_sq = distance_sq
			closest_enemy = enemy
	return closest_enemy

func get_enemies_in_radius(world_position: Vector2, radius: float, excluded_enemy_ids: Dictionary = {}) -> Array[Enemy]:
	var result: Array[Enemy] = []
	if radius <= 0.0:
		return result

	var radius_sq: float = radius * radius
	for enemy: Enemy in _iterate_alive_enemies():
		if enemy == null:
			continue
		if excluded_enemy_ids.has(enemy.get_instance_id()):
			continue
		if world_position.distance_squared_to(enemy.global_position) > radius_sq:
			continue
		result.append(enemy)
	return result

func _iterate_alive_enemies() -> Array[Enemy]:
	var alive_enemies: Array[Enemy] = []
	var stale_ids: Array[int] = []

	for id_value: Variant in _enemies_by_id.keys():
		var enemy_id: int = int(id_value)
		var enemy: Enemy = _enemies_by_id.get(enemy_id) as Enemy
		if enemy == null or not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			stale_ids.append(enemy_id)
			continue
		alive_enemies.append(enemy)

	for enemy_id: int in stale_ids:
		_enemies_by_id.erase(enemy_id)

	return alive_enemies
