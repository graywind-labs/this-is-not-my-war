extends Node

const BUILDING_DEFS_FILE := "building_defs.json"
const BUILDING_ROOT_PATH := "/root/Main/WorldRoot/Station/Buildings"
const PROPS_ROOT_PATH := "/root/Main/WorldRoot/Station/Props"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const CLICK_AREA_NAME := "ClickArea"
const PICK_RAY_LENGTH := 1000.0
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const PLAZA_LOCATION_ID := "plaza"
const DEFAULT_REPAIR_SECONDS_PER_HP := 30.0
const DEFAULT_REPAIR_LEVEL_TIME_FACTOR := 0.35
const DEFAULT_REPAIR_HELPER_BASE_BONUS := 0.10
const DEFAULT_REPAIR_HELPER_SKILL_SCALE := 0.005
const DEFAULT_REPAIR_HELPER_MAX_BONUS := 0.50
const DEFAULT_UPGRADE_SECONDS_PER_LEVEL := 3600.0
const DEFAULT_UPGRADE_LEVEL_TIME_FACTOR := 0.35

var _buildings: Dictionary = {}
var _building_order: Array[String] = []
var _selected_building_id: String = ""
var _building_scene_nodes: Dictionary = {}
var _active_repairs: Dictionary = {}
var _active_upgrades: Dictionary = {}


func initialize() -> void:
	_buildings.clear()
	_building_order.clear()
	_building_scene_nodes.clear()
	_active_repairs.clear()
	_active_upgrades.clear()
	_selected_building_id = ""

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("BuildingSystem requires ConfigLoader autoload.")
		return

	var loaded_defs: Variant = config_loader.load_data_file(BUILDING_DEFS_FILE, [])
	if not loaded_defs is Array:
		push_error("Building definitions must be a JSON array: %s" % BUILDING_DEFS_FILE)
		return

	for raw_definition in loaded_defs:
		if not raw_definition is Dictionary:
			push_error("Skipped invalid building definition because it is not a dictionary.")
			continue

		var definition: Dictionary = raw_definition
		var building_id := str(definition.get("id", ""))
		if building_id.is_empty():
			push_error("Skipped building definition with empty id.")
			continue

		var max_hp := int(definition.get("max_hp", definition.get("hp", 1)))
		var hp := clampi(int(definition.get("hp", max_hp)), 0, max_hp)
		definition["hp"] = hp
		definition["max_hp"] = max_hp
		definition["level"] = max(1, int(definition.get("level", 1)))

		_buildings[building_id] = definition.duplicate(true)
		_building_order.append(building_id)
		_bind_scene_nodes(building_id, definition)


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.logical_time_tick.connect(_on_logical_time_tick)
		event_bus.npc_state_changed.connect(_on_npc_state_changed)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var building_id := _pick_building_at_screen_position(event.position)
		if not building_id.is_empty():
			_select_building(building_id)
			get_viewport().set_input_as_handled()


func get_building(building_id: String) -> Dictionary:
	if not _buildings.has(building_id):
		push_warning("Unknown building id: %s" % building_id)
		return {}
	var building: Dictionary = _buildings[building_id].duplicate(true)
	building["condition"] = _get_building_condition(building_id)
	if _active_repairs.has(building_id):
		building["repair_status"] = _get_repair_status(building_id)
	else:
		building["repair_status"] = {}
	if _active_upgrades.has(building_id):
		building["upgrade_status"] = _get_upgrade_status(building_id)
	else:
		building["upgrade_status"] = {}
	return building


func get_building_ids() -> Array[String]:
	return _building_order.duplicate()


func get_building_snapshot() -> Dictionary:
	return _buildings.duplicate(true)


