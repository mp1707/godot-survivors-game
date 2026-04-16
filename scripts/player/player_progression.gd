extends Node
class_name PlayerProgression

signal xp_changed(current: int, required: int, level: int)
signal leveled_up(new_level: int)

@export var start_level: int = 1
@export var progression: LevelProgression

var _level: int = 1
var _xp_in_level: int = 0
var _xp_to_next_level: int = 2

func _ready() -> void:
	_level = maxi(start_level, 1)
	_xp_in_level = 0
	_xp_to_next_level = _required_xp_for_level(_level)

func add_xp(amount: int) -> void:
	if amount <= 0:
		return

	_xp_in_level += amount

	while _xp_in_level >= _xp_to_next_level:
		_xp_in_level -= _xp_to_next_level
		_level += 1
		leveled_up.emit(_level)
		_xp_to_next_level = _required_xp_for_level(_level)

	xp_changed.emit(_xp_in_level, _xp_to_next_level, _level)

func emit_state() -> void:
	xp_changed.emit(_xp_in_level, _xp_to_next_level, _level)

func get_level() -> int:
	return _level

func get_current_xp() -> int:
	return _xp_in_level

func get_xp_to_next_level() -> int:
	return _xp_to_next_level

func _required_xp_for_level(level: int) -> int:
	if progression != null:
		return progression.get_xp_required(level)
	return maxi(level + 1, 1)
