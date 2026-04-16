extends Node
class_name PlayerWeaponSystem

signal shoot_animation_requested(dir: Vector2)
signal charging_state_changed(is_charging: bool)
signal weapon_slots_changed()

const SLOT_ACTIONS: Array[StringName] = [&"action1", &"action2", &"action3"]

const ABILITY_KI_BLAST: StringName = &"ki_blast"
const ABILITY_CHARGED_KI_BLAST: StringName = &"charged_ki_blast"
const ABILITY_BARRIER: StringName = &"barrier"
const ABILITY_ENERGY_BALL: StringName = &"energy_ball"

const OPTION_TYPE_NEW_WEAPON: StringName = &"new_weapon"
const OPTION_TYPE_WEAPON_UPGRADE: StringName = &"weapon_upgrade"

const UPGRADE_COST: StringName = &"cost"
const UPGRADE_DAMAGE: StringName = &"damage"
const UPGRADE_PIERCE: StringName = &"pierce"
const UPGRADE_SPEED: StringName = &"speed"
const UPGRADE_BOUNCE: StringName = &"bounce"
const UPGRADE_SIZE: StringName = &"size"
const UPGRADE_ABSORB: StringName = &"absorb"
const UPGRADE_LIFETIME: StringName = &"lifetime"
const UPGRADE_REFLECT: StringName = &"reflect"
const UPGRADE_CHARGE_SPEED: StringName = &"charge_speed"

const KI_BLAST_SCENE: PackedScene = preload("res://scenes/abilities/laser_projectile.tscn")
const CHARGED_KI_BLAST_SCENE: PackedScene = preload("res://scenes/abilities/charged_laser_blast.tscn")
const ENERGY_BALL_SCENE: PackedScene = preload("res://scenes/abilities/energy_ball_projectile.tscn")
const CHARGING_KI_BLAST_SCENE: PackedScene = preload("res://scenes/abilities/charging_laser_ball.tscn")
const CHARGING_ENERGY_BALL_SCENE: PackedScene = preload("res://scenes/abilities/charging_energy_ball.tscn")

const ABILITY_DEFINITIONS_DIR: String = "res://resources/progression/abilities"
const UPGRADE_DEFINITIONS_DIR: String = "res://resources/progression/upgrades"
const ICONS_DIR: String = "res://resources/progression/icons"

const FALLBACK_ICON_KI_BLAST: Texture2D = preload("res://art/weapons/small_blast.png")
const FALLBACK_ICON_CHARGED_KI_BLAST: Texture2D = preload("res://art/weapons/charged_blast.png")
const FALLBACK_ICON_BARRIER: Texture2D = preload("res://art/character/barrier.png")
const FALLBACK_ICON_ENERGY_BALL: Texture2D = preload("res://art/weapons/blue_energy_ball.png")

class WeaponAbilityState:
	extends RefCounted

	var ability_id: StringName = &""
	var display_name: String = ""
	var icon: Texture2D = null # action bar
	var upgrade_icon: Texture2D = null # level-up/upgrades
	var slot_index: int = -1
	var is_unlocked: bool = false
	var is_chargeable: bool = false
	var projectile_scene: PackedScene = null
	var charge_vfx_scene: PackedScene = null

	var base_cost: int = 0
	var cost_upgrade_step: int = 0
	var min_cost: int = 1

	var base_damage_min: int = 0
	var base_damage_max: int = 0

	var base_charge_time: float = 0.0
	var charge_time_reduction_step: float = 0.0
	var min_charge_time: float = 1.0

	var base_speed: float = 0.0
	var speed_upgrade_factor: float = 1.0

	var base_size: float = 1.0
	var size_upgrade_factor: float = 1.0

	var base_pierce_amount: int = 0
	var base_bounce_amount: int = 0

	var barrier_base_absorb: int = 0
	var barrier_absorb_upgrade_step: int = 0
	var barrier_base_lifetime: float = 0.0
	var barrier_lifetime_upgrade_step: float = 0.0

	var available_upgrade_ids: Array[StringName] = []

	var cost_upgrade_count: int = 0
	var damage_upgrade_count: int = 0
	var pierce_upgrade_count: int = 0
	var speed_upgrade_count: int = 0
	var bounce_upgrade_count: int = 0
	var size_upgrade_count: int = 0
	var barrier_absorb_upgrade_count: int = 0
	var barrier_lifetime_upgrade_count: int = 0
	var barrier_reflect_unlocked: bool = false
	var charge_speed_upgrade_count: int = 0