func claim_workstation(building_id: String, npc_id: String, preferred_type: String = "") -> Dictionary:
	if building_id.is_empty() or npc_id.is_empty() or not _buildings.has(building_id):
		return {"ok": false, "reason": "invalid_workstation_request"}

	var building: Dictionary = _buildings[building_id]
	var workstations: Array = building.get("workstations", [])
	for index in range(workstations.size()):
		if not workstations[index] is Dictionary:
			continue
		var workstation: Dictionary = workstations[index]
		var occupied_by := str(workstation.get("occupied_by", ""))
		if occupied_by == "<null>":
			occupied_by = ""
		if not occupied_by.is_empty() and occupied_by != npc_id:
			continue
		var workstation_type := str(workstation.get("type", ""))
		if not preferred_type.is_empty() and workstation_type != preferred_type:
			continue
		workstation["occupied_by"] = npc_id
		workstations[index] = workstation
		building["workstations"] = workstations
		_buildings[building_id] = building
		_emit_building_state_changed(building_id)
		return {
			"ok": true,
			"building_id": building_id,
			"workstation_id": str(workstation.get("id", "")),
			"workstation_type": workstation_type
		}

	return {"ok": false, "reason": "no_free_workstation"}


func release_workstation(building_id: String, npc_id: String, workstation_id: String = "") -> bool:
	if building_id.is_empty() or npc_id.is_empty() or not _buildings.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var workstations: Array = building.get("workstations", [])
	var changed := false
	for index in range(workstations.size()):
		if not workstations[index] is Dictionary:
			continue
		var workstation: Dictionary = workstations[index]
		var current_id := str(workstation.get("id", ""))
		var occupied_by := str(workstation.get("occupied_by", ""))
		if occupied_by != npc_id:
			continue
		if not workstation_id.is_empty() and current_id != workstation_id:
			continue
		workstation["occupied_by"] = null
		workstations[index] = workstation
		changed = true
		if not workstation_id.is_empty():
			break

	if not changed:
		return false

	building["workstations"] = workstations
	_buildings[building_id] = building
	_emit_building_state_changed(building_id)
	return true


func get_selected_building_id() -> String:
	return _selected_building_id


func get_building_entry_position(building_id: String) -> Variant:
	if building_id == PLAZA_LOCATION_ID:
		var plaza_node := get_node_or_null("%s/Plaza" % PROPS_ROOT_PATH) as Node3D
		if plaza_node == null:
			push_warning("Cannot get plaza entry position.")
			return null
		var plaza_position := plaza_node.global_position
		plaza_position.y = 0.0
		return plaza_position

	if not _buildings.has(building_id):
		push_warning("Cannot get entry position for unknown building: %s" % building_id)
		return null
	if not _building_scene_nodes.has(building_id):
		push_warning("Building has no bound scene nodes: %s" % building_id)
		return null

	var node_paths: Array = _building_scene_nodes.get(building_id, [])
	for raw_path in node_paths:
		var building_node := get_node_or_null(NodePath(str(raw_path))) as Node3D
		if building_node == null:
			continue

		var entry_position := building_node.global_position
		var entry_offset := Vector3(0.0, 0.0, 1.2)
		if building_node is MeshInstance3D:
			var mesh_instance := building_node as MeshInstance3D
			if mesh_instance.mesh != null:
				var mesh_size := mesh_instance.mesh.get_aabb().size
				entry_offset.z = maxf(1.2, mesh_size.z * 0.5 + 0.8)
		entry_position += entry_offset
		entry_position.y = 0.0
		return entry_position

	return null


