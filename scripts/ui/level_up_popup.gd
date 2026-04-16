extends Panel
class_name LevelUpPopup

signal option_selected(option: LevelUpOption)

@onready var _root_margin: MarginContainer = $MarginContainer as MarginContainer
@onready var _root_vbox: VBoxContainer = $MarginContainer/VBoxContainer as VBoxContainer
@onready var _title_label: Label = $MarginContainer/VBoxContainer/TitleLabel as Label

@onready var _option_button_1: Button = $MarginContainer/VBoxContainer/OptionButton1 as Button
@onready var _option_button_2: Button = $MarginContainer/VBoxContainer/OptionButton2 as Button
@onready var _option_button_3: Button = $MarginContainer/VBoxContainer/OptionButton3 as Button

@onready var _option_1_icon: TextureRect = $MarginContainer/VBoxContainer/OptionButton1/ContentMargin/Row/IconSlot/Icon as TextureRect
@onready var _option_1_row: HBoxContainer = $MarginContainer/VBoxContainer/OptionButton1/ContentMargin/Row as HBoxContainer
@onready var _option_1_icon_slot: CenterContainer = $MarginContainer/VBoxContainer/OptionButton1/ContentMargin/Row/IconSlot as CenterContainer
@onready var _option_1_title: Label = $MarginContainer/VBoxContainer/OptionButton1/ContentMargin/Row/TextColumn/TitleLabel as Label
@onready var _option_1_description: Label = $MarginContainer/VBoxContainer/OptionButton1/ContentMargin/Row/TextColumn/DescriptionLabel as Label
@onready var _option_1_content_margin: MarginContainer = $MarginContainer/VBoxContainer/OptionButton1/ContentMargin as MarginContainer

@onready var _option_2_icon: TextureRect = $MarginContainer/VBoxContainer/OptionButton2/ContentMargin/Row/IconSlot/Icon as TextureRect
@onready var _option_2_row: HBoxContainer = $MarginContainer/VBoxContainer/OptionButton2/ContentMargin/Row as HBoxContainer
@onready var _option_2_icon_slot: CenterContainer = $MarginContainer/VBoxContainer/OptionButton2/ContentMargin/Row/IconSlot as CenterContainer
@onready var _option_2_title: Label = $MarginContainer/VBoxContainer/OptionButton2/ContentMargin/Row/TextColumn/TitleLabel as Label
@onready var _option_2_description: Label = $MarginContainer/VBoxContainer/OptionButton2/ContentMargin/Row/TextColumn/DescriptionLabel as Label
@onready var _option_2_content_margin: MarginContainer = $MarginContainer/VBoxContainer/OptionButton2/ContentMargin as MarginContainer

@onready var _option_3_icon: TextureRect = $MarginContainer/VBoxContainer/OptionButton3/ContentMargin/Row/IconSlot/Icon as TextureRect
@onready var _option_3_row: HBoxContainer = $MarginContainer/VBoxContainer/OptionButton3/ContentMargin/Row as HBoxContainer
@onready var _option_3_icon_slot: CenterContainer = $MarginContainer/VBoxContainer/OptionButton3/ContentMargin/Row/IconSlot as CenterContainer
@onready var _option_3_title: Label = $MarginContainer/VBoxContainer/OptionButton3/ContentMargin/Row/TextColumn/TitleLabel as Label
@onready var _option_3_description: Label = $MarginContainer/VBoxContainer/OptionButton3/ContentMargin/Row/TextColumn/DescriptionLabel as Label
@onready var _option_3_content_margin: MarginContainer = $MarginContainer/VBoxContainer/OptionButton3/ContentMargin as MarginContainer

var _option_buttons: Array[Button] = []
var _option_icons: Array[TextureRect] = []
var _option_rows: Array[HBoxContainer] = []
var _option_icon_slots: Array[Control] = []
var _option_titles: Array[Label] = []
var _option_descriptions: Array[Label] = []
var _option_content_margins: Array[MarginContainer] = []

var _base_panel_size: Vector2 = Vector2.ZERO

const MIN_BUTTON_HEIGHT: float = 52.0
const MIN_POPUP_HEIGHT: float = 232.0
const TEXT_COLUMN_SEPARATION: float = 1.0
const FALLBACK_TEXT_WIDTH: float = 220.0
const ROW_FALLBACK_SEPARATION: float = 10.0
const TEXT_VERTICAL_SAFETY_PADDING: float = 2.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false
	_base_panel_size = Vector2(offset_right - offset_left, offset_bottom - offset_top)

	_option_buttons = [_option_button_1, _option_button_2, _option_button_3]
	_option_icons = [_option_1_icon, _option_2_icon, _option_3_icon]
	_option_rows = [_option_1_row, _option_2_row, _option_3_row]
	_option_icon_slots = [_option_1_icon_slot, _option_2_icon_slot, _option_3_icon_slot]
	_option_titles = [_option_1_title, _option_2_title, _option_3_title]
	_option_descriptions = [_option_1_description, _option_2_description, _option_3_description]
	_option_content_margins = [_option_1_content_margin, _option_2_content_margin, _option_3_content_margin]

	_configure_wrapping(_option_titles)
	_configure_wrapping(_option_descriptions)

	for index: int in range(_option_buttons.size()):
		var button: Button = _option_buttons[index]
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_on_option_pressed.bind(index))
		_option_icon_slots[index].size_flags_vertical = Control.SIZE_SHRINK_CENTER

func _configure_wrapping(labels: Array[Label]) -> void:
	for label: Label in labels:
		if label == null:
			continue
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.clip_text = false
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func present_options(level: int, options: Array[LevelUpOption]) -> void:
	_title_label.text = "Level %d - Waehle ein Upgrade" % level
	for index: int in range(_option_buttons.size()):
		_setup_option(index, options)

	visible = true
	call_deferred("_refresh_layout")
	call_deferred("_refresh_layout_final_pass")

