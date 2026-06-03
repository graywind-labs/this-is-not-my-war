extends Node

const NPC_PROFILES_FILE := "npc_profiles.json"
const NPC_SCENE_PATH := "res://scenes/npc/NPC.tscn"
const NPC_ROOT_PATH := "/root/Main/WorldRoot/Station/NPCs"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const PLAZA_LOCATION_ID := "plaza"
const PLAYER_ACTOR_ID := "guard_officer"
const SYSTEM_ACTOR_ID := "system"
const PICK_RAY_LENGTH := 1000.0
const PROFESSIONAL_SKILLS: Array[String] = ["养马", "厨艺", "耕种", "打铁", "教练", "酿酒", "医术", "工程"]
const WEAPON_SKILLS: Array[String] = ["剑盾", "长杆", "弓", "弩", "骑术"]
const SPECIALTY_THRESHOLD := 25
const UNCONSCIOUS_NATURAL_RECOVERY_HP_PER_HOUR := 2.0
const UNCONSCIOUS_HEALING_BASE_HP_PER_HOUR := 2.0
const UNCONSCIOUS_HEALING_MAX_BONUS_HP_PER_HOUR := 10.0
const UNCONSCIOUS_HEALING_SKILL_THRESHOLD := 20.0
const REVIVE_HP_RATIO := 0.3

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
var _unconscious_recovery_remainders: Dictionary = {}


func _ready() -> void:
	initialize()
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and not event_bus.logical_time_tick.is_connected(_on_logical_time_tick):
		event_bus.logical_time_tick.connect(_on_logical_time_tick)


func initialize() -> void:
	_clear_spawned_npcs()
	_profiles.clear()
	_npc_order.clear()
	_npc_nodes.clear()
	_unconscious_recovery_remainders.clear()
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
	if not can_npc_act(npc_id):
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


func can_npc_act(npc_id: String) -> bool:
	if not _profiles.has(npc_id):
		return false
	var state := get_npc_state(npc_id)
	return not bool(state.get("unconscious", false)) and not bool(state.get("escaped", false))


func apply_damage_to_npc(
	npc_id: String,
	damage: int,
	actor_id: String = PLAYER_ACTOR_ID,
	visibility: String = "local_public"
) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Cannot damage unknown NPC: %s" % npc_id)
		return {}
	if damage <= 0:
		push_warning("NPC damage must be positive: %d" % damage)
		return {}

	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	var max_hp := maxi(1, int(states.get("max_hp", 100)))
	var hp_before := clampi(int(states.get("hp", max_hp)), 0, max_hp)
	var was_unconscious := bool(states.get("unconscious", false))
	var hp_after := maxi(0, hp_before - damage)
	states["hp"] = hp_after
	states["max_hp"] = max_hp
	var became_unconscious := hp_after <= 0 and not was_unconscious
	if became_unconscious:
		states["unconscious"] = true
		states["current_action"] = "unconscious"
		states["movement_target"] = ""
		states["movement_target_name"] = ""
		states["last_action_result"] = "became_unconscious"
	profile["states"] = states
	_profiles[npc_id] = profile

	if became_unconscious:
		_stop_npc_movement(npc_id)
	_refresh_npc_node(npc_id)
	_emit_npc_hp_changed(npc_id, hp_after, max_hp)
	_emit_npc_state_changed(npc_id)

	var damage_event := _log_damage_taken(npc_id, actor_id, damage, hp_before, hp_after, visibility)
	var unconscious_event := {}
	if became_unconscious:
		unconscious_event = _log_unconscious_started(npc_id, actor_id, damage, hp_before, hp_after, "local_public")
		_emit_npc_unconscious(npc_id)

	return {
		"ok": true,
		"npc_id": npc_id,
		"damage": damage,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"unconscious": bool(states.get("unconscious", false)),
		"damage_event": damage_event,
		"unconscious_event": unconscious_event
	}


func debug_damage_npc(npc_id: String, damage: int, visibility: String = "local_public") -> Dictionary:
	return apply_damage_to_npc(npc_id, damage, PLAYER_ACTOR_ID, visibility)


func debug_advance_unconscious_recovery(npc_id: String, game_seconds: float) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Cannot advance recovery for unknown NPC: %s" % npc_id)
		return {}
	if game_seconds <= 0.0:
		push_warning("Recovery advance seconds must be positive: %f" % game_seconds)
		return {}
	return _advance_unconscious_recovery(game_seconds, npc_id)