func get_building_location_context(building_id: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system != null and memory_system.has_method("get_location_snapshot"):
		var snapshot: Dictionary = memory_system.get_location_snapshot(building_id)
		if not snapshot.is_empty():
			return snapshot

	var building := get_building(building_id)
	if building.is_empty():
		return {}

	var workstations: Array = building.get("workstations", [])
	var visible_workstations: Array = []
	for raw_workstation in workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		var occupied_by := str(workstation.get("occupied_by", ""))
		visible_workstations.append({
			"id": str(workstation.get("id", "")),
			"type": str(workstation.get("type", "")),
			"occupied_by": occupied_by,
			"status": "free" if occupied_by.is_empty() or occupied_by == "<null>" else "occupied"
		})
	var external_state := {
		"id": building_id,
		"name": str(building.get("name", building_id)),
		"level": int(building.get("level", 1)),
		"condition": _get_building_condition(building_id)
	}
	return {
		"id": building_id,
		"name": str(building.get("name", building_id)),
		"is_enterable": true,
		"people_present": [],
		"level": int(external_state["level"]),
		"condition": str(external_state["condition"]),
		"external_state": external_state,
		"internal_state": {
			"people_present": [],
			"workstations": visible_workstations.duplicate(true)
		},
		"building": {
			"id": building_id,
			"name": str(building.get("name", building_id)),
			"external_state": external_state,
			"internal_state": {
				"people_present": [],
				"workstations": visible_workstations.duplicate(true)
			}
		},
		"workstations": visible_workstations.duplicate(true),
		"current_notice": "",
		"current_orders": "",
		"current_public_note_ids": [],
		"public_notes": []
	}


func can_repair_building(building_id: String) -> bool:
	if not _buildings.has(building_id):
		return false
	if _active_repairs.has(building_id) or _active_upgrades.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	if int(building.get("hp", 0)) >= int(building.get("max_hp", 0)):
		return false

	var repair_config: Dictionary = building.get("repair", {})
	var cost: Dictionary = repair_config.get("cost", {})
	if cost.is_empty():
		return false

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	return resource_system != null and resource_system.can_afford(cost)


func repair_building(building_id: String) -> bool:
	if not can_repair_building(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var repair_config: Dictionary = building.get("repair", {})
	var cost: Dictionary = repair_config.get("cost", {})
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.spend_resources(cost):
		return false

	var max_hp := int(building.get("max_hp", 0))
	var current_hp := int(building.get("hp", 0))
	var missing_hp := maxi(1, max_hp - current_hp)
	var duration_seconds := _calculate_repair_duration_seconds(building, repair_config, missing_hp)
	_active_repairs[building_id] = {
		"building_id": building_id,
		"duration_seconds": duration_seconds,
		"remaining_seconds": duration_seconds,
		"start_hp": current_hp,
		"target_hp": max_hp,
		"helpers": {}
	}
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)
	return true


func is_repair_in_progress(building_id: String) -> bool:
	return _active_repairs.has(building_id)


func get_repair_status(building_id: String) -> Dictionary:
	_prune_invalid_repair_helpers(building_id)
	return _get_repair_status(building_id)


func add_repair_helper(building_id: String, npc_id: String, engineering_skill: int) -> bool:
	if not _active_repairs.has(building_id) or npc_id.is_empty():
		return false

	var job: Dictionary = _active_repairs[building_id]
	var helpers: Dictionary = job.get("helpers", {})
	var bonus := _calculate_repair_helper_bonus(engineering_skill)
	helpers[npc_id] = {
		"engineering_skill": clampi(engineering_skill, 0, 100),
		"speed_bonus": bonus
	}
	job["helpers"] = helpers
	_active_repairs[building_id] = job
	_emit_building_state_changed(building_id)
	return true


func remove_repair_helper(building_id: String, npc_id: String) -> bool:
	if not _active_repairs.has(building_id):
		return false
	var job: Dictionary = _active_repairs[building_id]
	var helpers: Dictionary = job.get("helpers", {})
	if not helpers.has(npc_id):
		return false
	helpers.erase(npc_id)
	job["helpers"] = helpers
	_active_repairs[building_id] = job
	_emit_building_state_changed(building_id)
	return true


func can_upgrade_building(building_id: String) -> bool:
	if not _buildings.has(building_id):
		return false
	if _active_repairs.has(building_id) or _active_upgrades.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	if int(building.get("hp", 0)) < int(building.get("max_hp", 0)):
		return false

	var upgrade_config: Dictionary = building.get("upgrade", {})
	if upgrade_config.is_empty():
		return false

	var max_level := int(upgrade_config.get("max_level", int(building.get("level", 1))))
	if int(building.get("level", 1)) >= max_level:
		return false

	var cost: Dictionary = upgrade_config.get("cost", {})
	if cost.is_empty():
		return false

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	return resource_system != null and resource_system.can_afford(cost)


func upgrade_building(building_id: String) -> bool:
	if not can_upgrade_building(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var upgrade_config: Dictionary = building.get("upgrade", {})
	var cost: Dictionary = upgrade_config.get("cost", {})
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.spend_resources(cost):
		return false

	var duration_seconds := _calculate_upgrade_duration_seconds(building, upgrade_config)
	_active_upgrades[building_id] = {
		"building_id": building_id,
		"duration_seconds": duration_seconds,
		"remaining_seconds": duration_seconds,
		"start_level": int(building.get("level", 1)),
		"target_level": int(building.get("level", 1)) + 1,
		"upgrade_config": upgrade_config.duplicate(true),
		"helpers": {}
	}
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)
	return true


func is_upgrade_in_progress(building_id: String) -> bool:
	return _active_upgrades.has(building_id)


func get_upgrade_status(building_id: String) -> Dictionary:
	_prune_invalid_upgrade_helpers(building_id)
	return _get_upgrade_status(building_id)


func add_upgrade_helper(building_id: String, npc_id: String, engineering_skill: int) -> bool:
	if not _active_upgrades.has(building_id) or npc_id.is_empty():
		return false

	var job: Dictionary = _active_upgrades[building_id]
	var helpers: Dictionary = job.get("helpers", {})
	var bonus := _calculate_repair_helper_bonus(engineering_skill)
	helpers[npc_id] = {
		"engineering_skill": clampi(engineering_skill, 0, 100),
		"speed_bonus": bonus
	}
	job["helpers"] = helpers
	_active_upgrades[building_id] = job
	_emit_building_state_changed(building_id)
	return true


func remove_upgrade_helper(building_id: String, npc_id: String) -> bool:
	if not _active_upgrades.has(building_id):
		return false
	var job: Dictionary = _active_upgrades[building_id]
	var helpers: Dictionary = job.get("helpers", {})
	if not helpers.has(npc_id):
		return false
	helpers.erase(npc_id)
	job["helpers"] = helpers
	_active_upgrades[building_id] = job
	_emit_building_state_changed(building_id)
	return true


func debug_damage_building(building_id: String, amount: int) -> bool:
	if amount <= 0 or not _buildings.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	building["hp"] = maxi(0, int(building.get("hp", 0)) - amount)
	if _active_repairs.has(building_id):
		_release_repair_helpers(_active_repairs[building_id], building_id)
		_active_repairs.erase(building_id)
	if _active_upgrades.has(building_id):
		_release_upgrade_helpers(_active_upgrades[building_id], building_id)
		_active_upgrades.erase(building_id)
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)
	return true


