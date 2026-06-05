extends Node

const NPC_PROFILES_FILE := "npc_profiles.json"
const NPC_SCENE_PATH := "res://scenes/npc/NPC.tscn"
const NPC_ROOT_PATH := "/root/Main/WorldRoot/Station/NPCs"
const CAMERA_PATH := "/root/Main/CameraRig/Camera3D"
const BUILDING_SYSTEM_PATH := "/root/Main/Systems/BuildingSystem"
const MEMORY_SYSTEM_PATH := "/root/Main/Systems/MemorySystem"
const DIALOG_SYSTEM_PATH := "/root/Main/Systems/DialogSystem"
const RESOURCE_SYSTEM_PATH := "/root/Main/Systems/ResourceSystem"
const PLAZA_LOCATION_ID := "plaza"
const PLAYER_ACTOR_ID := "guard_officer"
const SYSTEM_ACTOR_ID := "system"
const MONEY_RESOURCE_ID := "money"
const PLACEHOLDER_WEAPON_RESOURCE_ID := "weapons"
const PLACEHOLDER_WEAPON_ID := "short_sword"
const PLACEHOLDER_WEAPON_NAME := "短剑"
const EQUIPMENT_SLOT_MAIN_WEAPON := "main_weapon"
const PICK_RAY_LENGTH := 1000.0
const PROFESSIONAL_SKILLS: Array[String] = ["养马", "厨艺", "耕种", "打铁", "教练", "酿酒", "医术", "工程"]
const WEAPON_SKILLS: Array[String] = ["剑盾", "长杆", "弓", "弩", "骑术"]
const SPECIALTY_THRESHOLD := 25
const UNCONSCIOUS_NATURAL_RECOVERY_HP_PER_HOUR := 2.0
const UNCONSCIOUS_HEALING_BASE_HP_PER_HOUR := 2.0
const UNCONSCIOUS_HEALING_MAX_BONUS_HP_PER_HOUR := 10.0
const UNCONSCIOUS_HEALING_SKILL_THRESHOLD := 20.0
const REVIVE_HP_RATIO := 0.3
const PROACTIVE_TALK_DEFAULT_DURATION_SECONDS := 3600.0

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
var _last_plan_reevaluation_request: Dictionary = {}


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
	_last_plan_reevaluation_request.clear()
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
		profile["current_order"] = _normalize_current_order(profile.get("current_order", {}))
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


func set_npc_recruited(npc_id: String, recruited: bool) -> bool:
	if not _profiles.has(npc_id):
		push_warning("Cannot update recruitment for unknown NPC: %s" % npc_id)
		return false
	var profile: Dictionary = _profiles[npc_id]
	if bool(profile.get("recruited", false)) == recruited:
		return true
	profile["recruited"] = recruited
	_profiles[npc_id] = profile
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("recruitment_changed"):
		event_bus.recruitment_changed.emit(npc_id, recruited)
	return true


func get_current_order(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		push_warning("Cannot get order for unknown NPC: %s" % npc_id)
		return {}
	return _normalize_current_order((_profiles[npc_id] as Dictionary).get("current_order", {}))


func give_money_to_npc(
	npc_id: String,
	amount: int,
	visibility: String = "local_public"
) -> Dictionary:
	if not _profiles.has(npc_id):
		return _interaction_failure("unknown_npc", "NPC 不存在。")
	if amount <= 0:
		return _interaction_failure("invalid_amount", "赠予金额必须大于 0。")

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.has_method("spend_resources"):
		return _interaction_failure("resource_system_missing", "资源系统不可用。")
	if not resource_system.spend_resources({MONEY_RESOURCE_ID: amount}):
		return _interaction_failure("not_enough_money", "第纳尔不足。")

	var profile: Dictionary = _profiles[npc_id]
	var states: Dictionary = profile.get("states", {})
	var money_before := int(states.get("money", 0))
	var money_after := money_before + amount
	states["money"] = money_after
	profile["states"] = states
	_profiles[npc_id] = profile

	var event := _log_player_interaction(npc_id, "money_given", {
		"amount": amount,
		"resource_id": MONEY_RESOURCE_ID,
		"npc_money_before": money_before,
		"npc_money_after": money_after
	}, visibility)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"amount": amount,
		"npc_money_before": money_before,
		"npc_money_after": money_after,
		"event": event
	}


