extends Node

const MERCHANT_DEFS_FILE := "merchant_defs.json"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const MARKER_PATH := "/root/Main/WorldRoot/Station/Props/MerchantEntranceMarker"
const WORLD_ROOT_PATH := "/root/Main/WorldRoot"
const STATION_LAYOUT_CONTROLLER_PATH := "/root/Main/Presentation/StationLayoutController"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const CLICK_AREA_NAME := "MerchantClickArea"
const WAGON_SCENE := preload("res://scenes/world/MerchantWagon.tscn")
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
var _last_evaluated_minute_key := ""
var _wagon: MerchantWagon
var _wagon_state := "absent"
var _route_navigation_region: NavigationRegion3D
var _route_navigation_map: RID
var _visit_started_day := 0
var _visit_departed_day := 0
var _forced_visit := false
var _formal_route_debug := false
var _formal_preview_owned := false
var _route_mode := "legacy_world_compatibility"
var _route_world_points: Array[Vector3] = []


func _ready() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		if event_bus.has_signal("time_changed"):
			event_bus.time_changed.connect(_on_time_changed)
		if event_bus.has_signal("game_over_changed"):
			event_bus.game_over_changed.connect(_on_game_over_changed)
		if event_bus.has_signal("gameplay_pause_changed"):
			event_bus.gameplay_pause_changed.connect(_on_gameplay_pause_changed)
	initialize()


func _exit_tree() -> void:
	if _route_navigation_map.is_valid():
		NavigationServer3D.free_rid(_route_navigation_map)
		_route_navigation_map = RID()


func initialize() -> void:
	_merchant.clear()
	_buy_offers.clear()
	_sell_offers.clear()
	_merchant_active = false
	_active_visit_day = 0
	_last_state_change.clear()
	_last_transaction.clear()
	_last_evaluated_minute_key = ""
	_visit_started_day = 0
	_visit_departed_day = 0
	_forced_visit = false
	_formal_route_debug = false
	_formal_preview_owned = false
	_route_mode = "legacy_world_compatibility"
	_route_world_points.clear()
	_clear_wagon()
	_load_config()
	_disable_legacy_marker()
	_build_route_navigation()
	_evaluate_current_time("initialize")


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
		"last_transaction": _last_transaction.duplicate(true),
		"wagon_state": _wagon_state,
		"wagon": _wagon.get_wagon_snapshot() if is_instance_valid(_wagon) else {},
		"route_mode": _route_mode,
		"route_point_count": _route_world_points.size(),
		"route_world_points": _route_world_points.duplicate(),
		"physical_presence_authority": true
	}


func create_formal_spatial_checkpoint() -> Dictionary:
	var wagon_position := Vector3.ZERO
	if is_instance_valid(_wagon):
		wagon_position = _wagon.global_position
	return {
		"schema": "formal_merchant_spatial_checkpoint_v1",
		"wagon_state": _wagon_state,
		"wagon_position": {"x": wagon_position.x, "y": wagon_position.y, "z": wagon_position.z},
		"merchant_active": _merchant_active,
		"active_visit_day": _active_visit_day,
		"visit_started_day": _visit_started_day,
		"visit_departed_day": _visit_departed_day,
		"forced_visit": _forced_visit,
		"route_mode": _route_mode
	}


