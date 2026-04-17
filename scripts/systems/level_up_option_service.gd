extends RefCounted
class_name LevelUpOptionService

const DEFAULT_OPTION_COUNT: int = 3

var _progression: AbilityProgressionModel
var _rng: RandomNumberGenerator

func setup(progression: AbilityProgressionModel, rng: RandomNumberGenerator) -> void:
	_progression = progression
	_rng = rng

func build_options(current_level: int, option_count: int = DEFAULT_OPTION_COUNT) -> Array[LevelUpOption]:
	if _progression == null or _rng == null:
		return []

	var requested_count: int = maxi(option_count, 1)
	var option_pool: Array[LevelUpOption] = _progression.get_level_up_options(current_level)
	if option_pool.is_empty():
		return []

	if not _progression.has_unlock_milestone(current_level):
		return _pick_random(option_pool, requested_count)

	var unlock_options: Array[LevelUpOption] = []
	var filler_options: Array[LevelUpOption] = []
	for option: LevelUpOption in option_pool:
		if option == null:
			continue
		if option.option_type == LevelUpOption.TYPE_NEW_WEAPON:
			unlock_options.append(option)
		else:
			filler_options.append(option)

	if unlock_options.is_empty():
		return _pick_random(option_pool, requested_count)

	var picked: Array[LevelUpOption] = _pick_random(unlock_options, requested_count)
	if picked.size() >= requested_count:
		return picked

	var missing: int = requested_count - picked.size()
	picked.append_array(_pick_random(filler_options, missing))
	return picked

func _pick_random(options: Array[LevelUpOption], count: int) -> Array[LevelUpOption]:
	var pool: Array[LevelUpOption] = options.duplicate()
	var picked: Array[LevelUpOption] = []
	var target_count: int = maxi(count, 0)

	while picked.size() < target_count and not pool.is_empty():
		var index: int = _rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index])
		pool.remove_at(index)

	return picked
