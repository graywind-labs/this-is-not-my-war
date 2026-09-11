extends SceneTree

const ARRIVAL_TIMEOUT_SECONDS := 60.0
const STOCK_RANGES := {
	"grain": Vector2i(18, 30),
	"wood": Vector2i(12, 22),
	"stone": Vector2i(10, 18),
	"iron": Vector2i(6, 12)
}


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var merchant := root.get_node_or_null("Main/Systems/MerchantSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var panel := root.get_node_or_null("Main/UI/MerchantPanel")
	if merchant == null or resources == null or memory == null or time_system == null or panel == null:
		_fail("T0342 required nodes unavailable")
		return
	Engine.time_scale = 6.0
	time_system.set_current_time(1, 10, 0, 0)
	if not await _wait_for_wagon_state(merchant, "parked", ARRIVAL_TIMEOUT_SECONDS):
		_fail("Merchant did not park for T0342")
		return
	var initial_stock: Dictionary = merchant.get_market_snapshot().get("daily_stock", {})
	if not _stock_is_in_configured_ranges(initial_stock):
		_fail("Daily merchant stock is outside configured ranges: %s" % initial_stock)
		return
	if int(merchant.get_market_snapshot().get("stock_visit_day", 0)) != 1:
		_fail("Daily stock did not bind to visit day 1")
		return
	merchant.debug_open_trade()
	await process_frame
	var ui: Dictionary = panel.debug_get_trade_ui_snapshot()
	if not bool(ui.get("visible", false)) or str(ui.get("title", "")) != "行商交易":
		_fail("New merchant panel title or visibility is incorrect: %s" % ui)
		return
	if not str(ui.get("schedule", "")).contains("10:00") or not str(ui.get("schedule", "")).contains("16:00"):
		_fail("Merchant visit schedule is missing from the panel")
		return
	if not str(ui.get("schedule", "")).contains(" 到 "):
		_fail("Merchant visit schedule did not use the requested start-to-end wording")
		return
	var wagon := root.get_node_or_null("Main/WorldRoot/DailyMerchantWagon")
	var marker := wagon.get_node_or_null("TradeBubble/Marker") as Sprite3D if wagon != null else null
	var marker_shape := wagon.get_node_or_null("TradeBubble/TradeBubbleArea/CollisionShape3D") as CollisionShape3D if wagon != null else null
	if marker == null or marker.pixel_size < 0.0089 or wagon.get_node_or_null("TradeBubble/Label3D") != null:
		_fail("Money-bag marker size or removed-text contract failed")
		return
	if marker_shape == null or not marker_shape.shape is BoxShape3D or (marker_shape.shape as BoxShape3D).size.x < 1.79:
		_fail("Enlarged money-bag marker did not retain a matching click area")
		return
	var cards: Dictionary = ui.get("cards", {})
	if cards.size() != 5:
		_fail("Merchant panel must retain all five designed trade-resource icons")
		return
	var resource_scroll := panel.get_node_or_null("PanelContainer/MarginContainer/Content/ResourceScroll") as ScrollContainer
	var resource_grid := panel.get_node_or_null("PanelContainer/MarginContainer/Content/ResourceScroll/MerchantResourceGrid") as GridContainer
	if not is_equal_approx(panel.size.x, 780.0) or not is_equal_approx(panel.size.y, 440.0) or resource_scroll == null or resource_grid == null or resource_scroll.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		_fail("Merchant panel whitespace was not trimmed to 780x440 or horizontal scrolling remained enabled")
		return
	if resource_grid.size.x > resource_scroll.size.x + 0.5:
		_fail("All five merchant cards do not fit in the widened viewport")
		return
	for resource_id in ["grain", "wood", "stone", "iron", "wine"]:
		if str(cards.get(resource_id, {}).get("tooltip", "")) == "" or int(cards.get(resource_id, {}).get("quantity", -1)) != 0:
			_fail("Trade card tooltip or zero default is invalid: %s" % resource_id)
			return
		if cards.get(resource_id, {}).get("control_order", []) != ["MinusButton", "QuantityInput", "PlusButton"]:
			_fail("Quantity controls are not ordered minus/input/plus: %s" % resource_id)
			return
		if (cards.get(resource_id, {}).get("card_size", Vector2.ZERO) as Vector2).x < 140.0 or (cards.get(resource_id, {}).get("card_size", Vector2.ZERO) as Vector2).y < 180.0:
			_fail("Resource card was not enlarged after the T0344 correction: %s" % resource_id)
			return
		if (cards.get(resource_id, {}).get("icon_size", Vector2.ZERO) as Vector2) != Vector2(84.0, 84.0):
			_fail("Resource icon was not enlarged to the corrected size: %s" % resource_id)
			return
		if (cards.get(resource_id, {}).get("button_size", Vector2.ZERO) as Vector2).x >= 28.0 or (cards.get(resource_id, {}).get("input_size", Vector2.ZERO) as Vector2).x >= 48.0:
			_fail("Quantity controls were not compacted: %s" % resource_id)
			return
	if str(cards.get("grain", {}).get("money_icon_path", "")) != "res://assets/ui/resource_icons/money.svg" or str(cards.get("grain", {}).get("price_text", "")).contains("第纳尔"):
		_fail("Quoted prices did not replace the currency word with the HUD money icon")
		return
	if int(cards.get("wine", {}).get("maximum", -1)) != 0:
		_fail("Wine must remain visible but unavailable in purchase mode")
		return
	var money_before_selection: int = resources.get_resource("money")
	var grain_before_selection: int = resources.get_resource("grain")
	var wood_before_selection: int = resources.get_resource("wood")
	panel.debug_set_quantity("grain", 2)
	panel.debug_set_quantity("wood", 1)
	ui = panel.debug_get_trade_ui_snapshot()
	if bool(ui.get("cards", {}).get("grain", {}).get("minus_disabled", true)):
		_fail("Minus button remained disabled after increasing quantity")
		return
	panel._change_quantity("grain", -1)
	panel._change_quantity("grain", -1)
	ui = panel.debug_get_trade_ui_snapshot()
	if int(ui.get("cards", {}).get("grain", {}).get("quantity", -1)) != 0 or not bool(ui.get("cards", {}).get("grain", {}).get("minus_disabled", false)):
		_fail("Minus button did not decrement to zero and disable at the minimum")
		return
	panel.debug_set_quantity("grain", 2)
	ui = panel.debug_get_trade_ui_snapshot()
	var buy_total_color: Color = ui.get("total_color", Color.WHITE)
	if str(ui.get("total_text", "")) != "-7" or buy_total_color.r <= buy_total_color.g or resources.get_resource("money") != money_before_selection or resources.get_resource("grain") != grain_before_selection:
		_fail("Purchase selection changed authority or calculated the wrong red negative total: %s" % ui)
		return
	panel.debug_confirm_trade()
	await process_frame
	if panel.visible:
		_fail("Successful purchase did not close the merchant panel")
		return
	if resources.get_resource("money") != money_before_selection - 7 or resources.get_resource("grain") != grain_before_selection + 2 or resources.get_resource("wood") != wood_before_selection + 1:
		_fail("Confirmed multi-resource purchase settled incorrectly")
		return
	if merchant.get_merchant_stock("grain") != int(initial_stock.get("grain", 0)) - 2 or merchant.get_merchant_stock("wood") != int(initial_stock.get("wood", 0)) - 1:
		_fail("Confirmed purchase did not reduce same-day merchant stock")
		return
	var stock_after_buy: Dictionary = merchant.get_market_snapshot().get("daily_stock", {}).duplicate(true)
	merchant.debug_open_trade()
	await process_frame
	if merchant.get_market_snapshot().get("daily_stock", {}) != stock_after_buy:
		_fail("Reopening trade regenerated same-day stock")
		return
	resources.add_resource("wine", 3)
	var wine_before_sell: int = resources.get_resource("wine")
	var money_before_sell: int = resources.get_resource("money")
	var wine_merchant_before: int = merchant.get_merchant_stock("wine")
	panel.debug_set_mode("sell")
	panel.debug_set_quantity("wine", 2)
	ui = panel.debug_get_trade_ui_snapshot()
	var sell_total_color: Color = ui.get("total_color", Color.WHITE)
	if str(ui.get("total_text", "")) != "+8" or sell_total_color.g <= sell_total_color.r or int(ui.get("cards", {}).get("wine", {}).get("maximum", -1)) != wine_before_sell:
		_fail("Sale mode total or player-owned maximum is wrong: %s" % ui)
		return
	panel.debug_confirm_trade()
	await process_frame
	if resources.get_resource("wine") != wine_before_sell - 2 or resources.get_resource("money") != money_before_sell + 8:
		_fail("Confirmed sale settled incorrectly")
		return
	if merchant.get_merchant_stock("wine") != wine_merchant_before + 2:
		_fail("Sold resource did not enter the merchant's same-day inventory")
		return
	resources.add_resource("money", 10000)
	var authority_before_fail: Dictionary = resources.get_resource_snapshot()
	var stock_before_fail: Dictionary = merchant.get_market_snapshot().get("daily_stock", {}).duplicate(true)
	var events_before_fail: int = memory.get_plaza_events().size()
	var failed: Dictionary = merchant.execute_trade_batch("buy", {"iron": merchant.get_merchant_stock("iron") + 1, "grain": 1})
	if bool(failed.get("ok", false)) or str(failed.get("code", "")) != "insufficient_merchant_stock":
		_fail("Over-stock batch was not rejected")
		return
	if resources.get_resource_snapshot() != authority_before_fail or merchant.get_market_snapshot().get("daily_stock", {}) != stock_before_fail or memory.get_plaza_events().size() != events_before_fail:
		_fail("Rejected batch produced a partial authority change")
		return
	var checkpoint: Dictionary = merchant.create_formal_spatial_checkpoint()
	if str(checkpoint.get("schema", "")) != "formal_merchant_spatial_checkpoint_v2" or checkpoint.get("daily_stock", {}) != stock_before_fail:
		_fail("Merchant checkpoint does not retain same-day stock")
		return
	Engine.time_scale = 1.0
	print("T0342 merchant trade UI and daily stock verified")
	main.queue_free()
	await process_frame
	quit(0)


func _stock_is_in_configured_ranges(stock: Dictionary) -> bool:
	for resource_id in STOCK_RANGES.keys():
		var limits: Vector2i = STOCK_RANGES[resource_id]
		var amount := int(stock.get(resource_id, -1))
		if amount < limits.x or amount > limits.y:
			return false
	return true


func _wait_for_wagon_state(merchant: Node, expected: String, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if str(merchant.get_market_snapshot().get("wagon_state", "")) == expected:
			return true
		await physics_frame
	return false


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	push_error(message)
	quit(1)
