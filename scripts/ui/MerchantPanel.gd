extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const MERCHANT_SYSTEM_PATH := "/root/Main/Systems/MerchantSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const RESOURCE_ORDER: Array[String] = ["grain", "wood", "stone", "iron", "wine"]
const RESOURCE_ICON_PATHS := {
	"grain": "res://assets/ui/resource_icons/grain.svg",
	"wood": "res://assets/ui/resource_icons/wood.svg",
	"stone": "res://assets/ui/resource_icons/stone.svg",
	"iron": "res://assets/ui/resource_icons/iron.svg",
	"wine": "res://assets/ui/resource_icons/wine.svg"
}
const MONEY_ICON_PATH := "res://assets/ui/resource_icons/money.svg"
const RESOURCE_CARD_SIZE := Vector2(140.0, 180.0)
const RESOURCE_ICON_SIZE := Vector2(84.0, 84.0)
const QUANTITY_BUTTON_SIZE := Vector2(22.0, 24.0)
const QUANTITY_INPUT_SIZE := Vector2(38.0, 24.0)
const BUY_TOTAL_COLOR := Color("#dc6157")
const SELL_TOTAL_COLOR := Color("#69c879")
const ZERO_TOTAL_COLOR := Color("#ead9b4")

@onready var title_label: Label = %TitleLabel
@onready var schedule_label: Label = %MerchantScheduleLabel
@onready var buy_mode_button: Button = %MerchantBuyModeButton
@onready var sell_mode_button: Button = %MerchantSellModeButton
@onready var resource_grid: GridContainer = %MerchantResourceGrid
@onready var feedback_label: Label = %MerchantFeedbackLabel
@onready var total_label: Label = %MerchantTotalLabel
@onready var confirm_button: Button = %MerchantConfirmButton
@onready var close_button: Button = %MerchantCloseButton

var _drag_controller
var _mode_group := ButtonGroup.new()
var _mode := "buy"
var _cards: Dictionary = {}
var _quantities: Dictionary = {}
var _updating_inputs := false
var _committing := false


func _ready() -> void:
	visible = false
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, get_node("PanelContainer/MarginContainer/Content/Header") as Control)
	buy_mode_button.button_group = _mode_group
	sell_mode_button.button_group = _mode_group
	buy_mode_button.pressed.connect(_set_mode.bind("buy"))
	sell_mode_button.pressed.connect(_set_mode.bind("sell"))
	confirm_button.pressed.connect(_on_confirm_pressed)
	close_button.pressed.connect(close_panel)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if event_bus.has_signal("merchant_clicked"):
			event_bus.merchant_clicked.connect(show_merchant)
		if event_bus.has_signal("merchant_state_changed"):
			event_bus.merchant_state_changed.connect(_on_merchant_state_changed)
		if event_bus.has_signal("resource_changed"):
			event_bus.resource_changed.connect(_on_resource_changed)
		if event_bus.has_signal("notice_board_clicked"):
			event_bus.notice_board_clicked.connect(close_panel)
		if event_bus.has_signal("npc_clicked"):
			event_bus.npc_clicked.connect(_on_world_selection_changed)
		if event_bus.has_signal("enemy_clicked"):
			event_bus.enemy_clicked.connect(_on_world_selection_changed)
		if event_bus.has_signal("horse_clicked"):
			event_bus.horse_clicked.connect(_on_world_selection_changed)
		if event_bus.has_signal("building_clicked"):
			event_bus.building_clicked.connect(_on_world_selection_changed)
	_build_resource_cards()
	_set_mode("buy")


func show_merchant() -> void:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null or not merchant_system.is_merchant_present():
		return
	feedback_label.text = ""
	_set_mode("buy")
	_refresh_panel()
	visible = true


func close_panel() -> void:
	visible = false


