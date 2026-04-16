extends Resource
class_name LevelProgression

@export var xp_curve: Curve
@export var max_level: int = 100
@export var fallback_xp_per_level: int = 2

func get_xp_required(level: int) -> int:
	var safe_level: int = maxi(level, 1)
	if xp_curve == null:
		return maxi(fallback_xp_per_level, 1)

	var safe_max: int = maxi(max_level, 1)
	var t: float = clampf(float(safe_level - 1) / float(safe_max), 0.0, 1.0)
	var value: float = xp_curve.sample(t)
	return maxi(int(round(value)), 1)
