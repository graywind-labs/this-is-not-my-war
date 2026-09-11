extends SceneTree


const FORMAL_ROUTE_TIMEOUT_SECONDS := 90.0


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
	if merchant_system == null or resource_system == null or memory_system == null or npc_system == null or time_system == null or merchant_panel == null:
		_fail("T1507 required nodes or systems are missing")
		return
	if merchant_system.is_merchant_present():
		_fail("Merchant should not be present at the 06:00 starting time")
		return
	for resource_id in ["grain", "wood", "stone", "iron"]:
		if merchant_system.get_buy_offer(resource_id).is_empty():
			_fail("Merchant is missing buy offer for %s" % resource_id)
			return
	var expected_sell_prices := {"grain": 1, "wood": 2, "stone": 3, "iron": 4, "wine": 4}
	for resource_id in expected_sell_prices.keys():
		if int(merchant_system.get_sell_offer(str(resource_id)).get("unit_price", 0)) != int(expected_sell_prices[resource_id]):
			_fail("Merchant sell-price contract mismatch for %s" % resource_id)
			return
		if resource_id != "wine" and int(merchant_system.get_buy_offer(str(resource_id)).get("unit_price", 0)) <= int(expected_sell_prices[resource_id]):
			_fail("Base-resource sell price must remain below its buy price for %s" % resource_id)
			return
	if not merchant_system.get_buy_offer("wine").is_empty():
		_fail("Wine must remain sell-only")
		return

	var plaza_npc_id := "priest_01"
	var indoor_npc_id := "doctor_01"
	npc_system.debug_enter_location_immediately(plaza_npc_id, "plaza")
	npc_system.debug_enter_location_immediately(indoor_npc_id, "clinic")
	var plaza_witness_before: int = memory_system.get_npc_witness_events(plaza_npc_id).size()
	var indoor_witness_before: int = memory_system.get_npc_witness_events(indoor_npc_id).size()
	Engine.time_scale = 3.0
	time_system.set_current_time(1, 10, 0, 0)
	if not await _wait_for_wagon_state(merchant_system, "parked", FORMAL_ROUTE_TIMEOUT_SECONDS):
		_fail("Merchant wagon did not physically reach the dock")
		return
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
	var wagon := root.get_node_or_null("Main/WorldRoot/DailyMerchantWagon")
	var click_shape := wagon.get_node_or_null("TradeBubble/TradeBubbleArea/CollisionShape3D") as CollisionShape3D if wagon != null else null
	var trade_marker := wagon.get_node_or_null("TradeBubble/Marker") as Sprite3D if wagon != null else null
	var cargo_bed := wagon.get_node_or_null("VisualRoot/LoadedCargoBed") if wagon != null else null
	var axles := wagon.get_node_or_null("VisualRoot/Chassis/Axles") if wagon != null else null
	var wheels := wagon.get_node_or_null("VisualRoot/Wheels") if wagon != null else null
	var left_horse := wagon.get_node_or_null("VisualRoot/Horses/LeftHorse") as Node3D if wagon != null else null
	var right_horse := wagon.get_node_or_null("VisualRoot/Horses/RightHorse") as Node3D if wagon != null else null
	var driver_art := wagon.get_node_or_null("VisualRoot/DriverSeat/MerchantChibiArtView") if wagon != null else null
	if click_shape == null or click_shape.disabled or trade_marker == null:
		_fail("Physical wagon arrival did not enable its trade bubble")
		return
	if wagon.get_node_or_null("TradeBubble/Label3D") != null or trade_marker.pixel_size < 0.0089:
		_fail("Trade marker did not remove its text or enlarge the money-bag icon")
		return
	if cargo_bed == null or cargo_bed.get_child_count() < 18:
		_fail("Merchant wagon cargo bed is not visibly loaded")
		return
	if axles == null or axles.get_child_count() != 2 or wheels == null or wheels.get_child_count() != 4:
		_fail("Merchant wagon four-wheel, two-axle chassis is missing")
		return
	if left_horse == null or right_horse == null or not is_equal_approx(left_horse.position.x, -right_horse.position.x):
		_fail("Merchant wagon paired horses are missing or misaligned")
		return
	if driver_art == null or str(driver_art.debug_get_snapshot().get("current_state", "")) != "vehicle_seated":
		_fail("Merchant wagon chibi driver is not using the dedicated driving pose")
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

	var grain_capacity: int = resource_system.get_resource_capacity("grain")
	var grain_fill_amount: int = grain_capacity - int(resource_system.get_resource("grain"))
	if grain_fill_amount <= 0 or not resource_system.add_resource("grain", grain_fill_amount):
		_fail("Failed to prepare a full warehouse for trade capacity verification")
		return
	var money_before_capacity_buy: int = resource_system.get_resource("money")
	var events_before_capacity_buy: int = memory_system.get_plaza_events().size()
	var capacity_buy: Dictionary = merchant_system.buy_resource("grain", 1)
	if (
		bool(capacity_buy.get("ok", false))
		or str(capacity_buy.get("code", "")) != "warehouse_capacity"
		or resource_system.get_resource("grain") != grain_capacity
		or resource_system.get_resource("money") != money_before_capacity_buy
		or memory_system.get_plaza_events().size() != events_before_capacity_buy
	):
		_fail("A purchase above warehouse capacity was not rejected atomically")
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
	if not click_shape.disabled or merchant_panel.visible:
		_fail("Merchant UI or world hotspot remained active after departure")
		return
	var unavailable_trade: Dictionary = merchant_system.buy_resource("wood", 1)
	if bool(unavailable_trade.get("ok", false)) or str(unavailable_trade.get("code", "")) != "merchant_unavailable":
		_fail("Trade remained available after merchant departure")
		return
	if not await _wait_for_wagon_state(merchant_system, "absent", FORMAL_ROUTE_TIMEOUT_SECONDS):
		_fail("Merchant wagon did not clear the route after departure")
		return

	time_system.set_current_time(2, 10, 0, 0)
	if not await _wait_for_wagon_state(merchant_system, "parked", FORMAL_ROUTE_TIMEOUT_SECONDS):
		_fail("Merchant wagon did not physically return on the next day")
		return
	if not merchant_system.is_merchant_present() or int(merchant_system.get_market_snapshot().get("active_visit_day", 0)) != 2:
		_fail("Merchant did not return on the next day")
		return

	Engine.time_scale = 1.0
	print("T1507 merchant trade system verification passed.")
	quit(0)


func _wait_for_wagon_state(merchant_system: Node, expected_state: String, timeout_seconds: float) -> bool:
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < int(timeout_seconds * 1000.0):
		if str(merchant_system.get_market_snapshot().get("wagon_state", "")) == expected_state:
			return true
		await physics_frame
	return false


func _find_latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Variant = events[index]
		if event is Dictionary and str(event.get("type", "")) == event_type:
			return event
	return {}


func _fail(message: String) -> void:
	Engine.time_scale = 1.0
	push_error(message)
	quit(1)