func _build_resource_cards() -> void:
	for child in resource_grid.get_children():
		child.free()
	_cards.clear()
	_quantities.clear()
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	for resource_id in RESOURCE_ORDER:
		var resource_name: String = resource_system.get_resource_name(resource_id) if resource_system != null else resource_id
		var card := PanelContainer.new()
		card.name = "TradeCard_%s" % resource_id
		card.custom_minimum_size = RESOURCE_CARD_SIZE
		card.set_meta("resource_id", resource_id)
		resource_grid.add_child(card)
		var content := VBoxContainer.new()
		content.add_theme_constant_override("separation", 5)
		content.alignment = BoxContainer.ALIGNMENT_CENTER
		card.add_child(content)
		var icon := TextureRect.new()
		icon.name = "Icon"
		icon.custom_minimum_size = RESOURCE_ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.mouse_filter = Control.MOUSE_FILTER_STOP
		icon.tooltip_text = resource_name
		var icon_path := str(RESOURCE_ICON_PATHS.get(resource_id, ""))
		if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
			icon.texture = load(icon_path) as Texture2D
		content.add_child(icon)
		var price_row := HBoxContainer.new()
		price_row.name = "PriceRow"
		price_row.alignment = BoxContainer.ALIGNMENT_CENTER
		price_row.add_theme_constant_override("separation", 2)
		content.add_child(price_row)
		var price_icon := TextureRect.new()
		price_icon.name = "MoneyIcon"
		price_icon.custom_minimum_size = Vector2(16.0, 16.0)
		price_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		price_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		price_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if ResourceLoader.exists(MONEY_ICON_PATH):
			price_icon.texture = load(MONEY_ICON_PATH) as Texture2D
		price_row.add_child(price_icon)
		var price_label := Label.new()
		price_label.name = "PriceLabel"
		price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		price_label.add_theme_font_size_override("font_size", 13)
		price_row.add_child(price_label)
		var quantity_row := HBoxContainer.new()
		quantity_row.name = "QuantityRow"
		quantity_row.alignment = BoxContainer.ALIGNMENT_CENTER
		quantity_row.add_theme_constant_override("separation", 3)
		content.add_child(quantity_row)
		var minus_button := Button.new()
		minus_button.name = "MinusButton"
		minus_button.text = "−"
		minus_button.custom_minimum_size = QUANTITY_BUTTON_SIZE
		minus_button.add_theme_font_size_override("font_size", 13)
		minus_button.pressed.connect(_change_quantity.bind(resource_id, -1))
		quantity_row.add_child(minus_button)
		var input := LineEdit.new()
		input.name = "QuantityInput"
		input.custom_minimum_size = QUANTITY_INPUT_SIZE
		input.add_theme_font_size_override("font_size", 13)
		input.text = "0"
		input.alignment = HORIZONTAL_ALIGNMENT_CENTER
		input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
		input.text_changed.connect(_on_quantity_text_changed.bind(resource_id))
		input.focus_exited.connect(_commit_quantity_input.bind(resource_id))
		input.text_submitted.connect(func(_text: String) -> void: _commit_quantity_input(resource_id))
		quantity_row.add_child(input)
		var plus_button := Button.new()
		plus_button.name = "PlusButton"
		plus_button.text = "+"
		plus_button.custom_minimum_size = QUANTITY_BUTTON_SIZE
		plus_button.add_theme_font_size_override("font_size", 13)
		plus_button.pressed.connect(_change_quantity.bind(resource_id, 1))
		quantity_row.add_child(plus_button)
		var available_label := Label.new()
		available_label.name = "AvailableLabel"
		available_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		available_label.add_theme_font_size_override("font_size", 12)
		content.add_child(available_label)
		_cards[resource_id] = {
			"card": card,
			"icon": icon,
			"price_icon": price_icon,
			"price": price_label,
			"plus": plus_button,
			"input": input,
			"minus": minus_button,
			"available": available_label
		}
		_quantities[resource_id] = 0


func _set_mode(next_mode: String) -> void:
	if not ["buy", "sell"].has(next_mode):
		return
	_mode = next_mode
	buy_mode_button.set_pressed_no_signal(_mode == "buy")
	sell_mode_button.set_pressed_no_signal(_mode == "sell")
	_reset_quantities()
	feedback_label.text = ""
	_refresh_panel()


func _reset_quantities() -> void:
	for resource_id in RESOURCE_ORDER:
		_quantities[resource_id] = 0
	_sync_all_inputs()


func _change_quantity(resource_id: String, delta: int) -> void:
	var current := int(_quantities.get(resource_id, 0))
	_set_quantity(resource_id, current + delta)


func _on_quantity_text_changed(new_text: String, resource_id: String) -> void:
	if _updating_inputs:
		return
	var digits := ""
	for character in new_text:
		if character >= "0" and character <= "9":
			digits += character
	if digits.is_empty():
		_quantities[resource_id] = 0
	else:
		_quantities[resource_id] = clampi(int(digits), 0, _get_quantity_max(resource_id))
	if digits != new_text or (not digits.is_empty() and int(digits) != int(_quantities[resource_id])):
		_sync_input(resource_id)
	_refresh_quantity_controls(resource_id)
	_refresh_total()