func assist_unconscious_recovery(
	target_npc_id: String,
	game_seconds: float,
	healer_npc_id: String,
	medical_skill: int
) -> Dictionary:
	if not _profiles.has(target_npc_id):
		push_warning("Cannot heal unknown NPC: %s" % target_npc_id)
		return {}
	if not _profiles.has(healer_npc_id):
		push_warning("Cannot use unknown healer NPC: %s" % healer_npc_id)
		return {}
	if game_seconds <= 0.0:
		return {}
	var hp_per_hour := _calculate_healing_hp_per_hour(medical_skill)
	return _advance_single_unconscious_recovery_with_rate(
		target_npc_id,
		game_seconds,
		hp_per_hour,
		"healing_assist",
		healer_npc_id
	)


func _on_logical_time_tick(game_delta_seconds: float, _numeric_multiplier: float) -> void:
	if game_delta_seconds <= 0.0:
		return
	_advance_unconscious_recovery(game_delta_seconds)


func _advance_unconscious_recovery(game_delta_seconds: float, only_npc_id: String = "") -> Dictionary:
	var result := {
		"ok": true,
		"game_seconds": game_delta_seconds,
		"recovered": [],
		"revived": []
	}
	var npc_ids: Array = [only_npc_id] if not only_npc_id.is_empty() else _npc_order.duplicate()
	for npc_id in npc_ids:
		if not _profiles.has(npc_id):
			continue
		var recovery_result := _advance_single_unconscious_recovery(npc_id, game_delta_seconds)
		if recovery_result.is_empty():
			continue
		(result["recovered"] as Array).append(recovery_result)
		if bool(recovery_result.get("revived", false)):
			(result["revived"] as Array).append(npc_id)
	return result


func _advance_single_unconscious_recovery(npc_id: String, game_delta_seconds: float) -> Dictionary:
	return _advance_single_unconscious_recovery_with_rate(
		npc_id,
		game_delta_seconds,
		UNCONSCIOUS_NATURAL_RECOVERY_HP_PER_HOUR,
		"natural_recovery"
	)


func _advance_single_unconscious_recovery_with_rate(
	npc_id: String,
	game_delta_seconds: float,
	hp_per_hour: float = UNCONSCIOUS_NATURAL_RECOVERY_HP_PER_HOUR,
	recovery_source: String = "natural_recovery",
	healer_npc_id: String = ""
) -> Dictionary:
	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	if not bool(states.get("unconscious", false)) or bool(states.get("escaped", false)):
		_unconscious_recovery_remainders.erase(npc_id)
		return {}

	var max_hp := maxi(1, int(states.get("max_hp", 100)))
	var hp_before := clampi(int(states.get("hp", 0)), 0, max_hp)
	var revive_threshold := _get_revive_hp_threshold(max_hp)
	if hp_before >= revive_threshold:
		return _revive_npc_from_unconscious(npc_id, hp_before, hp_before, recovery_source)

	var remainder_key := _get_recovery_remainder_key(npc_id, recovery_source, healer_npc_id)
	var accumulated := float(_unconscious_recovery_remainders.get(remainder_key, 0.0))
	accumulated += (maxf(0.0, hp_per_hour) / 3600.0) * game_delta_seconds
	var hp_to_restore := int(floor(accumulated))
	if hp_to_restore <= 0:
		_unconscious_recovery_remainders[remainder_key] = accumulated
		return {}

	accumulated -= float(hp_to_restore)
	var hp_after := mini(max_hp, hp_before + hp_to_restore)
	if hp_after >= revive_threshold:
		hp_after = revive_threshold
		_clear_recovery_remainders_for_npc(npc_id)
		return _revive_npc_from_unconscious(npc_id, hp_before, hp_after, recovery_source)

	_unconscious_recovery_remainders[remainder_key] = accumulated
	states["hp"] = hp_after
	states["max_hp"] = max_hp
	states["last_action_result"] = "unconscious_%s" % recovery_source
	profile["states"] = states
	_profiles[npc_id] = profile
	_refresh_npc_node(npc_id)
	_emit_npc_hp_changed(npc_id, hp_after, max_hp)
	_emit_npc_state_changed(npc_id)
	return {
		"npc_id": npc_id,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"revive_threshold": revive_threshold,
		"revived": false,
		"recovery_source": recovery_source,
		"hp_per_hour": hp_per_hour,
		"healer_npc_id": healer_npc_id
	}


