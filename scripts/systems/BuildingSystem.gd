extends Node

const WorldFeedbackPayload = preload("res://scripts/core/WorldFeedbackPayload.gd")
const BUILDING_DEFS_FILE := "building_defs.json"
const BUILDING_ROOT_PATH := "/root/Main/WorldRoot/Station/Buildings"
const PROPS_ROOT_PATH := "/root/Main/WorldRoot/Station/Props"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const DEFENSE_DEVICE_PRESENTER_PATH := "/root/Main/WorldRoot/Station/DefenseDevices"
const CLICK_AREA_NAME := "ClickArea"
const PICK_RAY_LENGTH := 1000.0
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const NPC_SYSTEM_PATH := "/root/Main/Systems/NPCSystem"
const HORSE_SYSTEM_PATH := "/root/Main/Systems/HorseSystem"
const TIME_SYSTEM_PATH := "/root/Main/Systems/TimeSystem"
const PLAZA_LOCATION_ID := "plaza"
const DEFAULT_DAMAGE_VISIBILITY := "local_public"
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
		var destruction: Dictionary = (
			definition.get("destruction", {}).duplicate(true)
			if definition.get("destruction", {}) is Dictionary
			else {}
		)
		definition["destruction"] = destruction
		definition["destruction_latched"] = not destruction.is_empty() and hp <= 0
		definition["workstations"] = _normalize_workstations(
			building_id,
			definition.get("workstations", []) if definition.get("workstations", []) is Array else []
		)
		definition["efficiency_bonuses"] = _normalize_efficiency_bonuses(
			definition.get("efficiency_bonuses", {})
		)

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
		if _try_route_horse_click(event.position):
			get_viewport().set_input_as_handled()
			return
		if _try_route_defense_device_click(event.position):
			get_viewport().set_input_as_handled()
			return
		var art_hit := _pick_building_art_view_at_screen_position(event.position)
		if not art_hit.is_empty():
			var art_building_id := str(art_hit.get("building_id", ""))
			if _should_defer_art_hit_to_foreground_npc(event.position, art_hit):
				return
			if bool(art_hit.get("interior_revealed", false)) and _try_select_interior_npc(event.position, art_building_id):
				get_viewport().set_input_as_handled()
				return
			if not art_building_id.is_empty():
				_select_building(art_building_id)
				get_viewport().set_input_as_handled()
				return
		var building_id := _pick_building_at_screen_position(event.position)
		if not building_id.is_empty():
			_select_building(building_id)
			get_viewport().set_input_as_handled()


func _try_route_defense_device_click(screen_position: Vector2) -> bool:
	var presenter := get_node_or_null(DEFENSE_DEVICE_PRESENTER_PATH)
	if presenter == null or not presenter.has_method("get_world_click_interaction"):
		return false
	var interaction: Dictionary = presenter.call("get_world_click_interaction", screen_position)
	if str(interaction.get("kind", "")) != "defense_device":
		return false
	var deployment_id := str(interaction.get("deployment_id", ""))
	return (
		not deployment_id.is_empty()
		and presenter.has_method("select_defense_device_from_world_click")
		and bool(presenter.call("select_defense_device_from_world_click", deployment_id))
	)


func _pick_building_art_view_at_screen_position(screen_position: Vector2) -> Dictionary:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	if camera == null:
		return {}
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * PICK_RAY_LENGTH
	var closest_hit: Dictionary = {}
	var closest_distance := INF
	for raw_view in get_tree().get_nodes_in_group("building_art_view"):
		var view := raw_view as Node
		if view == null or not view.has_method("get_building_interaction_ray_hit"):
			continue
		var hit: Variant = view.call("get_building_interaction_ray_hit", ray_origin, ray_end)
		if not hit is Dictionary or (hit as Dictionary).is_empty():
			continue
		var distance := float((hit as Dictionary).get("distance", INF))
		if distance < closest_distance:
			closest_distance = distance
			closest_hit = (hit as Dictionary).duplicate(true)
	return closest_hit


func _try_select_interior_npc(screen_position: Vector2, building_id: String) -> bool:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_world_click_interaction"):
		return false
	var interaction: Dictionary = npc_system.call("get_world_click_interaction", screen_position)
	if str(interaction.get("kind", "")) != "npc":
		return false
	var npc_id := str(interaction.get("npc_id", ""))
	if npc_id.is_empty() or not npc_system.has_method("get_npc_state"):
		return false
	var state: Dictionary = npc_system.call("get_npc_state", npc_id)
	if str(state.get("current_location", "")) != building_id:
		return false
	return npc_system.has_method("select_npc_from_world_click") and bool(npc_system.call("select_npc_from_world_click", npc_id))


func _try_select_interior_horse(screen_position: Vector2, building_id: String) -> bool:
	if building_id != "stable":
		return false
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("get_world_click_interaction"):
		return false
	var interaction: Dictionary = horse_system.call("get_world_click_interaction", screen_position)
	if str(interaction.get("kind", "")) != "horse":
		return false
	var horse_id := str(interaction.get("horse_id", ""))
	if horse_id.is_empty() or not horse_system.has_method("get_horse_snapshot"):
		return false
	var horse: Dictionary = horse_system.call("get_horse_snapshot", horse_id)
	if str(horse.get("location", "")) != "stable":
		return false
	return horse_system.has_method("select_horse_from_world_click") and bool(horse_system.call("select_horse_from_world_click", horse_id))


func _try_route_horse_click(screen_position: Vector2) -> bool:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null or not horse_system.has_method("get_world_click_interaction"):
		return false
	var interaction: Dictionary = horse_system.call("get_world_click_interaction", screen_position)
	if str(interaction.get("kind", "")) != "horse":
		return false
	var horse_id := str(interaction.get("horse_id", ""))
	if horse_id.is_empty() or not horse_system.has_method("get_horse_snapshot"):
		return false
	var horse: Dictionary = horse_system.call("get_horse_snapshot", horse_id)
	if str(horse.get("location", "")) != "stable":
		return horse_system.has_method("select_horse_from_world_click") and bool(horse_system.call("select_horse_from_world_click", horse_id))
	var stable_hit := _pick_specific_building_art_view_at_screen_position(screen_position, "stable")
	if stable_hit.is_empty():
		return false
	if bool(stable_hit.get("interior_revealed", false)):
		return _try_select_interior_horse(screen_position, "stable")
	_select_building("stable")
	return true


func _pick_specific_building_art_view_at_screen_position(screen_position: Vector2, building_id: String) -> Dictionary:
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	if camera == null:
		return {}
	var ray_origin := camera.project_ray_origin(screen_position)
	var ray_end := ray_origin + camera.project_ray_normal(screen_position) * PICK_RAY_LENGTH
	for raw_view in get_tree().get_nodes_in_group("building_art_view"):
		var view := raw_view as Node
		if view == null or str(view.get("building_id")) != building_id or not view.has_method("get_building_interaction_ray_hit"):
			continue
		var hit: Variant = view.call("get_building_interaction_ray_hit", ray_origin, ray_end)
		if hit is Dictionary and not (hit as Dictionary).is_empty():
			return (hit as Dictionary).duplicate(true)
	return {}