func _commit_quantity_input(resource_id: String) -> void:
	_set_quantity(resource_id, int(_quantities.get(resource_id, 0)))


func _set_quantity(resource_id: String, amount: int) -> void:
	_quantities[resource_id] = clampi(amount, 0, _get_quantity_max(resource_id))
	_sync_input(resource_id)
	_refresh_quantity_controls(resource_id)
	_refresh_total()


func _sync_all_inputs() -> void:
	for resource_id in RESOURCE_ORDER:
		_sync_input(resource_id)


func _sync_input(resource_id: String) -> void:
	if not _cards.has(resource_id):
		return
	_updating_inputs = true
	var input := _cards[resource_id].get("input") as LineEdit
	input.text = str(int(_quantities.get(resource_id, 0)))
	_updating_inputs = false


func _refresh_panel() -> void:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null:
		schedule_label.text = "到访时间 --"
		confirm_button.disabled = true
		return
	var snapshot: Dictionary = merchant_system.get_market_snapshot()
	schedule_label.text = "到访时间 %s" % str(snapshot.get("schedule_text", "--")).replace("-", " 到 ")
	var active := bool(snapshot.get("active", false))
	for resource_id in RESOURCE_ORDER:
		_refresh_card(resource_id, active)
	_refresh_total()


func _refresh_card(resource_id: String, merchant_active: bool) -> void:
	if not _cards.has(resource_id):
		return
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var offer: Dictionary = merchant_system.get_buy_offer(resource_id) if _mode == "buy" else merchant_system.get_sell_offer(resource_id)
	var available_in_mode := merchant_active and not offer.is_empty()
	var maximum := _get_quantity_max(resource_id) if available_in_mode else 0
	_quantities[resource_id] = clampi(int(_quantities.get(resource_id, 0)), 0, maximum)
	var controls: Dictionary = _cards[resource_id]
	var icon := controls.get("icon") as TextureRect
	var price_icon := controls.get("price_icon") as TextureRect
	var price_label := controls.get("price") as Label
	var plus_button := controls.get("plus") as Button
	var input := controls.get("input") as LineEdit
	var minus_button := controls.get("minus") as Button
	var available_label := controls.get("available") as Label
	icon.modulate = Color.WHITE if available_in_mode else Color(0.42, 0.39, 0.34, 0.72)
	price_icon.visible = not offer.is_empty()
	price_label.text = "%d /份" % int(offer.get("unit_price", 0)) if not offer.is_empty() else ("不可购买" if _mode == "buy" else "不可出售")
	input.editable = available_in_mode
	if _mode == "buy":
		available_label.text = "可购 %d" % maximum if available_in_mode else "—"
	else:
		available_label.text = "持有 %d" % maximum if available_in_mode and resource_system != null else "—"
	_sync_input(resource_id)
	_refresh_quantity_controls(resource_id)


func _refresh_quantity_controls(resource_id: String) -> void:
	if not _cards.has(resource_id):
		return
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	var offer: Dictionary = {}
	if merchant_system != null:
		offer = merchant_system.get_buy_offer(resource_id) if _mode == "buy" else merchant_system.get_sell_offer(resource_id)
	var available_in_mode: bool = merchant_system != null and merchant_system.is_merchant_present() and not offer.is_empty()
	var amount := int(_quantities.get(resource_id, 0))
	var maximum := _get_quantity_max(resource_id) if available_in_mode else 0
	var controls: Dictionary = _cards[resource_id]
	(controls.get("minus") as Button).disabled = not available_in_mode or amount <= 0
	(controls.get("plus") as Button).disabled = not available_in_mode or amount >= maximum


func _get_quantity_max(resource_id: String) -> int:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if merchant_system == null:
		return 0
	if _mode == "buy":
		if merchant_system.get_buy_offer(resource_id).is_empty():
			return 0
		return merchant_system.get_merchant_stock(resource_id)
	if resource_system == null or merchant_system.get_sell_offer(resource_id).is_empty():
		return 0
	return maxi(0, resource_system.get_resource(resource_id))