func _revive_npc_from_unconscious(npc_id: String, hp_before: int, hp_after: int, recovery_source: String) -> Dictionary:
	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	var max_hp := maxi(1, int(states.get("max_hp", 100)))
	var revive_threshold := _get_revive_hp_threshold(max_hp)
	hp_after = clampi(maxi(hp_after, revive_threshold), 1, max_hp)
	states["hp"] = hp_after
	states["max_hp"] = max_hp
	states["unconscious"] = false
	states["current_action"] = "idle"
	states["last_action_result"] = "revived_%s" % recovery_source
	profile["states"] = states
	_profiles[npc_id] = profile
	_clear_recovery_remainders_for_npc(npc_id)

	_refresh_npc_node(npc_id)
	_emit_npc_hp_changed(npc_id, hp_after, max_hp)
	_emit_npc_state_changed(npc_id)
	var revived_event := _log_revived(npc_id, hp_before, hp_after, recovery_source, "local_public")
	_emit_npc_revived(npc_id)
	return {
		"npc_id": npc_id,
		"hp_before": hp_before,
		"hp_after": hp_after,
		"max_hp": max_hp,
		"revive_threshold": revive_threshold,
		"revived": true,
		"revived_event": revived_event
	}


func _get_revive_hp_threshold(max_hp: int) -> int:
	return maxi(1, int(ceil(float(max_hp) * REVIVE_HP_RATIO)))


func _calculate_healing_hp_per_hour(medical_skill: int) -> float:
	var normalized_skill := clampf((float(medical_skill) - UNCONSCIOUS_HEALING_SKILL_THRESHOLD) / 80.0, 0.0, 1.0)
	var bonus := pow(normalized_skill, 1.5) * UNCONSCIOUS_HEALING_MAX_BONUS_HP_PER_HOUR
	return UNCONSCIOUS_HEALING_BASE_HP_PER_HOUR + bonus


func _get_recovery_remainder_key(npc_id: String, recovery_source: String, helper_id: String = "") -> String:
	if recovery_source == "natural_recovery" or helper_id.is_empty():
		return npc_id
	return "%s:%s:%s" % [npc_id, recovery_source, helper_id]


func _clear_recovery_remainders_for_npc(npc_id: String) -> void:
	var keys := _unconscious_recovery_remainders.keys()
	for raw_key in keys:
		var key := str(raw_key)
		if key == npc_id or key.begins_with("%s:" % npc_id):
			_unconscious_recovery_remainders.erase(key)


func _set_npc_state_without_signal(npc_id: String, changes: Dictionary) -> void:
	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	for key in changes.keys():
		states[str(key)] = changes[key]
	profile["states"] = states
	_profiles[npc_id] = profile


func _stop_npc_movement(npc_id: String) -> void:
	if not _npc_nodes.has(npc_id):
		return
	var npc_node := get_node_or_null(_npc_nodes[npc_id])
	if npc_node != null and npc_node.has_method("stop_movement"):
		npc_node.stop_movement()


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


func _emit_npc_hp_changed(npc_id: String, hp: int, max_hp: int) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_hp_changed"):
		event_bus.npc_hp_changed.emit(npc_id, hp, max_hp)


func _emit_npc_unconscious(npc_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_unconscious"):
		event_bus.npc_unconscious.emit(npc_id)


func _emit_npc_revived(npc_id: String) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_revived"):
		event_bus.npc_revived.emit(npc_id)


func _log_damage_taken(
	npc_id: String,
	actor_id: String,
	damage: int,
	hp_before: int,
	hp_after: int,
	visibility: String
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}

	var location_id := _get_current_info_location(npc_id, memory_system)
	return memory_system.add_event({
		"type": "damage_taken",
		"subject_npc_id": npc_id,
		"actor_ids": [actor_id],
		"target_ids": [npc_id, location_id],
		"location_id": location_id,
		"visibility": visibility,
		"importance": 60,
		"payload": {
			"damage": damage,
			"hp_before": hp_before,
			"hp_after": hp_after,
			"damage_source": actor_id
		}
	})


func _log_unconscious_started(
	npc_id: String,
	actor_id: String,
	damage: int,
	hp_before: int,
	hp_after: int,
	visibility: String
) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}

	var location_id := _get_current_info_location(npc_id, memory_system)
	return memory_system.add_event({
		"type": "unconscious_started",
		"subject_npc_id": npc_id,
		"actor_ids": [actor_id],
		"target_ids": [npc_id, location_id],
		"location_id": location_id,
		"visibility": visibility,
		"importance": 85,
		"payload": {
			"damage": damage,
			"hp_before": hp_before,
			"hp_after": hp_after,
			"damage_source": actor_id
		}
	})


