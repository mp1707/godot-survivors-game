extends Node2D

@export var run_balance: RunBalanceDefinition

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

@onready var _player: Player = $Player as Player
@onready var _wave_spawn_timer: Timer = $WaveSpawnTimer as Timer
@onready var _xp_orb_manager: XPOrbManager = $Pickups as XPOrbManager
@onready var _score_label: Label = $UI/ScoreLabel as Label
@onready var _xp_bar: XPProgressBar = $UI/XPBar as XPProgressBar
@onready var _power_level_value_label: Label = $UI/PowerLevelValue as Label
@onready var _action_button_bar: ActionButtonBar = $UI/ActionButtonBar as ActionButtonBar
@onready var _level_up_popup: LevelUpPopup = $UI/LevelUpPopup as LevelUpPopup
@onready var _game_over_panel: Panel = $UI/GameOverPanel as Panel
@onready var _game_over_kills_label: Label = $UI/GameOverPanel/MarginContainer/VBoxContainer/KillsLabel as Label
@onready var _enemies_parent: Node = $Enemies

var _enemy_spawner: EnemySpawner
var _level_up_controller: LevelUpController
var _game_hud: GameHud
var _has_configuration_error: bool = false

func _enter_tree() -> void:
	_apply_run_balance_to_scene_nodes()

func _ready() -> void:
	_rng.randomize()
	_setup_camera_limits()

	if _has_configuration_error:
		return

	if run_balance == null or not run_balance.is_valid():
		push_error("Main: RunBalanceDefinition is missing required references.")
		return
	if not _validate_progression_catalog():
		return

	if _player == null:
		push_error("Player node is not a Player instance.")
		return

	var progression: AbilityProgressionModel = _player.get_progression_model()
	if progression == null:
		push_error("Main: Player progression model is not initialized.")
		return

	_enemy_spawner = EnemySpawner.new()
	_enemy_spawner.name = "EnemySpawner"
	add_child(_enemy_spawner)
	_enemy_spawner.setup(
		_player,
		run_balance.wave_definition,
		run_balance.spawn_pacing_definition,
		_rng,
		_enemies_parent
	)
	_enemy_spawner.enemy_died.connect(_on_enemy_died)

	_level_up_controller = LevelUpController.new()
	_level_up_controller.name = "LevelUpController"
	add_child(_level_up_controller)
	_level_up_controller.setup(_player, progression, _level_up_popup, _rng)

	_game_hud = GameHud.new()
	_game_hud.name = "GameHud"
	add_child(_game_hud)
	_game_hud.setup(
		_player,
		progression,
		_enemy_spawner,
		_score_label,
		_xp_bar,
		_power_level_value_label,
		_action_button_bar,
		self
	)

	_player.died.connect(_on_player_died)

	if _xp_orb_manager != null:
		_xp_orb_manager.setup(_player)

	_game_over_panel.hide()
	_wave_spawn_timer.wait_time = _enemy_spawner.get_current_spawn_interval()
	_wave_spawn_timer.start()

func _apply_run_balance_to_scene_nodes() -> void:
	_has_configuration_error = false
	if run_balance == null:
		return
	if not run_balance.is_valid():
		push_error("Main: RunBalanceDefinition is missing required references.")
		_has_configuration_error = true
		return
	if run_balance.progression_catalog != null and not run_balance.progression_catalog.validate():
		_has_configuration_error = true
		return

	var player_node: Player = get_node_or_null("Player") as Player
	if player_node == null:
		push_error("Main: Player node is not a Player instance.")
		_has_configuration_error = true
		return

	player_node.definition = run_balance.player_definition
	player_node.progression_catalog = run_balance.progression_catalog

	var player_progression: PlayerProgression = player_node.get_node_or_null("Progression") as PlayerProgression
	if player_progression != null:
		player_progression.progression = run_balance.level_progression

func _validate_progression_catalog() -> bool:
	if run_balance == null or run_balance.progression_catalog == null:
		push_error("Main: ProgressionCatalog is missing.")
		return false
	if run_balance.progression_catalog.validate():
		return true

	var validation_errors: PackedStringArray = run_balance.progression_catalog.get_validation_errors()
	if validation_errors.is_empty():
		push_error("Main: ProgressionCatalog validation failed.")
		return false
	for error_text: String in validation_errors:
		push_error("Main: %s" % error_text)
	return false

func _setup_camera_limits() -> void:
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

func _on_wave_spawn_timer_timeout() -> void:
	if _enemy_spawner == null:
		return
	var keep_spawning: bool = _enemy_spawner.on_wave_tick()
	if not keep_spawning:
		_wave_spawn_timer.stop()
		return
	_wave_spawn_timer.wait_time = _enemy_spawner.get_current_spawn_interval()

func _on_enemy_died(enemy: Enemy) -> void:
	if enemy != null and is_instance_valid(enemy) and _xp_orb_manager != null:
		_xp_orb_manager.spawn_orb(enemy.global_position, enemy.xp_drop_value)

func _on_player_died() -> void:
	_wave_spawn_timer.stop()
	if _xp_orb_manager != null:
		_xp_orb_manager.clear_orbs()
	if _enemy_spawner != null:
		_enemy_spawner.clear_all_targets()
	if _level_up_controller != null:
		_level_up_controller.flush_and_resume()
	_game_over_kills_label.text = "Kills: %d" % _game_hud.get_kill_count()
	_game_over_panel.show()

func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()