func _refresh_total() -> void:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	var total := 0
	var has_amount := false
	if merchant_system != null:
		for resource_id in RESOURCE_ORDER:
			var amount := int(_quantities.get(resource_id, 0))
			if amount <= 0:
				continue
			var offer: Dictionary = merchant_system.get_buy_offer(resource_id) if _mode == "buy" else merchant_system.get_sell_offer(resource_id)
			if offer.is_empty():
				continue
			total += amount * int(offer.get("unit_price", 0))
			has_amount = true
	var signed_total := -total if _mode == "buy" else total
	total_label.text = "%+d" % signed_total if has_amount else "0"
	total_label.add_theme_color_override("font_color", BUY_TOTAL_COLOR if _mode == "buy" and has_amount else (SELL_TOTAL_COLOR if _mode == "sell" and has_amount else ZERO_TOTAL_COLOR))
	confirm_button.disabled = not has_amount or merchant_system == null or not merchant_system.is_merchant_present() or _committing


func _on_confirm_pressed() -> void:
	if _committing:
		return
	var amounts := {}
	for resource_id in RESOURCE_ORDER:
		var amount := int(_quantities.get(resource_id, 0))
		if amount > 0:
			amounts[resource_id] = amount
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null:
		feedback_label.text = "交易系统不可用。"
		return
	_committing = true
	_refresh_total()
	var result: Dictionary = merchant_system.execute_trade_batch(_mode, amounts)
	_committing = false
	if not bool(result.get("ok", false)):
		feedback_label.text = str(result.get("message", "交易失败。"))
		_refresh_panel()
		return
	close_panel()


func _on_merchant_state_changed(active: bool, _snapshot: Dictionary) -> void:
	if not active:
		close_panel()
		return
	_refresh_panel()


func _on_resource_changed(_resource_id: String, _amount: int) -> void:
	if visible and not _committing:
		_refresh_panel()


func _on_world_selection_changed(_id: String) -> void:
	close_panel()


func debug_get_trade_ui_snapshot() -> Dictionary:
	var card_snapshot := {}
	for resource_id in RESOURCE_ORDER:
		var controls: Dictionary = _cards.get(resource_id, {})
		card_snapshot[resource_id] = {
			"quantity": int(_quantities.get(resource_id, 0)),
			"maximum": _get_quantity_max(resource_id),
			"price_text": (controls.get("price") as Label).text if controls.has("price") else "",
			"availability_text": (controls.get("available") as Label).text if controls.has("available") else "",
			"tooltip": (controls.get("icon") as TextureRect).tooltip_text if controls.has("icon") else "",
			"control_order": _get_quantity_control_order(controls),
			"minus_disabled": (controls.get("minus") as Button).disabled if controls.has("minus") else true,
			"plus_disabled": (controls.get("plus") as Button).disabled if controls.has("plus") else true,
			"button_size": (controls.get("minus") as Button).custom_minimum_size if controls.has("minus") else Vector2.ZERO,
			"input_size": (controls.get("input") as LineEdit).custom_minimum_size if controls.has("input") else Vector2.ZERO,
			"card_size": (controls.get("card") as PanelContainer).custom_minimum_size if controls.has("card") else Vector2.ZERO,
			"icon_size": (controls.get("icon") as TextureRect).custom_minimum_size if controls.has("icon") else Vector2.ZERO,
			"money_icon_path": (controls.get("price_icon") as TextureRect).texture.resource_path if controls.has("price_icon") and (controls.get("price_icon") as TextureRect).texture != null else ""
		}
	return {
		"visible": visible,
		"title": title_label.text,
		"schedule": schedule_label.text,
		"mode": _mode,
		"buy_selected": buy_mode_button.button_pressed,
		"sell_selected": sell_mode_button.button_pressed,
		"total_text": total_label.text,
		"total_color": total_label.get_theme_color("font_color"),
		"confirm_disabled": confirm_button.disabled,
		"cards": card_snapshot
	}


func _get_quantity_control_order(controls: Dictionary) -> Array[String]:
	var order: Array[String] = []
	if not controls.has("input"):
		return order
	var input := controls.get("input") as LineEdit
	var row := input.get_parent()
	for child in row.get_children():
		order.append(str(child.name))
	return order


func debug_set_quantity(resource_id: String, amount: int) -> void:
	_set_quantity(resource_id, amount)


func debug_set_mode(mode: String) -> void:
	_set_mode(mode)


func debug_confirm_trade() -> void:
	_on_confirm_pressed()