func give_placeholder_weapon_to_npc(
	npc_id: String,
	visibility: String = "local_public"
) -> Dictionary:
	if not _profiles.has(npc_id):
		return _interaction_failure("unknown_npc", "NPC 不存在。")

	var resource_system := get_node_or_null(RESOURCE_SYSTEM_PATH)
	if resource_system == null or not resource_system.has_method("spend_resources"):
		return _interaction_failure("resource_system_missing", "资源系统不可用。")
	if not resource_system.spend_resources({PLACEHOLDER_WEAPON_RESOURCE_ID: 1}):
		return _interaction_failure("not_enough_weapons", "武器库存不足。")

	var profile: Dictionary = _profiles[npc_id]
	var equipment: Dictionary = profile.get("equipment", {})
	var previous_weapon: Dictionary = equipment.get(EQUIPMENT_SLOT_MAIN_WEAPON, {})
	equipment[EQUIPMENT_SLOT_MAIN_WEAPON] = {
		"id": PLACEHOLDER_WEAPON_ID,
		"name": PLACEHOLDER_WEAPON_NAME,
		"type": "melee",
		"placeholder": true
	}
	profile["equipment"] = equipment
	_profiles[npc_id] = profile

	var event_type := "equipment_changed" if not previous_weapon.is_empty() else "equipment_given"
	var event := _log_player_interaction(npc_id, event_type, {
		"slot": EQUIPMENT_SLOT_MAIN_WEAPON,
		"equipment_id": PLACEHOLDER_WEAPON_ID,
		"equipment_name": PLACEHOLDER_WEAPON_NAME,
		"previous_equipment_id": str(previous_weapon.get("id", "")),
		"previous_equipment_name": str(previous_weapon.get("name", "")),
		"resource_id": PLACEHOLDER_WEAPON_RESOURCE_ID
	}, visibility)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	return {
		"ok": true,
		"npc_id": npc_id,
		"equipment": equipment.duplicate(true),
		"event": event
	}


