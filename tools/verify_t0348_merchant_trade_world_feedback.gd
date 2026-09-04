extends SceneTree

const ARRIVAL_TIMEOUT_SECONDS := 60.0
const MONEY_ICON := "res://assets/ui/resource_icons/money.svg"
const GRAIN_ICON := "res://assets/ui/resource_icons/grain.svg"
const WOOD_ICON := "res://assets/ui/resource_icons/wood.svg"
const WINE_ICON := "res://assets/ui/resource_icons/wine.svg"


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
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var panel := root.get_node_or_null("Main/UI/MerchantPanel")
	var presenter := root.get_node_or_null("Main/UI/WorldFeedbackPresenter")
	if merchant == null or resources == null or time_system == null or panel == null or presenter == null:
		_fail("T0348 required nodes unavailable")
		return
	Engine.time_scale = 6.0
	time_system.set_current_time(1, 10, 0, 0)
	if not await _wait_for_wagon_state(merchant, "parked", ARRIVAL_TIMEOUT_SECONDS):
		_fail("Merchant did not park for T0348")
		return
	presenter.debug_advance_feedback(3.0)

	merchant.debug_open_trade()
	await process_frame
	panel.debug_set_quantity("grain", 2)
	panel.debug_set_quantity("wood", 1)
	if not presenter.debug_get_snapshot().is_empty():
		_fail("Changing purchase draft quantities emitted world feedback")
		return
	var money_before_buy: int = resources.get_resource("money")
	panel.debug_confirm_trade()
	await process_frame
	var feedback: Array[Dictionary] = presenter.debug_get_snapshot()
	if feedback.size() != 1:
		_fail("Confirmed purchase did not emit exactly one feedback group: %s" % feedback)
		return
	if not _verify_group(feedback[0], [
		{"amount": -7, "role": "trade_out", "icon": MONEY_ICON},
		{"amount": 2, "role": "trade_in", "icon": GRAIN_ICON},
		{"amount": 1, "role": "trade_in", "icon": WOOD_ICON},
	]):
		return
	if resources.get_resource("money") != money_before_buy - 7:
		_fail("Purchase feedback appeared without the expected authority settlement")
		return
	if not _verify_anchor(feedback[0], merchant):
		return

	presenter.debug_advance_feedback(3.0)
	resources.add_resource("wine", 3)
	resources.add_resource("wood", 1)
	merchant.debug_open_trade()
	await process_frame
	panel.debug_set_mode("sell")
	panel.debug_set_quantity("wine", 2)
	panel.debug_set_quantity("wood", 1)
	if not presenter.debug_get_snapshot().is_empty():
		_fail("Changing sale draft quantities emitted world feedback")
		return
	panel.debug_confirm_trade()
	await process_frame
	feedback = presenter.debug_get_snapshot()
	if feedback.size() != 1:
		_fail("Confirmed sale did not emit exactly one feedback group: %s" % feedback)
		return
	if not _verify_group(feedback[0], [
		{"amount": -2, "role": "trade_out", "icon": WINE_ICON},
		{"amount": -1, "role": "trade_out", "icon": WOOD_ICON},
		{"amount": 10, "role": "trade_in", "icon": MONEY_ICON},
	]):
		return

	presenter.debug_advance_feedback(3.0)
	var failed: Dictionary = merchant.execute_trade_batch("buy", {
		"iron": merchant.get_merchant_stock("iron") + 1,
	})
	if bool(failed.get("ok", false)) or not presenter.debug_get_snapshot().is_empty():
		_fail("Rejected trade emitted world feedback")
		return

	Engine.time_scale = 1.0
	print("T0348 merchant trade world feedback verified")
	main.queue_free()
	await process_frame
	quit(0)


func _verify_group(group: Dictionary, expected_entries: Array[Dictionary]) -> bool:
	if str(group.get("anchor_type", "")) != "merchant" or str(group.get("channel", "")) != "merchant_trade":
		_fail("Trade feedback used the wrong anchor or channel: %s" % group)
		return false
	var entries: Array = group.get("entries", []) as Array
	if entries.size() != expected_entries.size():
		_fail("Trade feedback lost or split batch entries: %s" % entries)
		return false
	for expected in expected_entries:
		var matched := false
		for raw_entry in entries:
			var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
			if (
				int(entry.get("amount", 0)) == int(expected.get("amount", 0))
				and str(entry.get("color_role", "")) == str(expected.get("role", ""))
				and str(entry.get("icon_path", "")) == str(expected.get("icon", ""))
			):
				matched = true
				break
		if not matched:
			_fail("Missing trade feedback entry %s in %s" % [expected, entries])
			return false
	return true


func _verify_anchor(group: Dictionary, merchant: Node) -> bool:
	var expected: Variant = merchant.get_merchant_feedback_anchor_position()
	var actual: Variant = group.get("last_world_position", null)
	if not expected is Vector3 or not actual is Vector3 or (actual as Vector3).distance_to(expected as Vector3) > 0.05:
		_fail("Trade feedback did not resolve to the merchant head anchor: %s / %s" % [actual, expected])
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
