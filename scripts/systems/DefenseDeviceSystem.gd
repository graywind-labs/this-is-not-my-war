extends Node

const DEVICE_DEFS_FILE := "defense_device_defs.json"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const COMBAT_SYSTEM_PATH := "/root/Main/Systems/CombatSystem"
const PLAZA_LOCATION_ID := "plaza"
const GUARD_OFFICER_ID := "guard_officer"
const DEPRECATED_FORMAL_INVENTORY_IDS: Array[String] = [
	"weapons", "armor", "defense_devices", "horse_readiness"
]
const COMBAT_ACTION_GAME_SECONDS_PER_SECOND := 60.0

var _definitions: Dictionary = {}
var _device_order: Array[String] = []
var _slots: Dictionary = {}
var _slot_order: Array[String] = []
var _deployments: Dictionary = {}
var _slot_occupancy: Dictionary = {}
var _last_deployment_result: Dictionary = {}
var _last_action_result: Dictionary = {}


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
		event_bus.logical_time_tick.connect(_on_logical_time_tick)


func initialize() -> void:
	_definitions.clear()
	_device_order.clear()
	_slots.clear()
	_slot_order.clear()
	_deployments.clear()
	_slot_occupancy.clear()
	_last_deployment_result.clear()
	_last_action_result.clear()

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("DefenseDeviceSystem requires ConfigLoader autoload.")
		return
	var loaded: Variant = config_loader.load_data_file(DEVICE_DEFS_FILE, {})
	if not loaded is Dictionary:
		push_error("Defense device definitions must be a JSON object: %s" % DEVICE_DEFS_FILE)
		return

	for raw_definition in (loaded as Dictionary).get("devices", []):
		if not raw_definition is Dictionary:
			continue
		var definition := _normalize_definition(raw_definition)
		var device_id := str(definition.get("id", ""))
		if device_id.is_empty() or _definitions.has(device_id):
			push_warning("Skipped invalid or duplicate defense device id: %s" % device_id)
			continue
		if (definition.get("inventory_cost", {}) as Dictionary).is_empty():
			push_warning("Skipped defense device with invalid single-item inventory cost: %s" % device_id)
			continue
		_definitions[device_id] = definition
		_device_order.append(device_id)

	for raw_slot in (loaded as Dictionary).get("slots", []):
		if not raw_slot is Dictionary:
			continue
		var slot := _normalize_slot(raw_slot)
		var slot_id := str(slot.get("id", ""))
		if slot_id.is_empty() or _slots.has(slot_id):
			push_warning("Skipped invalid or duplicate defense device slot id: %s" % slot_id)
			continue
		_slots[slot_id] = slot
		_slot_order.append(slot_id)


func get_device_ids() -> Array[String]:
	return _device_order.duplicate()


func get_device_definition(device_id: String) -> Dictionary:
	return _definitions.get(device_id, {}).duplicate(true)


func get_slot_ids() -> Array[String]:
	return _slot_order.duplicate()


func get_slot(slot_id: String) -> Dictionary:
	var slot: Dictionary = _slots.get(slot_id, {}).duplicate(true)
	if slot.is_empty():
		return {}
	var deployment_id := str(_slot_occupancy.get(slot_id, ""))
	slot["occupied"] = not deployment_id.is_empty()
	slot["deployment_id"] = deployment_id
	return slot


