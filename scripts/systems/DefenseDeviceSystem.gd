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
const ATTACK_TIMELINE_EPSILON := 0.000001

var _definitions: Dictionary = {}
var _device_order: Array[String] = []
var _slots: Dictionary = {}
var _configured_slots: Dictionary = {}
var _slot_order: Array[String] = []
var _deployments: Dictionary = {}
var _slot_occupancy: Dictionary = {}
var _device_ruins: Dictionary = {}
var _last_deployment_result: Dictionary = {}
var _last_action_result: Dictionary = {}
var _slot_spatial_binding := "configured_legacy"
var _pending_projectile_attacks: Dictionary = {}


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
		event_bus.logical_time_tick.connect(_on_logical_time_tick)


func _process(delta: float) -> void:
	if delta <= 0.0 or _device_ruins.is_empty():
		set_process(not _device_ruins.is_empty())
		return
	var expired_slots: Array[String] = []
	for raw_slot_id in _device_ruins.keys():
		var slot_id := str(raw_slot_id)
		var ruin: Dictionary = _device_ruins.get(slot_id, {})
		ruin["remaining_seconds"] = maxf(0.0, float(ruin.get("remaining_seconds", 0.0)) - delta)
		_device_ruins[slot_id] = ruin
		if float(ruin.get("remaining_seconds", 0.0)) <= 0.0:
			expired_slots.append(slot_id)
	if expired_slots.is_empty():
		return
	for slot_id in expired_slots:
		_device_ruins.erase(slot_id)
	set_process(not _device_ruins.is_empty())
	_emit_state_changed()


func initialize() -> void:
	_definitions.clear()
	_device_order.clear()
	_slots.clear()
	_configured_slots.clear()
	_slot_order.clear()
	_deployments.clear()
	_slot_occupancy.clear()
	_device_ruins.clear()
	_last_deployment_result.clear()
	_last_action_result.clear()
	_pending_projectile_attacks.clear()
	_slot_spatial_binding = "configured_legacy"
	set_process(false)

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
		_configured_slots[slot_id] = slot.duplicate(true)
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
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var building_id := str(slot.get("building_id", "wall"))
	var building: Dictionary = (
		building_system.get_building(building_id)
		if building_system != null and building_system.has_method("get_building")
		else {}
	)
	var current_level := int(building.get("level", 0))
	var required_level := maxi(1, int(slot.get("required_building_level", 1)))
	var host_available := not building.is_empty() and int(building.get("hp", 0)) > 0
	var modifiers: Dictionary = (
		slot.get("effect_modifiers", {}).duplicate(true)
		if slot.get("effect_modifiers", {}) is Dictionary
		else {}
	)
	var base_range_multiplier := maxf(
		0.1,
		float(modifiers.get("range_multiplier", 1.0))
	)
	var host_range_bonus := _get_host_defense_device_range_bonus(
		building_system,
		building_id,
		current_level
	)
	modifiers["base_range_multiplier"] = base_range_multiplier
	modifiers["host_range_bonus"] = host_range_bonus
	modifiers["range_multiplier"] = base_range_multiplier * (1.0 + host_range_bonus)
	slot["effect_modifiers"] = modifiers
	slot["occupied"] = not deployment_id.is_empty()
	slot["deployment_id"] = deployment_id
	slot["current_building_level"] = current_level
	slot["required_building_level"] = required_level
	slot["host_available"] = host_available
	slot["unlocked"] = host_available and current_level >= required_level
	return slot


func bind_formal_slot_positions(station_layout_controller: Node) -> Dictionary:
	if station_layout_controller == null or not station_layout_controller.has_method("get_defense_device_slot_pose"):
		return {"ok": false, "reason": "formal_slot_pose_provider_missing", "bound_slot_count": 0}
	var bound_slot_ids: Array[String] = []
	for slot_id in _slot_order:
		var slot: Dictionary = _slots.get(slot_id, {})
		var building_id := str(slot.get("building_id", ""))
		var pose: Variant = station_layout_controller.call("get_defense_device_slot_pose", building_id, slot_id)
		if not pose is Dictionary or (pose as Dictionary).is_empty():
			continue
		var pose_data := pose as Dictionary
		if pose_data.has("required_level") and int(pose_data.get("required_level", -1)) != int(slot.get("required_building_level", -2)):
			push_error("Defense slot level drift between runtime and formal layout: %s" % slot_id)
			continue
		var world_position: Variant = pose_data.get("position", null)
		var facing_direction: Variant = pose_data.get("facing_direction", null)
		if not world_position is Vector3 or not facing_direction is Vector3:
			continue
		slot["position"] = _vector3_to_dict(world_position as Vector3)
		slot["facing_direction"] = _vector3_to_dict(facing_direction as Vector3)
		slot["rotation_y_degrees"] = float(pose_data.get("rotation_y_degrees", 0.0))
		slot["spatial_source"] = "formal_station_fixture"
		slot["formal_fixture_id"] = str(pose_data.get("fixture_id", ""))
		for proxy_field in [
			"host_proxy_schema",
			"host_proxy_regions",
			"host_proxy_kind",
			"host_proxy_id",
			"host_proxy_wall_segment_id",
			"host_proxy_building_segment_id",
			"host_proxy_fixture_id",
			"host_proxy_position",
			"host_proxy_aim_position",
			"host_proxy_fixture_aim_position",
			"host_proxy_outward_direction",
			"host_proxy_contact_radius",
			"host_proxy_hit_radius"
		]:
			if pose_data.has(proxy_field):
				slot[proxy_field] = (
					_vector3_to_dict(pose_data[proxy_field])
					if pose_data[proxy_field] is Vector3
					else pose_data[proxy_field]
				)
		_slots[slot_id] = slot
		bound_slot_ids.append(slot_id)
	_slot_spatial_binding = "formal_station_fixture" if not bound_slot_ids.is_empty() else "configured_legacy"
	_emit_state_changed()
	return {
		"ok": not bound_slot_ids.is_empty(),
		"spatial_binding": _slot_spatial_binding,
		"bound_slot_count": bound_slot_ids.size(),
		"bound_slot_ids": bound_slot_ids
	}


