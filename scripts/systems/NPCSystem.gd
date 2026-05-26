extends Node

const NPC_PROFILES_FILE := "npc_profiles.json"
const NPC_SCENE_PATH := "res://scenes/npc/NPC.tscn"
const NPC_ROOT_PATH := "/root/Main/WorldRoot/Station/NPCs"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const PLAZA_LOCATION_ID := "plaza"
const PICK_RAY_LENGTH := 1000.0
const PROFESSIONAL_SKILLS: Array[String] = ["养马", "厨艺", "耕种", "打铁", "教练", "酿酒", "医术", "工程"]
const WEAPON_SKILLS: Array[String] = ["剑盾", "长杆", "弓", "弩", "骑术"]
const SPECIALTY_THRESHOLD := 25

const SPAWN_POINTS: Array[Vector3] = [
	Vector3(-8.0, 0.0, 2.5),
	Vector3(-4.8, 0.0, 3.3),
	Vector3(-1.6, 0.0, 2.7),
	Vector3(1.6, 0.0, 3.2),
	Vector3(4.8, 0.0, 2.4),
	Vector3(8.0, 0.0, 3.0),
	Vector3(-3.2, 0.0, -1.2),
	Vector3(3.2, 0.0, -1.2)
]

var _profiles: Dictionary = {}
var _npc_order: Array[String] = []
var _npc_nodes: Dictionary = {}
var _selected_npc_id: String = ""


func _ready() -> void:
	initialize()


func initialize() -> void:
	_clear_spawned_npcs()
	_profiles.clear()
	_npc_order.clear()
	_npc_nodes.clear()
	_selected_npc_id = ""

	var config_loader := get_node_or_null("/root/ConfigLoader")
	if config_loader == null:
		push_error("NPCSystem requires ConfigLoader autoload.")
		return

	var loaded_profiles: Variant = config_loader.load_data_file(NPC_PROFILES_FILE, [])
	if not loaded_profiles is Array:
		push_error("NPC profiles must be a JSON array: %s" % NPC_PROFILES_FILE)
		return

	var npc_scene := load(NPC_SCENE_PATH) as PackedScene
	if npc_scene == null:
		push_error("NPC scene not found or invalid: %s" % NPC_SCENE_PATH)
		return

	var npc_root := get_node_or_null(NPC_ROOT_PATH)
	if npc_root == null:
		push_error("NPC root not found: %s" % NPC_ROOT_PATH)
		return

	for raw_profile in loaded_profiles:
		if not raw_profile is Dictionary:
			push_error("Skipped invalid NPC profile because it is not a dictionary.")
			continue

		var profile: Dictionary = raw_profile
		var npc_id := str(profile.get("id", ""))
		if npc_id.is_empty():
			push_error("Skipped NPC profile with empty id.")
			continue
		if _profiles.has(npc_id):
			push_error("Skipped duplicate NPC id: %s" % npc_id)
			continue

		profile["skills"] = normalize_skills(profile.get("skills", {}))
		var npc_node := npc_scene.instantiate()
		npc_root.add_child(npc_node)
		npc_node.global_position = _get_spawn_position(_npc_order.size())
		if npc_node.has_method("setup"):
			npc_node.setup(profile)
		if npc_node.has_signal("movement_arrived"):
			npc_node.movement_arrived.connect(_on_npc_movement_arrived)

		_profiles[npc_id] = profile.duplicate(true)
		_ensure_runtime_state_defaults(npc_id)
		_npc_order.append(npc_id)
		_npc_nodes[npc_id] = npc_node.get_path()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var npc_id := _pick_npc_at_screen_position(event.position)
		if not npc_id.is_empty():
			_select_npc(npc_id)
			get_viewport().set_input_as_handled()