func get_slots_for_device(device_id: String, available_only: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_id in _slot_order:
		var slot := get_slot(slot_id)
		var allowed: Array = slot.get("allowed_device_ids", [])
		if not allowed.has(device_id):
			continue
		if available_only and bool(slot.get("occupied", false)):
			continue
		result.append(slot)
	return result


func get_deployment(deployment_id: String) -> Dictionary:
	return _make_deployment_snapshot(_deployments.get(deployment_id, {}))


func get_deployment_for_slot(slot_id: String) -> Dictionary:
	return get_deployment(str(_slot_occupancy.get(slot_id, "")))


func get_deployments() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_id in _slot_order:
		var deployment_id := str(_slot_occupancy.get(slot_id, ""))
		if deployment_id.is_empty():
			continue
		var deployment := get_deployment(deployment_id)
		if not deployment.is_empty():
			result.append(deployment)
	return result


func get_state_snapshot() -> Dictionary:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	return {
		"inventory_amounts": _get_inventory_amounts(resource_system),
		"device_inventory": _get_device_inventory_snapshot(resource_system),
		"device_ids": get_device_ids(),
		"slots": _get_all_slot_snapshots(),
		"deployments": get_deployments(),
		"last_deployment_result": _last_deployment_result.duplicate(true),
		"last_action_result": _last_action_result.duplicate(true)
	}


func get_deploy_eligibility(device_id: String, slot_id: String) -> Dictionary:
	if _is_game_over():
		return _deployment_error("game_over", "结算已经结束，不能继续部署器械。")
	if not _definitions.has(device_id):
		return _deployment_error("unknown_device", "未知工程器械。")
	if not _slots.has(slot_id):
		return _deployment_error("unknown_slot", "未知围墙部署槽。")
	if _slot_occupancy.has(slot_id):
		return _deployment_error("slot_occupied", "该部署槽已经被占用。")

	var slot: Dictionary = _slots.get(slot_id, {})
	if not (slot.get("allowed_device_ids", []) as Array).has(device_id):
		return _deployment_error("slot_incompatible", "该器械不能部署到所选槽位。")
	var definition: Dictionary = _definitions.get(device_id, {})
	var building_result := _validate_required_buildings(definition.get("required_building_levels", {}))
	if not bool(building_result.get("ok", false)):
		return building_result
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var cost: Dictionary = definition.get("inventory_cost", {})
	if cost.is_empty():
		return _deployment_error("invalid_inventory_cost", "器械没有合法的具体库存成本。")
	if resource_system == null or not resource_system.can_afford(cost):
		var cost_entry := _get_single_inventory_cost_entry(cost)
		var resource_name := str(cost_entry.get("resource_id", "工程器械"))
		if resource_system != null and resource_system.has_method("get_resource_name"):
			resource_name = str(resource_system.get_resource_name(resource_name))
		return _deployment_error("insufficient_inventory", "%s库存不足。" % resource_name)
	return {
		"ok": true,
		"device_id": device_id,
		"slot_id": slot_id,
		"inventory_cost": cost.duplicate(true)
	}


func deploy_device(device_id: String, slot_id: String) -> Dictionary:
	var eligibility := get_deploy_eligibility(device_id, slot_id)
	if not bool(eligibility.get("ok", false)):
		_last_deployment_result = eligibility.duplicate(true)
		return eligibility

	var definition: Dictionary = _definitions.get(device_id, {})
	var slot: Dictionary = _slots.get(slot_id, {})
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	var cost: Dictionary = definition.get("inventory_cost", {})
	if resource_system == null or not resource_system.spend_resources(cost):
		_last_deployment_result = _deployment_error("inventory_spend_failed", "工程器械库存扣除失败。")
		return _last_deployment_result.duplicate(true)

	var deployment_id := "deployed_%s" % slot_id
	var deployment := {
		"deployment_id": deployment_id,
		"device_id": device_id,
		"slot_id": slot_id,
		"building_id": str(slot.get("building_id", "wall")),
		"status": "active",
		"attack_cooldown": 0.0,
		"total_attacks": 0,
		"total_damage": 0,
		"last_action_result": {}
	}
	_deployments[deployment_id] = deployment
	_slot_occupancy[slot_id] = deployment_id

	var event := _record_deployment_event(deployment, definition, slot, cost)
	var result := {
		"ok": true,
		"deployment_id": deployment_id,
		"device_id": device_id,
		"slot_id": slot_id,
		"inventory_cost": cost.duplicate(true),
		"deployment": get_deployment(deployment_id),
		"event": event
	}
	_last_deployment_result = result.duplicate(true)
	_emit_deployed(deployment_id)
	_emit_state_changed()
	return result


func debug_deploy_device(device_id: String, slot_id: String) -> Dictionary:
	return deploy_device(device_id, slot_id)


func debug_advance_defense_devices(game_delta_seconds: float = 60.0) -> Dictionary:
	return _advance_defense_devices(maxf(0.0, game_delta_seconds))


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0 or _is_game_over():
		return
	_advance_defense_devices(game_delta_seconds)


func _advance_defense_devices(game_delta_seconds: float) -> Dictionary:
	var result := {
		"ok": true,
		"game_seconds": game_delta_seconds,
		"combat_seconds": game_delta_seconds / COMBAT_ACTION_GAME_SECONDS_PER_SECOND,
		"actions": []
	}
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("get_active_enemy_count"):
		result["ok"] = false
		result["error"] = "combat_system_missing"
		return result
	if int(combat_system.get_active_enemy_count()) <= 0:
		_last_action_result = result.duplicate(true)
		return result

	var action_seconds := maxf(0.0, float(result.get("combat_seconds", 0.0)))
	for deployment_id in _deployments.keys():
		if int(combat_system.get_active_enemy_count()) <= 0:
			break
		var action_result := _advance_auto_attack(str(deployment_id), action_seconds, combat_system)
		if not action_result.is_empty():
			(result["actions"] as Array).append(action_result)
	_last_action_result = result.duplicate(true)
	return result


func _advance_auto_attack(deployment_id: String, action_seconds: float, combat_system: Node) -> Dictionary:
	var deployment: Dictionary = _deployments.get(deployment_id, {})
	if deployment.is_empty() or str(deployment.get("status", "")) != "active":
		return {}
	var definition: Dictionary = _definitions.get(str(deployment.get("device_id", "")), {})
	var effect: Dictionary = definition.get("effect", {})
	if str(effect.get("kind", "")) != "auto_attack":
		return {}

	var remaining := action_seconds
	var cooldown := maxf(0.0, float(deployment.get("attack_cooldown", 0.0)))
	var interval := maxf(0.1, float(effect.get("attack_interval", 4.0)))
	var max_attacks := maxi(1, int(effect.get("max_attacks_per_tick", 16)))
	var attacks: Array[Dictionary] = []
	while remaining > 0.0 and attacks.size() < max_attacks and int(combat_system.get_active_enemy_count()) > 0:
		if cooldown > remaining:
			cooldown -= remaining
			remaining = 0.0
			break
		remaining -= cooldown
		var target := _select_attack_target(deployment, definition, combat_system)
		if target.is_empty():
			cooldown = 0.0
			break
		var attack_result: Dictionary = combat_system.apply_defense_device_attack(
			str(target.get("id", "")),
			maxf(1.0, float(effect.get("damage", 1.0))),
			{
				"deployment_id": deployment_id,
				"device_id": str(deployment.get("device_id", "")),
				"device_name": str(definition.get("name", "工程器械")),
				"slot_id": str(deployment.get("slot_id", ""))
			}
		)
		if attack_result.is_empty():
			break
		var resolved := {
			"deployment_id": deployment_id,
			"device_id": str(deployment.get("device_id", "")),
			"device_name": str(definition.get("name", "工程器械")),
			"target_enemy_id": str(attack_result.get("enemy_id", target.get("id", ""))),
			"target_enemy_name": str(attack_result.get("enemy_name", target.get("name", "敌人"))),
			"damage": int(attack_result.get("damage", 0)),
			"hp_before": int(attack_result.get("hp_before", 0)),
			"hp_after": int(attack_result.get("hp_after", 0)),
			"defeated": bool(attack_result.get("defeated", false)),
			"combat_result": attack_result
		}
		resolved["event"] = _record_action_event(deployment, definition, resolved)
		attacks.append(resolved)
		deployment["total_attacks"] = int(deployment.get("total_attacks", 0)) + 1
		deployment["total_damage"] = int(deployment.get("total_damage", 0)) + int(resolved.get("damage", 0))
		deployment["last_action_result"] = resolved.duplicate(true)
		cooldown = interval
		_emit_action_resolved(deployment_id, resolved)

	deployment["attack_cooldown"] = cooldown
	_deployments[deployment_id] = deployment
	if attacks.is_empty():
		return {
			"deployment_id": deployment_id,
			"attack_count": 0,
			"cooldown": cooldown,
			"reason": "no_target_in_range"
		}
	_emit_state_changed()
	return {
		"deployment_id": deployment_id,
		"device_id": str(deployment.get("device_id", "")),
		"attack_count": attacks.size(),
		"cooldown": cooldown,
		"attacks": attacks
	}


func _select_attack_target(deployment: Dictionary, definition: Dictionary, combat_system: Node) -> Dictionary:
	var effect: Dictionary = definition.get("effect", {})
	var slot: Dictionary = _slots.get(str(deployment.get("slot_id", "")), {})
	var origin := _dict_to_vector3(slot.get("position", {}))
	var forward := _dict_to_vector3(slot.get("facing_direction", {"z": 1.0}))
	forward.y = 0.0
	if forward.length() <= 0.001:
		forward = Vector3.FORWARD * -1.0
	else:
		forward = forward.normalized()
	var attack_range := maxf(0.1, float(effect.get("range", 20.0)))
	var minimum_forward_dot := clampf(float(effect.get("minimum_forward_dot", -1.0)), -1.0, 1.0)
	var nearest := {}
	var nearest_distance := INF
	for raw_enemy in combat_system.get_active_enemies():
		if not raw_enemy is Dictionary:
			continue
		var enemy: Dictionary = raw_enemy
		var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
		var offset := enemy_position - origin
		offset.y = 0.0
		var distance := offset.length()
		if distance > attack_range or distance >= nearest_distance:
			continue
		if distance > 0.001 and forward.dot(offset.normalized()) < minimum_forward_dot:
			continue
		nearest = {
			"id": str(enemy.get("id", "")),
			"name": str(enemy.get("name", "敌人")),
			"position": enemy_position,
			"distance": distance
		}
		nearest_distance = distance
	return nearest


func _record_deployment_event(deployment: Dictionary, definition: Dictionary, slot: Dictionary, cost: Dictionary) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var cost_entry := _get_single_inventory_cost_entry(cost)
	return memory_system.add_event({
		"type": "defense_device_deployed",
		"subject_npc_id": GUARD_OFFICER_ID,
		"actor_ids": [GUARD_OFFICER_ID],
		"target_ids": [str(deployment.get("device_id", "")), str(deployment.get("slot_id", "")), str(deployment.get("building_id", "wall"))],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 72,
		"payload": {
			"deployment_id": str(deployment.get("deployment_id", "")),
			"device_id": str(deployment.get("device_id", "")),
			"device_name": str(definition.get("name", "工程器械")),
			"slot_id": str(deployment.get("slot_id", "")),
			"slot_name": str(slot.get("name", "围墙部署槽")),
			"building_id": str(deployment.get("building_id", "wall")),
			"inventory_resource_id": str(cost_entry.get("resource_id", "")),
			"inventory_cost": int(cost_entry.get("amount", 0))
		}
	})


func _record_action_event(deployment: Dictionary, definition: Dictionary, action: Dictionary) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "defense_device_triggered",
		"subject_npc_id": GUARD_OFFICER_ID,
		"actor_ids": [GUARD_OFFICER_ID, str(deployment.get("device_id", ""))],
		"target_ids": [str(action.get("target_enemy_id", "")), str(deployment.get("slot_id", ""))],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "local_public",
		"importance": 58 if not bool(action.get("defeated", false)) else 74,
		"payload": {
			"deployment_id": str(deployment.get("deployment_id", "")),
			"device_id": str(deployment.get("device_id", "")),
			"device_name": str(definition.get("name", "工程器械")),
			"slot_id": str(deployment.get("slot_id", "")),
			"target_enemy_id": str(action.get("target_enemy_id", "")),
			"target_enemy_name": str(action.get("target_enemy_name", "敌人")),
			"damage": int(action.get("damage", 0)),
			"hp_before": int(action.get("hp_before", 0)),
			"hp_after": int(action.get("hp_after", 0)),
			"defeated": bool(action.get("defeated", false))
		}
	})