func restore_configured_slot_positions() -> Dictionary:
	for slot_id in _slot_order:
		if not _configured_slots.has(slot_id) or not _slots.has(slot_id):
			continue
		var configured: Dictionary = _configured_slots.get(slot_id, {})
		var slot: Dictionary = _slots.get(slot_id, {})
		for field in ["position", "facing_direction", "rotation_y_degrees"]:
			slot[field] = configured.get(field)
		slot.erase("spatial_source")
		slot.erase("formal_fixture_id")
		for proxy_field in [
			"host_proxy_schema",
			"host_proxy_regions",
			"host_proxy_kind",
			"host_proxy_id",
			"host_proxy_wall_segment_id",
			"host_proxy_building_segment_id",
			"host_proxy_fixture_id",
			"host_proxy_position",
			"host_proxy_aim_position",
			"host_proxy_fixture_aim_position",
			"host_proxy_outward_direction",
			"host_proxy_contact_radius",
			"host_proxy_hit_radius"
		]:
			slot.erase(proxy_field)
		_slots[slot_id] = slot
	_slot_spatial_binding = "configured_legacy"
	_emit_state_changed()
	return {"ok": true, "spatial_binding": _slot_spatial_binding, "restored_slot_count": _slot_order.size()}


func get_slots_for_device(
	device_id: String,
	available_only: bool = false,
	building_id: String = ""
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_id in _slot_order:
		var slot := get_slot(slot_id)
		if not building_id.is_empty() and str(slot.get("building_id", "")) != building_id:
			continue
		var allowed: Array = slot.get("allowed_device_ids", [])
		if not allowed.has(device_id):
			continue
		if available_only and (
			bool(slot.get("occupied", false))
			or not bool(slot.get("unlocked", false))
		):
			continue
		result.append(slot)
	return result


func get_slots_for_building(building_id: String, include_locked: bool = true) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_id in _slot_order:
		var slot := get_slot(slot_id)
		if str(slot.get("building_id", "")) != building_id:
			continue
		if not include_locked and not bool(slot.get("unlocked", false)):
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


func get_device_ruins() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_id in _slot_order:
		var ruin: Variant = _device_ruins.get(slot_id)
		if ruin is Dictionary and not (ruin as Dictionary).is_empty():
			result.append((ruin as Dictionary).duplicate(true))
	return result


func get_attack_range_indicator_snapshot(deployment_id: String) -> Dictionary:
	var deployment := get_deployment(deployment_id)
	if deployment.is_empty():
		return {"ready": false, "reason": "deployment_unavailable", "deployment_id": deployment_id}
	var slot := get_slot(str(deployment.get("slot_id", "")))
	if (
		str(deployment.get("status", "")) != "active"
		or int(deployment.get("hp", 0)) <= 0
		or not bool(slot.get("host_available", false))
	):
		return {"ready": false, "reason": "deployment_not_active", "deployment_id": deployment_id}
	var effect: Dictionary = deployment.get("effect", {}) if deployment.get("effect", {}) is Dictionary else {}
	var effective_range := maxf(0.0, float(effect.get("range", 0.0)))
	var world_position := _dict_to_vector3(deployment.get("position", {}))
	if effective_range <= 0.0:
		return {"ready": false, "reason": "authoritative_range_unavailable", "deployment_id": deployment_id}
	return {
		"ready": true,
		"source_type": "defense_device",
		"source_id": deployment_id,
		"source_name": str(deployment.get("device_name", deployment_id)),
		"device_id": str(deployment.get("device_id", "")),
		"building_id": str(deployment.get("building_id", "")),
		"slot_id": str(deployment.get("slot_id", "")),
		"effective_range": effective_range,
		"world_position": world_position,
		"range_authority": "defense_device_system.effect.range",
		"range_semantics": "maximum_attack_initiation_ballistic_distance"
	}


func get_active_defense_targets() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for deployment in get_deployments():
		var slot := get_slot(str(deployment.get("slot_id", "")))
		if (
			str(deployment.get("status", "")) != "active"
			or int(deployment.get("hp", 0)) <= 0
			or not bool(slot.get("host_available", false))
		):
			continue
		var host_proxy := _make_host_proxy_snapshot(slot, deployment)
		var host_proxy_regions: Array = host_proxy.get("regions", []) as Array
		var proxy_position := _dict_to_vector3(host_proxy.get("position", deployment.get("position", {})))
		var proxy_aim_position := _dict_to_vector3(host_proxy.get("aim_position", proxy_position))
		var proxy_outward_direction := _dict_to_vector3(host_proxy.get("outward_direction", slot.get("facing_direction", {"z": 1.0})))
		var effect: Dictionary = deployment.get("effect", {}) if deployment.get("effect", {}) is Dictionary else {}
		result.append({
			"type": "defense_device",
			"id": str(deployment.get("deployment_id", "")),
			"name": str(deployment.get("device_name", "工程器械")),
			"position": proxy_position,
			"aim_position": proxy_aim_position,
			"host_proxy_outward_direction": proxy_outward_direction,
			"facing_direction": _dict_to_vector3(slot.get("facing_direction", {"z": 1.0})),
			"contact_radius": float(host_proxy.get("contact_radius", 0.0)),
			"hp": int(deployment.get("hp", 0)),
			"max_hp": int(deployment.get("max_hp", 0)),
			"defense": float(deployment.get("defense", 0.0)),
			"effective_attack_range": maxf(0.0, float(effect.get("range", 0.0))),
			"building_id": str(deployment.get("building_id", "")),
			"slot_id": str(deployment.get("slot_id", "")),
			"host_proxy": host_proxy,
			"host_proxy_schema": str(host_proxy.get("schema", "")),
			"host_proxy_regions": host_proxy_regions.duplicate(true),
			"host_proxy_kind": str(host_proxy.get("kind", "")),
			"host_proxy_id": str(host_proxy.get("id", "")),
			"host_proxy_wall_segment_id": str(host_proxy.get("wall_segment_id", "")),
			"host_proxy_building_segment_id": str(host_proxy.get("building_segment_id", "")),
			"host_proxy_fixture_id": str(host_proxy.get("fixture_id", "")),
			"host_proxy_hit_radius": float(host_proxy.get("hit_radius", 0.0))
		})
	return result


func apply_damage_to_device(
	deployment_id: String,
	damage: int,
	context: Dictionary = {}
) -> Dictionary:
	if not _deployments.has(deployment_id):
		return {}
	var deployment: Dictionary = _deployments.get(deployment_id, {})
	if str(deployment.get("status", "")) != "active":
		return {}
	var hp_before := maxi(0, int(deployment.get("hp", 0)))
	var resolved_damage := maxi(0, damage)
	var hp_after := maxi(0, hp_before - resolved_damage)
	var destroyed := hp_after <= 0
	deployment["hp"] = hp_after
	deployment["status"] = "destroyed" if destroyed else "active"
	deployment["last_damage_result"] = {
		"damage": resolved_damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"destroyed": destroyed,
		"attacker_id": str(context.get("attacker_id", "")),
		"attacker_name": str(context.get("attacker_name", "敌人")),
		"attack_id": str(context.get("attack_id", "")),
		"host_proxy_id": str(context.get("host_proxy_id", "")),
		"collision_identity": context.get("collision_identity", {}).duplicate(true) if context.get("collision_identity", {}) is Dictionary else {}
	}
	_deployments[deployment_id] = deployment
	var snapshot := _make_deployment_snapshot(deployment)
	if destroyed:
		var slot_id := str(deployment.get("slot_id", ""))
		_slot_occupancy.erase(slot_id)
		_register_device_ruin(slot_id, snapshot)
		_deployments.erase(deployment_id)
	_emit_state_changed()
	return {
		"ok": true,
		"deployment_id": deployment_id,
		"device_id": str(deployment.get("device_id", "")),
		"device_name": str(snapshot.get("device_name", "工程器械")),
		"damage": resolved_damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"destroyed": destroyed,
		"deployment": snapshot
	}


func get_state_snapshot() -> Dictionary:
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	return {
		"inventory_amounts": _get_inventory_amounts(resource_system),
		"device_inventory": _get_device_inventory_snapshot(resource_system),
		"device_ids": get_device_ids(),
		"slot_spatial_binding": _slot_spatial_binding,
		"slots": _get_all_slot_snapshots(),
		"deployments": get_deployments(),
		"ruins": get_device_ruins(),
		"last_deployment_result": _last_deployment_result.duplicate(true),
		"last_action_result": _last_action_result.duplicate(true)
	}


func get_deploy_eligibility(device_id: String, slot_id: String) -> Dictionary:
	if _is_game_over():
		return _deployment_error("game_over", "结算已经结束，不能继续部署器械。")
	if not _definitions.has(device_id):
		return _deployment_error("unknown_device", "未知工程器械。")
	if not _slots.has(slot_id):
		return _deployment_error("unknown_slot", "未知工程器械部署槽。")
	if _slot_occupancy.has(slot_id):
		return _deployment_error("slot_occupied", "该部署槽已经被占用。")

	var slot: Dictionary = _slots.get(slot_id, {})
	if not (slot.get("allowed_device_ids", []) as Array).has(device_id):
		return _deployment_error("slot_incompatible", "该器械不能部署到所选槽位。")
	var host_result := _validate_slot_host(slot)
	if not bool(host_result.get("ok", false)):
		return host_result
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
		"hp": maxi(1, int(definition.get("max_hp", 1))),
		"max_hp": maxi(1, int(definition.get("max_hp", 1))),
		"defense": maxf(0.0, float(definition.get("defense", 0.0))),
		"attack_cooldown": 0.0,
		"attack_phase": "idle",
		"attack_elapsed": 0.0,
		"attack_cycle_duration": 0.0,
		"attack_release_seconds": 0.0,
		"attack_target": {},
		"attack_release_committed": false,
		"attack_sequence": 0,
		"total_attacks": 0,
		"total_damage": 0,
		"last_action_result": {}
	}
	_device_ruins.erase(slot_id)
	set_process(not _device_ruins.is_empty())
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