func get_npc(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Unknown NPC id: %s" % npc_id)
		return {}
	return _profiles[npc_id].duplicate(true)


func get_npc_state(npc_id: String) -> Dictionary:
	var profile := get_npc(npc_id)
	if profile.is_empty():
		return {}
	var states: Dictionary = profile.get("states", {})
	return states.duplicate(true)


func get_npc_ids() -> Array[String]:
	return _npc_order.duplicate()


func get_npc_count() -> int:
	return _npc_order.size()


func get_selected_npc_id() -> String:
	return _selected_npc_id


func get_professional_skill_names() -> Array[String]:
	return PROFESSIONAL_SKILLS.duplicate()


func get_weapon_skill_names() -> Array[String]:
	return WEAPON_SKILLS.duplicate()


func normalize_skills(raw_skills: Variant) -> Dictionary:
	var source: Dictionary = raw_skills if raw_skills is Dictionary else {}
	var normalized := {}
	for skill_name in PROFESSIONAL_SKILLS + WEAPON_SKILLS:
		normalized[skill_name] = clampi(int(source.get(skill_name, 0)), 0, 100)
	return normalized


func get_npc_specialties(npc_id: String, max_count: int = 3) -> Array[String]:
	var npc := get_npc(npc_id)
	if npc.is_empty():
		return []

	var skills: Dictionary = normalize_skills(npc.get("skills", {}))
	var entries: Array[Dictionary] = []
	for skill_name in PROFESSIONAL_SKILLS + WEAPON_SKILLS:
		var value := int(skills.get(skill_name, 0))
		if value >= SPECIALTY_THRESHOLD:
			entries.append({"name": skill_name, "value": value})

	entries.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return int(left.get("value", 0)) > int(right.get("value", 0))
	)

	var result: Array[String] = []
	for index in range(mini(max_count, entries.size())):
		var entry: Dictionary = entries[index]
		result.append("%s %d" % [str(entry.get("name", "")), int(entry.get("value", 0))])
	return result


func debug_select_npc(npc_id: String) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot select unknown NPC: %s" % npc_id)
		return false
	_select_npc(npc_id)
	return true


func move_npc_to_building(npc_id: String, building_id: String) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot move unknown NPC: %s" % npc_id)
		return false
	if not _npc_nodes.has(npc_id):
		push_warning("Cannot move NPC without scene node: %s" % npc_id)
		return false

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null:
		push_warning("Cannot move NPC because BuildingSystem is missing.")
		return false

	var target_position: Variant = building_system.get_building_entry_position(building_id)
	if target_position == null:
		push_warning("Cannot move NPC %s to building without entry position: %s" % [npc_id, building_id])
		return false

	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node == null or not npc_node.has_method("move_to_location"):
		push_warning("Cannot move NPC because node has no movement API: %s" % npc_id)
		return false

	var building_name := "广场" if building_id == PLAZA_LOCATION_ID else str(building_system.get_building(building_id).get("name", building_id))
	_set_npc_state_without_signal(npc_id, {
		"current_action": "moving_to_%s" % building_id,
		"movement_target": building_id,
		"movement_target_name": building_name,
		"location_context": {}
	})
	npc_node.move_to_location(building_id, target_position)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func debug_move_npc_to_building(npc_id: String, building_id: String) -> bool:
	return move_npc_to_building(npc_id, building_id)


func debug_move_selected_npc_to_building(building_id: String) -> bool:
	if _selected_npc_id.is_empty():
		push_warning("Cannot move selected NPC because no NPC is selected.")
		return false
	return move_npc_to_building(_selected_npc_id, building_id)


func update_npc_state(npc_id: String, changes: Dictionary) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot update unknown NPC: %s" % npc_id)
		return false
	if changes.is_empty():
		return true

	_set_npc_state_without_signal(npc_id, changes)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func set_npc_state_value(npc_id: String, state_key: String, value: Variant) -> bool:
	return update_npc_state(npc_id, {state_key: value})


func _set_npc_state_without_signal(npc_id: String, changes: Dictionary) -> void:
	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	for key in changes.keys():
		states[str(key)] = changes[key]
	profile["states"] = states
	_profiles[npc_id] = profile


func _ensure_runtime_state_defaults(npc_id: String) -> void:
	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	if not states.has("current_location"):
		states["current_location"] = "plaza"
	if not states.has("location_context"):
		states["location_context"] = {}
	profile["states"] = states
	_profiles[npc_id] = profile


func _clear_spawned_npcs() -> void:
	var npc_root := get_node_or_null(NPC_ROOT_PATH)
	if npc_root == null:
		return

	for child in npc_root.get_children():
		child.queue_free()


func _get_spawn_position(index: int) -> Vector3:
	if index < SPAWN_POINTS.size():
		return SPAWN_POINTS[index]

	var overflow_index := index - SPAWN_POINTS.size()
	return Vector3(-8.0 + float(overflow_index % 8) * 2.3, 0.0, -3.0 - float(overflow_index / 8) * 2.0)


func _pick_npc_at_screen_position(screen_position: Vector2) -> String:
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
		var npc_id := str(collider.get_meta("npc_id", ""))
		if not npc_id.is_empty():
			return npc_id
		collider = collider.get_parent()

	return ""