func _validate_required_buildings(raw_requirements: Variant) -> Dictionary:
	var requirements: Dictionary = raw_requirements if raw_requirements is Dictionary else {}
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		return _deployment_error("building_system_missing", "建筑系统不可用。")
	for building_id in requirements.keys():
		var building: Dictionary = building_system.get_building(str(building_id))
		var required_level := maxi(1, int(requirements[building_id]))
		if building.is_empty() or int(building.get("hp", 0)) <= 0:
			return _deployment_error("required_building_unavailable", "%s当前不可用于器械部署。" % str(building_id))
		if int(building.get("level", 1)) < required_level:
			return _deployment_error("building_level_too_low", "%s需要达到 Lv.%d。" % [str(building.get("name", building_id)), required_level])
	return {"ok": true}


func _normalize_inventory_cost(raw_cost: Variant) -> Dictionary:
	if not raw_cost is Dictionary:
		return {}
	var cost: Dictionary = raw_cost
	if cost.size() != 1:
		return {}
	var resource_id := str(cost.keys()[0]).strip_edges()
	var amount := int(cost.get(resource_id, 0))
	if resource_id.is_empty() or DEPRECATED_FORMAL_INVENTORY_IDS.has(resource_id) or amount <= 0:
		return {}
	return {resource_id: amount}


