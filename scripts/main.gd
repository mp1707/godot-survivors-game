extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var used_rect = $TileMapLayer.get_used_rect()
	var tile_size = 16

	var map_left = used_rect.position.x * tile_size
	var map_top = used_rect.position.y * tile_size
	var map_right = (used_rect.position.x + used_rect.size.x) * tile_size
	var map_bottom = (used_rect.position.y + used_rect.size.y) * tile_size

	$Player/Camera2D.limit_left = map_left
	$Player/Camera2D.limit_top = map_top
	$Player/Camera2D.limit_right = map_right
	$Player/Camera2D.limit_bottom = map_bottom


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