func undeploy_device(deployment_id: String, confirm_damaged_destruction: bool = false) -> Dictionary:
	var deployment := get_deployment(deployment_id)
	if deployment.is_empty() or str(deployment.get("status", "")) != "active":
		return _deployment_error("unknown_deployment", "该工程器械已经不在部署槽中。")
	var hp := maxi(0, int(deployment.get("hp", 0)))
	var max_hp := maxi(1, int(deployment.get("max_hp", 1)))
	var damaged := hp < max_hp
	if damaged and not confirm_damaged_destruction:
		return {
			"ok": false,
			"code": "damaged_device_confirmation_required",
			"message": "该器械已经受损，卸下会直接销毁且不会返回库存。",
			"requires_confirmation": true,
			"deployment_id": deployment_id,
			"deployment": deployment.duplicate(true)
		}

	var device_id := str(deployment.get("device_id", ""))
	var slot_id := str(deployment.get("slot_id", ""))
	var definition: Dictionary = _definitions.get(device_id, {})
	var inventory_return: Dictionary = (
		definition.get("inventory_cost", {}).duplicate(true)
		if not damaged and definition.get("inventory_cost", {}) is Dictionary
		else {}
	)
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if not inventory_return.is_empty() and (
		resource_system == null
		or not resource_system.has_method("can_store_resources")
		or not resource_system.has_method("add_resources")
	):
		return _deployment_error("resource_system_missing", "资源系统不可用，不能安全归还器械。")
	if not inventory_return.is_empty() and not bool(resource_system.can_store_resources(inventory_return)):
		return _deployment_error("inventory_return_failed", "器械库存空间不足，无法卸下。")

	_deployments.erase(deployment_id)
	_slot_occupancy.erase(slot_id)
	if not inventory_return.is_empty() and not bool(resource_system.add_resources(inventory_return)):
		_deployments[deployment_id] = deployment.duplicate(true)
		_slot_occupancy[slot_id] = deployment_id
		return _deployment_error("inventory_return_failed", "器械库存归还失败，部署未改变。")
	_remove_pending_projectiles_for_deployment(deployment_id)

	var result := {
		"ok": true,
		"deployment_id": deployment_id,
		"device_id": device_id,
		"device_name": str(deployment.get("device_name", device_id)),
		"slot_id": slot_id,
		"damaged": damaged,
		"destroyed": damaged,
		"returned_to_inventory": not damaged,
		"returned_inventory": inventory_return.duplicate(true),
		"deployment": deployment.duplicate(true)
	}
	_last_deployment_result = result.duplicate(true)
	_emit_state_changed()
	return result