func _should_defer_art_hit_to_foreground_npc(screen_position: Vector2, art_hit: Dictionary) -> bool:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_world_click_interaction"):
		return false
	var interaction: Dictionary = npc_system.call("get_world_click_interaction", screen_position)
	var npc_id := str(interaction.get("npc_id", ""))
	if npc_id.is_empty() or float(interaction.get("distance", INF)) >= float(art_hit.get("distance", 0.0)):
		return false
	var state: Dictionary = npc_system.call("get_npc_state", npc_id) if npc_system.has_method("get_npc_state") else {}
	var same_building := str(state.get("current_location", "")) == str(art_hit.get("building_id", ""))
	if not same_building:
		return true
	return bool(art_hit.get("interior_revealed", false)) and str(interaction.get("kind", "")) == "autonomous_dialogue_bubble"


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
	var availability := get_building_availability(building_id)
	building["is_enterable"] = bool(availability.get("is_enterable", false))
	building["has_enterable_interior"] = bool(availability.get("has_enterable_interior", false))
	building["is_accessible"] = bool(availability.get("is_accessible", false))
	building["is_operational"] = bool(availability.get("is_operational", false))
	building["is_activity_available"] = bool(availability.get("is_activity_available", false))
	building["unavailable_reason"] = str(availability.get("unavailable_reason", ""))
	building["damage_efficiency_multiplier"] = get_building_damage_efficiency_multiplier(building_id)
	building["condition_efficiency"] = building["damage_efficiency_multiplier"]
	building["operational_efficiency_multiplier"] = get_building_operational_efficiency_multiplier(building_id)
	building["operational_efficiency"] = building["operational_efficiency_multiplier"]
	building["activity_efficiency_multiplier"] = get_building_activity_efficiency_multiplier(building_id)
	building["activity_efficiency_multipliers"] = get_building_activity_efficiency_multipliers(building_id)
	building["activity_efficiency"] = building["activity_efficiency_multipliers"].duplicate(true)
	return building


func get_building_ids() -> Array[String]:
	return _building_order.duplicate()


func get_building_snapshot() -> Dictionary:
	var snapshot := {}
	for building_id in _building_order:
		snapshot[building_id] = get_building(building_id)
	return snapshot


func get_building_availability(building_id: String) -> Dictionary:
	if building_id == PLAZA_LOCATION_ID:
		return {
			"ok": true,
			"building_id": building_id,
			"condition": "intact",
			"is_enterable": true,
			"has_enterable_interior": true,
			"is_accessible": true,
			"is_operational": true,
			"is_activity_available": true,
			"unavailable_reason": ""
		}
	if not _buildings.has(building_id):
		return {
			"ok": false,
			"building_id": building_id,
			"condition": "unknown",
			"is_enterable": false,
			"has_enterable_interior": false,
			"is_accessible": false,
			"is_operational": false,
			"is_activity_available": false,
			"unavailable_reason": "unknown_building"
		}

	var building: Dictionary = _buildings[building_id]
	var has_enterable_interior := _is_building_location_enterable(building_id)
	var has_hp := int(building.get("hp", 0)) > 0
	var upgrading := _active_upgrades.has(building_id)
	var operational := has_hp and not upgrading
	var unavailable_reason := ""
	if not has_hp:
		unavailable_reason = "building_destroyed"
	elif upgrading:
		unavailable_reason = "building_upgrading"
	elif not has_enterable_interior:
		unavailable_reason = "building_not_enterable"
	var enterable := has_enterable_interior and operational
	return {
		"ok": enterable,
		"building_id": building_id,
		"condition": _get_building_condition(building_id),
		"is_enterable": enterable,
		"has_enterable_interior": has_enterable_interior,
		"is_accessible": operational,
		"is_operational": operational,
		"is_activity_available": enterable,
		"unavailable_reason": unavailable_reason
	}


func is_building_enterable(building_id: String) -> bool:
	return bool(get_building_availability(building_id).get("is_enterable", false))


func is_building_usable(building_id: String) -> bool:
	return bool(get_building_availability(building_id).get("is_activity_available", false))


func is_building_accessible(building_id: String) -> bool:
	return bool(get_building_availability(building_id).get("is_accessible", false))


func get_building_damage_efficiency_multiplier(building_id: String) -> float:
	if not _buildings.has(building_id):
		return 0.0
	var building: Dictionary = _buildings[building_id]
	if int(building.get("hp", 0)) <= 0 or _active_upgrades.has(building_id):
		return 0.0
	var max_hp := maxi(1, int(building.get("max_hp", 1)))
	var hp_ratio := clampf(float(building.get("hp", 0)) / float(max_hp), 0.0, 1.0)
	var efficiency_floor := clampf(float(building.get("damage_efficiency_floor", 0.0)), 0.0, 1.0)
	return lerpf(efficiency_floor, 1.0, hp_ratio)


func get_building_operational_efficiency_multiplier(building_id: String) -> float:
	if not _buildings.has(building_id) or not bool(get_building_availability(building_id).get("is_operational", false)):
		return 0.0
	var building: Dictionary = _buildings[building_id]
	var bonuses: Dictionary = building.get("efficiency_bonuses", {}) if building.get("efficiency_bonuses", {}) is Dictionary else {}
	var general_bonus := float(bonuses.get("general", bonuses.get("operational", 0.0)))
	return maxf(0.0, get_building_damage_efficiency_multiplier(building_id) * (1.0 + general_bonus))


func get_building_operational_efficiency(building_id: String) -> float:
	return get_building_operational_efficiency_multiplier(building_id)


func get_building_activity_efficiency_multiplier(building_id: String, activity_id: String = "general") -> float:
	if not _buildings.has(building_id) or not bool(get_building_availability(building_id).get("is_activity_available", false)):
		return 0.0
	var building: Dictionary = _buildings[building_id]
	var bonuses: Dictionary = building.get("efficiency_bonuses", {}) if building.get("efficiency_bonuses", {}) is Dictionary else {}
	var general_bonus := float(bonuses.get("general", bonuses.get("operational", 0.0)))
	var activity_bonus := 0.0
	if not activity_id.is_empty() and not ["general", "operational"].has(activity_id):
		activity_bonus = float(bonuses.get(activity_id, 0.0))
	return maxf(0.0, get_building_damage_efficiency_multiplier(building_id) * (1.0 + general_bonus + activity_bonus))


func get_building_activity_efficiency_multipliers(building_id: String) -> Dictionary:
	var result := {
		"general": get_building_activity_efficiency_multiplier(building_id),
		"operational": get_building_operational_efficiency_multiplier(building_id)
	}
	if not _buildings.has(building_id):
		return result
	var building: Dictionary = _buildings[building_id]
	var bonuses: Dictionary = building.get("efficiency_bonuses", {}) if building.get("efficiency_bonuses", {}) is Dictionary else {}
	for raw_activity_id in bonuses.keys():
		var activity_id := str(raw_activity_id)
		if activity_id.is_empty() or ["general", "operational"].has(activity_id):
			continue
		result[activity_id] = get_building_activity_efficiency_multiplier(building_id, activity_id)
	return result