func publish_npc_order(npc_id: String, text: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return _order_failure("unknown_npc", "NPC 不存在。")

	var profile: Dictionary = _profiles[npc_id]
	if not bool(profile.get("recruited", false)):
		return _order_failure("npc_not_recruited", "未入伍 NPC 不能接收个人指令。")

	var current_order := _normalize_current_order(profile.get("current_order", {}))
	var old_text := str(current_order.get("text", ""))
	var new_text := text.strip_edges()
	if new_text == old_text:
		return {
			"ok": true,
			"changed": false,
			"npc_id": npc_id,
			"current_order": current_order.duplicate(true)
		}

	var issued_at := _get_game_time_snapshot()
	var revision := int(current_order.get("revision", 0)) + 1
	var next_order := {
		"text": new_text,
		"issued_by": PLAYER_ACTOR_ID,
		"issued_day": int(issued_at.get("day", 1)),
		"issued_time": str(issued_at.get("time", "00:00:00")),
		"revision": revision
	}
	profile["current_order"] = next_order
	_profiles[npc_id] = profile

	var event := _log_order_assigned(npc_id, old_text, new_text, revision)
	_request_plan_reevaluation(npc_id, "order_changed")
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_order_changed"):
		event_bus.npc_order_changed.emit(npc_id, next_order.duplicate(true))

	return {
		"ok": true,
		"changed": true,
		"npc_id": npc_id,
		"current_order": next_order.duplicate(true),
		"event": event
	}


func debug_publish_npc_order(npc_id: String, text: String) -> Dictionary:
	return publish_npc_order(npc_id, text)


func start_proactive_talk(npc_id: String, prompt_text: String, duration_seconds: float = PROACTIVE_TALK_DEFAULT_DURATION_SECONDS) -> Dictionary:
	if not _profiles.has(npc_id):
		return _interaction_failure("unknown_npc", "NPC 不存在。")
	if not can_npc_act(npc_id):
		return _interaction_failure("npc_cannot_act", "NPC 当前无法主动交涉。")
	var clean_text := prompt_text.strip_edges()
	if clean_text.is_empty():
		clean_text = "守备官，我有件事想问你。"
	var duration := maxf(1.0, duration_seconds)
	var proactive_state := {
		"active": true,
		"prompt_text": clean_text,
		"remaining_seconds": duration,
		"duration_seconds": duration
	}
	_set_npc_state_without_signal(npc_id, {
		"current_action": "proactive_talk",
		"proactive_talk": proactive_state
	})
	var event := _log_proactive_talk_started(npc_id, clean_text, duration)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	_emit_npc_proactive_talk_changed(npc_id, true)
	return {
		"ok": true,
		"npc_id": npc_id,
		"proactive_talk": proactive_state.duplicate(true),
		"event": event
	}


func debug_start_proactive_talk(npc_id: String, prompt_text: String, duration_seconds: float = PROACTIVE_TALK_DEFAULT_DURATION_SECONDS) -> Dictionary:
	return start_proactive_talk(npc_id, prompt_text, duration_seconds)


func get_proactive_talk(npc_id: String) -> Dictionary:
	if not _profiles.has(npc_id):
		return {}
	var state := get_npc_state(npc_id)
	var proactive: Dictionary = state.get("proactive_talk", {})
	return proactive.duplicate(true)


func has_active_proactive_talk(npc_id: String) -> bool:
	var proactive := get_proactive_talk(npc_id)
	return bool(proactive.get("active", false))


func handle_npc_clicked(npc_id: String) -> bool:
	if not has_active_proactive_talk(npc_id):
		return false
	var proactive := get_proactive_talk(npc_id)
	var prompt_text := str(proactive.get("prompt_text", "")).strip_edges()
	_clear_proactive_talk(npc_id, "clicked")
	var dialog_system := get_node_or_null(DIALOG_SYSTEM_PATH)
	if dialog_system == null or not dialog_system.has_method("start_proactive_player_dialogue"):
		return false
	var result: Dictionary = dialog_system.start_proactive_player_dialogue(npc_id, prompt_text)
	return bool(result.get("ok", false))


func get_last_plan_reevaluation_request() -> Dictionary:
	return _last_plan_reevaluation_request.duplicate(true)


func request_plan_reevaluation(npc_id: String, reason: String) -> void:
	if not _profiles.has(npc_id):
		return
	_request_plan_reevaluation(npc_id, reason)


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
	_advance_proactive_talk_timers(game_delta_seconds)


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
	profile["current_order"] = _normalize_current_order(profile.get("current_order", {}))
	var states: Dictionary = profile.get("states", {})
	if not states.has("current_location"):
		states["current_location"] = "plaza"
	if not states.has("location_context"):
		states["location_context"] = {}
	if not states.has("proactive_talk"):
		states["proactive_talk"] = {}
	profile["states"] = states
	_profiles[npc_id] = profile


func _normalize_current_order(raw_order: Variant) -> Dictionary:
	var order: Dictionary = raw_order if raw_order is Dictionary else {}
	return {
		"text": str(order.get("text", "")),
		"issued_by": str(order.get("issued_by", PLAYER_ACTOR_ID)),
		"issued_day": maxi(0, int(order.get("issued_day", 0))),
		"issued_time": str(order.get("issued_time", "")),
		"revision": maxi(0, int(order.get("revision", 0)))
	}


func _get_game_time_snapshot() -> Dictionary:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return {"day": 1, "time": "00:00:00"}
	return {
		"day": int(game_state.current_day),
		"time": "%02d:%02d:%02d" % [
			int(game_state.current_hour),
			int(game_state.current_minute),
			int(game_state.current_second)
		]
	}


func _log_order_assigned(npc_id: String, old_text: String, new_text: String, revision: int) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "order_assigned",
		"subject_npc_id": npc_id,
		"actor_ids": [PLAYER_ACTOR_ID],
		"target_ids": [npc_id],
		"location_id": _get_current_info_location(npc_id, memory_system),
		"visibility": "private",
		"importance": 65,
		"payload": {
			"previous_order_text": old_text,
			"new_order_text": new_text,
			"order_revision": revision
		}
	})