var _weapon_slots: Array[StringName] = [&"", &"", &""]
var _abilities: Dictionary = {}
var _ability_definitions: Dictionary = {}
var _upgrade_definitions: Dictionary = {}

var _charging_ability_id: StringName = &""
var _charge_time: float = 0.0
var _aim_direction: Vector2 = Vector2.DOWN
var _charge_vfx: Area2D = null
var _charge_vfx_sprite: AnimatedSprite2D = null

@onready var _player: Player = get_parent() as Player
@onready var _muzzle_up: Marker2D = $"../MuzzleUp" as Marker2D
@onready var _muzzle_up_middle: Marker2D = $"../MuzzleUpMiddle" as Marker2D
@onready var _muzzle_down: Marker2D = $"../MuzzleDown" as Marker2D
@onready var _muzzle_side: Marker2D = $"../MuzzleSide" as Marker2D
@onready var _weapon_charge_loop_player: AudioStreamPlayer = $"../WeaponChargeLoopPlayer" as AudioStreamPlayer
@onready var _energy_ball_charge_loop_player: AudioStreamPlayer = $"../EnergyBallChargeLoopPlayer" as AudioStreamPlayer
@onready var _small_laser_shot_player: AudioStreamPlayer = $"../SmallLaserShotPlayer" as AudioStreamPlayer
@onready var _big_laser_shot_player: AudioStreamPlayer = $"../BigLaserShotPlayer" as AudioStreamPlayer
@onready var _energy_ball_release_player: AudioStreamPlayer = $"../EnergyBallReleasePlayer" as AudioStreamPlayer


func _ready() -> void:
	_load_progression_definitions()
	_setup_weapon_definitions()
	weapon_slots_changed.emit()

func physics_update(delta: float) -> void:
	_handle_weapon_input(delta)

func cancel_charge() -> void:
	if not is_charging():
		return
	_finish_charge()

func is_charging() -> bool:
	return _charging_ability_id != &""

func is_charging_energy_ball() -> bool:
	return _charging_ability_id == ABILITY_ENERGY_BALL

func get_aim_direction() -> Vector2:
	return _aim_direction

func get_current_charge_mana_cost() -> int:
	if not is_charging():
		return 0
	var state: WeaponAbilityState = _get_ability_state(_charging_ability_id)
	if state == null:
		return 0
	return _get_current_cost(state)

func has_weapon_in_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _weapon_slots.size():
		return false
	return _weapon_slots[slot_index] != &""

func get_slot_icon(slot_index: int) -> Texture2D:
	if slot_index < 0 or slot_index >= _weapon_slots.size():
		return null
	var ability_id: StringName = _weapon_slots[slot_index]
	if ability_id == &"":
		return null
	var state: WeaponAbilityState = _get_ability_state(ability_id)
	if state == null:
		return null
	return state.icon

func get_weapon_upgrade_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []

	for slot_index: int in range(_weapon_slots.size()):
		var ability_id: StringName = _weapon_slots[slot_index]
		if ability_id == &"":
			continue
		var state: WeaponAbilityState = _get_ability_state(ability_id)
		if state == null:
			continue

		for upgrade_id: StringName in state.available_upgrade_ids:
			if not _can_offer_upgrade(state, upgrade_id):
				continue
			options.append(_build_weapon_upgrade_option(state, upgrade_id))

	return options

