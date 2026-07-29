extends Node

const MERCHANT_DEFS_FILE := "merchant_defs.json"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const MARKER_PATH := "/root/Main/WorldRoot/Station/Props/MerchantEntranceMarker"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const CLICK_AREA_NAME := "MerchantClickArea"
const PICK_RAY_LENGTH := 1000.0
const PLAZA_LOCATION_ID := "plaza"
const GUARD_OFFICER_ID := "guard_officer"

var _merchant: Dictionary = {}
var _buy_offers: Dictionary = {}
var _sell_offers: Dictionary = {}
var _merchant_active := false
var _active_visit_day := 0
var _last_state_change: Dictionary = {}
var _last_transaction: Dictionary = {}


func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if event_bus.has_signal("time_changed"):
			event_bus.time_changed.connect(_on_time_changed)
		if event_bus.has_signal("game_over_changed"):
			event_bus.game_over_changed.connect(_on_game_over_changed)
	initialize()


func initialize() -> void:
	_merchant.clear()
	_buy_offers.clear()
	_sell_offers.clear()
	_merchant_active = false
	_active_visit_day = 0
	_last_state_change.clear()
	_last_transaction.clear()
	_load_config()
	_ensure_click_area()
	_evaluate_current_time("initialize")
	_update_marker_presentation()


func _unhandled_input(event: InputEvent) -> void:
	if not _merchant_active or not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if not mouse_event.pressed or mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if not _is_merchant_at_screen_position(mouse_event.position):
		return
	debug_open_trade()
	get_viewport().set_input_as_handled()


func is_merchant_present() -> bool:
	return _merchant_active and not _is_game_over()


func get_buy_offer_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in _buy_offers.keys():
		ids.append(str(raw_id))
	return ids


func get_sell_offer_ids() -> Array[String]:
	var ids: Array[String] = []
	for raw_id in _sell_offers.keys():
		ids.append(str(raw_id))
	return ids


func get_buy_offer(resource_id: String) -> Dictionary:
	return _buy_offers.get(resource_id, {}).duplicate(true)


func get_sell_offer(resource_id: String) -> Dictionary:
	return _sell_offers.get(resource_id, {}).duplicate(true)


func get_market_snapshot() -> Dictionary:
	return {
		"active": is_merchant_present(),
		"merchant": _merchant.duplicate(true),
		"active_visit_day": _active_visit_day,
		"schedule_text": _get_schedule_text(),
		"buy_offers": _buy_offers.duplicate(true),
		"sell_offers": _sell_offers.duplicate(true),
		"last_state_change": _last_state_change.duplicate(true),
		"last_transaction": _last_transaction.duplicate(true)
	}


func buy_resource(resource_id: String, amount: int) -> Dictionary:
	return _execute_trade("buy", resource_id, amount)


func sell_resource(resource_id: String, amount: int) -> Dictionary:
	return _execute_trade("sell", resource_id, amount)


func debug_evaluate_current_time() -> Dictionary:
	_evaluate_current_time("debug_evaluate")
	return get_market_snapshot()


func debug_open_trade() -> bool:
	if not is_merchant_present():
		return false
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("merchant_clicked"):
		event_bus.merchant_clicked.emit()
		return true
	return false


func _load_config() -> void:
	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("MerchantSystem requires ConfigLoader autoload.")
		return
	var loaded: Variant = config_loader.load_data_file(MERCHANT_DEFS_FILE, {})
	if not loaded is Dictionary:
		push_error("Merchant definitions must be a JSON object: %s" % MERCHANT_DEFS_FILE)
		return
	var config: Dictionary = loaded
	var raw_merchant: Variant = config.get("merchant", {})
	if not raw_merchant is Dictionary:
		push_error("Merchant definition is missing merchant object.")
		return
	_merchant = (raw_merchant as Dictionary).duplicate(true)
	_merchant["id"] = str(_merchant.get("id", "back_gate_merchant"))
	_merchant["name"] = str(_merchant.get("name", "后门商队"))
	_merchant["location_id"] = str(_merchant.get("location_id", "back_gate"))
	_merchant["arrival_hour"] = clampi(int(_merchant.get("arrival_hour", 10)), 0, 23)
	_merchant["arrival_minute"] = clampi(int(_merchant.get("arrival_minute", 0)), 0, 59)
	_merchant["departure_hour"] = clampi(int(_merchant.get("departure_hour", 16)), 0, 23)
	_merchant["departure_minute"] = clampi(int(_merchant.get("departure_minute", 0)), 0, 59)
	_buy_offers = _normalize_offers(config.get("buy_offers", []), "buy")
	_sell_offers = _normalize_offers(config.get("sell_offers", []), "sell")


