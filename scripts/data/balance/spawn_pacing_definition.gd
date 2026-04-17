extends Resource
class_name SpawnPacingDefinition

@export_group("Interval")
@export var spawn_interval_curve: Curve
@export var min_spawn_interval: float = 1.2
@export var max_spawn_interval: float = 1.2
@export var max_waves_for_curve: int = 100

@export_group("Batch Multiplier")
@export var spawn_batch_multiplier_curve: Curve
@export var min_spawn_batch_multiplier: float = 1.0
@export var max_spawn_batch_multiplier: float = 1.0

func get_spawn_interval(wave_index: int) -> float:
	var min_interval: float = maxf(min_spawn_interval, 0.01)
	var max_interval: float = maxf(max_spawn_interval, min_interval)
	if spawn_interval_curve == null:
		return max_interval

	var t: float = _normalized_wave_t(wave_index)
	var speed_ratio: float = clampf(spawn_interval_curve.sample(t), 0.0, 1.0)
	# 0.0 = slow (max interval), 1.0 = fast (min interval)
	return lerpf(max_interval, min_interval, speed_ratio)

func get_spawn_batch_multiplier(wave_index: int) -> float:
	var min_multiplier: float = maxf(min_spawn_batch_multiplier, 0.01)
	var max_multiplier: float = maxf(max_spawn_batch_multiplier, min_multiplier)
	if spawn_batch_multiplier_curve == null:
		return 1.0

	var t: float = _normalized_wave_t(wave_index)
	var sampled: float = spawn_batch_multiplier_curve.sample(t)
	return clampf(sampled, min_multiplier, max_multiplier)

func _normalized_wave_t(wave_index: int) -> float:
	var safe_max: int = maxi(max_waves_for_curve, 1)
	return clampf(float(maxi(wave_index, 0)) / float(safe_max), 0.0, 1.0)
