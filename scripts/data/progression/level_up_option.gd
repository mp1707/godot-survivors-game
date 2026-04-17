extends RefCounted
class_name LevelUpOption

const TYPE_NEW_WEAPON: StringName = &"new_weapon"
const TYPE_WEAPON_UPGRADE: StringName = &"weapon_upgrade"
const TYPE_PLAYER_UPGRADE: StringName = &"player_upgrade"

var option_type: StringName = &""
var ability_id: StringName = &""
var upgrade_id: StringName = &""
var title: String = ""
var description: String = ""
var icon: Texture2D = null

func _init(
	new_option_type: StringName = &"",
	new_title: String = "",
	new_description: String = "",
	new_icon: Texture2D = null,
	new_ability_id: StringName = &"",
	new_upgrade_id: StringName = &""
) -> void:
	option_type = new_option_type
	title = new_title
	description = new_description
	icon = new_icon
	ability_id = new_ability_id
	upgrade_id = new_upgrade_id

static func make_new_weapon(
	option_ability_id: StringName,
	option_title: String,
	option_description: String,
	option_icon: Texture2D
) -> LevelUpOption:
	return LevelUpOption.new(TYPE_NEW_WEAPON, option_title, option_description, option_icon, option_ability_id, &"")

static func make_weapon_upgrade(
	option_ability_id: StringName,
	option_upgrade_id: StringName,
	option_title: String,
	option_description: String,
	option_icon: Texture2D
) -> LevelUpOption:
	return LevelUpOption.new(
		TYPE_WEAPON_UPGRADE,
		option_title,
		option_description,
		option_icon,
		option_ability_id,
		option_upgrade_id
	)

static func make_player_upgrade(
	option_ability_id: StringName,
	option_upgrade_id: StringName,
	option_title: String,
	option_description: String,
	option_icon: Texture2D
) -> LevelUpOption:
	return LevelUpOption.new(TYPE_PLAYER_UPGRADE, option_title, option_description, option_icon, option_ability_id, option_upgrade_id)