func apply_weapon_upgrade(ability_id: StringName, upgrade_id: StringName) -> bool:
	var state: WeaponAbilityState = _get_ability_state(ability_id)
	if state == null:
		return false
	if not state.is_unlocked:
		return false
	if not _can_offer_upgrade(state, upgrade_id):
		return false

	match upgrade_id:
		UPGRADE_COST:
			state.cost_upgrade_count += 1
		UPGRADE_DAMAGE:
			state.damage_upgrade_count += 1
		UPGRADE_PIERCE:
			state.pierce_upgrade_count += 1
		UPGRADE_SPEED:
			state.speed_upgrade_count += 1
		UPGRADE_BOUNCE:
			state.bounce_upgrade_count += 1
		UPGRADE_SIZE:
			state.size_upgrade_count += 1
		UPGRADE_ABSORB:
			state.barrier_absorb_upgrade_count += 1
		UPGRADE_LIFETIME:
			state.barrier_lifetime_upgrade_count += 1
		UPGRADE_REFLECT:
			state.barrier_reflect_unlocked = true
		UPGRADE_CHARGE_SPEED:
			state.charge_speed_upgrade_count += 1
		_:
			return false

	return true

func get_unlockable_weapon_options() -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	for ability_id: StringName in [ABILITY_CHARGED_KI_BLAST, ABILITY_BARRIER, ABILITY_ENERGY_BALL]:
		var state: WeaponAbilityState = _get_ability_state(ability_id)
		if state == null or state.is_unlocked:
			continue
		options.append({
			"option_type": OPTION_TYPE_NEW_WEAPON,
			"ability_id": ability_id,
			"title": "Neue Ability: %s" % state.display_name,
			"description": _new_weapon_description(state),
			"icon": _get_option_icon_for_ability(state)
		})
	return options