func restore_formal_spatial_checkpoint(checkpoint: Dictionary) -> Dictionary:
	if str(checkpoint.get("schema", "")) != "formal_merchant_spatial_checkpoint_v1":
		return {"ok": false, "reason": "merchant_spatial_checkpoint_schema_mismatch"}
	_set_merchant_active(false, "save_restore_reset", false)
	_clear_wagon()
	_formal_route_debug = false
	_build_route_navigation()
	_active_visit_day = int(checkpoint.get("active_visit_day", 0))
	_visit_started_day = int(checkpoint.get("visit_started_day", 0))
	_visit_departed_day = int(checkpoint.get("visit_departed_day", 0))
	_forced_visit = bool(checkpoint.get("forced_visit", false))
	var saved_state := str(checkpoint.get("wagon_state", "absent"))
	if saved_state == "absent":
		return {"ok": true, "wagon_state": "absent", "presence_event_created": false}
	var world_root := get_node_or_null(WORLD_ROOT_PATH) as Node3D
	if world_root == null or not _route_navigation_map.is_valid():
		return {"ok": false, "reason": "merchant_restore_route_unavailable"}
	var route := _get_active_physical_route()
	var spawn_point: Vector3 = route.get("spawn", Vector3.ZERO)
	var dock_point: Vector3 = route.get("dock", Vector3.ZERO)
	var saved_position := _checkpoint_vector3(checkpoint.get("wagon_position", {}), spawn_point)
	# Route points are authored and audited. A newly rebuilt private NavigationMap
	# may not have completed its first server iteration in this same frame, so do
	# not issue a premature closest-point query that can incorrectly return origin.
	var safe_position := saved_position
	if not is_finite(safe_position.x) or not is_finite(safe_position.y) or not is_finite(safe_position.z) or safe_position == Vector3.ZERO:
		safe_position = dock_point if saved_state == "parked" else spawn_point
	_wagon = WAGON_SCENE.instantiate() as MerchantWagon
	_wagon.name = "DailyMerchantWagon"
	world_root.add_child(_wagon)
	_wagon.global_position = safe_position
	_wagon.set_navigation_map(_route_navigation_map)
	_wagon.motion_arrived.connect(_on_wagon_motion_arrived)
	_wagon.motion_failed.connect(_on_wagon_motion_failed)
	_wagon_state = saved_state if ["arriving", "parked", "departing"].has(saved_state) else "absent"
	if _wagon_state == "absent":
		_clear_wagon()
		return {"ok": true, "wagon_state": "absent", "presence_event_created": false}
	if _wagon_state == "parked":
		_wagon.global_position = dock_point
		_set_merchant_active(bool(checkpoint.get("merchant_active", true)), "save_restored_parked", false)
	elif _wagon_state == "arriving":
		_request_wagon_motion(dock_point, MerchantWagon.ARRIVAL_REQUEST)
	else:
		_request_wagon_motion(spawn_point, MerchantWagon.DEPARTURE_REQUEST)
	return {
		"ok": true,
		"wagon_state": _wagon_state,
		"route_mode": _route_mode,
		"wagon_position": _wagon.global_position if is_instance_valid(_wagon) else Vector3.ZERO,
		"presence_event_created": false
	}


func _checkpoint_vector3(raw_value: Variant, fallback: Vector3) -> Vector3:
	if not raw_value is Dictionary:
		return fallback
	var data := raw_value as Dictionary
	return Vector3(float(data.get("x", fallback.x)), float(data.get("y", fallback.y)), float(data.get("z", fallback.z)))


func buy_resource(resource_id: String, amount: int) -> Dictionary:
	return _execute_trade("buy", resource_id, amount)


func sell_resource(resource_id: String, amount: int) -> Dictionary:
	return _execute_trade("sell", resource_id, amount)


func debug_evaluate_current_time() -> Dictionary:
	_evaluate_current_time("debug_evaluate")
	return get_market_snapshot()


func debug_force_wagon_arrival() -> Dictionary:
	_begin_arrival("gm_force_arrival", true)
	return get_market_snapshot()


func debug_force_formal_wagon_arrival() -> Dictionary:
	if _wagon_state != "absent":
		_set_merchant_active(false, "gm_formal_route_replace", false)
		_clear_wagon()
	var layout_controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	if layout_controller == null or not layout_controller.has_method("get_formal_merchant_route_world"):
		return {"ok": false, "code": "formal_route_unavailable"}
	if layout_controller.has_method("is_runtime_formal_world_enabled") and not bool(layout_controller.call("is_runtime_formal_world_enabled")):
		layout_controller.call("set_runtime_formal_world_enabled", true)
		_formal_preview_owned = true
	_formal_route_debug = true
	_build_route_navigation()
	_begin_arrival("gm_force_formal_arrival", true)
	return {"ok": _wagon_state == "arriving", "snapshot": get_market_snapshot()}


func debug_force_wagon_departure() -> Dictionary:
	_begin_departure("gm_force_departure", true)
	return get_market_snapshot()


func refresh_default_world_route() -> Dictionary:
	# Never replace a wagon's NavigationMap while it is physically travelling.
	# The next visit will pick up the current default world route.
	if _wagon_state == "absent":
		_build_route_navigation()
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


func _on_time_changed(day: int, hour: int, minute: int, _second: int) -> void:
	var minute_key := "%d:%d:%d" % [day, hour, minute]
	if minute_key == _last_evaluated_minute_key:
		return
	_last_evaluated_minute_key = minute_key
	_evaluate_current_time("time_changed")


func _on_game_over_changed(_result: String, _reason: String) -> void:
	_set_merchant_active(false, "game_over", false)
	_clear_wagon()


func _on_gameplay_pause_changed(paused: bool) -> void:
	if is_instance_valid(_wagon):
		_wagon.set_motion_paused(paused)


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
	var within_trade_window := false
	if arrival_minutes < departure_minutes:
		within_trade_window = current_minutes >= arrival_minutes and current_minutes < departure_minutes
	elif arrival_minutes > departure_minutes:
		within_trade_window = current_minutes >= arrival_minutes or current_minutes < departure_minutes
	var day := int(game_state.current_day)
	if within_trade_window:
		if _wagon_state == "absent" and _visit_started_day != day:
			_begin_arrival(reason, false)
		return
	if ["arriving", "parked"].has(_wagon_state):
		_begin_departure("departure_time", true)