func get_building_special_state(building_id: String) -> Dictionary:
	if not _buildings.has(building_id):
		return {}
	var building: Dictionary = _buildings[building_id]
	var special_state: Variant = building.get("special_state", {})
	return special_state.duplicate(true) if special_state is Dictionary else {}


func get_building_special_state_section(building_id: String, section_id: String) -> Dictionary:
	if section_id.is_empty():
		return {}
	var special_state := get_building_special_state(building_id)
	var section: Variant = special_state.get(section_id, {})
	return section.duplicate(true) if section is Dictionary else {}


func set_building_special_state_section(
	building_id: String,
	section_id: String,
	section_state: Dictionary,
	emit_changed: bool = true
) -> bool:
	if not _buildings.has(building_id) or section_id.is_empty():
		return false
	var building: Dictionary = _buildings[building_id]
	var raw_special_state: Variant = building.get("special_state", {})
	var special_state: Dictionary = raw_special_state.duplicate(true) if raw_special_state is Dictionary else {}
	var previous: Dictionary = special_state.get(section_id, {}) if special_state.get(section_id, {}) is Dictionary else {}
	var next_state := section_state.duplicate(true)
	if previous == next_state:
		return true
	special_state[section_id] = next_state
	building["special_state"] = special_state
	_buildings[building_id] = building
	if emit_changed:
		_emit_building_state_changed(building_id)
	return true


func reserve_workstation(building_id: String, npc_id: String, preferred_type: String = "") -> Dictionary:
	if building_id.is_empty() or npc_id.is_empty() or not _buildings.has(building_id):
		return {"ok": false, "reason": "invalid_workstation_request"}
	var availability := get_building_availability(building_id)
	if not bool(availability.get("is_activity_available", false)):
		return {
			"ok": false,
			"reason": "building_unavailable",
			"unavailable_reason": str(availability.get("unavailable_reason", "building_unavailable")),
			"building_id": building_id,
			"preferred_type": preferred_type,
			"blocked_workstations": [],
			"blocked_by_npc_ids": []
		}

	var building: Dictionary = _buildings[building_id]
	var workstations: Array = building.get("workstations", [])
	var assigned_workstation_id := _find_assigned_workstation_id(workstations, npc_id, preferred_type)
	var blocked_workstations: Array[Dictionary] = []
	var blocked_by_npc_ids: Array[String] = []
	for index in range(workstations.size()):
		if not workstations[index] is Dictionary:
			continue
		var workstation: Dictionary = workstations[index]
		var workstation_id := str(workstation.get("id", ""))
		var workstation_type := str(workstation.get("type", ""))
		if not preferred_type.is_empty() and workstation_type != preferred_type:
			continue
		if not assigned_workstation_id.is_empty() and workstation_id != assigned_workstation_id:
			continue
		var assigned_npc_id := _clean_nullable_id(workstation.get("assigned_npc_id", ""))
		if assigned_workstation_id.is_empty() and not assigned_npc_id.is_empty() and assigned_npc_id != npc_id:
			continue
		var occupied_by := _clean_nullable_id(workstation.get("occupied_by", ""))
		var reserved_by := _clean_nullable_id(workstation.get("reserved_by", ""))
		if occupied_by == npc_id or reserved_by == npc_id:
			return {
				"ok": true,
				"building_id": building_id,
				"workstation_id": workstation_id,
				"workstation_type": workstation_type,
				"already_reserved": reserved_by == npc_id,
				"already_occupied": occupied_by == npc_id
			}
		if not occupied_by.is_empty() or not reserved_by.is_empty():
			var blocked_by := occupied_by if not occupied_by.is_empty() else reserved_by
			blocked_workstations.append({
				"workstation_id": workstation_id,
				"workstation_type": workstation_type,
				"occupied_by": occupied_by,
				"reserved_by": reserved_by,
				"assigned_npc_id": assigned_npc_id
			})
			if not blocked_by.is_empty() and not blocked_by_npc_ids.has(blocked_by):
				blocked_by_npc_ids.append(blocked_by)
			continue
		workstation["reserved_by"] = npc_id
		workstations[index] = workstation
		building["workstations"] = workstations
		_buildings[building_id] = building
		_emit_building_state_changed(building_id)
		return {
			"ok": true,
			"building_id": building_id,
			"workstation_id": workstation_id,
			"workstation_type": workstation_type,
			"already_reserved": false,
			"already_occupied": false
		}

	return {
		"ok": false,
		"reason": "no_free_workstation",
		"building_id": building_id,
		"preferred_type": preferred_type,
		"assigned_workstation_id": assigned_workstation_id,
		"blocked_workstations": blocked_workstations,
		"blocked_by_npc_ids": blocked_by_npc_ids
	}


func commit_workstation_reservation(
	building_id: String,
	npc_id: String,
	workstation_id: String = "",
	preferred_type: String = ""
) -> Dictionary:
	if building_id.is_empty() or npc_id.is_empty() or not _buildings.has(building_id):
		return {"ok": false, "reason": "invalid_workstation_request"}
	var availability := get_building_availability(building_id)
	if not bool(availability.get("is_activity_available", false)):
		return {
			"ok": false,
			"reason": "building_unavailable",
			"unavailable_reason": str(availability.get("unavailable_reason", "building_unavailable")),
			"building_id": building_id
		}
	var building: Dictionary = _buildings[building_id]
	var workstations: Array = building.get("workstations", [])
	for index in range(workstations.size()):
		if not workstations[index] is Dictionary:
			continue
		var workstation: Dictionary = workstations[index]
		var current_id := str(workstation.get("id", ""))
		var workstation_type := str(workstation.get("type", ""))
		if not workstation_id.is_empty() and current_id != workstation_id:
			continue
		if not preferred_type.is_empty() and workstation_type != preferred_type:
			continue
		if _clean_nullable_id(workstation.get("reserved_by", "")) != npc_id:
			continue
		var occupied_by := _clean_nullable_id(workstation.get("occupied_by", ""))
		if not occupied_by.is_empty() and occupied_by != npc_id:
			return {"ok": false, "reason": "workstation_occupied", "occupied_by": occupied_by}
		workstation["reserved_by"] = null
		workstation["occupied_by"] = npc_id
		workstations[index] = workstation
		building["workstations"] = workstations
		_buildings[building_id] = building
		_emit_building_state_changed(building_id)
		return {
			"ok": true,
			"building_id": building_id,
			"workstation_id": current_id,
			"workstation_type": workstation_type
		}
	return {"ok": false, "reason": "workstation_reservation_missing", "building_id": building_id}