func unlock_weapon_in_slot(ability_id: StringName, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _weapon_slots.size():
		return false
	if _weapon_slots[slot_index] != &"":
		return false

	var state: WeaponAbilityState = _get_ability_state(ability_id)
	if state == null or state.is_unlocked:
		return false

	state.is_unlocked = true
	state.slot_index = slot_index
	_weapon_slots[slot_index] = ability_id
	weapon_slots_changed.emit()
	return true

func _setup_weapon_definitions() -> void:
	_abilities.clear()
	_weapon_slots = [&"", &"", &""]

	var ki_blast: WeaponAbilityState = WeaponAbilityState.new()
	ki_blast.ability_id = ABILITY_KI_BLAST
	ki_blast.slot_index = 0
	ki_blast.is_unlocked = true
	ki_blast.is_chargeable = false
	ki_blast.projectile_scene = KI_BLAST_SCENE
	ki_blast.base_cost = 10
	ki_blast.cost_upgrade_step = 1
	ki_blast.min_cost = 1
	ki_blast.base_damage_min = 1
	ki_blast.base_damage_max = 1
	ki_blast.base_speed = 360.0
	ki_blast.speed_upgrade_factor = 1.2
	ki_blast.base_size = 0.7
	ki_blast.size_upgrade_factor = 1.2
	ki_blast.base_pierce_amount = 0
	ki_blast.base_bounce_amount = 0
	ki_blast.available_upgrade_ids = [UPGRADE_COST, UPGRADE_DAMAGE, UPGRADE_PIERCE, UPGRADE_SPEED, UPGRADE_BOUNCE, UPGRADE_SIZE]
	_apply_ability_visuals(
		ki_blast,
		"Ki-Blast",
		_make_atlas_icon(FALLBACK_ICON_KI_BLAST, Rect2(0, 0, 5, 19)),
		_make_atlas_icon(FALLBACK_ICON_KI_BLAST, Rect2(0, 0, 5, 19))
	)
	_abilities[ABILITY_KI_BLAST] = ki_blast
	_weapon_slots[0] = ABILITY_KI_BLAST

	var charged_ki_blast: WeaponAbilityState = WeaponAbilityState.new()
	charged_ki_blast.ability_id = ABILITY_CHARGED_KI_BLAST
	charged_ki_blast.is_chargeable = true
	charged_ki_blast.projectile_scene = CHARGED_KI_BLAST_SCENE
	charged_ki_blast.charge_vfx_scene = CHARGING_KI_BLAST_SCENE
	charged_ki_blast.base_cost = 30
	charged_ki_blast.cost_upgrade_step = 2
	charged_ki_blast.min_cost = 1
	charged_ki_blast.base_damage_min = 2
	charged_ki_blast.base_damage_max = 5
	charged_ki_blast.base_charge_time = 3.0
	charged_ki_blast.base_speed = 320.0
	charged_ki_blast.speed_upgrade_factor = 1.2
	charged_ki_blast.base_size = 1.0
	charged_ki_blast.size_upgrade_factor = 1.2
	charged_ki_blast.base_pierce_amount = 0
	charged_ki_blast.base_bounce_amount = 0
	charged_ki_blast.available_upgrade_ids = [UPGRADE_COST, UPGRADE_DAMAGE, UPGRADE_PIERCE, UPGRADE_SPEED, UPGRADE_BOUNCE, UPGRADE_SIZE]
	_apply_ability_visuals(
		charged_ki_blast,
		"Charged-Ki-Blast",
		_make_atlas_icon(FALLBACK_ICON_CHARGED_KI_BLAST, Rect2(0, 0, 6, 17)),
		_make_atlas_icon(FALLBACK_ICON_CHARGED_KI_BLAST, Rect2(0, 0, 6, 17))
	)
	_abilities[ABILITY_CHARGED_KI_BLAST] = charged_ki_blast

	var barrier: WeaponAbilityState = WeaponAbilityState.new()
	barrier.ability_id = ABILITY_BARRIER
	barrier.is_chargeable = false
	barrier.base_cost = 30
	barrier.cost_upgrade_step = 2
	barrier.min_cost = 1
	barrier.barrier_base_absorb = 5
	barrier.barrier_absorb_upgrade_step = 2
	barrier.barrier_base_lifetime = 10.0
	barrier.barrier_lifetime_upgrade_step = 2.0
	barrier.available_upgrade_ids = [UPGRADE_COST, UPGRADE_ABSORB, UPGRADE_LIFETIME, UPGRADE_REFLECT]
	_apply_ability_visuals(
		barrier,
		"Barrier",
		FALLBACK_ICON_BARRIER,
		FALLBACK_ICON_BARRIER
	)
	_abilities[ABILITY_BARRIER] = barrier

	var energy_ball: WeaponAbilityState = WeaponAbilityState.new()
	energy_ball.ability_id = ABILITY_ENERGY_BALL
	energy_ball.is_chargeable = true
	energy_ball.projectile_scene = ENERGY_BALL_SCENE
	energy_ball.charge_vfx_scene = CHARGING_ENERGY_BALL_SCENE
	energy_ball.base_cost = 50
	energy_ball.cost_upgrade_step = 2
	energy_ball.min_cost = 1
	energy_ball.base_damage_min = 5
	energy_ball.base_damage_max = 10
	energy_ball.base_charge_time = 5.0
	energy_ball.charge_time_reduction_step = 1.0
	energy_ball.min_charge_time = 1.0
	energy_ball.base_speed = 70.0
	energy_ball.base_size = 1.0
	energy_ball.size_upgrade_factor = 1.1
	energy_ball.base_pierce_amount = -1
	energy_ball.base_bounce_amount = 0
	energy_ball.available_upgrade_ids = [UPGRADE_COST, UPGRADE_DAMAGE, UPGRADE_SIZE, UPGRADE_CHARGE_SPEED]
	_apply_ability_visuals(
		energy_ball,
		"Energy-Ball",
		_make_atlas_icon(FALLBACK_ICON_ENERGY_BALL, Rect2(32, 32, 32, 32)),
		_make_atlas_icon(FALLBACK_ICON_ENERGY_BALL, Rect2(32, 32, 32, 32))
	)
	_abilities[ABILITY_ENERGY_BALL] = energy_ball

func _handle_weapon_input(delta: float) -> void:
	if is_charging():
		_update_charge_flow(delta)
		return

	for slot_index: int in range(_weapon_slots.size()):
		var action_name: StringName = SLOT_ACTIONS[slot_index]
		if not Input.is_action_just_pressed(action_name):
			continue
		var ability_id: StringName = _weapon_slots[slot_index]
		if ability_id == &"":
			continue
		var state: WeaponAbilityState = _get_ability_state(ability_id)
		if state == null:
			continue

		if state.is_chargeable:
			var charge_cost: int = _get_current_cost(state)
			if not _player.has_mana(charge_cost):
				continue
			_begin_charge(state)
			return

		_activate_instant_weapon(state)
		return

func _update_charge_flow(delta: float) -> void:
	var state: WeaponAbilityState = _get_ability_state(_charging_ability_id)
	if state == null:
		_finish_charge()
		return

	var action_name: StringName = _action_for_slot(state.slot_index)
	var max_charge_time: float = _get_current_charge_time(state)

	if Input.is_action_pressed(action_name):
		_charge_time = min(_charge_time + delta, max_charge_time)
		_aim_direction = _get_mouse_aim_direction()
		_update_charge_vfx()

	if Input.is_action_just_released(action_name):
		var mana_cost: int = _get_current_cost(state)
		if not _player.consume_mana(mana_cost):
			_finish_charge()
			return

		_fire_charge_weapon(state)
		_finish_charge()

func _activate_instant_weapon(state: WeaponAbilityState) -> void:
	var mana_cost: int = _get_current_cost(state)
	if not _player.consume_mana(mana_cost):
		return

	if state.ability_id == ABILITY_KI_BLAST:
		_fire_projectile_weapon(state, _get_current_min_damage(state), false)
		_play_if_available(_small_laser_shot_player)
		return

	if state.ability_id == ABILITY_BARRIER:
		_player.activate_barrier(
			_get_current_barrier_lifetime(state),
			_get_current_barrier_absorb(state),
			state.barrier_reflect_unlocked
		)
		return

func _fire_charge_weapon(state: WeaponAbilityState) -> void:
	if state.ability_id == ABILITY_CHARGED_KI_BLAST:
		_fire_projectile_weapon(state, _get_charged_damage(state), true)
		_play_if_available(_big_laser_shot_player)
		return

	if state.ability_id == ABILITY_ENERGY_BALL:
		_fire_projectile_weapon(state, _get_charged_damage(state), true)
		_play_if_available(_energy_ball_release_player)
		return

func _fire_projectile_weapon(state: WeaponAbilityState, damage: int, from_charge: bool) -> void:
	if state.projectile_scene == null:
		return

	var dir: Vector2 = _get_mouse_aim_direction()
	if dir == Vector2.ZERO:
		dir = _aim_direction
	if dir == Vector2.ZERO:
		dir = Vector2.DOWN
	_aim_direction = dir

	var projectile: Area2D = state.projectile_scene.instantiate() as Area2D
	if projectile == null:
		return

	projectile.global_position = _get_spawn_position(state, dir, from_charge)
	projectile.direction = dir
	if state.ability_id == ABILITY_ENERGY_BALL:
		projectile.rotation = 0.0
	else:
		projectile.rotation = dir.angle() + deg_to_rad(90.0)

	projectile.configure(
		damage,
		_get_current_speed(state),
		_get_current_size(state),
		_get_current_pierce_amount(state),
		_get_current_bounce_amount(state),
		_player
	)

	shoot_animation_requested.emit(dir)
	get_tree().current_scene.add_child(projectile)

func _begin_charge(state: WeaponAbilityState) -> void:
	_charging_ability_id = state.ability_id
	charging_state_changed.emit(true)
	_charge_time = 0.0
	_aim_direction = _get_mouse_aim_direction()
	_start_charge_vfx(state)

func _finish_charge() -> void:
	_charging_ability_id = &""
	_charge_time = 0.0
	_stop_charge_vfx()
	charging_state_changed.emit(false)

func _start_charge_vfx(state: WeaponAbilityState) -> void:
	if _charge_vfx != null:
		return
	if state.charge_vfx_scene == null:
		return

	_charge_vfx = state.charge_vfx_scene.instantiate() as Area2D
	_player.add_child(_charge_vfx)
	_charge_vfx_sprite = _charge_vfx.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	if _charge_vfx_sprite != null:
		_charge_vfx_sprite.play("charging")
		if not _charge_vfx_sprite.animation_finished.is_connected(_on_charge_vfx_anim_finished):
			_charge_vfx_sprite.animation_finished.connect(_on_charge_vfx_anim_finished)
	_update_charge_vfx()

	if state.ability_id == ABILITY_ENERGY_BALL:
		_play_loop_if_stopped(_energy_ball_charge_loop_player)
	else:
		_play_loop_if_stopped(_weapon_charge_loop_player)

func _on_charge_vfx_anim_finished() -> void:
	if not is_charging() or _charge_vfx_sprite == null:
		return
	if _charge_vfx_sprite.animation != "charging":
		return

	var state: WeaponAbilityState = _get_ability_state(_charging_ability_id)
	if state == null:
		return
	if state.ability_id == ABILITY_ENERGY_BALL:
		_charge_vfx_sprite.play(&"fully_charged")
	else:
		_charge_vfx_sprite.play(&"max_charge")

func _update_charge_vfx() -> void:
	if _charge_vfx == null:
		return
	var state: WeaponAbilityState = _get_ability_state(_charging_ability_id)
	if state == null:
		return
	var dir: Vector2 = _get_mouse_aim_direction()
	if dir == Vector2.ZERO:
		dir = _aim_direction
	_charge_vfx.global_position = _get_spawn_position(state, dir, true)

func _stop_charge_vfx() -> void:
	_stop_if_playing(_weapon_charge_loop_player)
	_stop_if_playing(_energy_ball_charge_loop_player)
	if _charge_vfx == null:
		return
	_charge_vfx.queue_free()
	_charge_vfx = null
	_charge_vfx_sprite = null

func _get_spawn_position(state: WeaponAbilityState, dir: Vector2, from_charge: bool) -> Vector2:
	if from_charge and state.ability_id == ABILITY_ENERGY_BALL and _muzzle_up_middle != null:
		return _muzzle_up_middle.global_position
	return _get_muzzle_world_position(dir)

func _get_muzzle_world_position(dir: Vector2) -> Vector2:
	if abs(dir.x) > abs(dir.y):
		var local_side: Vector2 = _muzzle_side.position
		if dir.x < 0.0:
			local_side.x *= -1.0
		return _player.to_global(local_side)
	if dir.y < 0.0:
		return _muzzle_up.global_position
	return _muzzle_down.global_position

func _get_mouse_aim_direction() -> Vector2:
	var to_mouse: Vector2 = _player.get_global_mouse_position() - _player.global_position
	if to_mouse.length_squared() > 0.0001:
		return to_mouse.normalized()
	return _aim_direction

func _can_offer_upgrade(state: WeaponAbilityState, upgrade_id: StringName) -> bool:
	if upgrade_id == UPGRADE_COST:
		return _get_current_cost(state) > state.min_cost
	if upgrade_id == UPGRADE_REFLECT:
		return not state.barrier_reflect_unlocked
	if upgrade_id == UPGRADE_CHARGE_SPEED:
		return _get_current_charge_time(state) > state.min_charge_time
	return true

func _build_weapon_upgrade_option(state: WeaponAbilityState, upgrade_id: StringName) -> Dictionary:
	var upgrade_definition: UpgradeDefinition = _get_upgrade_definition(state.ability_id, upgrade_id)
	var title: String = "%s" % state.display_name
	var description: String = ""

	match upgrade_id:
		UPGRADE_COST:
			title += ": Cost"
			description = "Ki-Kosten %d -> %d" % [_get_current_cost(state), max(_get_current_cost(state) - state.cost_upgrade_step, state.min_cost)]
		UPGRADE_DAMAGE:
			title += ": Damage"
			description = "Schaden +1"
		UPGRADE_PIERCE:
			title += ": Pierce"
			description = "Durchdringt +1 Enemy"
		UPGRADE_SPEED:
			title += ": Speed"
			description = "Projektil-Speed +20%"
		UPGRADE_BOUNCE:
			title += ": Bounce"
			description = "Abpraller +1"
		UPGRADE_SIZE:
			if state.ability_id == ABILITY_ENERGY_BALL:
				title += ": Size"
				description = "Groesse +10%"
			else:
				title += ": Size"
				description = "Groesse +20%"
		UPGRADE_ABSORB:
			title += ": Absorb"
			description = "Absorption +%d" % state.barrier_absorb_upgrade_step
		UPGRADE_LIFETIME:
			title += ": Lifetime"
			description = "Barrier-Laufzeit +%ds" % int(state.barrier_lifetime_upgrade_step)
		UPGRADE_REFLECT:
			title += ": Reflect"
			description = "Reflektiert absorbierten Schaden"
		UPGRADE_CHARGE_SPEED:
			title += ": Charge-Speed"
			description = "Max-Loadzeit -1s (mind. 1s)"

	if upgrade_definition != null:
		if not upgrade_definition.title.strip_edges().is_empty():
			title = upgrade_definition.title
		if not upgrade_definition.description.strip_edges().is_empty():
			description = upgrade_definition.description

	return {
		"option_type": OPTION_TYPE_WEAPON_UPGRADE,
		"ability_id": state.ability_id,
		"upgrade_id": upgrade_id,
		"title": title,
		"description": description,
		"icon": _get_option_icon_for_upgrade(state, upgrade_definition)
	}

func _new_weapon_description(state: WeaponAbilityState) -> String:
	if state.ability_id == ABILITY_CHARGED_KI_BLAST:
		return "Chargebar bis 3s, 2-5 Schaden"
	if state.ability_id == ABILITY_BARRIER:
		return "10s Barrier, absorbiert 5 Schaden"
	if state.ability_id == ABILITY_ENERGY_BALL:
		return "Chargebar bis 5s, pierct alle Enemies"
	return ""

func _load_progression_definitions() -> void:
	_ability_definitions.clear()
	_upgrade_definitions.clear()
	_load_ability_definitions_from_dir(ABILITY_DEFINITIONS_DIR)
	_load_upgrade_definitions_from_dir(UPGRADE_DEFINITIONS_DIR)

func _load_ability_definitions_from_dir(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path: String = dir_path.path_join(file_name)
			var resource: Resource = load(full_path)
			var definition: AbilityDefinition = resource as AbilityDefinition
			if definition != null:
				var definition_id: StringName = definition.id
				if definition_id == &"":
					definition_id = StringName(file_name.get_basename())
				_ability_definitions[definition_id] = definition
		file_name = dir.get_next()
	dir.list_dir_end()

func _load_upgrade_definitions_from_dir(dir_path: String) -> void:
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path: String = dir_path.path_join(file_name)
			var resource: Resource = load(full_path)
			var definition: UpgradeDefinition = resource as UpgradeDefinition
			if definition != null:
				var definition_id: StringName = definition.id
				if definition_id == &"":
					definition_id = StringName(file_name.get_basename())
				_upgrade_definitions[definition_id] = definition
		file_name = dir.get_next()
	dir.list_dir_end()

func _apply_ability_visuals(
	state: WeaponAbilityState,
	fallback_display_name: String,
	fallback_action_bar_icon: Texture2D,
	fallback_upgrade_icon: Texture2D
) -> void:
	var display_name: String = fallback_display_name
	var action_bar_icon: Texture2D = fallback_action_bar_icon
	var upgrade_icon: Texture2D = fallback_upgrade_icon

	var ability_definition: AbilityDefinition = _ability_definitions.get(state.ability_id) as AbilityDefinition
	if ability_definition != null:
		if not ability_definition.display_name.strip_edges().is_empty():
			display_name = ability_definition.display_name
		if _is_valid_icon(ability_definition.action_bar_icon):
			action_bar_icon = ability_definition.action_bar_icon
		if _is_valid_icon(ability_definition.level_up_icon):
			upgrade_icon = ability_definition.level_up_icon
		if _is_valid_icon(ability_definition.upgrade_icon):
			upgrade_icon = ability_definition.upgrade_icon

	if not _is_valid_icon(action_bar_icon):
		action_bar_icon = _load_icon_by_ability_id(state.ability_id)
	if not _is_valid_icon(upgrade_icon):
		upgrade_icon = _load_icon_by_ability_id(state.ability_id)
	if not _is_valid_icon(upgrade_icon):
		upgrade_icon = action_bar_icon

	state.display_name = display_name
	state.icon = action_bar_icon
	state.upgrade_icon = upgrade_icon

func _load_icon_by_ability_id(ability_id: StringName) -> Texture2D:
	var icon_path: String = ICONS_DIR.path_join("%s_atlas.tres" % String(ability_id))
	if not ResourceLoader.exists(icon_path):
		return null
	var icon: Texture2D = load(icon_path) as Texture2D
	if not _is_valid_icon(icon):
		return null
	return icon

func _get_upgrade_definition(ability_id: StringName, upgrade_id: StringName) -> UpgradeDefinition:
	var combined_id: StringName = StringName("%s_%s" % [String(ability_id), String(upgrade_id)])
	var definition: UpgradeDefinition = _upgrade_definitions.get(combined_id) as UpgradeDefinition
	if definition != null:
		return definition
	definition = _upgrade_definitions.get(upgrade_id) as UpgradeDefinition
	if definition == null:
		return null
	if definition.ability_id != &"" and definition.ability_id != ability_id:
		return null
	return definition

func _get_option_icon_for_ability(state: WeaponAbilityState) -> Texture2D:
	if state.upgrade_icon != null:
		return state.upgrade_icon
	return state.icon

func _get_option_icon_for_upgrade(state: WeaponAbilityState, definition: UpgradeDefinition) -> Texture2D:
	if definition != null and _is_valid_icon(definition.icon):
		return definition.icon
	return _get_option_icon_for_ability(state)

func _is_valid_icon(icon: Texture2D) -> bool:
	if icon == null:
		return false
	var atlas_icon: AtlasTexture = icon as AtlasTexture
	if atlas_icon != null and atlas_icon.atlas == null:
		return false
	return true

func _get_current_cost(state: WeaponAbilityState) -> int:
	return max(state.base_cost - (state.cost_upgrade_count * state.cost_upgrade_step), state.min_cost)

func _get_current_min_damage(state: WeaponAbilityState) -> int:
	return state.base_damage_min + state.damage_upgrade_count

func _get_current_max_damage(state: WeaponAbilityState) -> int:
	return state.base_damage_max + state.damage_upgrade_count

func _get_current_charge_time(state: WeaponAbilityState) -> float:
	if state.base_charge_time <= 0.0:
		return 0.0
	var reduced_time: float = state.base_charge_time - (state.charge_speed_upgrade_count * state.charge_time_reduction_step)
	return max(reduced_time, state.min_charge_time)

func _get_current_speed(state: WeaponAbilityState) -> float:
	return state.base_speed * pow(state.speed_upgrade_factor, state.speed_upgrade_count)

func _get_current_size(state: WeaponAbilityState) -> float:
	return state.base_size * pow(state.size_upgrade_factor, state.size_upgrade_count)

func _get_current_pierce_amount(state: WeaponAbilityState) -> int:
	if state.base_pierce_amount < 0:
		return -1
	return state.base_pierce_amount + state.pierce_upgrade_count

func _get_current_bounce_amount(state: WeaponAbilityState) -> int:
	return state.base_bounce_amount + state.bounce_upgrade_count

func _get_current_barrier_absorb(state: WeaponAbilityState) -> int:
	return state.barrier_base_absorb + (state.barrier_absorb_upgrade_count * state.barrier_absorb_upgrade_step)

func _get_current_barrier_lifetime(state: WeaponAbilityState) -> float:
	return state.barrier_base_lifetime + (state.barrier_lifetime_upgrade_count * state.barrier_lifetime_upgrade_step)

func _get_charged_damage(state: WeaponAbilityState) -> int:
	var max_charge_time: float = _get_current_charge_time(state)
	if max_charge_time <= 0.0:
		return _get_current_min_damage(state)
	var ratio: float = clamp(_charge_time / max_charge_time, 0.0, 1.0)
	var damage_float: float = lerpf(float(_get_current_min_damage(state)), float(_get_current_max_damage(state)), ratio)
	return int(floor(damage_float + 0.0001))

func _action_for_slot(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= SLOT_ACTIONS.size():
		return &""
	return SLOT_ACTIONS[slot_index]

func _make_atlas_icon(atlas_texture: Texture2D, region: Rect2) -> Texture2D:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = atlas_texture
	atlas.region = region
	return atlas

func _get_ability_state(ability_id: StringName) -> WeaponAbilityState:
	if not _abilities.has(ability_id):
		return null
	return _abilities[ability_id] as WeaponAbilityState

func _play_if_available(player: AudioStreamPlayer) -> void:
	if player != null:
		player.play()

func _play_loop_if_stopped(player: AudioStreamPlayer) -> void:
	if player != null and not player.playing:
		player.play()

func _stop_if_playing(player: AudioStreamPlayer) -> void:
	if player != null and player.playing:
		player.stop()
