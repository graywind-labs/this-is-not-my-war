class_name AbilityAudioController
extends Node

const CONFIG_PATH := "res://data/presentation/ability_audio.json"
const EXPECTED_SCHEMA := "ability_audio_v1"
const AUDIO_MANAGER_PATH := NodePath("/root/AudioManager")
const PIETY_SYSTEM_PATH := NodePath("/root/Main/Systems/PietySystem")
const TIME_SYSTEM_PATH := NodePath("/root/Main/Systems/TimeSystem")

var _config: Dictionary = {}
var _meteor_config: Dictionary = {}
var _fallback_source_root: Node3D
var _fallback_sources: Dictionary = {}
var _active_players: Dictionary = {}
var _impacted_cast_ids: Dictionary = {}
var _recent_history: Array[Dictionary] = []
var _initialized := false
var _initialization_attempts := 0
var _cast_signal_connected := false
var _impact_signal_connected := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("presentation_only", true)
	set_meta("authority_role", "read_only_meteor_audio_projection")
	_config = _load_json_dictionary(CONFIG_PATH)
	_meteor_config = _as_dictionary(_config.get("meteor", {}))
	_connect_signals()
	call_deferred("_initialize_audio")


func _exit_tree() -> void:
	_disconnect_signals()
	for raw_cast_id in _fallback_sources.keys():
		var source := _fallback_sources.get(raw_cast_id) as Node3D
		if is_instance_valid(source):
			source.queue_free()
	_fallback_sources.clear()
	_active_players.clear()
	_impacted_cast_ids.clear()


func _process(_delta: float) -> void:
	if not _initialized:
		return
	_apply_gameplay_pause()
	_prune_players()


func get_debug_snapshot() -> Dictionary:
	_prune_players()
	var active := {}
	for raw_cast_id in _active_players.keys():
		var cast_id := str(raw_cast_id)
		var cast_players := _as_dictionary(_active_players.get(cast_id, {}))
		var phase_snapshot := {}
		for raw_phase in cast_players.keys():
			var phase := str(raw_phase)
			var player := cast_players.get(phase) as AudioStreamPlayer3D
			if not is_instance_valid(player):
				continue
			phase_snapshot[phase] = {
				"asset_id": str(player.get_meta("ability_audio_asset_id", "")),
				"bus": str(player.bus),
				"playing": player.playing,
				"stream_paused": player.stream_paused,
				"source_path": str(player.get_parent().get_path()) if player.get_parent() != null else "",
				"source_position": (player.get_parent() as Node3D).global_position if player.get_parent() is Node3D else Vector3.ZERO,
				"stream_length_seconds": player.stream.get_length() if player.stream != null else 0.0,
				"volume_db": player.volume_db,
				"spatial_profile": str(player.get_meta("audio_spatial_profile", "")),
				"unit_size_m": player.unit_size,
				"max_distance_m": player.max_distance,
				"attenuation_filter_db": player.attenuation_filter_db,
			}
		if not phase_snapshot.is_empty():
			active[cast_id] = phase_snapshot
	return {
		"initialized": _initialized,
		"schema_version": str(_config.get("schema_version", "")),
		"cast_signal_connected": _cast_signal_connected,
		"impact_signal_connected": _impact_signal_connected,
		"active_casts": active,
		"impacted_cast_ids": _impacted_cast_ids.keys(),
		"recent_history": _recent_history.duplicate(true),
		"authority_role": "presentation_only",
	}


func debug_handle_cast(cast_id: String, target_position: Vector3, radius := 0.0) -> void:
	_handle_meteor_cast(cast_id, target_position, radius)


func debug_handle_impact(cast_id: String, result: Dictionary) -> void:
	_handle_meteor_impact(cast_id, result)


func debug_clear_history() -> void:
	_recent_history.clear()