func claim_workstation(building_id: String, npc_id: String, preferred_type: String = "") -> Dictionary:
	if building_id.is_empty() or npc_id.is_empty() or not _buildings.has(building_id):
		return {"ok": false, "reason": "invalid_workstation_request"}
	var availability := get_building_availability(building_id)
	if not bool(availability.get("is_activity_available", false)):
		return {
			"ok": false,
			"reason": "building_unavailable",
			"unavailable_reason": str(availability.get("unavailable_reason", "building_unavailable")),
			"building_id": building_id,
			"preferred_type": preferred_type,
			"condition": str(availability.get("condition", "unknown")),
			"is_enterable": bool(availability.get("is_enterable", false)),
			"is_accessible": bool(availability.get("is_accessible", false)),
			"is_operational": bool(availability.get("is_operational", false)),
			"is_activity_available": false,
			"blocked_workstations": [],
			"blocked_by_npc_ids": []
		}

	var building: Dictionary = _buildings[building_id]
	var workstations: Array = building.get("workstations", [])
	var blocked_workstations: Array[Dictionary] = []
	var blocked_by_npc_ids: Array[String] = []
	var reserved_workstations: Array[Dictionary] = []
	var assigned_workstation_id := _find_assigned_workstation_id(
		workstations,
		npc_id,
		preferred_type
	)
	for index in range(workstations.size()):
		if not workstations[index] is Dictionary:
			continue
		var workstation: Dictionary = workstations[index]
		var workstation_id := str(workstation.get("id", ""))
		var occupied_by := str(workstation.get("occupied_by", ""))
		if occupied_by == "<null>":
			occupied_by = ""
		var reserved_by := _clean_nullable_id(workstation.get("reserved_by", ""))
		var workstation_type := str(workstation.get("type", ""))
		if not preferred_type.is_empty() and workstation_type != preferred_type:
			continue
		var assigned_npc_id := str(workstation.get("assigned_npc_id", "")).strip_edges()
		if assigned_npc_id == "<null>":
			assigned_npc_id = ""
		if not assigned_workstation_id.is_empty() and workstation_id != assigned_workstation_id:
			continue
		if (
			assigned_workstation_id.is_empty()
			and not assigned_npc_id.is_empty()
			and assigned_npc_id != npc_id
		):
			reserved_workstations.append({
				"workstation_id": workstation_id,
				"workstation_type": workstation_type,
				"assigned_npc_id": assigned_npc_id
			})
			continue
		if not occupied_by.is_empty() and occupied_by != npc_id:
			blocked_workstations.append({
				"workstation_id": workstation_id,
				"workstation_type": workstation_type,
				"occupied_by": occupied_by,
				"assigned_npc_id": assigned_npc_id
			})
			if not blocked_by_npc_ids.has(occupied_by):
				blocked_by_npc_ids.append(occupied_by)
			continue
		if not reserved_by.is_empty() and reserved_by != npc_id:
			blocked_workstations.append({
				"workstation_id": workstation_id,
				"workstation_type": workstation_type,
				"occupied_by": occupied_by,
				"reserved_by": reserved_by,
				"assigned_npc_id": assigned_npc_id
			})
			if not blocked_by_npc_ids.has(reserved_by):
				blocked_by_npc_ids.append(reserved_by)
			continue
		workstation["reserved_by"] = null
		workstation["occupied_by"] = npc_id
		workstations[index] = workstation
		building["workstations"] = workstations
		_buildings[building_id] = building
		_emit_building_state_changed(building_id)
		return {
			"ok": true,
			"building_id": building_id,
			"workstation_id": workstation_id,
			"workstation_type": workstation_type,
			"assigned_npc_id": assigned_npc_id
		}

	return {
		"ok": false,
		"reason": "no_free_workstation",
		"building_id": building_id,
		"preferred_type": preferred_type,
		"assigned_workstation_id": assigned_workstation_id,
		"blocked_workstations": blocked_workstations,
		"blocked_by_npc_ids": blocked_by_npc_ids,
		"reserved_workstations": reserved_workstations
	}


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
		var occupied_by := _clean_nullable_id(workstation.get("occupied_by", ""))
		var reserved_by := _clean_nullable_id(workstation.get("reserved_by", ""))
		if occupied_by != npc_id and reserved_by != npc_id:
			continue
		if not workstation_id.is_empty() and current_id != workstation_id:
			continue
		if occupied_by == npc_id:
			workstation["occupied_by"] = null
		if reserved_by == npc_id:
			workstation["reserved_by"] = null
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


func release_workstation_reservation(building_id: String, npc_id: String, workstation_id: String = "") -> bool:
	if building_id.is_empty() or npc_id.is_empty() or not _buildings.has(building_id):
		return false
	var building: Dictionary = _buildings[building_id]
	var workstations: Array = building.get("workstations", [])
	var changed := false
	for index in range(workstations.size()):
		if not workstations[index] is Dictionary:
			continue
		var workstation: Dictionary = workstations[index]
		if not workstation_id.is_empty() and str(workstation.get("id", "")) != workstation_id:
			continue
		if _clean_nullable_id(workstation.get("reserved_by", "")) != npc_id:
			continue
		workstation["reserved_by"] = null
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
	var interior_route := get_building_interior_route(building_id)
	if not interior_route.is_empty():
		return interior_route.get("entry_outside_position")
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


func get_building_interior_route(building_id: String, workstation_id: String = "") -> Dictionary:
	for raw_view in get_tree().get_nodes_in_group("building_art_view"):
		var view := raw_view as Node
		if view == null or str(view.get("building_id")) != building_id:
			continue
		if not view.has_method("get_interior_route_snapshot"):
			continue
		var snapshot: Variant = view.call("get_interior_route_snapshot", workstation_id)
		if snapshot is Dictionary and not (snapshot as Dictionary).is_empty():
			return (snapshot as Dictionary).duplicate(true)
	return {}