func debug_deploy_device(device_id: String, slot_id: String) -> Dictionary:
	return deploy_device(device_id, slot_id)


func debug_destroy_device(deployment_id: String) -> Dictionary:
	var deployment := get_deployment(deployment_id)
	if deployment.is_empty():
		return {
			"ok": false,
			"reason": "unknown_deployment",
			"deployment_id": deployment_id
		}
	return apply_damage_to_device(
		deployment_id,
		maxi(1, int(deployment.get("hp", 0))),
		{
			"attacker_id": "gm_destructible_ruin_verification",
			"attacker_name": "GM 废墟验收",
			"attack_id": "gm_destroy_device:%s" % deployment_id
		}
	)


func debug_destroy_first_device() -> Dictionary:
	var deployments := get_deployments()
	if deployments.is_empty():
		return {
			"ok": false,
			"reason": "no_active_deployment"
		}
	return debug_destroy_device(str(deployments[0].get("deployment_id", "")))


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
		"combat_seconds": game_delta_seconds,
		"actions": []
	}
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("get_active_enemy_count"):
		result["ok"] = false
		result["error"] = "combat_system_missing"
		return result
	if int(combat_system.get_active_enemy_count()) <= 0:
		_reset_all_attack_timelines()
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
	var slot := get_slot(str(deployment.get("slot_id", "")))
	var host_result := _validate_slot_host(slot)
	if not bool(host_result.get("ok", false)):
		return {
			"deployment_id": deployment_id,
			"attack_count": 0,
			"cooldown": float(deployment.get("attack_cooldown", 0.0)),
			"reason": str(host_result.get("error", "slot_host_unavailable"))
		}
	var effect := _make_effective_effect(definition, slot)
	if str(effect.get("kind", "")) != "auto_attack":
		return {}

	var remaining := maxf(0.0, action_seconds)
	var interval := maxf(0.1, float(effect.get("attack_interval", 4.0)))
	var timing: Dictionary = effect.get("attack_timing", {}) if effect.get("attack_timing", {}) is Dictionary else {}
	var release_seconds := clampf(float(timing.get("release_seconds", interval * 0.25)), 0.0, interval)
	var max_attacks := maxi(1, int(effect.get("max_attacks_per_tick", 16)))
	var attacks: Array[Dictionary] = []
	while remaining > ATTACK_TIMELINE_EPSILON and attacks.size() < max_attacks:
		var phase := str(deployment.get("attack_phase", "idle"))
		if not phase in ["windup", "recovery"]:
			var acquired := _select_attack_target(deployment, definition, combat_system)
			if acquired.is_empty():
				_reset_attack_timeline(deployment)
				break
			deployment["attack_phase"] = "windup"
			deployment["attack_elapsed"] = 0.0
			deployment["attack_cycle_duration"] = interval
			deployment["attack_release_seconds"] = release_seconds
			deployment["attack_target"] = acquired.duplicate(true)
			deployment["attack_release_committed"] = false
			_emit_action_phase(deployment_id, _make_timeline_phase_snapshot(deployment, definition, slot, effect, "windup"))
			phase = "windup"

		if phase == "windup":
			var refreshed := _refresh_attack_target(deployment, definition, combat_system)
			if refreshed.is_empty():
				_emit_action_phase(deployment_id, _make_timeline_phase_snapshot(deployment, definition, slot, effect, "cancelled"))
				_reset_attack_timeline(deployment)
				break
			deployment["attack_target"] = refreshed.duplicate(true)

		var elapsed := maxf(0.0, float(deployment.get("attack_elapsed", 0.0)))
		var boundary := release_seconds if phase == "windup" else interval
		var consumed := minf(remaining, maxf(0.0, boundary - elapsed))
		elapsed += consumed
		remaining -= consumed
		deployment["attack_elapsed"] = elapsed
		deployment["attack_cooldown"] = maxf(0.0, interval - elapsed)
		_emit_action_phase(deployment_id, _make_timeline_phase_snapshot(deployment, definition, slot, effect, phase))
		if elapsed + ATTACK_TIMELINE_EPSILON < boundary:
			break

		if phase == "windup":
			var release_target := _refresh_attack_target(deployment, definition, combat_system)
			if release_target.is_empty():
				_emit_action_phase(deployment_id, _make_timeline_phase_snapshot(deployment, definition, slot, effect, "cancelled"))
				_reset_attack_timeline(deployment)
				continue
			deployment["attack_target"] = release_target.duplicate(true)
			deployment["attack_sequence"] = int(deployment.get("attack_sequence", 0)) + 1
			# The synchronous windup update turns the formal model before CombatSystem
			# samples its real muzzle transform.
			_emit_action_phase(deployment_id, _make_timeline_phase_snapshot(deployment, definition, slot, effect, "windup"))
			var release: Dictionary = combat_system.release_defense_device_projectile(
				_make_deployment_snapshot(deployment),
				release_target,
				effect
			) if combat_system.has_method("release_defense_device_projectile") else {}
			deployment["attack_release_committed"] = not release.is_empty()
			deployment["attack_phase"] = "recovery"
			if not release.is_empty():
				var attack_id := str(release.get("attack_id", ""))
				var released := _make_timeline_phase_snapshot(deployment, definition, slot, effect, "release")
				released["attack_id"] = attack_id
				released["projectile"] = release.duplicate(true)
				_pending_projectile_attacks[attack_id] = {
					"deployment_id": deployment_id,
					"device_id": str(deployment.get("device_id", "")),
					"device_name": str(definition.get("name", "工程器械")),
					"slot_id": str(deployment.get("slot_id", "")),
					"target_enemy_id": str(release_target.get("id", "")),
					"target_enemy_name": str(release_target.get("name", "敌人")),
					"origin_position": release.get("release_position", _dict_to_vector3(slot.get("position", {}))),
					"target_position": release_target.get("position", Vector3.ZERO),
					"attack_interval": interval,
					"attack_sequence": int(deployment.get("attack_sequence", 0))
				}
				deployment["total_attacks"] = int(deployment.get("total_attacks", 0)) + 1
				deployment["last_action_result"] = released.duplicate(true)
				attacks.append(released)
				_emit_action_phase(deployment_id, released)
			else:
				var rejected := _make_timeline_phase_snapshot(deployment, definition, slot, effect, "release_rejected")
				deployment["last_action_result"] = rejected.duplicate(true)
				_emit_action_phase(deployment_id, rejected)
			continue

		_reset_attack_timeline(deployment)
		_emit_action_phase(deployment_id, _make_timeline_phase_snapshot(deployment, definition, slot, effect, "idle"))

	_deployments[deployment_id] = deployment
	if attacks.is_empty():
		return {
			"deployment_id": deployment_id,
			"attack_count": 0,
			"cooldown": float(deployment.get("attack_cooldown", 0.0)),
			"phase": str(deployment.get("attack_phase", "idle")),
			"reason": "timeline_advanced_without_release"
		}
	_emit_state_changed()
	return {
		"deployment_id": deployment_id,
		"device_id": str(deployment.get("device_id", "")),
		"attack_count": attacks.size(),
		"cooldown": float(deployment.get("attack_cooldown", 0.0)),
		"phase": str(deployment.get("attack_phase", "idle")),
		"attacks": attacks
	}


