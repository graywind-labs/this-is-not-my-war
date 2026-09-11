class_name MovementAudioController
extends Node

const CONFIG_PATH := "res://data/presentation/movement_audio.json"
const EXPECTED_SCHEMA := "movement_audio_v1"
const AUDIO_MANAGER_PATH := NodePath("/root/AudioManager")
const NPC_SYSTEM_PATH := NodePath("/root/Main/Systems/NPCSystem")
const HORSE_SYSTEM_PATH := NodePath("/root/Main/Systems/HorseSystem")
const COMBAT_SYSTEM_PATH := NodePath("/root/Main/Systems/CombatSystem")
const TIME_SYSTEM_PATH := NodePath("/root/Main/Systems/TimeSystem")
const FORMAL_ROOT_PATH := NodePath("/root/Main/WorldRoot/FormalStationLayout")
const CAMERA_PATH := NodePath("/root/Main/CameraRig/Camera3D")
const LOOP_KEY_PREFIX := "movement_"

var _config: Dictionary = {}
var _source_root: Node3D
var _sources: Dictionary = {}
var _active_loops: Dictionary = {}
var _initialized := false
var _initialization_attempts := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("presentation_only", true)
	set_meta("authority_role", "read_only_actual_movement_audio_projection")
	_config = _load_json_dictionary(CONFIG_PATH)
	call_deferred("_initialize_audio")


func _exit_tree() -> void:
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager != null:
		audio_manager.stop_loops_with_prefix(LOOP_KEY_PREFIX, true)
	_active_loops.clear()


func _process(_delta: float) -> void:
	if _initialized:
		_refresh_audio()


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
		"paused": _is_gameplay_paused(),
		"excluded_movement": (_config.get("excluded_movement", []) as Array).duplicate(),
		"stop_mode": str(_config.get("stop_mode", "")),
		"authority_role": "presentation_only",
	}


func debug_force_refresh() -> Dictionary:
	if not _initialized:
		_initialize_audio()
	if _initialized:
		_refresh_audio()
	return get_debug_snapshot()


func debug_is_npc_running(snapshot: Dictionary) -> bool:
	return _is_npc_actual_run(snapshot)


func debug_is_horse_running(snapshot: Dictionary) -> bool:
	return _is_horse_actual_run(snapshot)


func debug_is_enemy_running(snapshot: Dictionary) -> bool:
	return _is_enemy_actual_run(snapshot)


