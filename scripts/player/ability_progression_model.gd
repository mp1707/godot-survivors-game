extends RefCounted
class_name AbilityProgressionModel

signal weapon_unlocked(slot_index: int, ability_id: StringName)
signal weapon_upgraded(ability_id: StringName, upgrade_id: StringName)
signal utility_applied(upgrade_id: StringName)

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

var _weapon_slots: Array[StringName] = []
var _abilities: Dictionary = {}
var _ability_definitions: Dictionary = {}
var _upgrade_definitions: Dictionary = {}
var _catalog: ProgressionCatalog

var _utility_states: Dictionary = {}
var _weapon_upgrade_applier: WeaponUpgradeApplier
var _utility_upgrade_applier: UtilityUpgradeApplier

func initialize(slot_count: int, catalog: ProgressionCatalog) -> void:
	_catalog = catalog
	_initialize_empty_slots(slot_count)
	_load_progression_definitions()
	_setup_weapon_abilities()
	_setup_utility_upgrades()

func set_weapon_upgrade_applier(applier: WeaponUpgradeApplier) -> void:
	_weapon_upgrade_applier = applier

func set_utility_upgrade_applier(applier: UtilityUpgradeApplier) -> void:
	_utility_upgrade_applier = applier

# --- Unified level-up API ---

func get_level_up_options(current_level: int) -> Array[LevelUpOption]:
	var unlock_options: Array[LevelUpOption] = get_unlockable_weapon_options(current_level)
	var options: Array[LevelUpOption] = []
	options.append_array(unlock_options)
	options.append_array(get_weapon_upgrade_options())
	options.append_array(get_utility_upgrade_options())
	return options

func apply_option(option: LevelUpOption) -> bool:
	if option == null:
		return false
	match option.option_type:
		LevelUpOption.TYPE_NEW_WEAPON:
			return unlock_weapon_in_next_free_slot(option.ability_id)
		LevelUpOption.TYPE_WEAPON_UPGRADE:
			return apply_weapon_upgrade(option.ability_id, option.upgrade_id)
		LevelUpOption.TYPE_PLAYER_UPGRADE:
			return apply_utility_upgrade(option.upgrade_id)
	return false

# --- Weapon slot queries ---

