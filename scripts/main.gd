extends Node2D

const ENEMY_SCENE: PackedScene = preload("res://scenes/enemies/ghoul.tscn")
const DAMAGE_NUMBER_SCENE: PackedScene = preload("res://scenes/ui/floating_damage_number.tscn")

@export var wave1_enemy_total: int = 20
@export var spawn_radius_min: float = 260.0
@export var spawn_radius_max: float = 340.0

var _spawned_in_wave1: int = 0

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

func _on_wave_spawn_timer_timeout() -> void:
	if _spawned_in_wave1 >= wave1_enemy_total:
		$WaveSpawnTimer.stop()
		return

	_spawn_enemy()
	_spawned_in_wave1 += 1

func _spawn_enemy() -> void:
	var enemy: Ghoul = ENEMY_SCENE.instantiate() as Ghoul
	if enemy == null:
		push_error("Failed to instantiate enemy as Ghoul.")
		return
	var player: Node2D = $Player

	var angle: float = randf_range(0.0, TAU)
	var radius: float = randf_range(spawn_radius_min, spawn_radius_max)
	var offset: Vector2 = Vector2.RIGHT.rotated(angle) * radius

	enemy.global_position = player.global_position + offset

	enemy.damage_taken.connect(_on_enemy_damage_taken)
	# enemy.gd braucht: var target: Node2D
	enemy.target = player

	$Enemies.add_child(enemy)
	
func _on_enemy_damage_taken(amount: int, world_position: Vector2) -> void:
	var number: FloatingDamageNumber = DAMAGE_NUMBER_SCENE.instantiate() as FloatingDamageNumber
	if number == null:
		push_error("Failed to instantiate floating damage number scene.")
		return
	number.global_position = world_position
	add_child(number) # auf Main-Ebene, damit es im World-Space mit Kamera läuft
	number.setup(amount)
