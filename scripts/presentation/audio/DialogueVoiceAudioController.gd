class_name DialogueVoiceAudioController
extends Node

const CONFIG_PATH := "res://data/presentation/dialogue_voice_audio.json"
const EXPECTED_SCHEMA := "dialogue_voice_audio_v1"
const AUDIO_MANAGER_PATH := NodePath("/root/AudioManager")
const NPC_SYSTEM_PATH := NodePath("/root/Main/Systems/NPCSystem")

var _config: Dictionary = {}
var _active_players: Dictionary = {}
var _recent_history: Array[Dictionary] = []
var _skipped_events: Array[Dictionary] = []
var _rng := RandomNumberGenerator.new()
var _initialized := false
var _initialization_attempts := 0
var _signal_connected := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("presentation_only", true)
	set_meta("authority_role", "read_only_dialogue_emotion_voice_projection")
	_config = _load_json_dictionary(CONFIG_PATH)
	_rng.randomize()
	_connect_signal()
	call_deferred("_initialize_audio")


func _exit_tree() -> void:
	_disconnect_signal()
	for raw_npc_id in _active_players.keys().duplicate():
		_stop_active_voice(str(raw_npc_id))


func _process(_delta: float) -> void:
	if not _initialized:
		return
	_prune_active_players()


func get_debug_snapshot() -> Dictionary:
	_prune_active_players()
	var active := {}
	for raw_npc_id in _active_players.keys():
		var npc_id := str(raw_npc_id)
		var raw_player: Variant = _active_players.get(npc_id)
		if not is_instance_valid(raw_player):
			continue
		var player := raw_player as AudioStreamPlayer
		active[npc_id] = {
			"player_path": str(player.get_path()),
			"asset_id": str(player.get_meta("dialogue_voice_asset_id", "")),
			"bus": str(player.bus),
			"playing": player.playing,
		}
	return {
		"initialized": _initialized,
		"schema_version": str(_config.get("schema_version", "")),
		"signal_connected": _signal_connected,
		"playback_mode": str(_config.get("playback_mode", "global_2d")),
		"source_count": 0,
		"sources": {},
		"active_voice_count": active.size(),
		"active_voices": active,
		"recent_history": _recent_history.duplicate(true),
		"skipped_events": _skipped_events.duplicate(true),
		"replace_active_voice_per_npc": bool(_config.get("replace_active_voice_per_npc", true)),
		"authority_role": "presentation_only",
	}


func debug_handle_dialogue_emotion(npc_id: String, presentation: Dictionary) -> Dictionary:
	if not _initialized:
		_initialize_audio()
	_handle_dialogue_emotion(npc_id, presentation.duplicate(true))
	return get_debug_snapshot()


func debug_set_rng_seed(value: int) -> void:
	_rng.seed = value


func debug_reset_history() -> void:
	_recent_history.clear()
	_skipped_events.clear()