func _set_merchant_active(active: bool, reason: String, record_event: bool) -> void:
	if _merchant_active == active:
		if is_instance_valid(_wagon):
			_wagon.set_trade_available(active)
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
	if is_instance_valid(_wagon):
		_wagon.set_trade_available(active)
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


func _begin_arrival(reason: String, forced: bool) -> void:
	if _merchant.is_empty() or _wagon_state != "absent":
		return
	var world_root := get_node_or_null(WORLD_ROOT_PATH) as Node3D
	if world_root == null or not _route_navigation_map.is_valid():
		push_error("Merchant wagon route is unavailable.")
		return
	var route := _get_active_physical_route()
	var spawn_point: Vector3 = route.get("spawn", Vector3.ZERO)
	var dock_point: Vector3 = route.get("dock", Vector3.ZERO)
	_wagon = WAGON_SCENE.instantiate() as MerchantWagon
	_wagon.name = "DailyMerchantWagon"
	world_root.add_child(_wagon)
	_wagon.global_position = spawn_point
	_wagon.set_navigation_map(_route_navigation_map)
	_wagon.motion_arrived.connect(_on_wagon_motion_arrived)
	_wagon.motion_failed.connect(_on_wagon_motion_failed)
	_wagon_state = "arriving"
	_forced_visit = forced
	var game_state := get_node_or_null("/root/GameState")
	_visit_started_day = int(game_state.current_day) if game_state != null else 1
	_last_state_change = {
		"active": false,
		"day": _visit_started_day,
		"time": _get_current_time_text(),
		"reason": reason,
		"wagon_state": _wagon_state
	}
	_request_wagon_motion.call_deferred(dock_point, MerchantWagon.ARRIVAL_REQUEST)


func _begin_departure(reason: String, record_event: bool) -> void:
	if not is_instance_valid(_wagon) or _wagon_state == "departing":
		return
	var was_trade_active := _merchant_active
	_set_merchant_active(false, reason, record_event and was_trade_active)
	_wagon_state = "departing"
	_forced_visit = false
	var game_state := get_node_or_null("/root/GameState")
	_visit_departed_day = int(game_state.current_day) if game_state != null else 1
	var route := _get_active_physical_route()
	var spawn_point: Vector3 = route.get("spawn", Vector3.ZERO)
	_request_wagon_motion(spawn_point, MerchantWagon.DEPARTURE_REQUEST)


func _request_wagon_motion(target: Vector3, request_id: String) -> void:
	if not is_instance_valid(_wagon):
		return
	_wagon.set_navigation_map(_route_navigation_map)
	if not _wagon.request_motion(target, request_id):
		push_error("Merchant wagon could not start %s." % request_id)


func _on_wagon_motion_arrived(request_id: String, _target: Vector3) -> void:
	if not is_instance_valid(_wagon):
		return
	if request_id == MerchantWagon.ARRIVAL_REQUEST and _wagon_state == "arriving":
		_wagon_state = "parked"
		_set_merchant_active(true, "physical_dock_arrived", true)
		return
	if request_id == MerchantWagon.DEPARTURE_REQUEST and _wagon_state == "departing":
		_clear_wagon()


func _on_wagon_motion_failed(request_id: String, reason: String) -> void:
	push_error("Merchant wagon motion failed (%s): %s" % [request_id, reason])
	_set_merchant_active(false, "wagon_motion_failed", false)
	_clear_wagon()


func _clear_wagon() -> void:
	if is_instance_valid(_wagon):
		_wagon.set_trade_available(false)
		_wagon.queue_free()
	_wagon = null
	_wagon_state = "absent"
	_merchant_active = false
	_forced_visit = false
	var restore_legacy_route := _formal_route_debug
	_formal_route_debug = false
	if _formal_preview_owned:
		var layout_controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		if layout_controller != null and layout_controller.has_method("set_runtime_formal_world_enabled"):
			layout_controller.call("set_runtime_formal_world_enabled", false)
	_formal_preview_owned = false
	if restore_legacy_route and not _merchant.is_empty():
		_build_route_navigation()


