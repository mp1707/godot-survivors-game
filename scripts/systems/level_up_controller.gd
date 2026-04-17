extends Node
class_name LevelUpController

var _player: Player
var _progression: AbilityProgressionModel
var _popup: LevelUpPopup
var _option_service: LevelUpOptionService
var _pending_level_ups: Array[int] = []
var _is_active: bool = false
var _is_blocked: bool = false

func setup(player: Player, progression: AbilityProgressionModel, popup: LevelUpPopup, rng: RandomNumberGenerator) -> void:
	_player = player
	_progression = progression
	_popup = popup
	_option_service = LevelUpOptionService.new()
	_option_service.setup(_progression, rng)

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
	var options: Array[LevelUpOption] = _option_service.build_options(level)
	if options.is_empty():
		_try_show_next()
		return

	_is_active = true
	get_tree().paused = true
	_popup.present_options(level, options)

func _on_option_selected(option: LevelUpOption) -> void:
	if _progression != null:
		_progression.apply_option(option)
	_is_active = false
	get_tree().paused = false
	_try_show_next()