func _get_single_inventory_cost_entry(cost: Dictionary) -> Dictionary:
	if cost.size() != 1:
		return {}
	var resource_id := str(cost.keys()[0])
	return {
		"resource_id": resource_id,
		"amount": int(cost.get(resource_id, 0))
	}


func _get_inventory_amounts(resource_system: Node) -> Dictionary:
	var amounts := {}
	if resource_system == null or not resource_system.has_method("get_resource"):
		return amounts
	for device_id in _device_order:
		var definition: Dictionary = _definitions.get(device_id, {})
		var cost_entry := _get_single_inventory_cost_entry(definition.get("inventory_cost", {}))
		var resource_id := str(cost_entry.get("resource_id", ""))
		if not resource_id.is_empty() and not amounts.has(resource_id):
			amounts[resource_id] = int(resource_system.get_resource(resource_id))
	return amounts


func _get_device_inventory_snapshot(resource_system: Node) -> Dictionary:
	var snapshot := {}
	for device_id in _device_order:
		var definition: Dictionary = _definitions.get(device_id, {})
		var cost: Dictionary = definition.get("inventory_cost", {})
		var cost_entry := _get_single_inventory_cost_entry(cost)
		var resource_id := str(cost_entry.get("resource_id", ""))
		var amount := 0
		var can_afford := false
		if resource_system != null and resource_system.has_method("get_resource"):
			amount = int(resource_system.get_resource(resource_id))
			can_afford = resource_system.can_afford(cost) if resource_system.has_method("can_afford") else false
		snapshot[device_id] = {
			"resource_id": resource_id,
			"amount": amount,
			"required_amount": int(cost_entry.get("amount", 0)),
			"can_afford": can_afford
		}
	return snapshot