func _normalize_offers(raw_offers: Variant, direction: String) -> Dictionary:
	var offers := {}
	if not raw_offers is Array:
		push_error("Merchant %s offers must be an array." % direction)
		return offers
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	for raw_offer in raw_offers:
		if not raw_offer is Dictionary:
			continue
		var offer: Dictionary = raw_offer
		var resource_id := str(offer.get("resource_id", ""))
		var unit_price := int(offer.get("unit_price", 0))
		if resource_id.is_empty() or unit_price <= 0:
			push_warning("Skipped invalid merchant offer: %s" % str(offer))
			continue
		if resource_system == null or resource_system.get_resource_definition(resource_id).is_empty():
			push_warning("Skipped merchant offer for unknown resource: %s" % resource_id)
			continue
		var normalized := offer.duplicate(true)
		normalized["resource_id"] = resource_id
		normalized["resource_name"] = resource_system.get_resource_name(resource_id)
		normalized["unit_price"] = unit_price
		offers[resource_id] = normalized
	return offers


func _on_time_changed(_day: int, _hour: int, _minute: int, _second: int) -> void:
	_evaluate_current_time("time_changed")


func _on_game_over_changed(_result: String, _reason: String) -> void:
	if _merchant_active:
		_set_merchant_active(false, "game_over", false)


func _evaluate_current_time(reason: String) -> void:
	if _merchant.is_empty() or _is_game_over():
		_set_merchant_active(false, reason, false)
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		_set_merchant_active(false, reason, false)
		return
	var current_minutes := int(game_state.current_hour) * 60 + int(game_state.current_minute)
	var arrival_minutes := int(_merchant.get("arrival_hour", 10)) * 60 + int(_merchant.get("arrival_minute", 0))
	var departure_minutes := int(_merchant.get("departure_hour", 16)) * 60 + int(_merchant.get("departure_minute", 0))
	var should_be_active := false
	if arrival_minutes < departure_minutes:
		should_be_active = current_minutes >= arrival_minutes and current_minutes < departure_minutes
	elif arrival_minutes > departure_minutes:
		should_be_active = current_minutes >= arrival_minutes or current_minutes < departure_minutes
	_set_merchant_active(should_be_active, reason, true)


func _set_merchant_active(active: bool, reason: String, record_event: bool) -> void:
	if _merchant_active == active:
		_update_marker_presentation()
		return
	_merchant_active = active
	var game_state := get_node_or_null("/root/GameState")
	var day := int(game_state.current_day) if game_state != null else 1
	if active:
		_active_visit_day = day
	_last_state_change = {
		"active": active,
		"day": day,
		"time": _get_current_time_text(),
		"reason": reason
	}
	_update_marker_presentation()
	if record_event:
		_record_presence_event(active, reason)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("merchant_state_changed"):
		event_bus.merchant_state_changed.emit(active, get_market_snapshot())


func _execute_trade(direction: String, resource_id: String, amount: int) -> Dictionary:
	if not is_merchant_present():
		return _trade_error("merchant_unavailable", "商人当前不在后门。")
	if amount <= 0:
		return _trade_error("invalid_amount", "交易数量必须大于 0。")
	var offers: Dictionary = _buy_offers if direction == "buy" else _sell_offers
	if not offers.has(resource_id):
		return _trade_error("offer_unavailable", "商人不接受这项交易。")
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null:
		return _trade_error("resource_system_unavailable", "资源系统不可用。")
	var offer: Dictionary = offers[resource_id]
	var unit_price := int(offer.get("unit_price", 0))
	var total_price := amount * unit_price
	var paid := false
	if direction == "buy":
		if not resource_system.can_afford({"money": total_price}):
			return _trade_error("insufficient_money", "第纳尔不足。")
		if (
			resource_system.has_method("can_store_resources")
			and not bool(resource_system.can_store_resources({resource_id: amount}))
		):
			return _trade_error(
				"warehouse_capacity",
				"%s已达到仓库储存上限。" % resource_system.get_resource_name(resource_id)
			)
		paid = resource_system.spend_resources({"money": total_price})
		if paid and not resource_system.add_resource(resource_id, amount):
			resource_system.add_resource("money", total_price)
			return _trade_error("resource_add_failed", "资源入库失败，交易已回滚。")
	else:
		if not resource_system.can_afford({resource_id: amount}):
			return _trade_error("insufficient_resource", "%s不足。" % resource_system.get_resource_name(resource_id))
		paid = resource_system.spend_resources({resource_id: amount})
		if paid and not resource_system.add_resource("money", total_price):
			resource_system.add_resource(resource_id, amount)
			return _trade_error("money_add_failed", "第纳尔入库失败，交易已回滚。")
	if not paid:
		return _trade_error("payment_failed", "交易扣款失败。")
	var money_delta := -total_price if direction == "buy" else total_price
	var resource_delta := amount if direction == "buy" else -amount
	var event := _record_trade_event(direction, resource_id, amount, unit_price, total_price, money_delta, resource_delta)
	_last_transaction = {
		"ok": true,
		"direction": direction,
		"resource_id": resource_id,
		"resource_name": resource_system.get_resource_name(resource_id),
		"amount": amount,
		"unit_price": unit_price,
		"total_price": total_price,
		"money_delta": money_delta,
		"resource_delta": resource_delta,
		"event_id": str(event.get("event_id", ""))
	}
	return _last_transaction.duplicate(true)


