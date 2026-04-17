extends Node
class_name GameHud

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/floating_damage_number.tscn")

var _player: Player
var _progression: AbilityProgressionModel
var _spawner: EnemySpawner
var _score_label: Label
var _xp_bar: XPProgressBar
var _power_level_label: Label
var _action_button_bar: ActionButtonBar
var _damage_number_parent: Node

var _kills: int = 0

func setup(
	player: Player,
	progression: AbilityProgressionModel,
	spawner: EnemySpawner,
	score_label: Label,
	xp_bar: XPProgressBar,
	power_level_label: Label,
	action_button_bar: ActionButtonBar,
	damage_number_parent: Node
) -> void:
	_player = player
	_progression = progression
	_spawner = spawner
	_score_label = score_label
	_xp_bar = xp_bar
	_power_level_label = power_level_label
	_action_button_bar = action_button_bar
	_damage_number_parent = damage_number_parent

	if _player != null:
		_player.xp_changed.connect(_on_player_xp_changed)
	if _progression != null:
		_progression.weapon_unlocked.connect(_on_weapon_unlocked)
		_progression.weapon_upgraded.connect(_on_weapon_upgraded)
	if _spawner != null:
		_spawner.enemy_damage_taken.connect(_on_enemy_damage_taken)
		_spawner.enemy_died.connect(_on_enemy_died)

	_update_score_label()
	_refresh_xp_ui()
	_refresh_action_bar_weapon_icons()

func get_kill_count() -> int:
	return _kills

func _on_player_xp_changed(current: int, required: int, level: int) -> void:
	if required <= 0 or _xp_bar == null:
		return
	_xp_bar.set_ratio(float(current) / float(required))
	if _power_level_label != null:
		_power_level_label.text = str(level)

func _refresh_xp_ui() -> void:
	if _player == null or _xp_bar == null:
		return
	var required: int = _player.get_xp_to_next_level()
	if required <= 0:
		return
	_xp_bar.set_ratio(float(_player.get_current_xp()) / float(required))
	if _power_level_label != null:
		_power_level_label.text = str(_player.get_power_level())

func _refresh_action_bar_weapon_icons() -> void:
	if _action_button_bar == null or _progression == null:
		return
	for slot_index: int in range(3):
		_action_button_bar.set_weapon_slot_icon(slot_index, _progression.get_slot_icon(slot_index))

func _on_weapon_unlocked(_slot_index: int, _ability_id: StringName) -> void:
	_refresh_action_bar_weapon_icons()

func _on_weapon_upgraded(_ability_id: StringName, _upgrade_id: StringName) -> void:
	_refresh_action_bar_weapon_icons()

func _on_enemy_damage_taken(amount: int, world_position: Vector2) -> void:
	if _damage_number_parent == null:
		return
	var number: FloatingDamageNumber = DAMAGE_NUMBER_SCENE.instantiate() as FloatingDamageNumber
	if number == null:
		push_error("Failed to instantiate floating damage number scene.")
		return
	number.global_position = world_position
	_damage_number_parent.add_child(number)
	number.setup(amount)

func _on_enemy_died(_enemy: Enemy) -> void:
	_kills += 1
	_update_score_label()

func _update_score_label() -> void:
	if _score_label != null:
		_score_label.text = "Kills:\n%d" % _kills