func _log_player_interaction(npc_id: String, event_type: String, payload: Dictionary, visibility: String) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("record_player_interaction"):
		return {}
	var normalized_visibility := "private" if visibility == "private" else "local_public"
	return memory_system.record_player_interaction(npc_id, event_type, payload, normalized_visibility)


func _request_plan_reevaluation(npc_id: String, reason: String) -> void:
	var issued_at := _get_game_time_snapshot()
	_last_plan_reevaluation_request = {
		"npc_id": npc_id,
		"reason": reason,
		"day": int(issued_at.get("day", 1)),
		"time": str(issued_at.get("time", "00:00:00")),
		"current_order": get_current_order(npc_id),
		"result": {
			"status": "rule_fallback_deferred",
			"fallback_used": true,
			"summary": "计划系统尚未实现；已保留最新指令，等待 T1002 统一重评估链路处理。"
		}
	}
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_plan_reevaluation_requested"):
		event_bus.npc_plan_reevaluation_requested.emit(npc_id, reason)


func _advance_proactive_talk_timers(game_delta_seconds: float) -> void:
	for npc_id in _npc_order:
		var proactive := get_proactive_talk(npc_id)
		if not bool(proactive.get("active", false)):
			continue
		var remaining := float(proactive.get("remaining_seconds", 0.0)) - game_delta_seconds
		if remaining <= 0.0:
			_clear_proactive_talk(npc_id, "expired")
			_request_plan_reevaluation(npc_id, "proactive_talk_expired")
		else:
			proactive["remaining_seconds"] = remaining
			_set_npc_state_without_signal(npc_id, {"proactive_talk": proactive})
			_refresh_npc_node(npc_id)
			_emit_npc_state_changed(npc_id)


func _clear_proactive_talk(npc_id: String, clear_reason: String) -> void:
	if not _profiles.has(npc_id):
		return
	var state := get_npc_state(npc_id)
	if not bool(state.get("proactive_talk", {}).get("active", false)):
		return
	var current_action := str(state.get("current_action", ""))
	var changes := {
		"proactive_talk": {},
		"last_action_result": "proactive_talk_%s" % clear_reason
	}
	if current_action == "proactive_talk":
		changes["current_action"] = "idle"
	_set_npc_state_without_signal(npc_id, changes)
	_refresh_npc_node(npc_id)
	_emit_npc_state_changed(npc_id)
	_emit_npc_proactive_talk_changed(npc_id, false)


func _order_failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "changed": false, "error": code, "message": message}


func _interaction_failure(code: String, message: String) -> Dictionary:
	return {"ok": false, "error": code, "message": message}


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
	if handle_npc_clicked(npc_id):
		return
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


func _emit_npc_proactive_talk_changed(npc_id: String, active: bool) -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null and event_bus.has_signal("npc_proactive_talk_changed"):
		event_bus.npc_proactive_talk_changed.emit(npc_id, active)


func _log_proactive_talk_started(npc_id: String, prompt_text: String, duration_seconds: float) -> Dictionary:
	var memory_system := get_node_or_null(MEMORY_SYSTEM_PATH)
	if memory_system == null or not memory_system.has_method("add_event"):
		return {}
	return memory_system.add_event({
		"type": "proactive_talk_started",
		"subject_npc_id": npc_id,
		"actor_ids": [npc_id],
		"target_ids": [npc_id, PLAYER_ACTOR_ID],
		"location_id": _get_current_info_location(npc_id, memory_system),
		"visibility": "private",
		"importance": 55,
		"payload": {
			"prompt_text": prompt_text,
			"duration_seconds": duration_seconds
		}
	})


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
