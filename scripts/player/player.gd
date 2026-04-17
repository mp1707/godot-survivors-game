extends DamageableBody2D
class_name Player

signal health_changed(current: int, max: int)
signal mana_changed(current: float, max: int)
signal mana_preview_changed(active: bool, preview_cost: int, max: int)
signal xp_changed(current: int, required: int, level: int)
signal leveled_up(new_level: int)
signal died()

@export var definition: PlayerDefinition
@export var progression_catalog: ProgressionCatalog

var speed: float = 0.0
var mouse_move_deadzone: float = 0.0
var max_mana: int = 0
var max_health: int = 0

@onready var _animated_sprite: AnimatedSprite2D = $AnimatedSprite2D as AnimatedSprite2D
@onready var _hit_reaction: HitReaction2D = $HitReaction as HitReaction2D
@onready var _weapon_system: PlayerWeaponSystem = $WeaponSystem as PlayerWeaponSystem
@onready var _progression: PlayerProgression = $Progression as PlayerProgression
@onready var _dash_afterimage_vfx: DashAfterimageVfx = $DashAfterimageVfx as DashAfterimageVfx
@onready var _vitals: PlayerVitals = $Vitals as PlayerVitals
@onready var _barrier: BarrierController = $Barrier as BarrierController
@onready var _dash: DashController = $Dash as DashController
@onready var _ki_charge: KiChargeController = $KiCharge as KiChargeController
@onready var _animation: PlayerAnimationController = $Animation as PlayerAnimationController

var _progression_model: AbilityProgressionModel

func _ready() -> void:
	if not _apply_definition():
		set_physics_process(false)
		return

	_hit_reaction.knockback_decay = _vitals.knockback_decay
	_dash.setup(self, _dash_afterimage_vfx, _animated_sprite)
	_ki_charge.setup(self, _vitals)

	_vitals.health_changed.connect(_on_vitals_health_changed)
	_vitals.mana_changed.connect(_on_vitals_mana_changed)
	_vitals.mana_preview_changed.connect(_on_vitals_mana_preview_changed)
	_vitals.died.connect(_on_vitals_died)
	_ki_charge.charge_state_changed.connect(_on_ki_charge_state_changed)
	_weapon_system.shoot_animation_requested.connect(_animation.play_shoot)

	_vitals.emit_initial_state()

	if not _setup_progression_model():
		set_physics_process(false)
		return
	if _progression != null:
		_progression.xp_changed.connect(_on_progression_xp_changed)
		_progression.leveled_up.connect(_on_progression_leveled_up)
		_progression.emit_state()

func _apply_definition() -> bool:
	if definition == null:
		push_error("Player: PlayerDefinition is missing.")
		return false
	speed = definition.speed
	mouse_move_deadzone = definition.mouse_move_deadzone
	max_mana = definition.max_mana
	max_health = definition.max_health
	_vitals.configure(definition)
	_dash.configure(definition)
	_ki_charge.configure(definition)
	_animation.configure(definition)
	return true

func _setup_progression_model() -> bool:
	if progression_catalog == null:
		push_error("Player: progression_catalog is missing.")
		return false
	_progression_model = AbilityProgressionModel.new()
	_progression_model.initialize(PlayerWeaponSystem.SLOT_ACTIONS.size(), progression_catalog)
	var weapon_upgrade_applier: WeaponUpgradeApplier = WeaponUpgradeApplier.new()
	var utility_upgrade_applier: UtilityUpgradeApplier = UtilityUpgradeApplier.new()
	utility_upgrade_applier.setup(self)
	_progression_model.set_weapon_upgrade_applier(weapon_upgrade_applier)
	_progression_model.set_utility_upgrade_applier(utility_upgrade_applier)
	_weapon_system.attach_progression_model(_progression_model)
	return true