func get_building_location_context(building_id: String) -> Dictionary:
	var building := get_building(building_id)
	if building.is_empty():
		return {}

	var workstations: Array = building.get("workstations", [])
	var visible_workstations: Array = []
	for raw_workstation in workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		var occupied_by := _clean_nullable_id(workstation.get("occupied_by", ""))
		var reserved_by := _clean_nullable_id(workstation.get("reserved_by", ""))
		visible_workstations.append({
			"id": str(workstation.get("id", "")),
			"name": str(workstation.get("name", workstation.get("id", ""))),
			"type": str(workstation.get("type", "")),
			"occupied_by": occupied_by,
			"reserved_by": reserved_by,
			"status": "occupied" if not occupied_by.is_empty() else "reserved" if not reserved_by.is_empty() else "free"
		})
	var availability := get_building_availability(building_id)
	var runtime_fields := {
		"is_enterable": bool(availability.get("is_enterable", false)),
		"has_enterable_interior": bool(availability.get("has_enterable_interior", false)),
		"is_accessible": bool(availability.get("is_accessible", false)),
		"is_operational": bool(availability.get("is_operational", false)),
		"is_activity_available": bool(availability.get("is_activity_available", false)),
		"unavailable_reason": str(availability.get("unavailable_reason", "")),
		"damage_efficiency_multiplier": float(building.get("damage_efficiency_multiplier", 0.0)),
		"condition_efficiency": float(building.get("condition_efficiency", 0.0)),
		"operational_efficiency_multiplier": float(building.get("operational_efficiency_multiplier", 0.0)),
		"operational_efficiency": float(building.get("operational_efficiency", 0.0)),
		"activity_efficiency_multiplier": float(building.get("activity_efficiency_multiplier", 0.0)),
		"activity_efficiency_multipliers": building.get("activity_efficiency_multipliers", {}).duplicate(true),
		"activity_efficiency": building.get("activity_efficiency", {}).duplicate(true),
		"efficiency_bonuses": building.get("efficiency_bonuses", {}).duplicate(true)
	}
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system != null and memory_system.has_method("get_location_snapshot"):
		var snapshot: Dictionary = memory_system.get_location_snapshot(building_id)
		if not snapshot.is_empty():
			snapshot = snapshot.duplicate(true)
			for field_name in runtime_fields.keys():
				snapshot[field_name] = runtime_fields[field_name]
			snapshot["workstations"] = visible_workstations.duplicate(true)
			var memory_internal: Dictionary = snapshot.get("internal_state", {}) if snapshot.get("internal_state", {}) is Dictionary else {}
			memory_internal["workstations"] = visible_workstations.duplicate(true)
			snapshot["internal_state"] = memory_internal
			var memory_building: Dictionary = snapshot.get("building", {}) if snapshot.get("building", {}) is Dictionary else {}
			for field_name in runtime_fields.keys():
				memory_building[field_name] = runtime_fields[field_name]
			var memory_building_internal: Dictionary = memory_building.get("internal_state", {}) if memory_building.get("internal_state", {}) is Dictionary else {}
			memory_building_internal["workstations"] = visible_workstations.duplicate(true)
			memory_building["internal_state"] = memory_building_internal
			snapshot["building"] = memory_building
			return snapshot
	var external_state := {
		"id": building_id,
		"name": str(building.get("name", building_id)),
		"level": int(building.get("level", 1)),
		"condition": _get_building_condition(building_id)
	}
	var special_state := get_building_special_state(building_id)
	var context := {
		"id": building_id,
		"name": str(building.get("name", building_id)),
		"people_present": [],
		"level": int(external_state["level"]),
		"condition": str(external_state["condition"]),
		"external_state": external_state,
		"internal_state": {
			"people_present": [],
			"workstations": visible_workstations.duplicate(true),
			"special_state": special_state.duplicate(true)
		},
		"building": {
			"id": building_id,
			"name": str(building.get("name", building_id)),
			"external_state": external_state,
			"internal_state": {
				"people_present": [],
				"workstations": visible_workstations.duplicate(true),
				"special_state": special_state.duplicate(true)
			}
		},
		"workstations": visible_workstations.duplicate(true),
		"special_state": special_state.duplicate(true),
		"current_notice": "",
		"current_orders": "",
		"current_public_note_ids": [],
		"public_notes": []
	}
	for field_name in runtime_fields.keys():
		context[field_name] = runtime_fields[field_name]
	var context_building: Dictionary = context.get("building", {})
	for field_name in runtime_fields.keys():
		context_building[field_name] = runtime_fields[field_name]
	context["building"] = context_building
	return context


func can_repair_building(building_id: String) -> bool:
	if not _buildings.has(building_id):
		return false
	if _active_repairs.has(building_id) or _active_upgrades.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	if int(building.get("hp", 0)) >= int(building.get("max_hp", 0)):
		return false

	var quote := get_repair_quote(building_id)
	var cost: Dictionary = quote.get("cost", {})
	if cost.is_empty():
		return false

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	return resource_system != null and resource_system.can_afford(cost)


func repair_building(building_id: String) -> bool:
	if not can_repair_building(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var repair_config: Dictionary = building.get("repair", {})
	var quote := get_repair_quote(building_id)
	var cost: Dictionary = quote.get("cost", {})
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
		"missing_hp": missing_hp,
		"repair_batches": int(quote.get("repair_batches", 0)),
		"hp_restore": int(quote.get("hp_restore", 0)),
		"cost": cost.duplicate(true),
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


func get_repair_quote(building_id: String) -> Dictionary:
	if not _buildings.has(building_id):
		return {}
	var building: Dictionary = _buildings[building_id]
	var max_hp := int(building.get("max_hp", 0))
	var current_hp := int(building.get("hp", 0))
	var missing_hp := maxi(0, max_hp - current_hp)
	var repair_config: Dictionary = building.get("repair", {})
	var base_cost: Dictionary = repair_config.get("cost", {})
	var hp_restore := int(repair_config.get("hp_restore", 0))
	if missing_hp <= 0 or base_cost.is_empty() or hp_restore <= 0:
		return {
			"building_id": building_id,
			"missing_hp": missing_hp,
			"hp_restore": hp_restore,
			"repair_batches": 0,
			"cost": {}
		}
	var repair_batches := int(ceil(float(missing_hp) / float(hp_restore)))
	var total_cost := {}
	for raw_resource_id in base_cost.keys():
		var resource_id := str(raw_resource_id)
		total_cost[resource_id] = maxi(0, int(base_cost[raw_resource_id])) * repair_batches
	return {
		"building_id": building_id,
		"missing_hp": missing_hp,
		"hp_restore": hp_restore,
		"repair_batches": repair_batches,
		"cost": total_cost
	}


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

	var max_level := _get_upgrade_max_level(building, upgrade_config)
	if int(building.get("level", 1)) >= max_level:
		return false

	var target_level := int(building.get("level", 1)) + 1
	var level_effect := _resolve_upgrade_level_effect(building, target_level)
	var cost: Dictionary = level_effect.get("cost", {}) if level_effect.get("cost", {}) is Dictionary else {}
	if cost.is_empty():
		return false

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	return resource_system != null and resource_system.can_afford(cost)


func upgrade_building(building_id: String) -> bool:
	if not can_upgrade_building(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var target_level := int(building.get("level", 1)) + 1
	var upgrade_config := _resolve_upgrade_level_effect(building, target_level)
	var cost: Dictionary = upgrade_config.get("cost", {}) if upgrade_config.get("cost", {}) is Dictionary else {}
	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.spend_resources(cost):
		return false

	var duration_seconds := _calculate_upgrade_duration_seconds(building, upgrade_config)
	_active_upgrades[building_id] = {
		"building_id": building_id,
		"duration_seconds": duration_seconds,
		"remaining_seconds": duration_seconds,
		"start_level": int(building.get("level", 1)),
		"target_level": target_level,
		"upgrade_config": upgrade_config.duplicate(true),
		"helpers": {}
	}
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)
	return true


func is_upgrade_in_progress(building_id: String) -> bool:
	return _active_upgrades.has(building_id)


func get_upgrade_level_effect(building_id: String, target_level: int = 0) -> Dictionary:
	if not _buildings.has(building_id):
		return {}
	var building: Dictionary = _buildings[building_id]
	var resolved_level := target_level
	if resolved_level <= 0:
		resolved_level = int(building.get("level", 1)) + 1
	return _resolve_upgrade_level_effect(building, resolved_level)


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
	return bool(apply_damage_to_building(building_id, amount, "gm_panel", DEFAULT_DAMAGE_VISIBILITY).get("ok", false))


func apply_damage_to_building(
	building_id: String,
	amount: int,
	actor_id: String = "system",
	visibility: String = DEFAULT_DAMAGE_VISIBILITY,
	options: Dictionary = {}
) -> Dictionary:
	if amount <= 0 or not _buildings.has(building_id):
		return {
			"ok": false,
			"building_id": building_id,
			"damage": amount,
			"error": "invalid_building_damage"
		}

	var building: Dictionary = _buildings[building_id]
	var max_hp := maxi(1, int(building.get("max_hp", 1)))
	var hp_before := clampi(int(building.get("hp", max_hp)), 0, max_hp)
	var hp_after := maxi(0, hp_before - amount)
	building["hp"] = hp_after
	if hp_after <= 0 and not (building.get("destruction", {}) as Dictionary).is_empty():
		building["destruction_latched"] = true
	if _active_repairs.has(building_id):
		_release_repair_helpers(_active_repairs[building_id], building_id)
		_active_repairs.erase(building_id)
	if _active_upgrades.has(building_id):
		_release_upgrade_helpers(_active_upgrades[building_id], building_id)
		_active_upgrades.erase(building_id)
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)
	var feedback_world_position: Variant = WorldFeedbackPayload.find_world_position(options)
	var prefer_feedback_position := feedback_world_position is Vector3
	if not prefer_feedback_position:
		feedback_world_position = get_building_entry_position(building_id)
	WorldFeedbackPayload.emit_hp_change(
		self,
		"building",
		building_id,
		hp_before,
		hp_after,
		feedback_world_position,
		prefer_feedback_position,
		0.35 if prefer_feedback_position else WorldFeedbackPayload.BUILDING_ANCHOR_HEIGHT
	)
	var event := _log_building_damaged(building_id, actor_id, amount, hp_before, hp_after, visibility, options)
	return {
		"ok": true,
		"building_id": building_id,
		"building_name": str(building.get("name", building_id)),
		"damage": amount,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"destroyed": hp_after <= 0,
		"event": event
	}