func hide_popup() -> void:
	visible = false

func _setup_option(index: int, options: Array[LevelUpOption]) -> void:
	var button: Button = _option_buttons[index]
	var icon: TextureRect = _option_icons[index]
	var title_label: Label = _option_titles[index]
	var description_label: Label = _option_descriptions[index]

	if index >= options.size():
		button.visible = false
		button.disabled = true
		button.custom_minimum_size = Vector2.ZERO
		button.set_meta("level_up_option", null)
		icon.texture = null
		icon.visible = false
		title_label.text = ""
		description_label.text = ""
		return

	var option: LevelUpOption = options[index]
	button.visible = true
	button.disabled = false
	button.set_meta("level_up_option", option)

	var option_icon: Texture2D = option.icon
	icon.texture = option_icon
	icon.visible = option_icon != null
	title_label.text = option.title
	description_label.text = option.description

func _refresh_layout() -> void:
	if not visible:
		return

	_refresh_option_min_heights()
	_root_vbox.queue_sort()
	_root_margin.update_minimum_size()
	update_minimum_size()
	_update_popup_height()

func _refresh_layout_final_pass() -> void:
	if not visible:
		return
	_refresh_layout()

func _refresh_option_min_heights() -> void:
	for index: int in range(_option_buttons.size()):
		var button: Button = _option_buttons[index]
		if not button.visible:
			button.custom_minimum_size = Vector2.ZERO
			continue

		var text_width: float = _get_available_text_width(index)
		var title_height: float = _estimate_wrapped_label_height(_option_titles[index], text_width)
		var description_height: float = _estimate_wrapped_label_height(_option_descriptions[index], text_width)
		var text_height: float = title_height + description_height
		if title_height > 0.0 and description_height > 0.0:
			text_height += TEXT_COLUMN_SEPARATION

		var icon_slot_height: float = _option_icon_slots[index].custom_minimum_size.y
		var vertical_padding: float = _get_content_vertical_padding(_option_content_margins[index])
		var required_height: float = maxf(icon_slot_height, text_height) + vertical_padding + TEXT_VERTICAL_SAFETY_PADDING
		button.custom_minimum_size = Vector2(0.0, maxf(MIN_BUTTON_HEIGHT, ceilf(required_height)))
		button.update_minimum_size()

func _get_available_text_width(index: int) -> float:
	var button: Button = _option_buttons[index]
	var content_margin: MarginContainer = _option_content_margins[index]
	var button_width: float = button.size.x
	if button_width <= 1.0:
		button_width = _base_panel_size.x - float(_root_margin.get_theme_constant("margin_left") + _root_margin.get_theme_constant("margin_right"))

	var inner_width: float = button_width - float(content_margin.get_theme_constant("margin_left") + content_margin.get_theme_constant("margin_right"))
	var icon_width: float = _option_icon_slots[index].custom_minimum_size.x
	var row_spacing: float = ROW_FALLBACK_SEPARATION
	var row: HBoxContainer = _option_rows[index]
	if row != null:
		row_spacing = float(row.get_theme_constant("separation"))
	var text_width: float = inner_width - icon_width - row_spacing
	if text_width <= 1.0:
		return FALLBACK_TEXT_WIDTH
	return text_width

func _estimate_wrapped_label_height(label: Label, max_width: float) -> float:
	var text: String = label.text.strip_edges()
	if text.is_empty():
		return 0.0

	var font: Font = label.get_theme_font("font")
	if font == null:
		return label.get_combined_minimum_size().y

	var font_size: int = label.get_theme_font_size("font_size")
	var measured: Vector2 = font.get_multiline_string_size(
		text,
		label.horizontal_alignment,
		max_width,
		font_size
	)
	return ceilf(maxf(measured.y, font.get_height(font_size)))

func _get_content_vertical_padding(content_margin: MarginContainer) -> float:
	return float(content_margin.get_theme_constant("margin_top") + content_margin.get_theme_constant("margin_bottom"))

func _update_popup_height() -> void:
	var target_width: float = _base_panel_size.x
	if target_width <= 0.0:
		target_width = offset_right - offset_left

	var required_height: float = _calculate_required_popup_height()
	var target_height: float = maxf(MIN_POPUP_HEIGHT, required_height)
	_set_centered_size(Vector2(target_width, target_height))

func _calculate_required_popup_height() -> float:
	var total_height: float = 0.0
	total_height += float(_root_margin.get_theme_constant("margin_top") + _root_margin.get_theme_constant("margin_bottom"))
	total_height += _title_label.get_combined_minimum_size().y

	var visible_buttons: int = 0
	for button: Button in _option_buttons:
		if not button.visible:
			continue
		visible_buttons += 1
		total_height += button.custom_minimum_size.y

	var item_count: int = 1 + visible_buttons
	if item_count > 1:
		total_height += float(item_count - 1) * float(_root_vbox.get_theme_constant("separation"))

	return total_height

func _set_centered_size(target_size: Vector2) -> void:
	var half_size: Vector2 = target_size * 0.5
	offset_left = -half_size.x
	offset_top = -half_size.y
	offset_right = half_size.x
	offset_bottom = half_size.y
	pivot_offset = half_size

func _on_option_pressed(index: int) -> void:
	if index < 0 or index >= _option_buttons.size():
		return

	var button: Button = _option_buttons[index]
	if not button.has_meta("level_up_option"):
		return

	var option: LevelUpOption = button.get_meta("level_up_option") as LevelUpOption
	if option == null:
		return

	hide_popup()
	option_selected.emit(option)
