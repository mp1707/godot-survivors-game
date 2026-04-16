extends Node2D

const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/floating_damage_number.tscn")

@export var wave: WaveDefinition

var _spawned_enemies: int = 0
var _wave_index: int = 0
var _kills: int = 0

var _pending_level_ups: Array[int] = []
var _is_level_up_active: bool = false
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _player: Player = $Player as Player
@onready var _weapon_system: PlayerWeaponSystem = $Player/WeaponSystem as PlayerWeaponSystem
@onready var _wave_spawn_timer: Timer = $WaveSpawnTimer as Timer
@onready var _xp_orb_manager: XPOrbManager = $Pickups as XPOrbManager
@onready var _score_label: Label = $UI/ScoreLabel as Label
@onready var _xp_bar: XPProgressBar = $UI/XPBar as XPProgressBar
@onready var _power_level_value_label: Label = $UI/PowerLevelValue as Label
@onready var _action_button_bar: ActionButtonBar = $UI/ActionButtonBar as ActionButtonBar
@onready var _level_up_popup: LevelUpPopup = $UI/LevelUpPopup as LevelUpPopup
@onready var _game_over_panel: Panel = $UI/GameOverPanel as Panel
@onready var _game_over_kills_label: Label = $UI/GameOverPanel/MarginContainer/VBoxContainer/KillsLabel as Label

func _ready() -> void:
	_rng.randomize()

	var used_rect: Rect2i = $TileMapLayer.get_used_rect()
	var tile_size: int = 16

	var map_left: int = used_rect.position.x * tile_size
	var map_top: int = used_rect.position.y * tile_size
	var map_right: int = (used_rect.position.x + used_rect.size.x) * tile_size
	var map_bottom: int = (used_rect.position.y + used_rect.size.y) * tile_size

	$Player/Camera2D.limit_left = map_left
	$Player/Camera2D.limit_top = map_top
	$Player/Camera2D.limit_right = map_right
	$Player/Camera2D.limit_bottom = map_bottom

	if _player == null:
		push_error("Player node is not a Player instance.")
		return

	_player.died.connect(_on_player_died)
	_player.xp_changed.connect(_on_player_xp_changed)
	_player.leveled_up.connect(_on_player_leveled_up)

	if _weapon_system != null:
		_weapon_system.weapon_slots_changed.connect(_refresh_action_bar_weapon_icons)

	if _level_up_popup != null:
		_level_up_popup.option_selected.connect(_on_level_up_option_selected)

	if _xp_orb_manager != null:
		_xp_orb_manager.setup(_player)

	_update_score_label()
	_refresh_xp_ui()
	_refresh_action_bar_weapon_icons()
	_game_over_panel.hide()

func _on_wave_spawn_timer_timeout() -> void:
	if wave == null:
		_wave_spawn_timer.stop()
		return
	var total: int = wave.get_total_enemy_count()
	if _spawned_enemies >= total:
		_wave_spawn_timer.stop()
		return

	var wave_size: int = wave.get_wave_size(_wave_index)
	var remaining: int = total - _spawned_enemies
	var spawn_count: int = mini(wave_size, remaining)

	for i: int in range(spawn_count):
		_spawn_enemy()
		_spawned_enemies += 1

	_wave_index += 1

func _spawn_enemy() -> void:
	if wave == null or _player == null:
		return

	var enemy_def: EnemyDefinition = wave.pick_enemy_for_spawn(_rng, _spawned_enemies)
	if enemy_def == null or enemy_def.scene == null:
		push_error("WaveDefinition has no valid enemy to spawn.")
		return

	var enemy: Ghoul = enemy_def.scene.instantiate() as Ghoul
	if enemy == null:
		push_error("Failed to instantiate enemy as Ghoul.")
		return

	enemy.definition = enemy_def

	var angle: float = _rng.randf_range(0.0, TAU)
	var radius: float = _rng.randf_range(wave.spawn_radius_min, wave.spawn_radius_max)
	var offset: Vector2 = Vector2.RIGHT.rotated(angle) * radius

	enemy.global_position = _player.global_position + offset
	enemy.damage_taken.connect(_on_enemy_damage_taken)
	enemy.died.connect(_on_enemy_died.bind(enemy))
	enemy.target = _player
	$Enemies.add_child(enemy)

func _on_enemy_damage_taken(amount: int, world_position: Vector2) -> void:
	var number: FloatingDamageNumber = DAMAGE_NUMBER_SCENE.instantiate() as FloatingDamageNumber
	if number == null:
		push_error("Failed to instantiate floating damage number scene.")
		return
	number.global_position = world_position
	add_child(number)
	number.setup(amount)

