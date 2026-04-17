extends Node
class_name LevelUpController

var _player: Player
var _progression: AbilityProgressionModel
var _popup: LevelUpPopup
var _rng: RandomNumberGenerator
var _pending_level_ups: Array[int] = []
var _is_active: bool = false
var _is_blocked: bool = false

func setup(player: Player, progression: AbilityProgressionModel, popup: LevelUpPopup, rng: RandomNumberGenerator) -> void:
	_player = player
	_progression = progression
	_popup = popup
	_rng = rng

	if _player != null and not _player.leveled_up.is_connected(_on_player_leveled_up):
		_player.leveled_up.connect(_on_player_leveled_up)
	if _popup != null and not _popup.option_selected.is_connected(_on_option_selected):
		_popup.option_selected.connect(_on_option_selected)

func flush_and_resume() -> void:
	_pending_level_ups.clear()
	_is_active = false
	if _popup != null:
		_popup.hide_popup()
	get_tree().paused = false

func set_blocked(blocked: bool) -> void:
	_is_blocked = blocked

func _on_player_leveled_up(new_level: int) -> void:
	_pending_level_ups.append(new_level)
	_try_show_next()

func _try_show_next() -> void:
	if _is_active or _is_blocked:
		return
	if _pending_level_ups.is_empty():
		return
	if _player == null or _popup == null or _progression == null:
		return

	var level: int = _pending_level_ups.pop_front()
	var options: Array[LevelUpOption] = _build_options(level)
	if options.is_empty():
		_try_show_next()
		return

	_is_active = true
	get_tree().paused = true
	_popup.present_options(level, options)

func _build_options(level: int) -> Array[LevelUpOption]:
	var unlock_options: Array[LevelUpOption] = _progression.get_unlockable_weapon_options(level)
	if _progression.has_unlock_milestone(level) and not unlock_options.is_empty():
		var picked_unlocks: Array[LevelUpOption] = _pick_random(unlock_options, 3)
		if picked_unlocks.size() >= 3:
			return picked_unlocks

		var filler_pool: Array[LevelUpOption] = []
		filler_pool.append_array(_progression.get_weapon_upgrade_options())
		filler_pool.append_array(_progression.get_utility_upgrade_options())

		var filler_count: int = 3 - picked_unlocks.size()
		picked_unlocks.append_array(_pick_random(filler_pool, filler_count))
		return picked_unlocks

	var options: Array[LevelUpOption] = []
	options.append_array(unlock_options)
	options.append_array(_progression.get_weapon_upgrade_options())
	options.append_array(_progression.get_utility_upgrade_options())
	return _pick_random(options, 3)

func _pick_random(options: Array[LevelUpOption], count: int) -> Array[LevelUpOption]:
	var pool: Array = options.duplicate()
	var picked: Array[LevelUpOption] = []
	while picked.size() < count and not pool.is_empty():
		var index: int = _rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index] as LevelUpOption)
		pool.remove_at(index)
	return picked

func _on_option_selected(option: LevelUpOption) -> void:
	if _progression != null:
		_progression.apply_option(option)
	_is_active = false
	get_tree().paused = false
	_try_show_next()