func _initialize_audio() -> void:
	if _initialized:
		return
	_initialization_attempts += 1
	if str(_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		push_error("AbilityAudioController invalid config schema: %s" % str(_config.get("schema_version", "")))
		return
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	var parent := get_node_or_null(str(_meteor_config.get("fallback_source_parent_path", ""))) as Node3D
	if audio_manager == null or parent == null:
		if _initialization_attempts < 8:
			call_deferred("_initialize_audio")
		else:
			push_error("AbilityAudioController could not find AudioManager or formal world")
		return
	_fallback_source_root = Node3D.new()
	_fallback_source_root.name = str(_meteor_config.get("fallback_source_root_name", "AbilityAudioSources"))
	_fallback_source_root.set_meta("presentation_only", true)
	parent.add_child(_fallback_source_root)
	_initialized = true


func _connect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	var cast_callback := Callable(self, "_on_meteor_cast_started")
	if event_bus.has_signal("meteor_cast_started") and not event_bus.meteor_cast_started.is_connected(cast_callback):
		event_bus.meteor_cast_started.connect(cast_callback)
	_cast_signal_connected = event_bus.has_signal("meteor_cast_started") and event_bus.meteor_cast_started.is_connected(cast_callback)
	var impact_callback := Callable(self, "_on_meteor_impacted")
	if event_bus.has_signal("meteor_impacted") and not event_bus.meteor_impacted.is_connected(impact_callback):
		event_bus.meteor_impacted.connect(impact_callback)
	_impact_signal_connected = event_bus.has_signal("meteor_impacted") and event_bus.meteor_impacted.is_connected(impact_callback)


func _disconnect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	var cast_callback := Callable(self, "_on_meteor_cast_started")
	if event_bus != null and event_bus.has_signal("meteor_cast_started") and event_bus.meteor_cast_started.is_connected(cast_callback):
		event_bus.meteor_cast_started.disconnect(cast_callback)
	var impact_callback := Callable(self, "_on_meteor_impacted")
	if event_bus != null and event_bus.has_signal("meteor_impacted") and event_bus.meteor_impacted.is_connected(impact_callback):
		event_bus.meteor_impacted.disconnect(impact_callback)
	_cast_signal_connected = false
	_impact_signal_connected = false


func _on_meteor_cast_started(cast_id: String, target_position: Vector3, radius: float) -> void:
	if not _initialized:
		call_deferred("_handle_meteor_cast", cast_id, target_position, radius)
		return
	_handle_meteor_cast(cast_id, target_position, radius)


func _on_meteor_impacted(cast_id: String, result: Dictionary) -> void:
	if not _initialized:
		call_deferred("_handle_meteor_impact", cast_id, result.duplicate(true))
		return
	_handle_meteor_impact(cast_id, result)


func _handle_meteor_cast(cast_id: String, target_position: Vector3, _radius: float) -> void:
	var clean_cast_id := cast_id.strip_edges()
	if clean_cast_id.is_empty() or _active_players.has(clean_cast_id):
		return
	var source := _find_meteor_visual(clean_cast_id)
	if source == null:
		source = _ensure_fallback_source(clean_cast_id, target_position)
	_play_phase(clean_cast_id, "fall", str(_meteor_config.get("fall_asset", "")), source)


func _handle_meteor_impact(cast_id: String, result: Dictionary) -> void:
	var clean_cast_id := cast_id.strip_edges()
	if clean_cast_id.is_empty() or _impacted_cast_ids.has(clean_cast_id):
		return
	_impacted_cast_ids[clean_cast_id] = true
	var target_position := _to_vector3(result.get("target_position", Vector3.ZERO))
	var source := _find_meteor_visual(clean_cast_id)
	if source == null:
		source = _ensure_fallback_source(clean_cast_id, target_position)
	else:
		target_position = source.global_position
	var fallback_source := _fallback_sources.get(clean_cast_id) as Node3D
	if is_instance_valid(fallback_source):
		fallback_source.global_position = target_position
	_play_phase(clean_cast_id, "impact", str(_meteor_config.get("impact_asset", "")), source)


func _play_phase(cast_id: String, phase: String, asset_id: String, source: Node3D) -> void:
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if source == null or audio_manager == null or asset_id.is_empty() or not audio_manager.has_asset(asset_id):
		return
	var player: AudioStreamPlayer3D = audio_manager.play_3d(
		asset_id,
		source,
		Vector3.ZERO,
		StringName(str(_meteor_config.get("bus", "Combat"))),
		StringName(str(_meteor_config.get("spatial_profile", "ability_priority")))
	)
	if player == null:
		return
	player.volume_db = float(_meteor_config.get("%s_gain_db" % phase, 0.0))
	player.set_meta("ability_audio_asset_id", asset_id)
	player.set_meta("ability_audio_cast_id", cast_id)
	player.set_meta("ability_audio_phase", phase)
	var cast_players := _as_dictionary(_active_players.get(cast_id, {}))
	cast_players[phase] = player
	_active_players[cast_id] = cast_players
	player.finished.connect(_on_player_finished.bind(cast_id, phase, player))
	_record_history({
		"cast_id": cast_id,
		"phase": phase,
		"asset_id": asset_id,
		"bus": str(player.bus),
		"source_path": str(source.get_path()),
		"source_position": source.global_position,
		"stream_length_seconds": player.stream.get_length() if player.stream != null else 0.0,
		"volume_db": player.volume_db,
		"spatial_profile": str(player.get_meta("audio_spatial_profile", "")),
		"unit_size_m": player.unit_size,
		"max_distance_m": player.max_distance,
	})


func _find_meteor_visual(cast_id: String) -> Node3D:
	if not bool(_meteor_config.get("follow_actual_meteor_visual", true)):
		return null
	var root_path := str(_meteor_config.get("visual_root_path", ""))
	var visual_root := get_node_or_null(root_path)
	if visual_root == null:
		return null
	for child in visual_root.get_children():
		if child is Node3D and str(child.get_meta("cast_id", "")) == cast_id:
			return child as Node3D
	return null


func _ensure_fallback_source(cast_id: String, position: Vector3) -> Node3D:
	var existing := _fallback_sources.get(cast_id) as Node3D
	if is_instance_valid(existing):
		existing.global_position = position
		return existing
	if not is_instance_valid(_fallback_source_root):
		return null
	var source := Node3D.new()
	source.name = "MeteorAudio_%s" % cast_id.to_pascal_case()
	source.set_meta("presentation_only", true)
	source.set_meta("cast_id", cast_id)
	_fallback_source_root.add_child(source)
	source.global_position = position
	_fallback_sources[cast_id] = source
	return source


func _apply_gameplay_pause() -> void:
	if not bool(_meteor_config.get("pause_with_gameplay", true)):
		return
	var time_system := get_node_or_null(TIME_SYSTEM_PATH)
	var paused := time_system != null and time_system.has_method("is_gameplay_paused") and bool(time_system.is_gameplay_paused())
	for raw_cast_players in _active_players.values():
		var cast_players := _as_dictionary(raw_cast_players)
		for raw_player in cast_players.values():
			# A crater/body may free its child player before this controller's next frame.
			if not is_instance_valid(raw_player):
				continue
			var player := raw_player as AudioStreamPlayer3D
			if is_instance_valid(player):
				player.stream_paused = paused


func _on_player_finished(cast_id: String, phase: String, player: AudioStreamPlayer3D) -> void:
	var cast_players := _as_dictionary(_active_players.get(cast_id, {}))
	if cast_players.get(phase) == player:
		cast_players.erase(phase)
	if cast_players.is_empty():
		_active_players.erase(cast_id)
		_cleanup_fallback_source(cast_id)
	else:
		_active_players[cast_id] = cast_players


func _prune_players() -> void:
	for raw_cast_id in _active_players.keys().duplicate():
		var cast_id := str(raw_cast_id)
		var cast_players := _as_dictionary(_active_players.get(cast_id, {}))
		for raw_phase in cast_players.keys().duplicate():
			if not is_instance_valid(cast_players.get(raw_phase)):
				cast_players.erase(raw_phase)
		if cast_players.is_empty():
			_active_players.erase(cast_id)
			_cleanup_fallback_source(cast_id)
		else:
			_active_players[cast_id] = cast_players


func _cleanup_fallback_source(cast_id: String) -> void:
	var source := _fallback_sources.get(cast_id) as Node3D
	if is_instance_valid(source):
		source.queue_free()
	_fallback_sources.erase(cast_id)


func _record_history(entry: Dictionary) -> void:
	_recent_history.append(entry.duplicate(true))
	var limit := maxi(1, int(_meteor_config.get("recent_history_limit", 32)))
	while _recent_history.size() > limit:
		_recent_history.pop_front()


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value as Vector3
	if value is Dictionary:
		var dictionary := value as Dictionary
		return Vector3(
			float(dictionary.get("x", 0.0)),
			float(dictionary.get("y", 0.0)),
			float(dictionary.get("z", 0.0))
		)
	return Vector3.ZERO


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed as Dictionary if parsed is Dictionary else {}


func _as_dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}
