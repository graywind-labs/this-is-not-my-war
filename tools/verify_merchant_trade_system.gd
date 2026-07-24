extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var merchant_system := root.get_node_or_null("Main/Systems/MerchantSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var merchant_panel := root.get_node_or_null("Main/UI/MerchantPanel")
	var marker := root.get_node_or_null("Main/WorldRoot/Station/Props/MerchantEntranceMarker")
	if merchant_system == null or resource_system == null or memory_system == null or npc_system == null or time_system == null or merchant_panel == null or marker == null:
		_fail("T1507 required nodes or systems are missing")
		return
	if merchant_system.is_merchant_present():
		_fail("Merchant should not be present at the 06:00 starting time")
		return
	for resource_id in ["grain", "wood", "stone", "iron"]:
		if merchant_system.get_buy_offer(resource_id).is_empty():
			_fail("Merchant is missing buy offer for %s" % resource_id)
			return
	if merchant_system.get_sell_offer("wine").is_empty():
		_fail("Merchant is missing wine sell offer")
		return

	var plaza_npc_id := "priest_01"
	var indoor_npc_id := "doctor_01"
	npc_system.debug_enter_location_immediately(plaza_npc_id, "plaza")
	npc_system.debug_enter_location_immediately(indoor_npc_id, "clinic")
	var plaza_witness_before: int = memory_system.get_npc_witness_events(plaza_npc_id).size()
	var indoor_witness_before: int = memory_system.get_npc_witness_events(indoor_npc_id).size()
	time_system.set_current_time(1, 10, 0, 0)
	if not merchant_system.is_merchant_present():
		_fail("Merchant did not arrive at configured time")
		return
	if memory_system.get_npc_witness_events(plaza_npc_id).size() != plaza_witness_before + 1:
		_fail("Merchant arrival was not broadcast to current plaza NPC")
		return
	if memory_system.get_npc_witness_events(indoor_npc_id).size() != indoor_witness_before:
		_fail("Merchant arrival leaked to indoor NPC")
		return
	var arrival_event := _find_latest_event(memory_system.get_plaza_events(), "merchant_arrived")
	if arrival_event.is_empty() or not str(arrival_event.get("summary", "")).contains("抵达后门"):
		_fail("Merchant arrival structured event is missing")
		return
	var click_shape := marker.get_node_or_null("MerchantClickArea/CollisionShape3D") as CollisionShape3D
	var marker_label := marker.get_node_or_null("MerchantEntranceLabel") as Label3D
	if click_shape == null or click_shape.disabled or marker_label == null or not marker_label.text.contains("商人马车已到"):
		_fail("Merchant arrival was not reflected at the back-gate marker")
		return
	if not merchant_system.debug_open_trade():
		_fail("Active merchant could not open trade UI")
		return
	await process_frame
	if not merchant_panel.visible:
		_fail("Merchant click did not open trade panel")
		return

	var grain_price := int(merchant_system.get_buy_offer("grain").get("unit_price", 0))
	var money_before_buy: int = resource_system.get_resource("money")
	var grain_before_buy: int = resource_system.get_resource("grain")
	var plaza_witness_before_trade: int = memory_system.get_npc_witness_events(plaza_npc_id).size()
	var indoor_witness_before_trade: int = memory_system.get_npc_witness_events(indoor_npc_id).size()
	var buy_result: Dictionary = merchant_system.buy_resource("grain", 2)
	if not bool(buy_result.get("ok", false)):
		_fail("Configured grain purchase failed")
		return
	if resource_system.get_resource("money") != money_before_buy - grain_price * 2:
		_fail("Grain purchase deducted the wrong amount of money")
		return
	if resource_system.get_resource("grain") != grain_before_buy + 2:
		_fail("Grain purchase did not add inventory")
		return
	var buy_event := _find_latest_event(memory_system.get_plaza_events(), "merchant_trade_completed")
	if buy_event.is_empty() or str(buy_event.get("payload", {}).get("direction", "")) != "buy":
		_fail("Purchase structured event is missing")
		return
	if int(buy_event.get("payload", {}).get("total_price", 0)) != grain_price * 2:
		_fail("Purchase event did not retain configured price")
		return
	if not str(buy_event.get("summary", "")).contains("守备官从商人处购买"):
		_fail("Purchase summary did not use deterministic world wording")
		return
	if memory_system.get_npc_witness_events(plaza_npc_id).size() != plaza_witness_before_trade + 1:
		_fail("Purchase event was not broadcast to plaza NPC")
		return
	if memory_system.get_npc_witness_events(indoor_npc_id).size() != indoor_witness_before_trade:
		_fail("Purchase event leaked to indoor NPC")
		return

	var money_before_failed_buy: int = resource_system.get_resource("money")
	var grain_before_failed_buy: int = resource_system.get_resource("grain")
	var events_before_failed_buy: int = memory_system.get_plaza_events().size()
	var failed_buy: Dictionary = merchant_system.buy_resource("grain", 9999)
	if bool(failed_buy.get("ok", false)) or str(failed_buy.get("code", "")) != "insufficient_money":
		_fail("Unaffordable purchase was not rejected")
		return
	if resource_system.get_resource("money") != money_before_failed_buy or resource_system.get_resource("grain") != grain_before_failed_buy:
		_fail("Failed purchase changed inventory")
		return
	if memory_system.get_plaza_events().size() != events_before_failed_buy:
		_fail("Failed purchase should not create a completed trade event")
		return

	resource_system.add_resource("wine", 3)
	var wine_price := int(merchant_system.get_sell_offer("wine").get("unit_price", 0))
	var money_before_sell: int = resource_system.get_resource("money")
	var wine_before_sell: int = resource_system.get_resource("wine")
	var sell_result: Dictionary = merchant_system.sell_resource("wine", 2)
	if not bool(sell_result.get("ok", false)):
		_fail("Wine sale failed")
		return
	if resource_system.get_resource("wine") != wine_before_sell - 2:
		_fail("Wine sale did not consume T0807 wine inventory")
		return
	if resource_system.get_resource("money") != money_before_sell + wine_price * 2:
		_fail("Wine sale added the wrong amount of money")
		return
	var sell_event := _find_latest_event(memory_system.get_plaza_events(), "merchant_trade_completed")
	if str(sell_event.get("payload", {}).get("direction", "")) != "sell" or not str(sell_event.get("summary", "")).contains("守备官向商人出售"):
		_fail("Wine sale structured event is invalid")
		return

	resource_system.add_resource("wine", -9999)
	var money_before_failed_sell: int = resource_system.get_resource("money")
	var failed_sell: Dictionary = merchant_system.sell_resource("wine", 1)
	if bool(failed_sell.get("ok", false)) or str(failed_sell.get("code", "")) != "insufficient_resource":
		_fail("Wine sale without inventory was not rejected")
		return
	if resource_system.get_resource("money") != money_before_failed_sell:
		_fail("Failed wine sale changed money")
		return

	time_system.set_current_time(1, 16, 0, 0)
	if merchant_system.is_merchant_present():
		_fail("Merchant did not leave at configured departure time")
		return
	var departure_event := _find_latest_event(memory_system.get_plaza_events(), "merchant_departed")
	if departure_event.is_empty():
		_fail("Merchant departure structured event is missing")
		return
	if not click_shape.disabled or not merchant_panel.buy_button.disabled or not merchant_panel.sell_button.disabled:
		_fail("Merchant UI or world hotspot remained active after departure")
		return
	var unavailable_trade: Dictionary = merchant_system.buy_resource("wood", 1)
	if bool(unavailable_trade.get("ok", false)) or str(unavailable_trade.get("code", "")) != "merchant_unavailable":
		_fail("Trade remained available after merchant departure")
		return

	time_system.set_current_time(2, 10, 0, 0)
	if not merchant_system.is_merchant_present() or int(merchant_system.get_market_snapshot().get("active_visit_day", 0)) != 2:
		_fail("Merchant did not return on the next day")
		return

	print("T1507 merchant trade system verification passed.")
	quit(0)


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