func _log_revived(npc_id: String, hp_before: int, hp_after: int, recovery_source: String, visibility: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}

	var location_id := _get_current_info_location(npc_id, memory_system)
	return memory_system.add_event({
		"type": "revived",
		"subject_npc_id": npc_id,
		"actor_ids": [SYSTEM_ACTOR_ID],
		"target_ids": [npc_id, location_id],
		"location_id": location_id,
		"visibility": visibility,
		"importance": 80,
		"payload": {
			"hp_before": hp_before,
			"hp_after": hp_after,
			"recovery_source": recovery_source
		}
	})


func _get_current_info_location(npc_id: String, memory_system: Node) -> String:
	var state := get_npc_state(npc_id)
	var location_id := str(state.get("current_location", PLAZA_LOCATION_ID))
	if memory_system != null and memory_system.has_method("is_enterable_location") and memory_system.is_enterable_location(location_id):
		return location_id
	return PLAZA_LOCATION_ID


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
		location_context = _transition_npc_info_location(
			npc_id,
			previous_info_location_id,
			building_id,
			info_location_id,
			memory_system
		)
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
		location_context = _transition_npc_info_location(
			npc_id,
			previous_info_location_id,
			location_id,
			info_location_id,
			memory_system
		)

	_set_npc_state_without_signal(npc_id, {
		"current_action": "idle",
		"current_location": location_id,
		"current_location_name": str(location_context.get("name", location_id)),
		"movement_target": "",
		"movement_target_name": "",
		"location_context": location_context
	})
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return true


func _transition_npc_info_location(
	npc_id: String,
	from_info_location_id: String,
	to_location_id: String,
	to_info_location_id: String,
	memory_system: Node
) -> Dictionary:
	if memory_system == null or not memory_system.has_method("move_npc_between_locations"):
		return {}

	var normalized_from_info := _get_info_location_id(memory_system, from_info_location_id)
	var normalized_to_info := _get_info_location_id(memory_system, to_info_location_id)
	if normalized_from_info == normalized_to_info:
		return memory_system.move_npc_between_locations(npc_id, normalized_from_info, normalized_to_info)

	if _should_route_between_indoor_locations_through_plaza(normalized_from_info, normalized_to_info):
		memory_system.move_npc_between_locations(npc_id, normalized_from_info, PLAZA_LOCATION_ID)
		_log_location_exited(npc_id, normalized_from_info, PLAZA_LOCATION_ID)
		_log_location_entered(npc_id, normalized_from_info, PLAZA_LOCATION_ID, PLAZA_LOCATION_ID)

		var final_context: Dictionary = memory_system.move_npc_between_locations(npc_id, PLAZA_LOCATION_ID, normalized_to_info)
		_log_location_exited(npc_id, PLAZA_LOCATION_ID, normalized_to_info)
		_log_location_entered(npc_id, PLAZA_LOCATION_ID, to_location_id, normalized_to_info)
		return final_context

	var location_context: Dictionary = memory_system.move_npc_between_locations(npc_id, normalized_from_info, normalized_to_info)
	_log_location_exited(npc_id, normalized_from_info, normalized_to_info)
	_log_location_entered(npc_id, normalized_from_info, to_location_id, normalized_to_info)
	return location_context


func _should_route_between_indoor_locations_through_plaza(from_info_location_id: String, to_info_location_id: String) -> bool:
	return (
		from_info_location_id != PLAZA_LOCATION_ID
		and to_info_location_id != PLAZA_LOCATION_ID
		and from_info_location_id != to_info_location_id
	)


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