func _normalize_definition(raw: Dictionary) -> Dictionary:
	var normalized := raw.duplicate(true)
	normalized["id"] = str(raw.get("id", "")).strip_edges()
	normalized["name"] = str(raw.get("name", normalized.get("id", "工程器械")))
	normalized["inventory_cost"] = _normalize_inventory_cost(raw.get("inventory_cost", {}))
	normalized["required_building_levels"] = raw.get("required_building_levels", {}).duplicate(true) if raw.get("required_building_levels", {}) is Dictionary else {}
	normalized["effect"] = raw.get("effect", {}).duplicate(true) if raw.get("effect", {}) is Dictionary else {}
	normalized["presentation"] = raw.get("presentation", {}).duplicate(true) if raw.get("presentation", {}) is Dictionary else {}
	return normalized


func _normalize_slot(raw: Dictionary) -> Dictionary:
	var normalized := raw.duplicate(true)
	normalized["id"] = str(raw.get("id", "")).strip_edges()
	normalized["name"] = str(raw.get("name", normalized.get("id", "围墙部署槽")))
	normalized["building_id"] = str(raw.get("building_id", "wall"))
	var allowed: Array[String] = []
	for raw_id in raw.get("allowed_device_ids", []):
		var device_id := str(raw_id)
		if not device_id.is_empty() and not allowed.has(device_id):
			allowed.append(device_id)
	normalized["allowed_device_ids"] = allowed
	normalized["position"] = _vector3_to_dict(_dict_to_vector3(raw.get("position", {})))
	normalized["facing_direction"] = _vector3_to_dict(_dict_to_vector3(raw.get("facing_direction", {"z": 1.0})))
	normalized["rotation_y_degrees"] = float(raw.get("rotation_y_degrees", 0.0))
	return normalized