func _on_enemy_died(enemy: Ghoul) -> void:
	if enemy != null and is_instance_valid(enemy) and _xp_orb_manager != null:
		_xp_orb_manager.spawn_orb(enemy.global_position, enemy.xp_drop_value)
	_kills += 1
	_update_score_label()

func _update_score_label() -> void:
	_score_label.text = "Kills:\n%d" % _kills

func _on_player_xp_changed(current: int, required: int, level: int) -> void:
	if required <= 0:
		return
	_xp_bar.set_ratio(float(current) / float(required))
	_power_level_value_label.text = str(level)

func _refresh_xp_ui() -> void:
	var required: int = _player.get_xp_to_next_level()
	if required <= 0:
		return
	var ratio: float = float(_player.get_current_xp()) / float(required)
	_xp_bar.set_ratio(ratio)
	_power_level_value_label.text = str(_player.get_power_level())

func _refresh_action_bar_weapon_icons() -> void:
	if _action_button_bar == null or _weapon_system == null:
		return
	for slot_index: int in range(3):
		_action_button_bar.set_weapon_slot_icon(slot_index, _weapon_system.get_slot_icon(slot_index))

func _on_player_leveled_up(new_level: int) -> void:
	_pending_level_ups.append(new_level)
	_try_show_next_level_up_popup()

func _try_show_next_level_up_popup() -> void:
	if _is_level_up_active:
		return
	if _pending_level_ups.is_empty():
		return
	if _player == null or _level_up_popup == null:
		return
	if _game_over_panel != null and _game_over_panel.visible:
		return

	var level: int = _pending_level_ups.pop_front()
	var options: Array[LevelUpOption] = _build_level_up_options(level)
	if options.is_empty():
		_try_show_next_level_up_popup()
		return

	_is_level_up_active = true
	get_tree().paused = true
	_level_up_popup.present_options(level, options)

func _build_level_up_options(level: int) -> Array[LevelUpOption]:
	var unlock_options: Array[LevelUpOption] = _weapon_system.get_unlockable_weapon_options(level)
	if _weapon_system.has_unlock_milestone(level) and not unlock_options.is_empty():
		var picked_unlocks: Array[LevelUpOption] = _pick_random_options(unlock_options, 3)
		if picked_unlocks.size() >= 3:
			return picked_unlocks

		var filler_pool: Array[LevelUpOption] = []
		filler_pool.append_array(_weapon_system.get_weapon_upgrade_options())
		filler_pool.append_array(_player.get_utility_upgrade_options())

		var filler_count: int = 3 - picked_unlocks.size()
		picked_unlocks.append_array(_pick_random_options(filler_pool, filler_count))
		return picked_unlocks

	var options: Array[LevelUpOption] = []
	options.append_array(unlock_options)
	options.append_array(_weapon_system.get_weapon_upgrade_options())
	options.append_array(_player.get_utility_upgrade_options())
	return _pick_random_options(options, 3)

func _pick_random_options(options: Array[LevelUpOption], count: int) -> Array[LevelUpOption]:
	var pool: Array = options.duplicate()
	var picked: Array[LevelUpOption] = []
	while picked.size() < count and not pool.is_empty():
		var index: int = _rng.randi_range(0, pool.size() - 1)
		picked.append(pool[index] as LevelUpOption)
		pool.remove_at(index)
	return picked

func _on_level_up_option_selected(option: LevelUpOption) -> void:
	_apply_level_up_option(option)
	_is_level_up_active = false
	get_tree().paused = false
	_try_show_next_level_up_popup()

func _apply_level_up_option(option: LevelUpOption) -> void:
	match option.option_type:
		LevelUpOption.TYPE_NEW_WEAPON:
			_weapon_system.unlock_weapon_in_next_free_slot(option.ability_id)
		LevelUpOption.TYPE_WEAPON_UPGRADE:
			_weapon_system.apply_weapon_upgrade(option.ability_id, option.upgrade_id)
		LevelUpOption.TYPE_PLAYER_UPGRADE:
			_player.apply_utility_upgrade(option.upgrade_id)

func _on_player_died() -> void:
	_wave_spawn_timer.stop()
	if _xp_orb_manager != null:
		_xp_orb_manager.clear_orbs()
	var enemies_root: Node = $Enemies
	for child: Node in enemies_root.get_children():
		var enemy: Ghoul = child as Ghoul
		if enemy != null:
			enemy.target = null
	_pending_level_ups.clear()
	_is_level_up_active = false
	if _level_up_popup != null:
		_level_up_popup.hide_popup()
	get_tree().paused = false
	_game_over_kills_label.text = "Kills: %d" % _kills
	_game_over_panel.show()

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