func resolve_defense_device_projectile(projectile_result: Dictionary) -> Dictionary:
	var attack_id := str(projectile_result.get("attack_id", ""))
	if attack_id.is_empty() or not _pending_projectile_attacks.has(attack_id):
		return {}
	var pending: Dictionary = _pending_projectile_attacks.get(attack_id, {})
	_pending_projectile_attacks.erase(attack_id)
	var deployment_id := str(pending.get("deployment_id", ""))
	if not _deployments.has(deployment_id):
		return {}
	var deployment: Dictionary = _deployments.get(deployment_id, {})
	var definition: Dictionary = _definitions.get(str(deployment.get("device_id", "")), {})
	var resolution: Dictionary = projectile_result.get("resolution", {}) if projectile_result.get("resolution", {}) is Dictionary else {}
	var damage_result: Dictionary = resolution.get("damage_result", {}) if resolution.get("damage_result", {}) is Dictionary else {}
	var actual_target_id := str(resolution.get("actual_target_id", pending.get("target_enemy_id", "")))
	var resolved := {
		"deployment_id": deployment_id,
		"device_id": str(pending.get("device_id", "")),
		"device_name": str(pending.get("device_name", "工程器械")),
		"slot_id": str(pending.get("slot_id", "")),
		"attack_id": attack_id,
		"attack_sequence": int(pending.get("attack_sequence", 0)),
		"projectile_status": str(projectile_result.get("status", "miss")),
		"target_enemy_id": actual_target_id,
		"target_enemy_name": str(damage_result.get("enemy_name", pending.get("target_enemy_name", "敌人"))),
		"damage": int(damage_result.get("damage", 0)),
		"hp_before": int(damage_result.get("hp_before", 0)),
		"hp_after": int(damage_result.get("hp_after", 0)),
		"defeated": bool(damage_result.get("defeated", false)),
		"origin_position": _vector3_to_dict(pending.get("origin_position", Vector3.ZERO)),
		"target_position": _vector3_to_dict(pending.get("target_position", Vector3.ZERO)),
		"attack_interval": float(pending.get("attack_interval", 0.0)),
		"damage_authority": "combat_system_swept_collision",
		"combat_result": damage_result.duplicate(true),
		"projectile_result": projectile_result.duplicate(true)
	}
	resolved["event"] = _record_action_event(deployment, definition, resolved)
	deployment["total_damage"] = int(deployment.get("total_damage", 0)) + int(resolved.get("damage", 0))
	deployment["last_action_result"] = resolved.duplicate(true)
	_deployments[deployment_id] = deployment
	_last_action_result = resolved.duplicate(true)
	_emit_action_resolved(deployment_id, resolved)
	_emit_state_changed()
	return resolved


func _refresh_attack_target(deployment: Dictionary, definition: Dictionary, combat_system: Node) -> Dictionary:
	var current: Dictionary = deployment.get("attack_target", {}) if deployment.get("attack_target", {}) is Dictionary else {}
	var target_id := str(current.get("id", ""))
	if target_id.is_empty() or not combat_system.has_method("get_enemy"):
		return {}
	var enemy: Dictionary = combat_system.get_enemy(target_id)
	if enemy.is_empty() or int(enemy.get("hp", 0)) <= 0:
		return {}
	var slot := get_slot(str(deployment.get("slot_id", "")))
	var effect := _make_effective_effect(definition, slot)
	var origin := _dict_to_vector3(slot.get("position", {}))
	var enemy_position: Vector3 = enemy.get("position", Vector3.ZERO)
	var offset := enemy_position - origin
	offset.y = 0.0
	var distance := offset.length()
	if distance > float(effect.get("range", 0.0)) + ATTACK_TIMELINE_EPSILON:
		return {}
	var forward := _dict_to_vector3(slot.get("facing_direction", {"z": 1.0}))
	forward.y = 0.0
	if forward.length_squared() > ATTACK_TIMELINE_EPSILON:
		forward = forward.normalized()
		if distance > ATTACK_TIMELINE_EPSILON and forward.dot(offset.normalized()) < float(effect.get("minimum_forward_dot", -1.0)):
			return {}
	return {
		"type": "enemy",
		"id": target_id,
		"name": str(enemy.get("name", current.get("name", "敌人"))),
		"position": enemy_position,
		"distance": distance
	}


func _reset_attack_timeline(deployment: Dictionary) -> void:
	deployment["attack_phase"] = "idle"
	deployment["attack_elapsed"] = 0.0
	deployment["attack_cycle_duration"] = 0.0
	deployment["attack_release_seconds"] = 0.0
	deployment["attack_target"] = {}
	deployment["attack_release_committed"] = false
	deployment["attack_cooldown"] = 0.0