func _trade_error(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}


func _record_presence_event(active: bool, reason: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null:
		return {}
	var event_type := "merchant_arrived" if active else "merchant_departed"
	return memory_system.broadcast_plaza_event({
		"type": event_type,
		"subject_npc_id": str(_merchant.get("id", "back_gate_merchant")),
		"actor_ids": [str(_merchant.get("id", "back_gate_merchant"))],
		"target_ids": [str(_merchant.get("location_id", "back_gate")), str(_merchant.get("id", "back_gate_merchant"))],
		"importance": 55,
		"payload": {
			"merchant_id": str(_merchant.get("id", "back_gate_merchant")),
			"merchant_name": str(_merchant.get("name", "后门商队")),
			"arrival_time": _format_schedule_time(true),
			"departure_time": _format_schedule_time(false),
			"visit_day": _active_visit_day if _active_visit_day > 0 else int(_last_state_change.get("day", 1)),
			"reason": reason
		}
	})


func _record_trade_event(
	direction: String,
	resource_id: String,
	amount: int,
	unit_price: int,
	total_price: int,
	money_delta: int,
	resource_delta: int
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if memory_system == null or resource_system == null:
		return {}
	return memory_system.broadcast_plaza_event({
		"type": "merchant_trade_completed",
		"subject_npc_id": str(_merchant.get("id", "back_gate_merchant")),
		"actor_ids": [GUARD_OFFICER_ID, str(_merchant.get("id", "back_gate_merchant"))],
		"target_ids": [resource_id, "money", str(_merchant.get("id", "back_gate_merchant")), str(_merchant.get("location_id", "back_gate"))],
		"importance": 50,
		"payload": {
			"merchant_id": str(_merchant.get("id", "back_gate_merchant")),
			"merchant_name": str(_merchant.get("name", "后门商队")),
			"direction": direction,
			"resource_id": resource_id,
			"resource_name": resource_system.get_resource_name(resource_id),
			"amount": amount,
			"unit_price": unit_price,
			"total_price": total_price,
			"money_delta": money_delta,
			"resource_delta": resource_delta,
			"money_after": resource_system.get_resource("money"),
			"resource_after": resource_system.get_resource(resource_id)
		}
	})


func _ensure_click_area() -> void:
	var marker := get_node_or_null(MARKER_PATH) as MeshInstance3D
	if marker == null or marker.mesh == null:
		push_error("Merchant entrance marker not found: %s" % MARKER_PATH)
		return
	var click_area := marker.get_node_or_null(CLICK_AREA_NAME) as Area3D
	if click_area == null:
		click_area = Area3D.new()
		click_area.name = CLICK_AREA_NAME
		marker.add_child(click_area)
	var collision_shape := click_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		click_area.add_child(collision_shape)
	var shape := BoxShape3D.new()
	var mesh_size := marker.mesh.get_aabb().size
	shape.size = Vector3(mesh_size.x, maxf(mesh_size.y, 0.5), mesh_size.z)
	collision_shape.shape = shape
	click_area.set_meta("merchant_hotspot", true)
	click_area.input_ray_pickable = true


func _update_marker_presentation() -> void:
	var marker := get_node_or_null(MARKER_PATH) as MeshInstance3D
	if marker == null:
		return
	var label := marker.get_node_or_null("MerchantEntranceLabel") as Label3D
	if label != null:
		if is_merchant_present():
			label.text = "商人马车已到\n点击交易"
		else:
			label.text = "商人入口\n%s" % _get_schedule_text()
	var click_area := marker.get_node_or_null(CLICK_AREA_NAME) as Area3D
	if click_area != null:
		click_area.input_ray_pickable = is_merchant_present()
		var collision_shape := click_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
		if collision_shape != null:
			collision_shape.disabled = not is_merchant_present()


func _is_merchant_at_screen_position(screen_position: Vector2) -> bool:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	if camera == null or get_viewport().world_3d == null:
		return false
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * PICK_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var result := get_viewport().world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return false
	var collider := result.get("collider") as Node
	while collider != null:
		if bool(collider.get_meta("merchant_hotspot", false)):
			return true
		collider = collider.get_parent()
	return false


func _get_schedule_text() -> String:
	return "%s-%s" % [_format_schedule_time(true), _format_schedule_time(false)]


func _format_schedule_time(arrival: bool) -> String:
	var prefix := "arrival" if arrival else "departure"
	return "%02d:%02d" % [
		int(_merchant.get("%s_hour" % prefix, 0)),
		int(_merchant.get("%s_minute" % prefix, 0))
	]


func _get_current_time_text() -> String:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return "00:00:00"
	return "%02d:%02d:%02d" % [game_state.current_hour, game_state.current_minute, game_state.current_second]


func _is_game_over() -> bool:
	var game_state := get_node_or_null("/root/GameState")
	return game_state != null and bool(game_state.get("game_over"))