func restore_building_hp(building_id: String, amount: int) -> bool:
	if amount <= 0 or not _buildings.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var max_hp := int(building.get("max_hp", 0))
	var current_hp := int(building.get("hp", 0))
	if current_hp >= max_hp:
		return true

	building["hp"] = mini(max_hp, current_hp + amount)
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)
	return true


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0:
		return

	var finished_buildings: Array[String] = []
	for raw_building_id in _active_repairs.keys():
		var building_id := str(raw_building_id)
		_prune_invalid_repair_helpers(building_id)
		var job: Dictionary = _active_repairs[building_id]
		var speed_multiplier := _get_repair_speed_multiplier(job)
		job["remaining_seconds"] = maxf(0.0, float(job.get("remaining_seconds", 0.0)) - game_delta_seconds * speed_multiplier)
		_active_repairs[building_id] = job
		_apply_repair_progress(building_id, false)
		_emit_building_state_changed(building_id)
		if float(job.get("remaining_seconds", 0.0)) <= 0.0:
			finished_buildings.append(building_id)

	for building_id in finished_buildings:
		_finish_repair(building_id)

	var finished_upgrades: Array[String] = []
	for raw_building_id in _active_upgrades.keys():
		var building_id := str(raw_building_id)
		_prune_invalid_upgrade_helpers(building_id)
		var job: Dictionary = _active_upgrades[building_id]
		var speed_multiplier := _get_upgrade_speed_multiplier(job)
		job["remaining_seconds"] = maxf(0.0, float(job.get("remaining_seconds", 0.0)) - game_delta_seconds * speed_multiplier)
		_active_upgrades[building_id] = job
		_emit_building_state_changed(building_id)
		if float(job.get("remaining_seconds", 0.0)) <= 0.0:
			finished_upgrades.append(building_id)

	for building_id in finished_upgrades:
		_finish_upgrade(building_id)