func _remove_pending_projectiles_for_deployment(deployment_id: String) -> void:
	for raw_attack_id in _pending_projectile_attacks.keys():
		var attack_id := str(raw_attack_id)
		var pending: Dictionary = _pending_projectile_attacks.get(attack_id, {})
		if str(pending.get("deployment_id", "")) == deployment_id:
			_pending_projectile_attacks.erase(attack_id)


func _reset_all_attack_timelines() -> void:
	var changed := false
	for raw_deployment_id in _deployments.keys():
		var deployment_id := str(raw_deployment_id)
		var deployment: Dictionary = _deployments.get(deployment_id, {})
		if str(deployment.get("attack_phase", "idle")) == "idle":
			continue
		var definition: Dictionary = _definitions.get(str(deployment.get("device_id", "")), {})
		var slot := get_slot(str(deployment.get("slot_id", "")))
		var effect := _make_effective_effect(definition, slot)
		_reset_attack_timeline(deployment)
		_deployments[deployment_id] = deployment
		_emit_action_phase(deployment_id, _make_timeline_phase_snapshot(deployment, definition, slot, effect, "idle"))
		changed = true
	if changed:
		_emit_state_changed()


func _make_timeline_phase_snapshot(
	deployment: Dictionary,
	definition: Dictionary,
	slot: Dictionary,
	effect: Dictionary,
	phase: String
) -> Dictionary:
	var target: Dictionary = deployment.get("attack_target", {}) if deployment.get("attack_target", {}) is Dictionary else {}
	var timing: Dictionary = effect.get("attack_timing", {}) if effect.get("attack_timing", {}) is Dictionary else {}
	return {
		"phase": phase,
		"deployment_id": str(deployment.get("deployment_id", "")),
		"device_id": str(deployment.get("device_id", "")),
		"device_name": str(definition.get("name", "工程器械")),
		"slot_id": str(deployment.get("slot_id", "")),
		"attack_sequence": int(deployment.get("attack_sequence", 0)),
		"attack_elapsed": float(deployment.get("attack_elapsed", 0.0)),
		"attack_interval": float(deployment.get("attack_cycle_duration", effect.get("attack_interval", 0.0))),
		"release_seconds": float(deployment.get("attack_release_seconds", timing.get("release_seconds", 0.0))),
		"recovery_seconds": float(timing.get("recovery_seconds", 0.0)),
		"playback_multiplier": float(timing.get("playback_multiplier", 1.0)),
		"release_committed": bool(deployment.get("attack_release_committed", false)),
		"target_enemy_id": str(target.get("id", "")),
		"target_enemy_name": str(target.get("name", "敌人")),
		"origin_position": _vector3_to_dict(_dict_to_vector3(slot.get("position", {}))),
		"target_position": _vector3_to_dict(target.get("position", Vector3.ZERO))
	}


func _select_attack_target(deployment: Dictionary, definition: Dictionary, combat_system: Node) -> Dictionary:
	var slot := get_slot(str(deployment.get("slot_id", "")))
	var effect := _make_effective_effect(definition, slot)
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


func _validate_slot_host(slot: Dictionary) -> Dictionary:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		return _deployment_error("building_system_missing", "建筑系统不可用。")
	var building_id := str(slot.get("building_id", "wall"))
	var building: Dictionary = building_system.get_building(building_id)
	if building.is_empty() or int(building.get("hp", 0)) <= 0:
		return _deployment_error("slot_host_unavailable", "部署位置所属建筑当前不可用。")
	var required_level := maxi(1, int(slot.get("required_building_level", 1)))
	if int(building.get("level", 1)) < required_level:
		return _deployment_error(
			"slot_locked",
			"%s达到 Lv.%d 后解锁该部署位。" % [
				str(building.get("name", building_id)),
				required_level
			]
		)
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
	normalized["tier"] = maxi(1, int(raw.get("tier", 1)))
	normalized["max_hp"] = maxi(1, int(raw.get("max_hp", 1)))
	normalized["defense"] = maxf(0.0, float(raw.get("defense", 0.0)))
	normalized["inventory_cost"] = _normalize_inventory_cost(raw.get("inventory_cost", {}))
	normalized["required_building_levels"] = raw.get("required_building_levels", {}).duplicate(true) if raw.get("required_building_levels", {}) is Dictionary else {}
	var effect: Dictionary = raw.get("effect", {}).duplicate(true) if raw.get("effect", {}) is Dictionary else {}
	effect["damage"] = maxf(1.0, float(effect.get("damage", 1.0)))
	effect["penetration"] = maxf(0.0, float(effect.get("penetration", 0.0)))
	var attack_speed := maxf(0.0, float(effect.get("attack_speed", 0.0)))
	var attack_interval := maxf(0.1, float(effect.get("attack_interval", 1.8)))
	if attack_speed <= 0.0:
		attack_speed = 1.0 / attack_interval
	attack_interval = 1.0 / attack_speed
	effect["attack_speed"] = attack_speed
	effect["attack_interval"] = attack_interval
	effect["range"] = maxf(0.1, float(effect.get("range", 1.0)))
	var raw_timing: Dictionary = effect.get("attack_timing", {}) if effect.get("attack_timing", {}) is Dictionary else {}
	var authored_cycle := maxf(0.1, float(raw_timing.get("authored_cycle_seconds", attack_interval)))
	var release_authored := clampf(float(raw_timing.get("release_authored_seconds", authored_cycle * 0.25)), 0.0, authored_cycle)
	effect["attack_timing"] = {
		"authored_cycle_seconds": authored_cycle,
		"release_authored_seconds": release_authored
	}
	var raw_projectile: Dictionary = effect.get("projectile", {}) if effect.get("projectile", {}) is Dictionary else {}
	var weapon_type := str(raw_projectile.get("weapon_type", "crossbow"))
	if not weapon_type in ["bow", "crossbow"]:
		weapon_type = "crossbow"
	effect["projectile"] = {
		"weapon_type": weapon_type,
		"speed": maxf(0.1, float(raw_projectile.get("speed", 30.0))),
		"gravity": maxf(0.01, float(raw_projectile.get("gravity", 9.8)))
	}
	normalized["effect"] = effect
	normalized["presentation"] = raw.get("presentation", {}).duplicate(true) if raw.get("presentation", {}) is Dictionary else {}
	return normalized


