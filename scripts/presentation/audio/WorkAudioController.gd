class_name WorkAudioController
extends Node

const CONFIG_PATH := "res://data/presentation/action_audio.json"
const EXPECTED_SCHEMA := "action_audio_v1"
const AUDIO_MANAGER_PATH := NodePath("/root/AudioManager")
const NPC_SYSTEM_PATH := NodePath("/root/Main/Systems/NPCSystem")
const ACTION_SYSTEM_PATH := NodePath("/root/Main/Systems/ActionSystem")
const HORSE_SYSTEM_PATH := NodePath("/root/Main/Systems/HorseSystem")
const BUILDING_SYSTEM_PATH := NodePath("/root/Main/Systems/BuildingSystem")
const CRAFTING_SYSTEM_PATH := NodePath("/root/Main/Systems/CraftingSystem")
const FORMAL_ROOT_PATH := NodePath("/root/Main/WorldRoot/FormalStationLayout")
const LOOP_KEY_PREFIX := "work_action_"
const RELEVANT_NPC_STATE_FIELDS: Array[String] = [
	"current_action", "current_location", "unconscious", "escaped",
]

var _config: Dictionary = {}
var _source_root: Node3D
var _sources: Dictionary = {}
var _active_loops: Dictionary = {}
var _active_edge_tokens: Dictionary = {}
var _building_job_states: Dictionary = {}
var _crafting_targets: Dictionary = {}
var _recent_one_shots: Array[Dictionary] = []
var _elapsed_realtime := 0.0
var _mass_active := false
var _mass_chant_ready := false
var _mass_chant_due_seconds := -1.0
var _initialized := false
var _initialization_attempts := 0
var _refresh_queued := false
var _connected_signals: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("presentation_only", true)
	set_meta("authority_role", "read_only_action_audio_projection")
	_config = _load_json_dictionary(CONFIG_PATH)
	_connect_signals()
	call_deferred("_initialize_audio")


func _exit_tree() -> void:
	_disconnect_signals()
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager != null:
		audio_manager.stop_loops_with_prefix(LOOP_KEY_PREFIX, true)
	_active_loops.clear()
	_active_edge_tokens.clear()
	_building_job_states.clear()
	_crafting_targets.clear()
	_recent_one_shots.clear()


func _process(delta: float) -> void:
	if not _initialized:
		return
	_elapsed_realtime += maxf(0.0, delta)
	if (
		_mass_active
		and not _mass_chant_ready
		and _mass_chant_due_seconds >= 0.0
		and _elapsed_realtime >= _mass_chant_due_seconds
	):
		_mass_chant_ready = true
		_mass_chant_due_seconds = -1.0
		_queue_refresh()


func get_debug_snapshot() -> Dictionary:
	var loops := {}
	for raw_key in _active_loops.keys():
		loops[str(raw_key)] = (_active_loops.get(raw_key, {}) as Dictionary).duplicate(true)
	var sources := {}
	for raw_key in _sources.keys():
		var source_key := str(raw_key)
		var source := _sources.get(source_key) as Node3D
		if is_instance_valid(source):
			sources[source_key] = {
				"path": str(source.get_path()),
				"global_position": source.global_position,
			}
	return {
		"initialized": _initialized,
		"schema_version": str(_config.get("schema_version", "")),
		"active_loop_count": loops.size(),
		"active_loops": loops,
		"source_count": sources.size(),
		"sources": sources,
		"active_edge_tokens": _active_edge_tokens.keys(),
		"building_job_states": _building_job_states.duplicate(true),
		"crafting_targets": _crafting_targets.duplicate(true),
		"recent_one_shots": _recent_one_shots.duplicate(true),
		"mass_active": _mass_active,
		"mass_chant_ready": _mass_chant_ready,
		"mass_chant_due_seconds": _mass_chant_due_seconds,
		"connected_signals": _connected_signals.duplicate(),
		"authority_role": "presentation_only",
	}


func debug_force_refresh() -> Dictionary:
	if not _initialized:
		_initialize_audio()
	if _initialized:
		_refresh_audio()
	return get_debug_snapshot()