func _on_npc_state_changed(npc_id: String) -> void:
	if _active_repairs.is_empty() and _active_upgrades.is_empty():
		return

	for raw_building_id in _active_repairs.keys():
		var building_id := str(raw_building_id)
		var job: Dictionary = _active_repairs[building_id]
		var helpers: Dictionary = job.get("helpers", {})
		if helpers.has(npc_id) and not _is_repair_helper_still_valid(building_id, npc_id):
			helpers.erase(npc_id)
			job["helpers"] = helpers
			_active_repairs[building_id] = job
			_emit_building_state_changed(building_id)

	for raw_building_id in _active_upgrades.keys():
		var building_id := str(raw_building_id)
		var job: Dictionary = _active_upgrades[building_id]
		var helpers: Dictionary = job.get("helpers", {})
		if helpers.has(npc_id) and not _is_upgrade_helper_still_valid(building_id, npc_id):
			helpers.erase(npc_id)
			job["helpers"] = helpers
			_active_upgrades[building_id] = job
			_emit_building_state_changed(building_id)


func _calculate_repair_duration_seconds(building: Dictionary, repair_config: Dictionary, missing_hp: int) -> float:
	var seconds_per_hp := maxf(1.0, float(repair_config.get("seconds_per_missing_hp", DEFAULT_REPAIR_SECONDS_PER_HP)))
	var level_factor := maxf(0.0, float(repair_config.get("level_time_factor", DEFAULT_REPAIR_LEVEL_TIME_FACTOR)))
	var level := maxi(1, int(building.get("level", 1)))
	var duration := float(missing_hp) * seconds_per_hp * (1.0 + float(level - 1) * level_factor)
	return maxf(60.0, duration)


func _calculate_upgrade_duration_seconds(building: Dictionary, upgrade_config: Dictionary) -> float:
	if upgrade_config.has("duration_seconds"):
		return maxf(60.0, float(upgrade_config.get("duration_seconds", DEFAULT_UPGRADE_SECONDS_PER_LEVEL)))
	var seconds_per_level := maxf(1.0, float(upgrade_config.get("seconds_per_current_level", DEFAULT_UPGRADE_SECONDS_PER_LEVEL)))
	var level_factor := maxf(0.0, float(upgrade_config.get("level_time_factor", DEFAULT_UPGRADE_LEVEL_TIME_FACTOR)))
	var level := maxi(1, int(building.get("level", 1)))
	var duration := seconds_per_level * (1.0 + float(level - 1) * level_factor)
	return maxf(60.0, duration)


func _calculate_repair_helper_bonus(engineering_skill: int) -> float:
	var skill := clampi(engineering_skill, 0, 100)
	return minf(
		DEFAULT_REPAIR_HELPER_MAX_BONUS,
		DEFAULT_REPAIR_HELPER_BASE_BONUS + float(skill) * DEFAULT_REPAIR_HELPER_SKILL_SCALE
	)


func _get_repair_speed_multiplier(job: Dictionary) -> float:
	var multiplier := 1.0
	var helpers: Dictionary = job.get("helpers", {})
	for helper in helpers.values():
		if helper is Dictionary:
			multiplier += float((helper as Dictionary).get("speed_bonus", 0.0))
	return multiplier


