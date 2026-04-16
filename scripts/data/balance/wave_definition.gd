extends Resource
class_name WaveDefinition

@export var total_enemy_count: int = 100
@export var wave_size_increase_every: int = 5
@export var max_enemies_per_wave: int = 6

@export_group("Spawn Ring")
@export var spawn_radius_min: float = 260.0
@export var spawn_radius_max: float = 340.0

@export_group("Scaling")
@export var wave_size_curve: Curve
@export var max_waves_for_curve: int = 100

@export_group("Enemies")
@export var enemy_pool: Array[EnemyDefinition] = []

func get_wave_size(wave_index: int) -> int:
	var cap: int = maxi(max_enemies_per_wave, 1)

	if wave_size_curve != null:
		var safe_max: int = maxi(max_waves_for_curve, 1)
		var t: float = clampf(float(wave_index) / float(safe_max), 0.0, 1.0)
		var value: float = wave_size_curve.sample(t)
		return clampi(int(round(value)), 1, cap)

	var waves_per_step: int = maxi(wave_size_increase_every, 1)
	var step_index: int = int(float(wave_index) / float(waves_per_step))
	return clampi(1 + step_index, 1, cap)

func pick_enemy(rng: RandomNumberGenerator) -> EnemyDefinition:
	if enemy_pool.is_empty():
		return null
	var index: int = rng.randi_range(0, enemy_pool.size() - 1)
	return enemy_pool[index]