func _normalize_slot(raw: Dictionary) -> Dictionary:
	var normalized := raw.duplicate(true)
	normalized["id"] = str(raw.get("id", "")).strip_edges()
	normalized["name"] = str(raw.get("name", normalized.get("id", "围墙部署槽")))
	normalized["building_id"] = str(raw.get("building_id", "wall"))
	normalized["required_building_level"] = maxi(1, int(raw.get("required_building_level", 1)))
	var allowed: Array[String] = []
	for raw_id in raw.get("allowed_device_ids", []):
		var device_id := str(raw_id)
		if not device_id.is_empty() and not allowed.has(device_id):
			allowed.append(device_id)
	normalized["allowed_device_ids"] = allowed
	normalized["position"] = _vector3_to_dict(_dict_to_vector3(raw.get("position", {})))
	normalized["facing_direction"] = _vector3_to_dict(_dict_to_vector3(raw.get("facing_direction", {"z": 1.0})))
	normalized["rotation_y_degrees"] = float(raw.get("rotation_y_degrees", 0.0))
	var modifiers: Dictionary = raw.get("effect_modifiers", {}).duplicate(true) if raw.get("effect_modifiers", {}) is Dictionary else {}
	modifiers["range_multiplier"] = maxf(0.1, float(modifiers.get("range_multiplier", 1.0)))
	normalized["effect_modifiers"] = modifiers
	return normalized


func _make_deployment_snapshot(raw_deployment: Variant) -> Dictionary:
	if not raw_deployment is Dictionary or (raw_deployment as Dictionary).is_empty():
		return {}
	var deployment: Dictionary = (raw_deployment as Dictionary).duplicate(true)
	var definition: Dictionary = _definitions.get(str(deployment.get("device_id", "")), {})
	var slot := get_slot(str(deployment.get("slot_id", "")))
	deployment["device_name"] = str(definition.get("name", deployment.get("device_id", "工程器械")))
	deployment["description"] = str(definition.get("description", ""))
	deployment["tier"] = int(definition.get("tier", 1))
	deployment["hp"] = maxi(0, int(deployment.get("hp", definition.get("max_hp", 1))))
	deployment["max_hp"] = maxi(1, int(deployment.get("max_hp", definition.get("max_hp", 1))))
	deployment["defense"] = maxf(0.0, float(deployment.get("defense", definition.get("defense", 0.0))))
	deployment["base_effect"] = definition.get("effect", {}).duplicate(true) if definition.get("effect", {}) is Dictionary else {}
	deployment["effect"] = _make_effective_effect(definition, slot)
	deployment["presentation"] = definition.get("presentation", {}).duplicate(true) if definition.get("presentation", {}) is Dictionary else {}
	deployment["slot_name"] = str(slot.get("name", deployment.get("slot_id", "围墙部署槽")))
	deployment["position"] = slot.get("position", {}).duplicate(true) if slot.get("position", {}) is Dictionary else {}
	deployment["facing_direction"] = slot.get("facing_direction", {}).duplicate(true) if slot.get("facing_direction", {}) is Dictionary else {}
	deployment["rotation_y_degrees"] = float(slot.get("rotation_y_degrees", 0.0))
	deployment["range_multiplier"] = float((slot.get("effect_modifiers", {}) as Dictionary).get("range_multiplier", 1.0))
	deployment["host_proxy"] = _make_host_proxy_snapshot(slot, deployment)
	return deployment


func _make_host_proxy_snapshot(slot: Dictionary, deployment: Dictionary = {}) -> Dictionary:
	var slot_position := _dict_to_vector3(slot.get("position", {}))
	var building_id := str(slot.get("building_id", deployment.get("building_id", "")))
	var slot_id := str(slot.get("id", deployment.get("slot_id", "")))
	var proxy_kind := str(slot.get("host_proxy_kind", "legacy_host_building"))
	var proxy_id := str(slot.get("host_proxy_id", "%s:%s" % [building_id, slot_id]))
	var proxy_position := _dict_to_vector3(slot.get("host_proxy_position", slot_position))
	var proxy_aim_position := _dict_to_vector3(
		slot.get("host_proxy_aim_position", proxy_position + Vector3.UP * 1.15)
	)
	var proxy_fixture_aim_position := _dict_to_vector3(
		slot.get("host_proxy_fixture_aim_position", proxy_aim_position)
	)
	var proxy_outward_direction := _dict_to_vector3(
		slot.get("host_proxy_outward_direction", slot.get("facing_direction", {"z": 1.0}))
	)
	var snapshot := {
		"schema": str(slot.get("host_proxy_schema", "single_host_proxy_v1")),
		"kind": proxy_kind,
		"id": proxy_id,
		"building_id": building_id,
		"slot_id": slot_id,
		"wall_segment_id": str(slot.get("host_proxy_wall_segment_id", "")),
		"building_segment_id": str(slot.get("host_proxy_building_segment_id", "")),
		"fixture_id": str(slot.get("host_proxy_fixture_id", "")),
		"position": _vector3_to_dict(proxy_position),
		"aim_position": _vector3_to_dict(proxy_aim_position),
		"fixture_aim_position": _vector3_to_dict(proxy_fixture_aim_position),
		"outward_direction": _vector3_to_dict(proxy_outward_direction),
		"contact_radius": maxf(0.0, float(slot.get("host_proxy_contact_radius", 0.0))),
		"hit_radius": maxf(0.1, float(slot.get("host_proxy_hit_radius", 2.0))),
		"strict_collision_identity": proxy_kind != "legacy_host_building"
	}
	var region_snapshots: Array[Dictionary] = []
	var raw_regions: Variant = slot.get("host_proxy_regions", [])
	if raw_regions is Array:
		for raw_region in raw_regions as Array:
			if not raw_region is Dictionary:
				continue
			var region := raw_region as Dictionary
			var region_position := _dict_to_vector3(region.get("position", proxy_position))
			var region_aim_position := _dict_to_vector3(region.get("aim_position", region_position + Vector3.UP * 1.15))
			var region_fixture_aim_position := _dict_to_vector3(region.get("fixture_aim_position", proxy_fixture_aim_position))
			var region_outward_direction := _dict_to_vector3(region.get("outward_direction", proxy_outward_direction))
			region_snapshots.append({
				"kind": str(region.get("kind", proxy_kind)),
				"id": str(region.get("id", proxy_id)),
				"building_id": str(region.get("building_id", building_id)),
				"slot_id": str(region.get("slot_id", slot_id)),
				"wall_segment_id": str(region.get("wall_segment_id", "")),
				"building_segment_id": str(region.get("building_segment_id", "")),
				"fixture_id": str(region.get("fixture_id", slot.get("host_proxy_fixture_id", ""))),
				"position": _vector3_to_dict(region_position),
				"aim_position": _vector3_to_dict(region_aim_position),
				"fixture_aim_position": _vector3_to_dict(region_fixture_aim_position),
				"outward_direction": _vector3_to_dict(region_outward_direction),
				"contact_radius": maxf(0.0, float(region.get("contact_radius", snapshot.get("contact_radius", 0.0)))),
				"hit_radius": maxf(0.1, float(region.get("hit_radius", snapshot.get("hit_radius", 2.0)))),
				"strict_collision_identity": bool(region.get("strict_collision_identity", proxy_kind != "legacy_host_building"))
			})
	if region_snapshots.is_empty():
		var fallback_region := snapshot.duplicate(true)
		fallback_region.erase("schema")
		fallback_region.erase("regions")
		region_snapshots.append(fallback_region)
	snapshot["regions"] = region_snapshots
	return snapshot