func _get_upgrade_speed_multiplier(job: Dictionary) -> float:
	return _get_repair_speed_multiplier(job)


func _apply_repair_progress(building_id: String, emit_changed: bool = true) -> void:
	if not _buildings.has(building_id) or not _active_repairs.has(building_id):
		return

	var building: Dictionary = _buildings[building_id]
	var job: Dictionary = _active_repairs[building_id]
	var duration := maxf(0.001, float(job.get("duration_seconds", 1.0)))
	var remaining := clampf(float(job.get("remaining_seconds", duration)), 0.0, duration)
	var progress := clampf((duration - remaining) / duration, 0.0, 1.0)
	var start_hp := int(job.get("start_hp", int(building.get("hp", 0))))
	var target_hp := int(job.get("target_hp", int(building.get("max_hp", 0))))
	var next_hp := mini(target_hp, int(floor(lerpf(float(start_hp), float(target_hp), progress))))
	if next_hp > int(building.get("hp", 0)):
		building["hp"] = next_hp
		_buildings[building_id] = building
		_refresh_bound_scene_nodes(building_id)
		if emit_changed:
			_emit_building_state_changed(building_id)


func _finish_repair(building_id: String) -> void:
	if not _buildings.has(building_id) or not _active_repairs.has(building_id):
		return

	var job: Dictionary = _active_repairs[building_id]
	var building: Dictionary = _buildings[building_id]
	building["hp"] = int(job.get("target_hp", building.get("max_hp", 0)))
	_buildings[building_id] = building
	_active_repairs.erase(building_id)
	_release_repair_helpers(job, building_id)
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)


func _release_repair_helpers(job: Dictionary, building_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var helpers: Dictionary = job.get("helpers", {})
	for raw_npc_id in helpers.keys():
		var npc_id := str(raw_npc_id)
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": "completed_assist_repair_%s" % building_id
		})


func _release_upgrade_helpers(job: Dictionary, building_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var helpers: Dictionary = job.get("helpers", {})
	for raw_npc_id in helpers.keys():
		var npc_id := str(raw_npc_id)
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": "completed_assist_upgrade_%s" % building_id
		})


func _get_repair_status(building_id: String) -> Dictionary:
	if not _active_repairs.has(building_id):
		return {}
	var job: Dictionary = _active_repairs[building_id]
	var duration := maxf(0.001, float(job.get("duration_seconds", 1.0)))
	var remaining := clampf(float(job.get("remaining_seconds", duration)), 0.0, duration)
	var helpers: Dictionary = job.get("helpers", {})
	return {
		"active": true,
		"duration_seconds": duration,
		"remaining_seconds": remaining,
		"progress": clampf((duration - remaining) / duration, 0.0, 1.0),
		"speed_multiplier": _get_repair_speed_multiplier(job),
		"helper_count": helpers.size(),
		"helpers": helpers.duplicate(true),
		"target_hp": int(job.get("target_hp", 0))
	}


func _get_upgrade_status(building_id: String) -> Dictionary:
	if not _active_upgrades.has(building_id):
		return {}
	var job: Dictionary = _active_upgrades[building_id]
	var duration := maxf(0.001, float(job.get("duration_seconds", 1.0)))
	var remaining := clampf(float(job.get("remaining_seconds", duration)), 0.0, duration)
	var helpers: Dictionary = job.get("helpers", {})
	return {
		"active": true,
		"duration_seconds": duration,
		"remaining_seconds": remaining,
		"progress": clampf((duration - remaining) / duration, 0.0, 1.0),
		"speed_multiplier": _get_upgrade_speed_multiplier(job),
		"helper_count": helpers.size(),
		"helpers": helpers.duplicate(true),
		"target_level": int(job.get("target_level", 0))
	}


func _get_building_condition(building_id: String) -> String:
	if _active_upgrades.has(building_id):
		return "upgrading"
	if _active_repairs.has(building_id):
		return "repairing"
	if not _buildings.has(building_id):
		return "unknown"
	var building: Dictionary = _buildings[building_id]
	if int(building.get("hp", 0)) >= int(building.get("max_hp", 0)):
		return "intact"
	return "damaged"