func has_weapon_in_slot(slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _weapon_slots.size():
		return false
	return _weapon_slots[slot_index] != &""

func get_slot_ability_id(slot_index: int) -> StringName:
	if slot_index < 0 or slot_index >= _weapon_slots.size():
		return &""
	return _weapon_slots[slot_index]

func get_slot_icon(slot_index: int) -> Texture2D:
	var ability_id: StringName = get_slot_ability_id(slot_index)
	if ability_id == &"":
		return null
	var state: WeaponAbilityState = get_ability_state(ability_id)
	if state == null:
		return null
	return state.icon

# --- Weapon level-up building blocks ---

func get_unlockable_weapon_options(current_level: int) -> Array[LevelUpOption]:
	if get_next_free_slot_index() < 0:
		return []

	var options: Array[LevelUpOption] = []
	for state: WeaponAbilityState in _get_unlockable_states(current_level):
		options.append(
			LevelUpOption.make_new_weapon(
				state.ability_id,
				"Neue Ability: %s" % state.display_name,
				_get_new_weapon_description(state),
				_get_option_icon_for_ability(state)
			)
		)
	return options

func has_unlock_milestone(current_level: int) -> bool:
	if get_next_free_slot_index() < 0:
		return false
	for state_value: Variant in _abilities.values():
		var state: WeaponAbilityState = state_value as WeaponAbilityState
		if state == null or state.is_unlocked:
			continue
		if state.unlock_level == current_level:
			return true
	return false

func unlock_weapon_in_next_free_slot(ability_id: StringName) -> bool:
	var next_free_slot_index: int = get_next_free_slot_index()
	if next_free_slot_index < 0:
		return false
	var unlocked: bool = _unlock_weapon_in_slot(ability_id, next_free_slot_index)
	if unlocked:
		weapon_unlocked.emit(next_free_slot_index, ability_id)
	return unlocked

func get_weapon_upgrade_options() -> Array[LevelUpOption]:
	var options: Array[LevelUpOption] = []

	for slot_index: int in range(_weapon_slots.size()):
		var ability_id: StringName = _weapon_slots[slot_index]
		if ability_id == &"":
			continue
		var state: WeaponAbilityState = get_ability_state(ability_id)
		if state == null:
			continue

		for upgrade_id: StringName in state.available_upgrade_ids:
			if not _can_offer_upgrade(state, upgrade_id):
				continue
			var option: LevelUpOption = _build_weapon_upgrade_option(state, upgrade_id)
			if option != null:
				options.append(option)

	return options

func apply_weapon_upgrade(ability_id: StringName, upgrade_id: StringName) -> bool:
	var state: WeaponAbilityState = get_ability_state(ability_id)
	if state == null:
		return false
	if not state.is_unlocked:
		return false
	if not _can_offer_upgrade(state, upgrade_id):
		return false
	if _weapon_upgrade_applier == null:
		push_error("AbilityProgressionModel: WeaponUpgradeApplier is not configured.")
		return false

	var definition: UpgradeDefinition = _get_upgrade_definition(ability_id, upgrade_id)
	if definition == null:
		push_error("AbilityProgressionModel: missing upgrade definition '%s' for ability '%s'." % [String(upgrade_id), String(ability_id)])
		return false
	if not _weapon_upgrade_applier.apply_upgrade(state, definition):
		return false

	weapon_upgraded.emit(ability_id, upgrade_id)
	return true

# --- Utility upgrade API ---

func get_utility_upgrade_options() -> Array[LevelUpOption]:
	var options: Array[LevelUpOption] = []
	for state_value: Variant in _utility_states.values():
		var state: UtilityUpgradeState = state_value as UtilityUpgradeState
		if state == null or state.definition == null:
			continue
		if state.is_max_stacked():
			continue
		var definition: UpgradeDefinition = state.definition
		options.append(
			LevelUpOption.make_player_upgrade(
				definition.id,
				definition.title,
				definition.description,
				definition.icon
			)
		)
	return options

func apply_utility_upgrade(upgrade_id: StringName) -> bool:
	var state: UtilityUpgradeState = _utility_states.get(upgrade_id) as UtilityUpgradeState
	if state == null or state.definition == null:
		return false
	if state.is_max_stacked():
		return false
	if _utility_upgrade_applier == null:
		push_error("AbilityProgressionModel: UtilityUpgradeApplier is not configured.")
		return false
	if not _utility_upgrade_applier.apply_upgrade(state.definition):
		return false

	state.stack_count += 1
	utility_applied.emit(upgrade_id)
	return true

func get_utility_stack_count(upgrade_id: StringName) -> int:
	var state: UtilityUpgradeState = _utility_states.get(upgrade_id) as UtilityUpgradeState
	if state == null:
		return 0
	return state.stack_count

# --- Stat calculators ---

func get_ability_state(ability_id: StringName) -> WeaponAbilityState:
	if not _abilities.has(ability_id):
		return null
	return _abilities[ability_id] as WeaponAbilityState

func get_current_cost(state: WeaponAbilityState) -> int:
	return max(state.base_cost - (state.cost_upgrade_count * state.cost_upgrade_step), state.min_cost)

func get_current_min_damage(state: WeaponAbilityState) -> int:
	return state.base_damage_min + state.damage_upgrade_count

func get_current_max_damage(state: WeaponAbilityState) -> int:
	return state.base_damage_max + state.damage_upgrade_count

func get_current_charge_time(state: WeaponAbilityState) -> float:
	if state.base_charge_time <= 0.0:
		return 0.0
	var reduced_time: float = state.base_charge_time - (state.charge_speed_upgrade_count * state.charge_time_reduction_step)
	return max(reduced_time, state.min_charge_time)

func get_current_speed(state: WeaponAbilityState) -> float:
	return state.base_speed * pow(state.speed_upgrade_factor, state.speed_upgrade_count)

func get_current_size(state: WeaponAbilityState) -> float:
	return state.base_size * pow(state.size_upgrade_factor, state.size_upgrade_count)

func get_current_pierce_amount(state: WeaponAbilityState) -> int:
	if state.base_pierce_amount < 0:
		return -1
	return state.base_pierce_amount + state.pierce_upgrade_count

func get_current_bounce_amount(state: WeaponAbilityState) -> int:
	return state.base_bounce_amount + state.bounce_upgrade_count

func get_current_barrier_absorb(state: WeaponAbilityState) -> int:
	return state.barrier_base_absorb + (state.barrier_absorb_upgrade_count * state.barrier_absorb_upgrade_step)

func get_current_barrier_lifetime(state: WeaponAbilityState) -> float:
	return state.barrier_base_lifetime + (state.barrier_lifetime_upgrade_count * state.barrier_lifetime_upgrade_step)

func get_charged_damage(state: WeaponAbilityState, current_charge_time: float) -> int:
	var max_charge_time: float = get_current_charge_time(state)
	if max_charge_time <= 0.0:
		return get_current_min_damage(state)
	var ratio: float = clamp(current_charge_time / max_charge_time, 0.0, 1.0)
	var damage_float: float = lerpf(float(get_current_min_damage(state)), float(get_current_max_damage(state)), ratio)
	return int(floor(damage_float + 0.0001))

func get_next_free_slot_index() -> int:
	for slot_index: int in range(_weapon_slots.size()):
		if _weapon_slots[slot_index] == &"":
			return slot_index
	return -1

# --- Internal setup ---

func _initialize_empty_slots(slot_count: int) -> void:
	_weapon_slots.clear()
	for _index: int in range(max(slot_count, 0)):
		_weapon_slots.append(&"")

func _setup_weapon_abilities() -> void:
	_abilities.clear()

	var definitions: Array[AbilityDefinition] = []
	for definition_value: Variant in _ability_definitions.values():
		var definition: AbilityDefinition = definition_value as AbilityDefinition
		if definition == null:
			continue
		if definition.id == &"":
			continue
		if definition.progression_domain != AbilityDefinition.DOMAIN_WEAPON:
			continue
		definitions.append(definition)

	definitions.sort_custom(func(a: AbilityDefinition, b: AbilityDefinition) -> bool:
		return String(a.id) < String(b.id)
	)

	for definition: AbilityDefinition in definitions:
		var state: WeaponAbilityState = WeaponAbilityState.new()
		state.apply_definition(definition)
		_apply_ability_visuals(state, definition)
		_abilities[state.ability_id] = state

	for definition: AbilityDefinition in definitions:
		if not definition.starts_unlocked:
			continue
		var state: WeaponAbilityState = get_ability_state(definition.id)
		if state == null:
			continue
		var preferred_slot: int = definition.start_slot_index
		if preferred_slot < 0 or preferred_slot >= _weapon_slots.size() or _weapon_slots[preferred_slot] != &"":
			preferred_slot = get_next_free_slot_index()
		if preferred_slot >= 0:
			_unlock_weapon_in_slot(definition.id, preferred_slot)

func _setup_utility_upgrades() -> void:
	_utility_states.clear()
	for upgrade_value: Variant in _upgrade_definitions.values():
		var upgrade: UpgradeDefinition = upgrade_value as UpgradeDefinition
		if upgrade == null or upgrade.id == &"":
			continue
		if upgrade.get_domain() != UpgradeDefinition.DOMAIN_UTILITY:
			continue
		_register_utility_state(upgrade)
	if _utility_states.is_empty():
		push_error("AbilityProgressionModel: no utility upgrades configured in catalog.")

func _register_utility_state(upgrade: UpgradeDefinition) -> void:
	if _utility_states.has(upgrade.id):
		return
	var state: UtilityUpgradeState = UtilityUpgradeState.new()
	state.upgrade_id = upgrade.id
	state.definition = upgrade
	_utility_states[upgrade.id] = state

func _unlock_weapon_in_slot(ability_id: StringName, slot_index: int) -> bool:
	if slot_index < 0 or slot_index >= _weapon_slots.size():
		return false
	if _weapon_slots[slot_index] != &"":
		return false

	var state: WeaponAbilityState = get_ability_state(ability_id)
	if state == null or state.is_unlocked:
		return false

	state.is_unlocked = true
	state.slot_index = slot_index
	_weapon_slots[slot_index] = ability_id
	return true

func _get_unlockable_states(current_level: int) -> Array[WeaponAbilityState]:
	var unlockable_states: Array[WeaponAbilityState] = []
	for state_value: Variant in _abilities.values():
		var state: WeaponAbilityState = state_value as WeaponAbilityState
		if state == null or state.is_unlocked:
			continue
		if state.unlock_level > current_level:
			continue
		unlockable_states.append(state)

	unlockable_states.sort_custom(func(a: WeaponAbilityState, b: WeaponAbilityState) -> bool:
		if a.unlock_level == b.unlock_level:
			return String(a.ability_id) < String(b.ability_id)
		return a.unlock_level < b.unlock_level
	)
	return unlockable_states

func _get_new_weapon_description(state: WeaponAbilityState) -> String:
	if not state.unlock_description.strip_edges().is_empty():
		return state.unlock_description
	if state.behavior == AbilityDefinition.BEHAVIOR_BARRIER:
		return "Aktive Barrier mit Absorption."
	if state.is_chargeable:
		return "Aufladbar fuer hoehere Wirkung."
	return "Neue aktive Ability."

func _can_offer_upgrade(state: WeaponAbilityState, upgrade_id: StringName) -> bool:
	if _weapon_upgrade_applier == null:
		push_error("AbilityProgressionModel: WeaponUpgradeApplier is not configured.")
		return false

	var definition: UpgradeDefinition = _get_upgrade_definition(state.ability_id, upgrade_id)
	if definition == null:
		push_error("AbilityProgressionModel: missing upgrade definition '%s' for ability '%s'." % [String(upgrade_id), String(state.ability_id)])
		return false

	if upgrade_id == UPGRADE_COST:
		return get_current_cost(state) > state.min_cost
	if upgrade_id == UPGRADE_CHARGE_SPEED:
		return get_current_charge_time(state) > state.min_charge_time

	var max_stacks: int = definition.max_stacks
	var stack_count: int = _weapon_upgrade_applier.get_stack_count_for_upgrade(state, definition)
	if max_stacks >= 0 and stack_count >= max_stacks:
		return false

	return true

func _build_weapon_upgrade_option(state: WeaponAbilityState, upgrade_id: StringName) -> LevelUpOption:
	var upgrade_definition: UpgradeDefinition = _get_upgrade_definition(state.ability_id, upgrade_id)
	if upgrade_definition == null:
		return null

	var title: String = "%s: %s" % [state.display_name, _upgrade_display_name(upgrade_id)]
	var description: String = _upgrade_description(state, upgrade_id)

	if not upgrade_definition.title.strip_edges().is_empty():
		title = upgrade_definition.title
	if not upgrade_definition.description.strip_edges().is_empty():
		description = upgrade_definition.description

	return LevelUpOption.make_weapon_upgrade(
		state.ability_id,
		upgrade_id,
		title,
		description,
		_get_option_icon_for_upgrade(state, upgrade_definition)
	)

func _upgrade_display_name(upgrade_key: StringName) -> String:
	match upgrade_key:
		UPGRADE_COST:
			return "Cost"
		UPGRADE_DAMAGE:
			return "Damage"
		UPGRADE_PIERCE:
			return "Pierce"
		UPGRADE_SPEED:
			return "Speed"
		UPGRADE_BOUNCE:
			return "Bounce"
		UPGRADE_SIZE:
			return "Size"
		UPGRADE_ABSORB:
			return "Absorb"
		UPGRADE_LIFETIME:
			return "Lifetime"
		UPGRADE_REFLECT:
			return "Reflect"
		UPGRADE_CHARGE_SPEED:
			return "Charge-Speed"
		_:
			return String(upgrade_key)

func _upgrade_description(state: WeaponAbilityState, upgrade_key: StringName) -> String:
	match upgrade_key:
		UPGRADE_COST:
			return "Ki-Kosten %d -> %d" % [get_current_cost(state), max(get_current_cost(state) - state.cost_upgrade_step, state.min_cost)]
		UPGRADE_DAMAGE:
			return "Schaden +1"
		UPGRADE_PIERCE:
			return "Durchdringt +1 Enemy"
		UPGRADE_SPEED:
			return "Projektil-Speed +20%"
		UPGRADE_BOUNCE:
			return "Abpraller +1"
		UPGRADE_SIZE:
			return "Groesse +10%" if state.ability_id == &"energy_ball" else "Groesse +20%"
		UPGRADE_ABSORB:
			return "Absorption +%d" % state.barrier_absorb_upgrade_step
		UPGRADE_LIFETIME:
			return "Barrier-Laufzeit +%ds" % int(state.barrier_lifetime_upgrade_step)
		UPGRADE_REFLECT:
			return "Reflektiert absorbierten Schaden"
		UPGRADE_CHARGE_SPEED:
			return "Max-Loadzeit -1s (mind. 1s)"
		_:
			return ""

func _load_progression_definitions() -> void:
	_ability_definitions.clear()
	_upgrade_definitions.clear()
	if _catalog == null:
		push_error("AbilityProgressionModel: ProgressionCatalog is required.")
		return

	for ability_definition: AbilityDefinition in _catalog.abilities:
		_register_ability_definition(ability_definition)
	for upgrade_definition: UpgradeDefinition in _catalog.upgrades:
		_register_upgrade_definition(upgrade_definition)

	if _ability_definitions.is_empty():
		push_error("AbilityProgressionModel: catalog contains no valid abilities.")
	if _upgrade_definitions.is_empty():
		push_error("AbilityProgressionModel: catalog contains no valid upgrades.")

func _register_ability_definition(definition: AbilityDefinition) -> void:
	if definition == null:
		push_warning("AbilityProgressionModel: null ability definition in catalog.")
		return
	if definition.id == &"":
		push_error("AbilityProgressionModel: ability without id in catalog.")
		return
	if _ability_definitions.has(definition.id):
		push_error("AbilityProgressionModel: duplicate ability id '%s' in catalog." % String(definition.id))
		return
	_ability_definitions[definition.id] = definition

func _register_upgrade_definition(definition: UpgradeDefinition) -> void:
	if definition == null:
		push_warning("AbilityProgressionModel: null upgrade definition in catalog.")
		return
	if definition.id == &"":
		push_error("AbilityProgressionModel: upgrade without id in catalog.")
		return
	if _upgrade_definitions.has(definition.id):
		push_error("AbilityProgressionModel: duplicate upgrade id '%s' in catalog." % String(definition.id))
		return
	_upgrade_definitions[definition.id] = definition

func _apply_ability_visuals(state: WeaponAbilityState, ability_definition: AbilityDefinition) -> void:
	if ability_definition.display_name.strip_edges().is_empty():
		push_error("AbilityProgressionModel: ability '%s' has empty display_name." % String(ability_definition.id))
	if not _is_valid_icon(ability_definition.action_bar_icon):
		push_error("AbilityProgressionModel: ability '%s' has invalid action_bar_icon." % String(ability_definition.id))
	if not _is_valid_icon(ability_definition.upgrade_icon):
		push_error("AbilityProgressionModel: ability '%s' has invalid upgrade_icon." % String(ability_definition.id))

	state.display_name = ability_definition.display_name
	state.icon = ability_definition.action_bar_icon
	state.upgrade_icon = ability_definition.upgrade_icon

func _get_upgrade_definition(ability_id: StringName, upgrade_id: StringName) -> UpgradeDefinition:
	var definition: UpgradeDefinition = _upgrade_definitions.get(upgrade_id) as UpgradeDefinition
	if definition == null:
		return null
	if definition.ability_id != &"" and definition.ability_id != ability_id:
		return null
	return definition

func _get_option_icon_for_ability(state: WeaponAbilityState) -> Texture2D:
	return state.upgrade_icon

func _get_option_icon_for_upgrade(state: WeaponAbilityState, definition: UpgradeDefinition) -> Texture2D:
	if definition == null:
		return null
	if _is_valid_icon(definition.icon):
		return definition.icon
	if state != null and _is_valid_icon(state.upgrade_icon):
		return state.upgrade_icon
	return null

func _is_valid_icon(icon: Texture2D) -> bool:
	if icon == null:
		return false
	var atlas_icon: AtlasTexture = icon as AtlasTexture
	if atlas_icon != null and atlas_icon.atlas == null:
		return false
	return true