func restore_building_hp(building_id: String, amount: int) -> bool:
	if amount <= 0 or not _buildings.has(building_id):
		return false

	var building: Dictionary = _buildings[building_id]
	var max_hp := int(building.get("max_hp", 0))
	var current_hp := int(building.get("hp", 0))
	if current_hp >= max_hp:
		return true

	var hp_after := mini(max_hp, current_hp + amount)
	building["hp"] = hp_after
	_refresh_destruction_latch(building)
	_buildings[building_id] = building
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)
	WorldFeedbackPayload.emit_hp_change(
		self,
		"building",
		building_id,
		current_hp,
		hp_after,
		get_building_entry_position(building_id)
	)
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
	for raw_npc_id in helpers.keys():
		var helper: Variant = helpers[raw_npc_id]
		if helper is Dictionary:
			multiplier += float((helper as Dictionary).get("speed_bonus", 0.0)) * _get_npc_work_output_multiplier(str(raw_npc_id))
	return multiplier


func _get_upgrade_speed_multiplier(job: Dictionary) -> float:
	return _get_repair_speed_multiplier(job)


func _get_npc_work_output_multiplier(npc_id: String) -> float:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc_work_output_multiplier"):
		return 1.0
	return maxf(1.0, float(npc_system.get_npc_work_output_multiplier(npc_id)))


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
	var hp_before := int(building.get("hp", 0))
	if next_hp > hp_before:
		building["hp"] = next_hp
		_refresh_destruction_latch(building)
		_buildings[building_id] = building
		_refresh_bound_scene_nodes(building_id)
		if emit_changed:
			_emit_building_state_changed(building_id)
		WorldFeedbackPayload.emit_hp_change(
			self,
			"building",
			building_id,
			hp_before,
			next_hp,
			get_building_entry_position(building_id)
		)


func _finish_repair(building_id: String) -> void:
	if not _buildings.has(building_id) or not _active_repairs.has(building_id):
		return

	var job: Dictionary = _active_repairs[building_id]
	var building: Dictionary = _buildings[building_id]
	var hp_before := int(building.get("hp", 0))
	var hp_after := int(job.get("target_hp", building.get("max_hp", 0)))
	building["hp"] = hp_after
	_refresh_destruction_latch(building)
	_buildings[building_id] = building
	_active_repairs.erase(building_id)
	_release_repair_helpers(job, building_id)
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)
	WorldFeedbackPayload.emit_hp_change(
		self,
		"building",
		building_id,
		hp_before,
		hp_after,
		get_building_entry_position(building_id)
	)
	_emit_building_job_completed(building_id, "repair", {
		"building_id": building_id,
		"building_name": str(building.get("name", building_id)),
		"job_type": "repair",
		"hp": hp_after,
		"max_hp": int(building.get("max_hp", hp_after)),
	})