func _finish_upgrade(building_id: String) -> void:
	if not _buildings.has(building_id) or not _active_upgrades.has(building_id):
		return

	var job: Dictionary = _active_upgrades[building_id]
	var building: Dictionary = _buildings[building_id]
	var upgrade_config: Dictionary = job.get("upgrade_config", building.get("upgrade", {}))
	var max_hp_bonus: int = maxi(0, int(upgrade_config.get("max_hp_bonus", 0)))
	building["level"] = int(job.get("target_level", int(building.get("level", 1)) + 1))
	building["max_hp"] = int(building.get("max_hp", 0)) + max_hp_bonus
	building["hp"] = int(building.get("max_hp", building.get("hp", 0)))
	_apply_workstation_upgrade(building, upgrade_config)
	_buildings[building_id] = building
	_active_upgrades.erase(building_id)
	_release_upgrade_helpers(job, building_id)
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)


func _prune_invalid_repair_helpers(building_id: String) -> void:
	if not _active_repairs.has(building_id):
		return

	var job: Dictionary = _active_repairs[building_id]
	var helpers: Dictionary = job.get("helpers", {})
	var removed_any := false
	for raw_npc_id in helpers.keys():
		var npc_id := str(raw_npc_id)
		if not _is_repair_helper_still_valid(building_id, npc_id):
			helpers.erase(npc_id)
			removed_any = true
	if not removed_any:
		return

	job["helpers"] = helpers
	_active_repairs[building_id] = job
	_emit_building_state_changed(building_id)


func _prune_invalid_upgrade_helpers(building_id: String) -> void:
	if not _active_upgrades.has(building_id):
		return

	var job: Dictionary = _active_upgrades[building_id]
	var helpers: Dictionary = job.get("helpers", {})
	var removed_any := false
	for raw_npc_id in helpers.keys():
		var npc_id := str(raw_npc_id)
		if not _is_upgrade_helper_still_valid(building_id, npc_id):
			helpers.erase(npc_id)
			removed_any = true
	if not removed_any:
		return

	job["helpers"] = helpers
	_active_upgrades[building_id] = job
	_emit_building_state_changed(building_id)


func _is_repair_helper_still_valid(building_id: String, npc_id: String) -> bool:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return false

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if state.is_empty():
		return false
	return (
		str(state.get("current_action", "")) == "assist_repair_%s" % building_id
		and str(state.get("current_location", "")) == PLAZA_LOCATION_ID
	)


func _is_upgrade_helper_still_valid(building_id: String, npc_id: String) -> bool:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return false

	var state: Dictionary = npc_system.get_npc_state(npc_id)
	if state.is_empty():
		return false
	return (
		str(state.get("current_action", "")) == "assist_upgrade_%s" % building_id
		and str(state.get("current_location", "")) == PLAZA_LOCATION_ID
	)


func debug_select_building(building_id: String) -> bool:
	if not _buildings.has(building_id):
		push_warning("Cannot select unknown building: %s" % building_id)
		return false
	_select_building(building_id)
	return true


func _bind_scene_nodes(building_id: String, definition: Dictionary) -> void:
	var root := get_node_or_null(BUILDING_ROOT_PATH)
	if root == null:
		push_error("Building root not found: %s" % BUILDING_ROOT_PATH)
		return

	var scene_nodes: Array = definition.get("scene_nodes", [])
	if scene_nodes.is_empty():
		push_warning("Building has no scene_nodes mapping: %s" % building_id)
		return

	for raw_node_name in scene_nodes:
		var node_name := str(raw_node_name)
		var building_node := root.get_node_or_null(node_name)
		if building_node == null:
			push_warning("Building scene node not found for %s: %s" % [building_id, node_name])
			continue

		building_node.set_meta("building_id", building_id)
		if not _building_scene_nodes.has(building_id):
			_building_scene_nodes[building_id] = []
		_building_scene_nodes[building_id].append(building_node.get_path())
		_update_debug_label(building_node, definition)
		_ensure_click_area(building_node, building_id)