func _make_deployment_snapshot(raw_deployment: Variant) -> Dictionary:
	if not raw_deployment is Dictionary or (raw_deployment as Dictionary).is_empty():
		return {}
	var deployment: Dictionary = (raw_deployment as Dictionary).duplicate(true)
	var definition: Dictionary = _definitions.get(str(deployment.get("device_id", "")), {})
	var slot: Dictionary = _slots.get(str(deployment.get("slot_id", "")), {})
	deployment["device_name"] = str(definition.get("name", deployment.get("device_id", "工程器械")))
	deployment["description"] = str(definition.get("description", ""))
	deployment["effect"] = definition.get("effect", {}).duplicate(true) if definition.get("effect", {}) is Dictionary else {}
	deployment["presentation"] = definition.get("presentation", {}).duplicate(true) if definition.get("presentation", {}) is Dictionary else {}
	deployment["slot_name"] = str(slot.get("name", deployment.get("slot_id", "围墙部署槽")))
	deployment["position"] = slot.get("position", {}).duplicate(true) if slot.get("position", {}) is Dictionary else {}
	deployment["facing_direction"] = slot.get("facing_direction", {}).duplicate(true) if slot.get("facing_direction", {}) is Dictionary else {}
	deployment["rotation_y_degrees"] = float(slot.get("rotation_y_degrees", 0.0))
	return deployment


func _get_all_slot_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_id in _slot_order:
		result.append(get_slot(slot_id))
	return result


func _deployment_error(code: String, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}


func _is_game_over() -> bool:
	var game_state := get_node_or_null("/root/GameState")
	return game_state != null and bool(game_state.get("game_over"))


func _emit_deployed(deployment_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("defense_device_deployed"):
		event_bus.defense_device_deployed.emit(deployment_id, get_deployment(deployment_id))


func _emit_state_changed() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("defense_device_state_changed"):
		event_bus.defense_device_state_changed.emit(get_state_snapshot())


func _emit_action_resolved(deployment_id: String, action_result: Dictionary) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("defense_device_action_resolved"):
		event_bus.defense_device_action_resolved.emit(deployment_id, action_result.duplicate(true))


func _dict_to_vector3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if not raw is Dictionary:
		return Vector3.ZERO
	return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))


func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}