func _initialize_audio() -> void:
	if _initialized:
		return
	_initialization_attempts += 1
	if str(_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		push_error("DialogueVoiceAudioController invalid config schema: %s" % str(_config.get("schema_version", "")))
		return
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if audio_manager == null or npc_system == null:
		if _initialization_attempts < 8:
			call_deferred("_initialize_audio")
		else:
			push_error("DialogueVoiceAudioController could not find AudioManager or NPCSystem")
		return
	_initialized = true


func _connect_signal() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null or not event_bus.has_signal("npc_dialogue_emotion_presented"):
		return
	var callback := Callable(self, "_on_dialogue_emotion_presented")
	if not event_bus.npc_dialogue_emotion_presented.is_connected(callback):
		event_bus.npc_dialogue_emotion_presented.connect(callback)
	_signal_connected = event_bus.npc_dialogue_emotion_presented.is_connected(callback)


func _disconnect_signal() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	var callback := Callable(self, "_on_dialogue_emotion_presented")
	if (
		event_bus != null
		and event_bus.has_signal("npc_dialogue_emotion_presented")
		and event_bus.npc_dialogue_emotion_presented.is_connected(callback)
	):
		event_bus.npc_dialogue_emotion_presented.disconnect(callback)
	_signal_connected = false


func _on_dialogue_emotion_presented(npc_id: String, presentation: Dictionary) -> void:
	if not _initialized:
		call_deferred("_handle_dialogue_emotion", npc_id, presentation.duplicate(true))
		return
	_handle_dialogue_emotion(npc_id, presentation)


func _handle_dialogue_emotion(npc_id: String, presentation: Dictionary) -> void:
	if not _initialized:
		return
	var clean_npc_id := npc_id.strip_edges()
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if clean_npc_id.is_empty() or npc_system == null:
		_record_skip(clean_npc_id, presentation, "npc_unavailable")
		return
	if not npc_system.get_npc_ids().has(clean_npc_id):
		_record_skip(clean_npc_id, presentation, "unknown_npc")
		return
	var profile: Dictionary = npc_system.get_npc(clean_npc_id)
	if profile.is_empty():
		_record_skip(clean_npc_id, presentation, "unknown_npc")
		return
	var emotion_id := DialogueEmotionCatalog.normalize(str(presentation.get(
		"emotion_id",
		presentation.get("emotion", "none")
	)))
	var gender := _normalize_gender(str(profile.get("gender", _config.get("default_gender", "male"))))
	var asset_id := _pick_voice_asset(gender, emotion_id)
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if asset_id.is_empty() or audio_manager == null or not audio_manager.has_asset(asset_id):
		_record_skip(clean_npc_id, {"emotion_id": emotion_id, "gender": gender}, "asset_unavailable")
		return
	if bool(_config.get("replace_active_voice_per_npc", true)):
		_stop_active_voice(clean_npc_id)
	var player: AudioStreamPlayer = audio_manager.play_2d(asset_id, &"Voice")
	if player == null:
		_record_skip(clean_npc_id, {"emotion_id": emotion_id, "gender": gender}, "playback_failed")
		return
	player.set_meta("dialogue_voice_asset_id", asset_id)
	_active_players[clean_npc_id] = player
	player.finished.connect(_on_voice_finished.bind(clean_npc_id, player), CONNECT_ONE_SHOT)
	_recent_history.append({
		"npc_id": clean_npc_id,
		"gender": gender,
		"emotion_id": emotion_id,
		"asset_id": asset_id,
		"player_type": player.get_class(),
		"bus": str(player.bus),
		"spatial_mode": "global_2d",
	})
	_trim_records(_recent_history)


func _pick_voice_asset(gender: String, emotion_id: String) -> String:
	var voices: Dictionary = _config.get("voices", {})
	var gender_mapping: Dictionary = voices.get(gender, {}) if voices.get(gender, {}) is Dictionary else {}
	var raw_variants: Variant = gender_mapping.get(emotion_id, [])
	var variants: Array = raw_variants if raw_variants is Array else [raw_variants]
	var valid: Array[String] = []
	for raw_asset_id in variants:
		var asset_id := str(raw_asset_id).strip_edges()
		if not asset_id.is_empty():
			valid.append(asset_id)
	if valid.is_empty():
		return ""
	return valid[_rng.randi_range(0, valid.size() - 1)]


func _normalize_gender(raw_gender: String) -> String:
	return "female" if raw_gender.strip_edges().to_lower() == "female" else "male"


func _stop_active_voice(npc_id: String) -> void:
	var raw_player: Variant = _active_players.get(npc_id)
	_active_players.erase(npc_id)
	if is_instance_valid(raw_player):
		var player := raw_player as AudioStreamPlayer
		player.stop()
		player.queue_free()


func _on_voice_finished(npc_id: String, player: AudioStreamPlayer) -> void:
	if _active_players.get(npc_id) == player:
		_active_players.erase(npc_id)


func _prune_active_players() -> void:
	for raw_npc_id in _active_players.keys().duplicate():
		if not is_instance_valid(_active_players.get(raw_npc_id)):
			_active_players.erase(raw_npc_id)


func _record_skip(npc_id: String, presentation: Dictionary, reason: String) -> void:
	_skipped_events.append({
		"npc_id": npc_id,
		"emotion_id": str(presentation.get("emotion_id", presentation.get("emotion", "none"))),
		"gender": str(presentation.get("gender", "")),
		"reason": reason,
	})
	_trim_records(_skipped_events)


func _trim_records(records: Array[Dictionary]) -> void:
	var limit := maxi(8, int(_config.get("recent_history_limit", 64)))
	while records.size() > limit:
		records.pop_front()


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("DialogueVoiceAudioController missing config: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DialogueVoiceAudioController could not open config: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("DialogueVoiceAudioController config must be a dictionary: %s" % path)
		return {}
	return parsed as Dictionary