func _select_npc(npc_id: String) -> void:
	_selected_npc_id = npc_id
	print("NPC selected: %s" % npc_id)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_clicked.emit(npc_id)


func _refresh_npc_node(npc_id: String) -> void:
	if not _npc_nodes.has(npc_id):
		return

	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node != null and npc_node.has_method("update_profile"):
		npc_node.update_profile(_profiles[npc_id])


func _emit_npc_state_changed(npc_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		event_bus.npc_state_changed.emit(npc_id)


func _on_npc_movement_arrived(npc_id: String, building_id: String) -> void:
	if not _profiles.has(npc_id):
		return

	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	var location_context: Dictionary = {}
	var building_name := building_id
	var previous_state: Dictionary = get_npc_state(npc_id)
	var previous_location_id := str(previous_state.get("current_location", "plaza"))
	var info_location_id := building_id
	var previous_info_location_id := previous_location_id
	if memory_system != null and memory_system.has_method("is_enterable_location"):
		previous_info_location_id = _get_info_location_id(memory_system, previous_location_id)
		if not memory_system.is_enterable_location(building_id):
			info_location_id = "plaza"
		location_context = memory_system.move_npc_between_locations(npc_id, previous_location_id, info_location_id)
	if location_context.is_empty() and building_system != null:
		location_context = building_system.get_building_location_context(building_id)
		building_name = str(location_context.get("name", building_id))
	elif building_system != null and building_id != PLAZA_LOCATION_ID:
		var building: Dictionary = building_system.get_building(building_id)
		building_name = str(building.get("name", location_context.get("name", building_id)))
	else:
		building_name = str(location_context.get("name", building_id))

	_set_npc_state_without_signal(npc_id, {
		"current_action": "idle",
		"current_location": building_id,
		"current_location_name": building_name,
		"movement_target": "",
		"movement_target_name": "",
		"location_context": location_context
	})
	_refresh_npc_node(npc_id)
	if previous_info_location_id != info_location_id:
		_log_location_exited(npc_id, previous_info_location_id, info_location_id)
		_log_location_entered(npc_id, previous_info_location_id, building_id, info_location_id)
	_emit_npc_state_changed(npc_id)


func debug_enter_location_immediately(npc_id: String, location_id: String) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot set location for unknown NPC: %s" % npc_id)
		return false

	var previous_state: Dictionary = get_npc_state(npc_id)
	var previous_location_id := str(previous_state.get("current_location", "plaza"))
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	var info_location_id := location_id
	var previous_info_location_id := previous_location_id
	var location_context: Dictionary = {}
	if memory_system != null and memory_system.has_method("is_enterable_location"):
		previous_info_location_id = _get_info_location_id(memory_system, previous_location_id)
		if not memory_system.is_enterable_location(location_id):
			info_location_id = "plaza"
		location_context = memory_system.move_npc_between_locations(npc_id, previous_location_id, info_location_id)

	_set_npc_state_without_signal(npc_id, {
		"current_action": "idle",
		"current_location": location_id,
		"current_location_name": str(location_context.get("name", location_id)),
		"movement_target": "",
		"movement_target_name": "",
		"location_context": location_context
	})
	_refresh_npc_node(npc_id)
	if previous_info_location_id != info_location_id:
		_log_location_exited(npc_id, previous_info_location_id, info_location_id)
		_log_location_entered(npc_id, previous_info_location_id, location_id, info_location_id)
	_emit_npc_state_changed(npc_id)
	return true


func _log_location_entered(
	npc_id: String,
	from_location_id: String,
	to_location_id: String,
	event_location_id: String,
	location_context: Dictionary = {}
) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return

	memory_system.add_event({
		"type": "location_entered",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [to_location_id],
		"location_id": event_location_id,
		"visibility": "local_public",
		"importance": 20,
		"payload": {
			"from_location_id": from_location_id,
			"to_location_id": to_location_id
		}
	})


func _log_location_exited(npc_id: String, from_location_id: String, to_location_id: String) -> void:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return
	if from_location_id.is_empty() or from_location_id == to_location_id:
		return

	memory_system.add_event({
		"type": "location_exited",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [from_location_id, to_location_id],
		"location_id": from_location_id,
		"visibility": "local_public",
		"importance": 20,
		"payload": {
			"from_location_id": from_location_id,
			"to_location_id": to_location_id
		}
	})


func _get_info_location_id(memory_system: Node, location_id: String) -> String:
	if memory_system != null and memory_system.has_method("is_enterable_location") and memory_system.is_enterable_location(location_id):
		return location_id
	return PLAZA_LOCATION_ID