func debug_advance_audio_seconds(seconds: float) -> Dictionary:
	if seconds > 0.0:
		_elapsed_realtime += seconds
		if (
			_mass_active
			and not _mass_chant_ready
			and _mass_chant_due_seconds >= 0.0
			and _elapsed_realtime >= _mass_chant_due_seconds
		):
			_mass_chant_ready = true
			_mass_chant_due_seconds = -1.0
			_refresh_audio()
	return get_debug_snapshot()


func debug_clear_recent_one_shots() -> void:
	_recent_one_shots.clear()


func _initialize_audio() -> void:
	if _initialized:
		return
	_initialization_attempts += 1
	if str(_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		push_error("WorkAudioController invalid config schema: %s" % str(_config.get("schema_version", "")))
		return
	var formal_root := get_node_or_null(FORMAL_ROOT_PATH) as Node3D
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if formal_root == null or audio_manager == null or npc_system == null or action_system == null:
		if _initialization_attempts < 8:
			call_deferred("_initialize_audio")
		else:
			push_error("WorkAudioController could not find formal world or required systems")
		return
	_source_root = Node3D.new()
	_source_root.name = "WorkAudioSources"
	_source_root.set_meta("presentation_only", true)
	formal_root.add_child(_source_root)
	_prime_authority_audio_states()
	_initialized = true
	_refresh_audio()


func _connect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	for signal_name in ["npc_state_changed", "horse_state_changed"]:
		var callback := Callable(self, "_on_authority_state_changed")
		if event_bus.has_signal(signal_name) and not event_bus.is_connected(signal_name, callback):
			event_bus.connect(signal_name, callback)
		if event_bus.has_signal(signal_name) and event_bus.is_connected(signal_name, callback):
			_connected_signals.append(signal_name)
	var building_callback := Callable(self, "_on_building_state_changed")
	if event_bus.has_signal("building_state_changed") and not event_bus.building_state_changed.is_connected(building_callback):
		event_bus.building_state_changed.connect(building_callback)
	if event_bus.has_signal("building_state_changed") and event_bus.building_state_changed.is_connected(building_callback):
		_connected_signals.append("building_state_changed")
	var crafting_callback := Callable(self, "_on_crafting_state_changed")
	if event_bus.has_signal("crafting_state_changed") and not event_bus.crafting_state_changed.is_connected(crafting_callback):
		event_bus.crafting_state_changed.connect(crafting_callback)
	if event_bus.has_signal("crafting_state_changed") and event_bus.crafting_state_changed.is_connected(crafting_callback):
		_connected_signals.append("crafting_state_changed")


func _disconnect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	for signal_name in _connected_signals:
		var callback := Callable(self, "_on_authority_state_changed")
		if signal_name == "building_state_changed":
			callback = Callable(self, "_on_building_state_changed")
		elif signal_name == "crafting_state_changed":
			callback = Callable(self, "_on_crafting_state_changed")
		if event_bus.has_signal(signal_name) and event_bus.is_connected(signal_name, callback):
			event_bus.disconnect(signal_name, callback)
	_connected_signals.clear()


func _on_authority_state_changed(arg1: Variant = null, _arg2: Variant = null) -> void:
	if arg1 is String:
		var npc_id := str(arg1)
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		if (
			npc_system != null
			and npc_system.has_method("is_active_npc_state_change_relevant")
			and not npc_system.is_active_npc_state_change_relevant(npc_id, RELEVANT_NPC_STATE_FIELDS)
		):
			return
	_queue_refresh()


func _on_building_state_changed(building_id: String) -> void:
	if _initialized:
		_process_building_job_edge(building_id)
	_queue_refresh()


func _on_crafting_state_changed(building_id: String) -> void:
	if _initialized:
		_process_crafting_target_edge(building_id)


func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	call_deferred("_flush_queued_refresh")


func _flush_queued_refresh() -> void:
	_refresh_queued = false
	if _initialized:
		_refresh_audio()


func _refresh_audio() -> void:
	var entries := _collect_active_entries()
	var desired := {}
	_add_configured_loop_rules(entries, desired)
	_add_building_construction_loops(desired)
	_add_clinic_loops(entries, desired)
	_update_chapel_state(entries, desired)
	_update_one_shot_edges(entries)
	_reconcile_loops(desired)


func _prime_authority_audio_states() -> void:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and building_system.has_method("get_building_ids"):
		for raw_building_id in building_system.get_building_ids():
			var building_id := str(raw_building_id)
			_building_job_states[building_id] = _get_building_job_type(building_id)
	var crafting_config := _config.get("crafting_target_selection", {}) as Dictionary
	for crafting_building_id in _get_crafting_audio_building_ids(crafting_config):
		_crafting_targets[crafting_building_id] = _get_crafting_target(crafting_building_id)


func _add_building_construction_loops(desired: Dictionary) -> void:
	var building_jobs := _config.get("building_jobs", {}) as Dictionary
	var asset_id := str(building_jobs.get("loop_asset_id", ""))
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if asset_id.is_empty() or building_system == null or not building_system.has_method("get_building_ids"):
		return
	for raw_building_id in building_system.get_building_ids():
		var building_id := str(raw_building_id)
		var job_type := _get_building_job_type(building_id)
		if job_type.is_empty():
			continue
		_add_desired_loop(desired, "construction_%s" % building_id, asset_id, {
			"building_id": building_id,
			"target_id": building_id,
			"action_id": "building_%s" % job_type,
			"has_world_position": false,
		}, float(building_jobs.get("loop_gain_db", 0.0)))


func _process_building_job_edge(building_id: String) -> void:
	var current_job := _get_building_job_type(building_id)
	if not _building_job_states.has(building_id):
		_building_job_states[building_id] = current_job
		return
	var previous_job := str(_building_job_states.get(building_id, ""))
	_building_job_states[building_id] = current_job
	if previous_job == current_job or current_job.is_empty():
		return
	var building_jobs := _config.get("building_jobs", {}) as Dictionary
	_play_building_one_shot(
		str(building_jobs.get("start_asset_id", "")),
		building_id,
		"building_job_started",
		current_job,
		float(building_jobs.get("start_gain_db", 0.0))
	)


func _process_crafting_target_edge(building_id: String) -> void:
	var crafting_config := _config.get("crafting_target_selection", {}) as Dictionary
	if building_id not in _get_crafting_audio_building_ids(crafting_config):
		return
	var current_target := _get_crafting_target(building_id)
	if not _crafting_targets.has(building_id):
		_crafting_targets[building_id] = current_target
		return
	var previous_target := str(_crafting_targets.get(building_id, ""))
	_crafting_targets[building_id] = current_target
	if current_target == previous_target or current_target.is_empty():
		return
	_play_building_one_shot(
		str(crafting_config.get("asset_id", "")),
		building_id,
		"crafting_target_selected",
		current_target,
		float(crafting_config.get("gain_db", 0.0))
	)


func _get_building_job_type(building_id: String) -> String:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system == null or not building_system.has_method("get_building"):
		return ""
	var building: Dictionary = building_system.get_building(building_id)
	if not (building.get("upgrade_status", {}) as Dictionary).is_empty():
		return "upgrade"
	if not (building.get("repair_status", {}) as Dictionary).is_empty():
		return "repair"
	return ""


func _get_crafting_target(building_id: String) -> String:
	var crafting_system := get_node_or_null(CRAFTING_SYSTEM_PATH)
	if crafting_system == null or not crafting_system.has_method("get_project_snapshot"):
		return ""
	return str(crafting_system.get_project_snapshot(building_id).get("target_recipe_id", ""))


func _get_crafting_audio_building_ids(config: Dictionary) -> Array[String]:
	var result: Array[String] = []
	for raw_building_id in config.get("building_ids", []):
		var building_id := str(raw_building_id).strip_edges()
		if not building_id.is_empty() and building_id not in result:
			result.append(building_id)
	if result.is_empty():
		var legacy_building_id := str(config.get("building_id", "blacksmith")).strip_edges()
		if not legacy_building_id.is_empty():
			result.append(legacy_building_id)
	return result


func _play_building_one_shot(asset_id: String, building_id: String, kind: String, detail: String, gain_db := 0.0) -> void:
	if asset_id.is_empty():
		return
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager == null:
		return
	var player: AudioStreamPlayer = audio_manager.play_2d(asset_id, &"UI", gain_db)
	if player == null:
		return
	_recent_one_shots.append({
		"kind": kind,
		"asset_id": asset_id,
		"building_id": building_id,
		"detail": detail,
		"player_type": "AudioStreamPlayer",
		"bus": "UI",
		"spatial_profile": "global_2d",
		"gain_db": gain_db,
	})
	while _recent_one_shots.size() > 48:
		_recent_one_shots.pop_front()


func _collect_active_entries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var action_system := get_node_or_null(ACTION_SYSTEM_PATH)
	if npc_system == null or action_system == null:
		return result
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var snapshot: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
		var phase := str(snapshot.get("phase", ""))
		if phase != "active" and phase != "external_active":
			continue
		var position_variant: Variant = npc_system.get_npc_world_position(npc_id)
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		result.append({
			"npc_id": npc_id,
			"action_id": str(snapshot.get("action_id", "")),
			"phase": phase,
			"target_id": str(snapshot.get("target_id", "")),
			"building_id": str(snapshot.get("building_id", state.get("current_location", ""))),
			"prayer_mode": str(snapshot.get("prayer_mode", "")),
			"state": state,
			"world_position": position_variant if position_variant is Vector3 else Vector3.ZERO,
			"has_world_position": position_variant is Vector3,
		})
	return result


func _add_configured_loop_rules(entries: Array[Dictionary], desired: Dictionary) -> void:
	for raw_rule in _config.get("loop_rules", []):
		if not raw_rule is Dictionary:
			continue
		var rule := raw_rule as Dictionary
		var matches: Array[Dictionary] = []
		var action_ids: Array = rule.get("action_ids", [])
		for entry in entries:
			if action_ids.has(str(entry.get("action_id", ""))):
				matches.append(entry)
		if matches.is_empty():
			continue
		if bool(rule.get("group_by_target", false)):
			var by_target := {}
			for entry in matches:
				var target_id := str(entry.get("target_id", "unknown"))
				if target_id.is_empty():
					target_id = "unknown"
				if not by_target.has(target_id):
					by_target[target_id] = entry
			for raw_target_id in by_target.keys():
				var target_id := str(raw_target_id)
				_add_desired_loop(
					desired,
					"%s_%s" % [str(rule.get("id", "action")), target_id],
					_resolve_rule_asset(rule),
					by_target[target_id] as Dictionary
				)
		else:
			_add_desired_loop(
				desired,
				str(rule.get("id", "action")),
				_resolve_rule_asset(rule),
				matches[0]
			)


func _resolve_rule_asset(rule: Dictionary) -> String:
	if rule.has("asset_id_with_horse"):
		var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
		var has_stabled_horse := false
		if horse_system != null and horse_system.has_method("get_stable_horse_summary"):
			has_stabled_horse = int(horse_system.get_stable_horse_summary().get("total", 0)) > 0
		return str(
			rule.get("asset_id_with_horse", "")
			if has_stabled_horse
			else rule.get("asset_id_without_horse", "")
		)
	return str(rule.get("asset_id", ""))


func _add_clinic_loops(entries: Array[Dictionary], desired: Dictionary) -> void:
	var clinic: Dictionary = _config.get("clinic", {})
	var doctor_action_id := str(clinic.get("doctor_action_id", ""))
	var patient_action_id := str(clinic.get("patient_action_id", ""))
	var assist_action_id := str(clinic.get("assist_action_id", ""))
	var doctors: Array[Dictionary] = []
	var patients: Array[Dictionary] = []
	var assists_by_target := {}
	for entry in entries:
		var action_id := str(entry.get("action_id", ""))
		if action_id == doctor_action_id:
			doctors.append(entry)
		elif action_id == patient_action_id:
			patients.append(entry)
		elif action_id == assist_action_id:
			var target_id := str(entry.get("target_id", "unknown"))
			if not assists_by_target.has(target_id):
				assists_by_target[target_id] = entry
	var doctor_treating := false
	for doctor in doctors:
		var state: Dictionary = doctor.get("state", {})
		if str(state.get("presentation_clinic_duty_mode", "study")) == "treatment":
			doctor_treating = true
			break
	if not patients.is_empty() or doctor_treating:
		var source_entry: Dictionary = doctors[0] if not doctors.is_empty() else patients[0]
		_add_desired_loop(desired, "clinic_treatment", str(clinic.get("treatment_asset_id", "")), source_entry)
	elif not doctors.is_empty():
		_add_desired_loop(desired, "clinic_reading", str(clinic.get("reading_asset_id", "")), doctors[0])
	for raw_target_id in assists_by_target.keys():
		var target_id := str(raw_target_id)
		_add_desired_loop(
			desired,
			"healing_assist_%s" % target_id,
			str(clinic.get("treatment_asset_id", "")),
			assists_by_target[target_id] as Dictionary
		)


func _update_chapel_state(entries: Array[Dictionary], desired: Dictionary) -> void:
	var chapel: Dictionary = _config.get("chapel", {})
	var prayer_action_id := str(chapel.get("prayer_action_id", ""))
	var mass_action_id := str(chapel.get("mass_action_id", ""))
	var prayers: Array[Dictionary] = []
	var mass_participants: Array[Dictionary] = []
	var mass_leaders: Array[Dictionary] = []
	for entry in entries:
		var action_id := str(entry.get("action_id", ""))
		if action_id == mass_action_id:
			mass_leaders.append(entry)
			mass_participants.append(entry)
		elif action_id == prayer_action_id:
			if str(entry.get("prayer_mode", "")) == "mass":
				mass_participants.append(entry)
			else:
				prayers.append(entry)
	var next_mass_active := not mass_leaders.is_empty()
	if next_mass_active and not _mass_active:
		var leader := mass_leaders[0]
		_play_entry_one_shot(str(chapel.get("mass_start_asset_id", "")), leader, "chapel_mass_start")
		_mass_chant_ready = false
		_mass_chant_due_seconds = _elapsed_realtime + maxf(
			0.0,
			float(chapel.get("mass_start_duration_seconds", 5.0))
		)
	elif not next_mass_active and _mass_active:
		_mass_chant_ready = false
		_mass_chant_due_seconds = -1.0
	_mass_active = next_mass_active
	if _mass_active:
		if _mass_chant_ready:
			var mass_source: Dictionary = mass_leaders[0] if not mass_leaders.is_empty() else mass_participants[0]
			_add_desired_loop(desired, "chapel_mass", str(chapel.get("mass_loop_asset_id", "")), mass_source)
	elif not prayers.is_empty():
		_add_desired_loop(desired, "chapel_prayer", str(chapel.get("prayer_asset_id", "")), prayers[0])


func _update_one_shot_edges(entries: Array[Dictionary]) -> void:
	var next_tokens := {}
	for raw_rule in _config.get("one_shots", []):
		if not raw_rule is Dictionary:
			continue
		var rule := raw_rule as Dictionary
		var action_id := str(rule.get("action_id", ""))
		for entry in entries:
			if str(entry.get("action_id", "")) != action_id:
				continue
			var token := "%s_%s" % [str(rule.get("id", "action")), str(entry.get("npc_id", ""))]
			next_tokens[token] = true
			if not _active_edge_tokens.has(token):
				_play_entry_one_shot(str(rule.get("asset_id", "")), entry, token)
	_active_edge_tokens = next_tokens


func _add_desired_loop(desired: Dictionary, semantic_key: String, asset_id: String, entry: Dictionary, gain_db := 0.0) -> void:
	if semantic_key.is_empty() or asset_id.is_empty():
		return
	desired[semantic_key] = {
		"asset_id": asset_id,
		"world_position": _resolve_entry_position(entry),
		"npc_id": str(entry.get("npc_id", "")),
		"action_id": str(entry.get("action_id", "")),
		"target_id": str(entry.get("target_id", "")),
		"gain_db": gain_db,
	}


func _reconcile_loops(desired: Dictionary) -> void:
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager == null:
		return
	for raw_semantic_key in desired.keys():
		var semantic_key := str(raw_semantic_key)
		var request := desired.get(semantic_key, {}) as Dictionary
		var source := _ensure_source(semantic_key)
		if source == null:
			continue
		source.global_position = request.get("world_position", Vector3.ZERO)
		var asset_id := str(request.get("asset_id", ""))
		var gain_db := float(request.get("gain_db", 0.0))
		var existing := _active_loops.get(semantic_key, {}) as Dictionary
		if str(existing.get("asset_id", "")) == asset_id and is_equal_approx(float(existing.get("gain_db", 0.0)), gain_db) and audio_manager.is_loop_active(str(existing.get("loop_key", ""))):
			existing["world_position"] = source.global_position
			_active_loops[semantic_key] = existing
			continue
		if not existing.is_empty():
			audio_manager.stop_loop(str(existing.get("loop_key", "")), false)
		var loop_key := "%s%s_%s" % [LOOP_KEY_PREFIX, _safe_key(semantic_key), asset_id]
		var player: AudioStreamPlayer3D = audio_manager.start_loop_3d(
			loop_key,
			asset_id,
			source,
			Vector3.ZERO,
			&"Work",
			_start_offset_for(semantic_key, asset_id),
			&"local",
			gain_db
		)
		if player != null:
			_active_loops[semantic_key] = {
				"loop_key": loop_key,
				"asset_id": asset_id,
				"source_path": str(source.get_path()),
				"world_position": source.global_position,
				"npc_id": str(request.get("npc_id", "")),
				"action_id": str(request.get("action_id", "")),
				"target_id": str(request.get("target_id", "")),
				"gain_db": gain_db,
			}
	for raw_semantic_key in _active_loops.keys().duplicate():
		var semantic_key := str(raw_semantic_key)
		if desired.has(semantic_key):
			continue
		var existing := _active_loops.get(semantic_key, {}) as Dictionary
		audio_manager.stop_loop(str(existing.get("loop_key", "")), false)
		_active_loops.erase(semantic_key)


func _play_entry_one_shot(asset_id: String, entry: Dictionary, source_key: String, gain_db := 0.0) -> AudioStreamPlayer3D:
	if asset_id.is_empty():
		return null
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	var source := _ensure_source(source_key)
	if audio_manager == null or source == null:
		return null
	source.global_position = _resolve_entry_position(entry)
	return audio_manager.play_3d(asset_id, source, Vector3.ZERO, &"Work", &"local", gain_db)


func _ensure_source(source_key: String) -> Node3D:
	var existing := _sources.get(source_key) as Node3D
	if is_instance_valid(existing):
		return existing
	if _source_root == null:
		return null
	var source := Node3D.new()
	source.name = "Action%s" % _safe_key(source_key).to_pascal_case()
	source.set_meta("source_key", source_key)
	source.set_meta("presentation_only", true)
	_source_root.add_child(source)
	_sources[source_key] = source
	return source


func _resolve_entry_position(entry: Dictionary) -> Vector3:
	var position := entry.get("world_position", Vector3.ZERO) as Vector3
	if not bool(entry.get("has_world_position", false)):
		var building_id := str(entry.get("building_id", ""))
		if building_id.is_empty():
			building_id = str(entry.get("target_id", ""))
		var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
		if building_system != null and building_system.has_method("get_building_entry_position"):
			var fallback: Variant = building_system.get_building_entry_position(building_id)
			if fallback is Vector3:
				position = fallback
	position.y += float(_config.get("source_height_m", 1.15))
	return position


func _start_offset_for(semantic_key: String, asset_id: String) -> float:
	var info := {}
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager != null and audio_manager.has_method("get_asset_info"):
		info = audio_manager.get_asset_info(asset_id)
	var duration := maxf(0.0, float(info.get("duration_seconds", 0.0)))
	if duration <= 1.0:
		return 0.0
	return fmod(float(abs(semantic_key.hash())), maxf(1.0, duration - 0.25))


func _safe_key(value: String) -> String:
	var result := value.to_lower()
	for character in [" ", ":", "/", "\\", ".", "-"]:
		result = result.replace(character, "_")
	return result


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("WorkAudioController missing config: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WorkAudioController could not open config: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("WorkAudioController config must be a dictionary: %s" % path)
		return {}
	return parsed as Dictionary