func _initialize_audio() -> void:
	if _initialized:
		return
	_initialization_attempts += 1
	if str(_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		push_error("MovementAudioController invalid config schema: %s" % str(_config.get("schema_version", "")))
		return
	var formal_root := get_node_or_null(FORMAL_ROOT_PATH) as Node3D
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if formal_root == null or audio_manager == null or npc_system == null or horse_system == null:
		if _initialization_attempts < 8:
			call_deferred("_initialize_audio")
		else:
			push_error("MovementAudioController could not find formal world or required systems")
		return
	_source_root = Node3D.new()
	_source_root.name = "MovementAudioSources"
	_source_root.set_meta("presentation_only", true)
	formal_root.add_child(_source_root)
	_initialized = true
	_refresh_audio()


func _refresh_audio() -> void:
	var desired := {}
	if not _is_gameplay_paused():
		_collect_npc_run_entries(desired)
		_collect_unmounted_horse_run_entries(desired)
		_collect_enemy_run_entries(desired)
	_apply_desired_loops(desired)


func _collect_npc_run_entries(desired: Dictionary) -> void:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null:
		return
	for raw_npc_id in npc_system.get_npc_ids():
		var npc_id := str(raw_npc_id)
		var snapshot: Dictionary = npc_system.get_npc_locomotion_needs_snapshot(npc_id)
		if not _is_npc_actual_run(snapshot):
			continue
		var raw_position: Variant = npc_system.get_npc_world_position(npc_id)
		if not raw_position is Vector3:
			continue
		var mounted := bool(snapshot.get("combat_mounted", false))
		var source_key := ("mounted_npc:%s" if mounted else "npc:%s") % npc_id
		desired[source_key] = {
			"source_key": source_key,
			"entity_id": npc_id,
			"entity_kind": "mounted_npc" if mounted else "npc",
			"asset_id": str(_config.get("horse_run_asset_id" if mounted else "npc_run_asset_id", "")),
			"world_position": raw_position,
			"source_height_m": float(_config.get("horse_source_height_m" if mounted else "source_height_m", 0.15)),
			"actual_speed_mps": float(snapshot.get("actual_horizontal_speed", 0.0)),
		}


func _collect_unmounted_horse_run_entries(desired: Dictionary) -> void:
	var horse_system := get_node_or_null(HORSE_SYSTEM_PATH)
	if horse_system == null:
		return
	for raw_horse_id in horse_system.get_horse_ids():
		var horse_id := str(raw_horse_id)
		var horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
		if not bool(horse.get("alive", true)) or not str(horse.get("ridden_by_npc_id", "")).is_empty():
			continue
		var motion: Dictionary = horse_system.get_horse_motion_snapshot(horse_id)
		if not _is_horse_actual_run(motion):
			continue
		var raw_position: Variant = motion.get("world_position", horse.get("world_position", null))
		if not raw_position is Vector3:
			continue
		var source_key := "horse:%s" % horse_id
		desired[source_key] = {
			"source_key": source_key,
			"entity_id": horse_id,
			"entity_kind": "horse",
			"asset_id": str(_config.get("horse_run_asset_id", "")),
			"world_position": raw_position,
			"source_height_m": float(_config.get("horse_source_height_m", 0.8)),
			"actual_speed_mps": float(motion.get("actual_speed", 0.0)),
		}


func _collect_enemy_run_entries(desired: Dictionary) -> void:
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	if combat_system == null or not combat_system.has_method("get_enemy_audio_motion_snapshots"):
		return
	var camera := get_node_or_null(CAMERA_PATH) as Camera3D
	var camera_position := camera.global_position if camera != null else Vector3.ZERO
	var candidates: Array[Dictionary] = []
	for raw_snapshot in combat_system.get_enemy_audio_motion_snapshots():
		var snapshot: Dictionary = raw_snapshot if raw_snapshot is Dictionary else {}
		if not _is_enemy_actual_run(snapshot):
			continue
		var position: Variant = snapshot.get("world_position", null)
		if not position is Vector3:
			continue
		snapshot = snapshot.duplicate(true)
		snapshot["camera_distance_squared"] = camera_position.distance_squared_to(position)
		candidates.append(snapshot)
	candidates.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		var left_distance := float(left.get("camera_distance_squared", INF))
		var right_distance := float(right.get("camera_distance_squared", INF))
		return (
			str(left.get("enemy_id", "")) < str(right.get("enemy_id", ""))
			if is_equal_approx(left_distance, right_distance)
			else left_distance < right_distance
		)
	)
	var limit := maxi(1, int(_config.get("max_enemy_run_loops", 6)))
	for index in range(mini(limit, candidates.size())):
		var snapshot: Dictionary = candidates[index]
		var enemy_id := str(snapshot.get("enemy_id", ""))
		var mounted := bool(snapshot.get("mounted", false))
		var source_key := ("mounted_enemy:%s" if mounted else "enemy:%s") % enemy_id
		desired[source_key] = {
			"source_key": source_key,
			"entity_id": enemy_id,
			"entity_kind": "mounted_enemy" if mounted else "enemy",
			"asset_id": str(_config.get("horse_run_asset_id" if mounted else "npc_run_asset_id", "")),
			"world_position": snapshot.get("world_position", Vector3.ZERO),
			"source_height_m": float(_config.get("horse_source_height_m" if mounted else "source_height_m", 0.15)),
			"actual_speed_mps": float(snapshot.get("actual_horizontal_speed", 0.0)),
		}