func _update_debug_label(building_node: Node, definition: Dictionary) -> void:
	for child in building_node.get_children():
		if child is Label3D:
			child.text = "%s\nLv.%d HP %d/%d" % [
				str(definition.get("name", definition.get("id", ""))),
				int(definition.get("level", 1)),
				int(definition.get("hp", 0)),
				int(definition.get("max_hp", 0))
			]
			return


func _ensure_click_area(building_node: Node, building_id: String) -> void:
	if not building_node is MeshInstance3D:
		return

	var mesh_instance := building_node as MeshInstance3D
	if mesh_instance.mesh == null:
		return

	var click_area := mesh_instance.get_node_or_null(CLICK_AREA_NAME) as Area3D
	if click_area == null:
		click_area = Area3D.new()
		click_area.name = CLICK_AREA_NAME
		mesh_instance.add_child(click_area)

	var collision_shape := click_area.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collision_shape == null:
		collision_shape = CollisionShape3D.new()
		collision_shape.name = "CollisionShape3D"
		click_area.add_child(collision_shape)

	var shape := BoxShape3D.new()
	var mesh_size := mesh_instance.mesh.get_aabb().size
	shape.size = Vector3(mesh_size.x, max(mesh_size.y, 0.5), mesh_size.z)
	collision_shape.shape = shape
	click_area.set_meta("building_id", building_id)
	click_area.input_ray_pickable = true

	var input_callable := Callable(self, "_on_building_area_input_event").bind(click_area)
	if not click_area.input_event.is_connected(input_callable):
		click_area.input_event.connect(input_callable)


func _pick_building_at_screen_position(screen_position: Vector2) -> String:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	if camera == null:
		return ""

	var world_3d := get_viewport().world_3d
	if world_3d == null:
		return ""

	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * PICK_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var result := world_3d.direct_space_state.intersect_ray(query)
	if result.is_empty():
		return ""

	var collider := result.get("collider") as Node
	while collider != null:
		var building_id := str(collider.get_meta("building_id", ""))
		if not building_id.is_empty():
			return building_id
		collider = collider.get_parent()

	return ""


func _on_building_area_input_event(
	_camera: Node,
	event: InputEvent,
	_position: Vector3,
	_normal: Vector3,
	_shape_idx: int,
	click_area: Area3D
) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var building_id := str(click_area.get_meta("building_id", ""))
		if not building_id.is_empty():
			_select_building(building_id)


func _select_building(building_id: String) -> void:
	_selected_building_id = building_id
	_emit_building_clicked_if_selected(building_id)


func _refresh_bound_scene_nodes(building_id: String) -> void:
	if not _buildings.has(building_id):
		return

	var building: Dictionary = _buildings[building_id]
	var node_paths: Array = _building_scene_nodes.get(building_id, [])
	for raw_path in node_paths:
		var building_node := get_node_or_null(NodePath(str(raw_path)))
		if building_node != null:
			_update_debug_label(building_node, building)


func _apply_workstation_upgrade(building: Dictionary, upgrade_config: Dictionary) -> void:
	var workstation_bonus: int = maxi(0, int(upgrade_config.get("workstation_bonus", 0)))
	if workstation_bonus <= 0:
		return

	var workstations: Array = building.get("workstations", [])
	var station_type := str(upgrade_config.get("workstation_type", "general"))
	for index in range(workstation_bonus):
		workstations.append({
			"id": "%s_upgrade_%02d" % [str(building.get("id", "building")), workstations.size() + index + 1],
			"type": station_type,
			"occupied_by": null
		})
	building["workstations"] = workstations


func _emit_building_clicked_if_selected(building_id: String) -> void:
	if building_id != _selected_building_id:
		return

	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.building_clicked.emit(building_id)


func _emit_building_state_changed(building_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.building_state_changed.emit(building_id)