func _make_effective_effect(definition: Dictionary, slot: Dictionary) -> Dictionary:
	var effect: Dictionary = definition.get("effect", {}).duplicate(true) if definition.get("effect", {}) is Dictionary else {}
	var modifiers: Dictionary = slot.get("effect_modifiers", {}) if slot.get("effect_modifiers", {}) is Dictionary else {}
	var range_multiplier := maxf(0.1, float(modifiers.get("range_multiplier", 1.0)))
	effect["base_range"] = maxf(0.1, float(effect.get("range", 1.0)))
	effect["range_multiplier"] = range_multiplier
	effect["range"] = float(effect.get("base_range", 1.0)) * range_multiplier
	var attack_speed := maxf(0.01, float(effect.get("attack_speed", 0.0)))
	if attack_speed <= 0.01:
		attack_speed = 1.0 / maxf(0.1, float(effect.get("attack_interval", 1.8)))
	effect["attack_speed"] = attack_speed
	effect["attack_interval"] = 1.0 / attack_speed
	var interval := float(effect.get("attack_interval", 1.0))
	var authored: Dictionary = effect.get("attack_timing", {}) if effect.get("attack_timing", {}) is Dictionary else {}
	var authored_cycle := maxf(0.1, float(authored.get("authored_cycle_seconds", interval)))
	var release_authored := clampf(float(authored.get("release_authored_seconds", authored_cycle * 0.25)), 0.0, authored_cycle)
	var release_ratio := release_authored / authored_cycle
	effect["attack_timing"] = {
		"authored_cycle_seconds": authored_cycle,
		"release_authored_seconds": release_authored,
		"release_ratio": release_ratio,
		"cycle_seconds": interval,
		"release_seconds": interval * release_ratio,
		"recovery_seconds": interval * (1.0 - release_ratio),
		"playback_multiplier": authored_cycle / interval
	}
	var projectile: Dictionary = effect.get("projectile", {}) if effect.get("projectile", {}) is Dictionary else {}
	projectile["max_range"] = float(effect.get("range", 0.0))
	projectile["max_lifetime"] = maxf(
		0.25,
		float(effect.get("range", 0.0)) / maxf(0.1, float(projectile.get("speed", 1.0))) * 2.0
	)
	effect["projectile"] = projectile
	return effect


func _get_host_defense_device_range_bonus(
	building_system: Node,
	building_id: String,
	current_level: int
) -> float:
	if (
		building_system == null
		or not building_system.has_method("get_upgrade_level_effect")
		or current_level < 2
	):
		return 0.0
	var bonus := 0.0
	for target_level in range(2, current_level + 1):
		var level_effect: Dictionary = building_system.get_upgrade_level_effect(
			building_id,
			target_level
		)
		bonus += maxf(
			0.0,
			float(level_effect.get("defense_device_range_bonus", 0.0))
		)
	return clampf(bonus, 0.0, 1.0)


func _get_all_slot_snapshots() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_id in _slot_order:
		result.append(get_slot(slot_id))
	return result


func _register_device_ruin(slot_id: String, destroyed_snapshot: Dictionary) -> void:
	if slot_id.is_empty() or destroyed_snapshot.is_empty():
		return
	var presentation: Dictionary = (
		destroyed_snapshot.get("presentation", {})
		if destroyed_snapshot.get("presentation", {}) is Dictionary
		else {}
	)
	var lifetime := maxf(0.1, float(presentation.get("ruin_lifetime_seconds", 15.0)))
	var ruin := destroyed_snapshot.duplicate(true)
	ruin["ruin_id"] = "ruin_%s" % slot_id
	ruin["status"] = "ruin"
	ruin["destroyed"] = true
	ruin["ruin_kind"] = str(presentation.get("ruin_kind", "collapsed_device"))
	ruin["lifetime_seconds"] = lifetime
	ruin["remaining_seconds"] = lifetime
	_device_ruins[slot_id] = ruin
	set_process(true)


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


func _emit_action_phase(deployment_id: String, phase_snapshot: Dictionary) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("defense_device_action_phase"):
		event_bus.defense_device_action_phase.emit(deployment_id, phase_snapshot.duplicate(true))


func _dict_to_vector3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if not raw is Dictionary:
		return Vector3.ZERO
	return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))


func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}