func _is_npc_actual_run(snapshot: Dictionary) -> bool:
	if snapshot.is_empty() or not bool(snapshot.get("movement_active", false)):
		return false
	if str(snapshot.get("locomotion_state", "walk")) != "run":
		return false
	var margin := maxf(0.0, float(_config.get("actual_run_speed_margin_mps", 0.05)))
	return float(snapshot.get("actual_horizontal_speed", 0.0)) > float(snapshot.get("walk_speed", 3.2)) + margin


func _is_horse_actual_run(snapshot: Dictionary) -> bool:
	if snapshot.is_empty() or not bool(snapshot.get("active", false)) or bool(snapshot.get("paused", false)):
		return false
	var margin := maxf(0.0, float(_config.get("actual_run_speed_margin_mps", 0.05)))
	return float(snapshot.get("actual_speed", 0.0)) > float(_config.get("horse_walk_speed_mps", 3.2)) + margin


func _is_enemy_actual_run(snapshot: Dictionary) -> bool:
	return (
		bool(snapshot.get("movement_active", false))
		and float(snapshot.get("actual_horizontal_speed", 0.0))
		> maxf(0.0, float(_config.get("enemy_actual_movement_min_speed_mps", 0.05)))
	)


func _apply_desired_loops(desired: Dictionary) -> void:
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager == null:
		return
	for raw_source_key in _active_loops.keys().duplicate():
		var source_key := str(raw_source_key)
		var current: Dictionary = _active_loops.get(source_key, {})
		var next: Dictionary = desired.get(source_key, {})
		if next.is_empty() or str(next.get("asset_id", "")) != str(current.get("asset_id", "")):
			audio_manager.stop_loop(str(current.get("loop_key", "")), true)
			_active_loops.erase(source_key)
	for raw_source_key in desired.keys():
		var source_key := str(raw_source_key)
		var entry: Dictionary = desired.get(source_key, {})
		var source := _ensure_source(source_key)
		if source == null:
			continue
		var position: Vector3 = entry.get("world_position", Vector3.ZERO)
		position.y += float(entry.get("source_height_m", 0.15))
		source.global_position = position
		if _active_loops.has(source_key):
			var active: Dictionary = _active_loops[source_key]
			active["world_position"] = position
			active["actual_speed_mps"] = float(entry.get("actual_speed_mps", 0.0))
			_active_loops[source_key] = active
			continue
		var asset_id := str(entry.get("asset_id", ""))
		if asset_id.is_empty():
			continue
		var loop_key := "%s%s" % [LOOP_KEY_PREFIX, _safe_key(source_key)]
		var player: AudioStreamPlayer3D = audio_manager.start_loop_3d(
			loop_key,
			asset_id,
			source,
			Vector3.ZERO,
			&"Combat"
		)
		if player == null:
			continue
		_active_loops[source_key] = {
			"loop_key": loop_key,
			"asset_id": asset_id,
			"entity_id": str(entry.get("entity_id", "")),
			"entity_kind": str(entry.get("entity_kind", "")),
			"world_position": position,
			"actual_speed_mps": float(entry.get("actual_speed_mps", 0.0)),
		}


func _ensure_source(source_key: String) -> Node3D:
	var existing := _sources.get(source_key) as Node3D
	if is_instance_valid(existing):
		return existing
	if _source_root == null:
		return null
	var source := Node3D.new()
	source.name = "Movement%s" % _safe_key(source_key).to_pascal_case()
	source.set_meta("source_key", source_key)
	source.set_meta("presentation_only", true)
	_source_root.add_child(source)
	_sources[source_key] = source
	return source


func _is_gameplay_paused() -> bool:
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	return time_system != null and time_system.has_method("is_gameplay_paused") and bool(time_system.is_gameplay_paused())


func _safe_key(value: String) -> String:
	var result := value.to_lower()
	for character in [" ", ":", "/", "\\", ".", "-"]:
		result = result.replace(character, "_")
	return result


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("MovementAudioController missing config: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MovementAudioController could not open config: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("MovementAudioController config must be a dictionary: %s" % path)
		return {}
	return parsed as Dictionary
