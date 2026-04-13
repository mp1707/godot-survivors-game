extends Node
class_name PlayerUIController

@onready var _player: Player = get_parent() as Player
@onready var _health_bar: PlayerHealthBar = $"../HealthBar" as PlayerHealthBar
@onready var _mana_bar: PlayerManaBar = $"../ManaBar" as PlayerManaBar
@onready var _weapon_system: PlayerWeaponSystem = $"../WeaponSystem" as PlayerWeaponSystem

func _ready() -> void:
	if _player == null:
		push_error("PlayerUIController: parent is not a Player.")
		return
	if _health_bar == null or _mana_bar == null:
		push_error("PlayerUIController: missing health or mana bar node.")
		return
	if _weapon_system == null:
		push_error("PlayerUIController: missing WeaponSystem node.")
		return

	_player.health_changed.connect(_on_health_changed)
	_player.mana_changed.connect(_on_mana_changed)
	_player.mana_preview_changed.connect(_on_mana_preview_changed)
	_weapon_system.charging_state_changed.connect(_on_weapon_charging_state_changed)

func _on_health_changed(current: int, max_value: int) -> void:
	if max_value <= 0:
		return
	var ratio: float = float(current) / float(max_value)
	_health_bar.set_ratio(ratio)

func _on_mana_changed(current: float, max_value: int) -> void:
	if max_value <= 0:
		return
	var ratio: float = current / float(max_value)
	_mana_bar.set_ratio(ratio)

func _on_mana_preview_changed(active: bool, preview_cost: int, max_value: int) -> void:
	if max_value <= 0:
		return
	_mana_bar.set_preview(active, preview_cost, max_value)

func _on_weapon_charging_state_changed(is_charging: bool) -> void:
	_mana_bar.set_preview(is_charging, _weapon_system.charged_mana_cost, _player.max_mana)
