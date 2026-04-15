extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/ghoul.tscn")
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/floating_damage_number.tscn")

@export var wave1_enemy_total: int = 20
@export var spawn_radius_min: float = 260.0
@export var spawn_radius_max: float = 340.0

var _spawned_in_wave1: int = 0
var _kills: int = 0

@onready var _player: Player = $Player as Player
@onready var _wave_spawn_timer: Timer = $WaveSpawnTimer as Timer
@onready var _xp_orb_manager: XPOrbManager = $Pickups as XPOrbManager
@onready var _score_label: Label = $UI/ScoreLabel as Label
@onready var _xp_bar: XPProgressBar = $UI/XPBar as XPProgressBar
@onready var _power_level_value_label: Label = $UI/PowerLevelValue as Label
@onready var _game_over_panel: Panel = $UI/GameOverPanel as Panel
@onready var _game_over_kills_label: Label = $UI/GameOverPanel/MarginContainer/VBoxContainer/KillsLabel as Label

func _ready() -> void:
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
	if _xp_orb_manager != null:
		_xp_orb_manager.setup(_player)
	_update_score_label()
	_refresh_xp_ui()
	_game_over_panel.hide()

func _on_wave_spawn_timer_timeout() -> void:
	if _spawned_in_wave1 >= wave1_enemy_total:
		_wave_spawn_timer.stop()
		return

	_spawn_enemy()
	_spawned_in_wave1 += 1

func _spawn_enemy() -> void:
	var enemy: Ghoul = ENEMY_SCENE.instantiate() as Ghoul
	if enemy == null:
		push_error("Failed to instantiate enemy as Ghoul.")
		return

	if _player == null:
		push_error("Player node is not a Player instance.")
		return

	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(spawn_radius_min, spawn_radius_max)
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

func _on_player_died() -> void:
	_wave_spawn_timer.stop()
	if _xp_orb_manager != null:
		_xp_orb_manager.clear_orbs()
	var enemies_root: Node = $Enemies
	for child: Node in enemies_root.get_children():
		var enemy: Ghoul = child as Ghoul
		if enemy != null:
			enemy.target = null
	_game_over_kills_label.text = "Kills: %d" % _kills
	_game_over_panel.show()

func _on_restart_button_pressed() -> void:
	get_tree().reload_current_scene()