func _build_route_navigation() -> void:
	if is_instance_valid(_route_navigation_region):
		_route_navigation_region.queue_free()
	if _route_navigation_map.is_valid():
		NavigationServer3D.free_rid(_route_navigation_map)
		_route_navigation_map = RID()
	var route := _get_active_physical_route()
	var spawn: Vector3 = route.get("spawn", Vector3.ZERO)
	var dock: Vector3 = route.get("dock", Vector3.ZERO)
	var half_width := maxf(1.8, float(route.get("corridor_half_width", 3.2)))
	_route_mode = str(route.get("route_mode", "legacy_world_compatibility"))
	_route_world_points.clear()
	for raw_point in route.get("path_points", []):
		if raw_point is Vector3:
			var point: Vector3 = raw_point
			point.y = 0.12
			_route_world_points.append(point)
	if _route_world_points.size() < 2 or spawn.distance_squared_to(dock) <= 0.001:
		push_error("Merchant physical route has identical spawn and dock points.")
		return
	var vertices := _build_route_strip_vertices(_route_world_points, half_width)
	var mesh := NavigationMesh.new()
	mesh.agent_radius = 1.1
	mesh.agent_height = 2.4
	mesh.set_vertices(vertices)
	for index in range(_route_world_points.size() - 1):
		var first := index * 2
		var next := (index + 1) * 2
		mesh.add_polygon(PackedInt32Array([first, next, next + 1, first + 1]))
	_route_navigation_map = NavigationServer3D.map_create()
	NavigationServer3D.map_set_cell_size(_route_navigation_map, 0.25)
	NavigationServer3D.map_set_cell_height(_route_navigation_map, 0.1)
	NavigationServer3D.map_set_active(_route_navigation_map, true)
	_route_navigation_region = NavigationRegion3D.new()
	_route_navigation_region.name = "MerchantRouteNavigation"
	_route_navigation_region.navigation_mesh = mesh
	_route_navigation_region.use_edge_connections = true
	_route_navigation_region.enabled = true
	_route_navigation_region.set_navigation_map(_route_navigation_map)
	_route_navigation_region.set_meta("roads_affect_navigation", false)
	_route_navigation_region.set_meta("authority", "merchant_physical_route")
	var world_root := get_node_or_null(WORLD_ROOT_PATH)
	if world_root != null:
		world_root.add_child(_route_navigation_region)


func _get_active_physical_route() -> Dictionary:
	if _formal_route_debug or _should_use_default_formal_route():
		var layout_controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
		if layout_controller != null and layout_controller.has_method("get_formal_merchant_route_world"):
			var formal_route := layout_controller.call("get_formal_merchant_route_world") as Dictionary
			if not formal_route.is_empty():
				formal_route["route_mode"] = "formal_rear_trade_debug" if _formal_route_debug else "formal_rear_trade_default"
				return formal_route
	var configured := (_merchant.get("physical_route", {}) as Dictionary).duplicate(true)
	var spawn := _route_point_to_world(configured.get("spawn", []))
	var dock := _route_point_to_world(configured.get("dock", []))
	configured["spawn"] = spawn
	configured["dock"] = dock
	configured["path_points"] = [spawn, dock]
	configured["route_mode"] = "legacy_world_compatibility"
	return configured


func _should_use_default_formal_route() -> bool:
	var layout_controller := get_node_or_null(STATION_LAYOUT_CONTROLLER_PATH)
	return (
		layout_controller != null
		and layout_controller.has_method("is_default_formal_world_enabled")
		and bool(layout_controller.is_default_formal_world_enabled())
	)


func _build_route_strip_vertices(points: Array[Vector3], half_width: float) -> PackedVector3Array:
	var vertices := PackedVector3Array()
	for index in range(points.size()):
		var current := Vector2(points[index].x, points[index].z)
		var previous := Vector2(points[maxi(index - 1, 0)].x, points[maxi(index - 1, 0)].z)
		var following := Vector2(points[mini(index + 1, points.size() - 1)].x, points[mini(index + 1, points.size() - 1)].z)
		var incoming := (current - previous).normalized() if index > 0 else (following - current).normalized()
		var outgoing := (following - current).normalized() if index < points.size() - 1 else incoming
		var incoming_normal := Vector2(-incoming.y, incoming.x)
		var outgoing_normal := Vector2(-outgoing.y, outgoing.x)
		var miter := (incoming_normal + outgoing_normal).normalized()
		if miter.length_squared() <= 0.001:
			miter = outgoing_normal
		var denominator := maxf(0.5, absf(miter.dot(outgoing_normal)))
		var side := miter * minf(half_width / denominator, half_width * 1.5)
		vertices.append(Vector3(current.x + side.x, 0.12, current.y + side.y))
		vertices.append(Vector3(current.x - side.x, 0.12, current.y - side.y))
	return vertices


func _route_point_to_world(raw_point: Variant) -> Vector3:
	if raw_point is Array and (raw_point as Array).size() >= 2:
		return Vector3(float(raw_point[0]), 0.12, float(raw_point[1]))
	return Vector3.ZERO


func _disable_legacy_marker() -> void:
	var marker := get_node_or_null(MARKER_PATH) as Node3D
	if marker != null:
		marker.visible = false
		marker.process_mode = Node.PROCESS_MODE_DISABLED


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
