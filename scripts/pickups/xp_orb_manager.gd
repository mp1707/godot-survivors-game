extends Node2D
class_name XPOrbManager

# Skalierungs-Absicht:
# - Alle Orb-Lifecycle-Aktionen laufen zentral über diesen Manager (spawn/collect/clear),
#   damit Gameplay-Code außerhalb (z. B. main/enemies) nicht von Orb-Implementierungsdetails abhängt.
# - Die aktuelle Pool-Struktur (_pool/_active_orbs) ist die Basis für Reuse statt ständigem Instanziieren.
# - Spätere Performance-Upgrades (z. B. Grid-Culling, Batch-Updates, MultiMesh-Rendering)
#   können hier eingebaut werden, ohne die Aufrufer-API zu ändern.
const XP_ORB_SCENE: PackedScene = preload("res://scenes/pickups/xp_orb.tscn")

@export var spawn_scatter_radius: float = 4.0
@export var prewarm_count: int = 0

var _player: Player
var _pool: Array[XPOrb] = []
var _active_orbs: Array[XPOrb] = []

func _ready() -> void:
	_prewarm(prewarm_count)

func setup(player: Player) -> void:
	_player = player

func spawn_orb(world_position: Vector2, xp_value: int = 1) -> void:
	if _player == null or not is_instance_valid(_player):
		push_error("XPOrbManager: player is not set. Call setup(player) before spawn_orb.")
		return

	var orb: XPOrb = _acquire_orb()
	if orb == null:
		push_error("XPOrbManager: failed to acquire XPOrb.")
		return

	var scatter: Vector2 = Vector2(
		randf_range(-spawn_scatter_radius, spawn_scatter_radius),
		randf_range(-spawn_scatter_radius, spawn_scatter_radius)
	)
	orb.activate(_player, xp_value, world_position + scatter)
	_active_orbs.append(orb)

func clear_orbs() -> void:
	while not _active_orbs.is_empty():
		var orb: XPOrb = _active_orbs.pop_back()
		if orb == null or not is_instance_valid(orb):
			continue
		orb.deactivate()
		_pool.append(orb)

func _prewarm(count: int) -> void:
	for i: int in range(maxi(count, 0)):
		var orb: XPOrb = _create_orb()
		if orb == null:
			continue
		orb.deactivate()
		_pool.append(orb)

func _acquire_orb() -> XPOrb:
	if _pool.is_empty():
		return _create_orb()
	return _pool.pop_back()

func _create_orb() -> XPOrb:
	var orb: XPOrb = XP_ORB_SCENE.instantiate() as XPOrb
	if orb == null:
		return null
	add_child(orb)
	orb.collected.connect(_on_orb_collected)
	return orb

func _on_orb_collected(orb: XPOrb, amount: int) -> void:
	if _player != null and is_instance_valid(_player):
		_player.collect_xp(amount)

	var index: int = _active_orbs.find(orb)
	if index != -1:
		_active_orbs.remove_at(index)

	if orb == null or not is_instance_valid(orb):
		return
	orb.deactivate()
	_pool.append(orb)
