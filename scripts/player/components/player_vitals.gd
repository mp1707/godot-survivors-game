extends Node
class_name PlayerVitals

signal health_changed(current: int, max: int)
signal mana_changed(current: float, max: int)
signal mana_preview_changed(active: bool, preview_cost: int, max: int)
signal died()

var max_health: int = 0
var max_mana: int = 0
var damage_invuln_time: float = 0.0
var knockback_strength: float = 0.0
var knockback_decay: float = 0.0
var hit_flash_time: float = 0.0
var mana_regen_per_second: float = 0.0
var xp_magnet_radius: float = 0.0

var _health: int = 0
var _mana: float = 0.0
var _damage_invuln_left: float = 0.0
var _is_dead: bool = false

func configure(definition: PlayerDefinition) -> void:
	max_health = definition.max_health
	max_mana = definition.max_mana
	damage_invuln_time = definition.damage_invuln_time
	knockback_strength = definition.knockback_strength
	knockback_decay = definition.knockback_decay
	hit_flash_time = definition.hit_flash_time
	mana_regen_per_second = definition.mana_regen_per_second
	xp_magnet_radius = definition.xp_magnet_radius
	_health = max_health
	_mana = float(max_mana)

func emit_initial_state() -> void:
	health_changed.emit(_health, max_health)
	mana_changed.emit(_mana, max_mana)
	mana_preview_changed.emit(false, 0, max_mana)

func tick_invuln(delta: float) -> void:
	if _damage_invuln_left > 0.0:
		_damage_invuln_left = maxf(_damage_invuln_left - delta, 0.0)

func regen_mana(delta: float, rate_override: float = -1.0) -> bool:
	var rate: float = mana_regen_per_second if rate_override < 0.0 else rate_override
	if rate <= 0.0:
		return false
	var previous: float = _mana
	_mana = minf(_mana + rate * delta, float(max_mana))
	if _mana == previous:
		return false
	mana_changed.emit(_mana, max_mana)
	return true

func set_mana_preview(active: bool, preview_cost: int) -> void:
	mana_preview_changed.emit(active, preview_cost, max_mana)

func is_invulnerable() -> bool:
	return _damage_invuln_left > 0.0

func is_dead() -> bool:
	return _is_dead

func take_damage(amount: int) -> bool:
	if amount <= 0 or _is_dead:
		return false
	_health = maxi(_health - amount, 0)
	_damage_invuln_left = damage_invuln_time
	health_changed.emit(_health, max_health)
	if _health == 0:
		_is_dead = true
		died.emit()
		return true
	return false

func has_mana(amount: int) -> bool:
	return float(amount) <= _mana

func consume_mana(amount: int) -> bool:
	if not has_mana(amount):
		return false
	_mana -= float(amount)
	mana_changed.emit(_mana, max_mana)
	return true

func get_health() -> int:
	return _health

func get_mana() -> float:
	return _mana

func get_xp_magnet_radius() -> float:
	return xp_magnet_radius

func set_xp_magnet_radius(new_radius: float) -> void:
	xp_magnet_radius = maxf(new_radius, 0.0)