func _release_repair_helpers(job: Dictionary, building_id: String) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	var helpers: Dictionary = job.get("helpers", {})
	for raw_npc_id in helpers.keys():
		var npc_id := str(raw_npc_id)
		npc_system.update_npc_state(npc_id, {
			"current_action": "idle",
			"last_action_result": "completed_assist_repair_%s" % building_id,
			"last_action_failure_context": {}
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
			"last_action_result": "completed_assist_upgrade_%s" % building_id,
			"last_action_failure_context": {}
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
		"duration_text": _format_job_duration(duration, false),
		"remaining_text": _format_job_duration(remaining, true),
		"progress": clampf((duration - remaining) / duration, 0.0, 1.0),
		"speed_multiplier": _get_repair_speed_multiplier(job),
		"helper_count": helpers.size(),
		"helpers": helpers.duplicate(true),
		"target_hp": int(job.get("target_hp", 0)),
		"missing_hp": int(job.get("missing_hp", 0)),
		"repair_batches": int(job.get("repair_batches", 0)),
		"hp_restore": int(job.get("hp_restore", 0)),
		"cost": (job.get("cost", {}) as Dictionary).duplicate(true)
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
		"duration_text": _format_job_duration(duration, false),
		"remaining_text": _format_job_duration(remaining, true),
		"progress": clampf((duration - remaining) / duration, 0.0, 1.0),
		"speed_multiplier": _get_upgrade_speed_multiplier(job),
		"helper_count": helpers.size(),
		"helpers": helpers.duplicate(true),
		"target_level": int(job.get("target_level", 0))
	}


func _format_job_duration(game_seconds: float, respect_display_precision: bool) -> String:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	if time_system != null and time_system.has_method("format_game_duration"):
		return str(time_system.format_game_duration(game_seconds, true, respect_display_precision))
	var total_seconds := ceili(maxf(0.0, game_seconds))
	var hours := total_seconds / 3600
	var remainder := total_seconds % 3600
	return "%d小时%d分%02d秒" % [hours, remainder / 60, remainder % 60]


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


func _refresh_destruction_latch(building: Dictionary) -> void:
	if not bool(building.get("destruction_latched", false)):
		return
	var destruction: Dictionary = (
		building.get("destruction", {})
		if building.get("destruction", {}) is Dictionary
		else {}
	)
	if destruction.is_empty() or not bool(destruction.get("recoverable", false)):
		return
	var maximum_hp := maxi(1, int(building.get("max_hp", 1)))
	var recovery_ratio := clampf(float(destruction.get("recovery_hp_ratio", 1.0)), 0.0, 1.0)
	var required_hp := maxi(1, int(ceil(float(maximum_hp) * recovery_ratio)))
	if int(building.get("hp", 0)) >= required_hp:
		building["destruction_latched"] = false


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
	_refresh_destruction_latch(building)
	_apply_workstation_upgrade(building, upgrade_config)
	_apply_efficiency_upgrade(building, upgrade_config)
	_buildings[building_id] = building
	_active_upgrades.erase(building_id)
	_release_upgrade_helpers(job, building_id)
	_refresh_bound_scene_nodes(building_id)
	_emit_building_state_changed(building_id)
	_emit_building_job_completed(building_id, "upgrade", {
		"building_id": building_id,
		"building_name": str(building.get("name", building_id)),
		"job_type": "upgrade",
		"level": int(building.get("level", 1)),
		"hp": int(building.get("hp", 0)),
		"max_hp": int(building.get("max_hp", 0)),
	})


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
	return select_building(building_id)


func select_building(building_id: String) -> bool:
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
	var deltas := _normalize_workstation_deltas(upgrade_config.get("workstation_deltas", []))
	var legacy_bonus: int = maxi(0, int(upgrade_config.get("workstation_bonus", 0)))
	if deltas.is_empty() and legacy_bonus > 0:
		deltas.append({
			"type": str(upgrade_config.get("workstation_type", "general")),
			"count": legacy_bonus,
			"id_prefix": str(upgrade_config.get("workstation_id_prefix", "")),
			"name_prefix": str(upgrade_config.get("workstation_name_prefix", ""))
		})
	if deltas.is_empty():
		return

	var building_id := str(building.get("id", "building"))
	var workstations: Array = building.get("workstations", []) if building.get("workstations", []) is Array else []
	var fixed_types := _get_fixed_workstation_types(building, upgrade_config)
	for delta in deltas:
		var station_type := str(delta.get("type", delta.get("workstation_type", ""))).strip_edges()
		var count := maxi(0, int(delta.get("count", delta.get("amount", 0))))
		if station_type.is_empty() or count <= 0:
			continue
		if fixed_types.has(station_type):
			push_warning("Skipped workstation expansion for fixed type '%s' in building '%s'." % [station_type, building_id])
			continue
		for addition_index in range(count):
			var ordinal := _count_workstations_of_type(workstations, station_type) + 1
			var id_prefix := str(delta.get("id_prefix", "")).strip_edges()
			if id_prefix.is_empty():
				id_prefix = "%s_%s" % [building_id, station_type]
			var workstation_id := _make_unique_workstation_id(workstations, id_prefix, ordinal)
			var configured_name := str(delta.get("name", "")).strip_edges()
			var name_prefix := str(delta.get("name_prefix", "")).strip_edges()
			var has_explicit_name_prefix := not name_prefix.is_empty()
			if name_prefix.is_empty():
				name_prefix = station_type
			var workstation_name := configured_name
			if workstation_name.contains("{index}"):
				workstation_name = workstation_name.replace("{index}", str(ordinal))
			elif workstation_name.contains("{number}"):
				workstation_name = workstation_name.replace("{number}", str(ordinal))
			elif workstation_name.is_empty() or count > 1:
				var display_prefix := name_prefix if configured_name.is_empty() else configured_name
				var index_separator := "" if has_explicit_name_prefix and configured_name.is_empty() else " "
				workstation_name = "%s%s%d" % [display_prefix, index_separator, ordinal]
			workstations.append({
				"id": workstation_id,
				"name": workstation_name,
				"type": station_type,
				"occupied_by": null
			})
	building["workstations"] = _normalize_workstations(building_id, workstations)


func _apply_efficiency_upgrade(building: Dictionary, upgrade_config: Dictionary) -> void:
	var increments := _normalize_efficiency_bonuses(upgrade_config.get("efficiency_bonuses", {}))
	if increments.is_empty():
		return
	var current := _normalize_efficiency_bonuses(building.get("efficiency_bonuses", {}))
	for raw_activity_id in increments.keys():
		var activity_id := str(raw_activity_id)
		current[activity_id] = float(current.get(activity_id, 0.0)) + float(increments.get(activity_id, 0.0))
	building["efficiency_bonuses"] = current


func _resolve_upgrade_level_effect(building: Dictionary, target_level: int) -> Dictionary:
	var base_upgrade: Dictionary = building.get("upgrade", {}) if building.get("upgrade", {}) is Dictionary else {}
	if base_upgrade.is_empty():
		return {}
	var resolved := base_upgrade.duplicate(true)
	resolved.erase("level_effects")
	var raw_level_effects: Variant = base_upgrade.get("level_effects", {})
	var selected_effect := {}
	if raw_level_effects is Dictionary:
		var effects_by_level: Dictionary = raw_level_effects
		var raw_effect: Variant = effects_by_level.get(str(target_level), {})
		if raw_effect is Dictionary:
			selected_effect = (raw_effect as Dictionary).duplicate(true)
	elif raw_level_effects is Array:
		for raw_effect in raw_level_effects:
			if not raw_effect is Dictionary:
				continue
			var effect: Dictionary = raw_effect
			if int(effect.get("target_level", effect.get("level", 0))) == target_level:
				selected_effect = effect.duplicate(true)
				break
	for raw_key in selected_effect.keys():
		resolved[raw_key] = selected_effect[raw_key]
	resolved["target_level"] = target_level
	return resolved


func _get_upgrade_max_level(building: Dictionary, upgrade_config: Dictionary) -> int:
	if upgrade_config.has("max_level"):
		return maxi(int(building.get("level", 1)), int(upgrade_config.get("max_level", building.get("level", 1))))
	var max_level := int(building.get("level", 1))
	var raw_level_effects: Variant = upgrade_config.get("level_effects", {})
	if raw_level_effects is Dictionary:
		for raw_level in (raw_level_effects as Dictionary).keys():
			max_level = maxi(max_level, int(str(raw_level)))
	elif raw_level_effects is Array:
		for raw_effect in raw_level_effects:
			if raw_effect is Dictionary:
				max_level = maxi(max_level, int((raw_effect as Dictionary).get("target_level", (raw_effect as Dictionary).get("level", 0))))
	return max_level


func _normalize_workstation_deltas(raw_deltas: Variant) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if raw_deltas is Dictionary:
		for raw_type in (raw_deltas as Dictionary).keys():
			var raw_delta: Variant = (raw_deltas as Dictionary).get(raw_type)
			if raw_delta is Dictionary:
				var delta := (raw_delta as Dictionary).duplicate(true)
				delta["type"] = str(delta.get("type", raw_type))
				result.append(delta)
			else:
				result.append({"type": str(raw_type), "count": int(raw_delta)})
	elif raw_deltas is Array:
		for raw_delta in raw_deltas:
			if raw_delta is Dictionary:
				result.append((raw_delta as Dictionary).duplicate(true))
	return result


func _normalize_efficiency_bonuses(raw_bonuses: Variant) -> Dictionary:
	var result := {}
	if not raw_bonuses is Dictionary:
		return result
	for raw_activity_id in (raw_bonuses as Dictionary).keys():
		var activity_id := str(raw_activity_id).strip_edges()
		if activity_id.is_empty():
			continue
		result[activity_id] = float((raw_bonuses as Dictionary).get(raw_activity_id, 0.0))
	return result


func _normalize_workstations(building_id: String, raw_workstations: Array) -> Array:
	var normalized: Array = []
	var type_counts := {}
	for raw_workstation in raw_workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation := (raw_workstation as Dictionary).duplicate(true)
		var station_type := str(workstation.get("type", "general")).strip_edges()
		if station_type.is_empty():
			station_type = "general"
		var ordinal := int(type_counts.get(station_type, 0)) + 1
		type_counts[station_type] = ordinal
		var workstation_id := str(workstation.get("id", "")).strip_edges()
		if workstation_id.is_empty() or _has_workstation_id(normalized, workstation_id):
			workstation_id = _make_unique_workstation_id(normalized, "%s_%s" % [building_id, station_type], ordinal)
		var workstation_name := str(workstation.get("name", "")).strip_edges()
		if workstation_name.is_empty():
			workstation_name = "%s %d" % [station_type, ordinal]
		workstation["id"] = workstation_id
		workstation["name"] = workstation_name
		workstation["type"] = station_type
		var assigned_npc_id := str(workstation.get("assigned_npc_id", "")).strip_edges()
		if assigned_npc_id.is_empty() or assigned_npc_id == "<null>":
			workstation.erase("assigned_npc_id")
		else:
			workstation["assigned_npc_id"] = assigned_npc_id
		if not workstation.has("occupied_by"):
			workstation["occupied_by"] = null
		if not workstation.has("reserved_by"):
			workstation["reserved_by"] = null
		normalized.append(workstation)
	return normalized


func _clean_nullable_id(value: Variant) -> String:
	var clean_id := str(value).strip_edges()
	return "" if clean_id == "<null>" else clean_id


func _find_assigned_workstation_id(
	workstations: Array,
	npc_id: String,
	preferred_type: String
) -> String:
	for raw_workstation in workstations:
		if not raw_workstation is Dictionary:
			continue
		var workstation: Dictionary = raw_workstation
		if (
			not preferred_type.is_empty()
			and str(workstation.get("type", "")) != preferred_type
		):
			continue
		if str(workstation.get("assigned_npc_id", "")).strip_edges() == npc_id:
			return str(workstation.get("id", ""))
	return ""


func _get_fixed_workstation_types(building: Dictionary, upgrade_config: Dictionary) -> Array[String]:
	var result: Array[String] = []
	var sources: Array = [
		building.get("fixed_workstation_types", []),
		(building.get("upgrade", {}) as Dictionary).get("fixed_workstation_types", []) if building.get("upgrade", {}) is Dictionary else [],
		upgrade_config.get("fixed_workstation_types", [])
	]
	for raw_source in sources:
		if not raw_source is Array:
			continue
		for raw_type in raw_source:
			var station_type := str(raw_type).strip_edges()
			if not station_type.is_empty() and not result.has(station_type):
				result.append(station_type)
	for raw_workstation in building.get("workstations", []):
		if not raw_workstation is Dictionary or not bool((raw_workstation as Dictionary).get("fixed_capacity", false)):
			continue
		var fixed_type := str((raw_workstation as Dictionary).get("type", ""))
		if not fixed_type.is_empty() and not result.has(fixed_type):
			result.append(fixed_type)
	return result


func _count_workstations_of_type(workstations: Array, station_type: String) -> int:
	var count := 0
	for raw_workstation in workstations:
		if raw_workstation is Dictionary and str((raw_workstation as Dictionary).get("type", "")) == station_type:
			count += 1
	return count


func _has_workstation_id(workstations: Array, workstation_id: String) -> bool:
	for raw_workstation in workstations:
		if raw_workstation is Dictionary and str((raw_workstation as Dictionary).get("id", "")) == workstation_id:
			return true
	return false


func _make_unique_workstation_id(workstations: Array, raw_prefix: String, preferred_ordinal: int) -> String:
	var prefix := raw_prefix.strip_edges().replace(" ", "_")
	if prefix.is_empty():
		prefix = "workstation"
	var ordinal := maxi(1, preferred_ordinal)
	var candidate := "%s_%02d" % [prefix, ordinal]
	while _has_workstation_id(workstations, candidate):
		ordinal += 1
		candidate = "%s_%02d" % [prefix, ordinal]
	return candidate


func _is_building_location_enterable(building_id: String) -> bool:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system != null and memory_system.has_method("is_enterable_location"):
		return bool(memory_system.is_enterable_location(building_id))
	if not _buildings.has(building_id):
		return false
	var building: Dictionary = _buildings[building_id]
	return building.get("workstations", []) is Array and not (building.get("workstations", []) as Array).is_empty()


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


func _emit_building_job_completed(building_id: String, job_type: String, result: Dictionary) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("building_job_completed"):
		event_bus.building_job_completed.emit(building_id, job_type, result.duplicate(true))


func _log_building_damaged(
	building_id: String,
	actor_id: String,
	damage: int,
	hp_before: int,
	hp_after: int,
	visibility: String,
	options: Dictionary
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	var building: Dictionary = _buildings.get(building_id, {})
	var building_name := str(building.get("name", building_id))
	var attacker_name := str(options.get("attacker_name", actor_id))
	var summary := str(options.get("summary", "")).strip_edges()
	if summary.is_empty():
		summary = "%s攻击了%s，造成%d点建筑伤害，HP 从%d降到%d。" % [
			attacker_name,
			building_name,
			damage,
			hp_before,
			hp_after
		]
	return memory_system.add_event({
		"type": "building_damaged",
		"subject_npc_id": "",
		"actor_ids": [actor_id],
		"target_ids": [building_id, PLAZA_LOCATION_ID],
		"location_id": PLAZA_LOCATION_ID,
		"visibility": "private" if visibility == "private" else DEFAULT_DAMAGE_VISIBILITY,
		"importance": 70,
		"summary": summary,
		"payload": {
			"building_id": building_id,
			"building_name": building_name,
			"damage": damage,
			"hp_before": hp_before,
			"hp_after": hp_after,
			"damage_source": actor_id
		}
	})
