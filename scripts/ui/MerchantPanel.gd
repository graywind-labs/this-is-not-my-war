extends Control

const DraggablePanelController = preload("res://scripts/ui/DraggablePanel.gd")
const MERCHANT_SYSTEM_PATH := "/root/Main/Systems/MerchantSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"

@onready var merchant_status_label: Label = %MerchantStatusLabel
@onready var merchant_resources_label: Label = %MerchantResourcesLabel
@onready var buy_select: OptionButton = %MerchantBuySelect
@onready var sell_select: OptionButton = %MerchantSellSelect
@onready var amount_spin: SpinBox = %MerchantAmountSpin
@onready var buy_button: Button = %MerchantBuyButton
@onready var sell_button: Button = %MerchantSellButton
@onready var result_label: Label = %MerchantResultLabel
@onready var close_button: Button = %MerchantCloseButton

var _drag_controller


func _ready() -> void:
	visible = false
	_drag_controller = DraggablePanelController.new()
	_drag_controller.bind(self, get_node("PanelContainer/MarginContainer/Content/Header") as Control)
	buy_button.pressed.connect(_on_buy_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
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
		if event_bus.has_signal("building_clicked"):
			event_bus.building_clicked.connect(_on_world_selection_changed)
	_populate_offers()
	_refresh_panel()


func show_merchant() -> void:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null or not merchant_system.is_merchant_present():
		return
	result_label.text = "选择货物和数量后交易。"
	_populate_offers()
	_refresh_panel()
	visible = true


func close_panel() -> void:
	visible = false


func _on_buy_pressed() -> void:
	var resource_id := _selected_resource_id(buy_select)
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null:
		result_label.text = "交易系统不可用。"
		return
	var result: Dictionary = merchant_system.buy_resource(resource_id, int(amount_spin.value))
	_show_trade_result(result)


func _on_sell_pressed() -> void:
	var resource_id := _selected_resource_id(sell_select)
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null:
		result_label.text = "交易系统不可用。"
		return
	var result: Dictionary = merchant_system.sell_resource(resource_id, int(amount_spin.value))
	_show_trade_result(result)


func _on_merchant_state_changed(active: bool, _snapshot: Dictionary) -> void:
	if not active:
		close_panel()
		return
	_refresh_panel()


func _on_resource_changed(_resource_id: String, _amount: int) -> void:
	if visible:
		_refresh_panel()


func _on_world_selection_changed(_id: String) -> void:
	close_panel()


func _populate_offers() -> void:
	buy_select.clear()
	sell_select.clear()
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	if merchant_system == null:
		return
	for resource_id in merchant_system.get_buy_offer_ids():
		var offer: Dictionary = merchant_system.get_buy_offer(resource_id)
		buy_select.add_item("%s（%d 第纳尔/份）" % [offer.get("resource_name", resource_id), int(offer.get("unit_price", 0))])
		buy_select.set_item_metadata(buy_select.item_count - 1, resource_id)
	for resource_id in merchant_system.get_sell_offer_ids():
		var offer: Dictionary = merchant_system.get_sell_offer(resource_id)
		sell_select.add_item("%s（%d 第纳尔/份）" % [offer.get("resource_name", resource_id), int(offer.get("unit_price", 0))])
		sell_select.set_item_metadata(sell_select.item_count - 1, resource_id)


func _refresh_panel() -> void:
	var merchant_system := get_node_or_null(MERCHANT_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if merchant_system == null:
		merchant_status_label.text = "商人系统不可用"
		buy_button.disabled = true
		sell_button.disabled = true
		return
	var snapshot: Dictionary = merchant_system.get_market_snapshot()
	var merchant: Dictionary = snapshot.get("merchant", {})
	var active := bool(snapshot.get("active", false))
	merchant_status_label.text = "%s：%s（到访 %s）" % [
		str(merchant.get("name", "后门商队")),
		"正在后门停留" if active else "当前不在驿站",
		str(snapshot.get("schedule_text", "--"))
	]
	if resource_system == null:
		merchant_resources_label.text = "库存无法读取"
	else:
		merchant_resources_label.text = "驿站库存：第纳尔 %d / 酒 %d / 粮食 %d / 木材 %d / 石料 %d / 铁 %d" % [
			resource_system.get_resource("money"),
			resource_system.get_resource("wine"),
			resource_system.get_resource("grain"),
			resource_system.get_resource("wood"),
			resource_system.get_resource("stone"),
			resource_system.get_resource("iron")
		]
	buy_button.disabled = not active or buy_select.item_count == 0
	sell_button.disabled = not active or sell_select.item_count == 0


func _show_trade_result(result: Dictionary) -> void:
	if not bool(result.get("ok", false)):
		result_label.text = str(result.get("message", "交易失败。"))
		_refresh_panel()
		return
	var direction_text := "购买" if str(result.get("direction", "")) == "buy" else "出售"
	result_label.text = "%s成功：%s x%d，共 %d 第纳尔。" % [
		direction_text,
		str(result.get("resource_name", result.get("resource_id", "货物"))),
		int(result.get("amount", 0)),
		int(result.get("total_price", 0))
	]
	_refresh_panel()


func _selected_resource_id(select: OptionButton) -> String:
	if select.item_count == 0 or select.selected < 0:
		return ""
	return str(select.get_item_metadata(select.selected))