func _physics_process(delta: float) -> void:
	if _vitals.is_dead():
		velocity = Vector2.ZERO
		move_and_slide()
		return

	_vitals.tick_invuln(delta)
	_dash.tick_cooldown(delta)
	_barrier.tick(delta)
	_hit_reaction.physics_step(delta)

	if not _dash.is_dashing():
		_dash.try_start(_get_movement_input_vector())

	var can_ki_charge: bool = (not _dash.is_dashing()) and (not _weapon_system.is_charging())
	var still_charging: bool = _ki_charge.update(delta, can_ki_charge)
	if still_charging:
		velocity = _hit_reaction.add_to_velocity(Vector2.ZERO)
		move_and_slide()
		return

	if not _weapon_system.is_charging():
		_vitals.set_mana_preview(false, 0)

	_vitals.regen_mana(delta)
	_weapon_system.physics_update(delta)
	_animation.tick(delta)

	if _weapon_system.is_charging() and not _dash.is_dashing():
		_animation.play_charging_weapon(_weapon_system.get_aim_direction(), _weapon_system.is_charging_energy_ball())
		velocity = _hit_reaction.add_to_velocity(Vector2.ZERO)
		move_and_slide()
		return

	if _dash.is_dashing():
		_dash.update(delta)
		return

	var input_vector: Vector2 = _get_movement_input_vector()
	velocity = _hit_reaction.add_to_velocity(input_vector.normalized() * speed)
	move_and_slide()

	if _animation.is_shoot_anim_active():
		return
	_animation.play_movement(input_vector)

func apply_damage(amount: int, source_world_position: Vector2) -> void:
	if amount <= 0:
		return
	if _dash.blocks_damage():
		return
	if _vitals.is_invulnerable():
		return

	var remaining: int = _barrier.try_absorb(amount, source_world_position, global_position)
	if remaining <= 0:
		return

	var did_die: bool = _vitals.take_damage(remaining)
	if did_die:
		_dash.finish()
		_ki_charge.force_cancel()
		_weapon_system.cancel_charge()
	_hit_reaction.apply_hit(global_position, source_world_position, _vitals.knockback_strength, _vitals.hit_flash_time)

func activate_barrier(lifetime_seconds: float, absorb_amount: int, reflect_damage: bool) -> void:
	_barrier.activate(lifetime_seconds, absorb_amount, reflect_damage)

func has_mana(amount: int) -> bool:
	return _vitals.has_mana(amount)

func consume_mana(amount: int) -> bool:
	return _vitals.consume_mana(amount)

func collect_xp(amount: int) -> void:
	if _progression == null:
		return
	_progression.add_xp(amount)

func get_power_level() -> int:
	if _progression == null:
		return 1
	return _progression.get_level()

func get_current_xp() -> int:
	if _progression == null:
		return 0
	return _progression.get_current_xp()

func get_xp_to_next_level() -> int:
	if _progression == null:
		return 1
	return _progression.get_xp_to_next_level()

func get_xp_magnet_radius() -> float:
	return _vitals.get_xp_magnet_radius()

func set_xp_magnet_radius(new_radius: float) -> void:
	_vitals.set_xp_magnet_radius(new_radius)

func get_progression_model() -> AbilityProgressionModel:
	return _progression_model

func attach_projectile_parent(parent: Node) -> void:
	_weapon_system.attach_projectile_parent(parent)

func get_dash() -> DashController:
	return _dash

func get_ki_charge() -> KiChargeController:
	return _ki_charge

func get_barrier() -> BarrierController:
	return _barrier

func get_vitals() -> PlayerVitals:
	return _vitals

func _get_keyboard_input_vector() -> Vector2:
	var input_vector: Vector2 = Vector2.ZERO
	if Input.is_action_pressed("move_right"):
		input_vector.x += 1.0
	if Input.is_action_pressed("move_left"):
		input_vector.x -= 1.0
	if Input.is_action_pressed("move_down"):
		input_vector.y += 1.0
	if Input.is_action_pressed("move_up"):
		input_vector.y -= 1.0
	return input_vector

func _get_movement_input_vector() -> Vector2:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		var to_mouse: Vector2 = get_global_mouse_position() - global_position
		if to_mouse.length_squared() > mouse_move_deadzone * mouse_move_deadzone:
			return to_mouse.normalized()
	return _get_keyboard_input_vector()

func _on_vitals_health_changed(current: int, max_value: int) -> void:
	health_changed.emit(current, max_value)

func _on_vitals_mana_changed(current: float, max_value: int) -> void:
	mana_changed.emit(current, max_value)

func _on_vitals_mana_preview_changed(active: bool, preview_cost: int, max_value: int) -> void:
	mana_preview_changed.emit(active, preview_cost, max_value)

func _on_vitals_died() -> void:
	died.emit()

func _on_ki_charge_state_changed(active: bool) -> void:
	if active:
		_animation.play_charging_aura()
	else:
		_animation.reset_from_charging_aura()

func _on_progression_xp_changed(current: int, required: int, level: int) -> void:
	xp_changed.emit(current, required, level)

func _on_progression_leveled_up(new_level: int) -> void:
	leveled_up.emit(new_level)
