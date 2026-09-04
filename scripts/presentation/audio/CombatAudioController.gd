class_name CombatAudioController
extends Node

const CONFIG_PATH := "res://data/presentation/combat_audio.json"
const EXPECTED_SCHEMA := "combat_audio_v1"
const AUDIO_MANAGER_PATH := NodePath("/root/AudioManager")
const NPC_SYSTEM_PATH := NodePath("/root/Main/Systems/NPCSystem")
const COMBAT_SYSTEM_PATH := NodePath("/root/Main/Systems/CombatSystem")
const BUILDING_SYSTEM_PATH := NodePath("/root/Main/Systems/BuildingSystem")
const DEFENSE_DEVICE_SYSTEM_PATH := NodePath("/root/Main/Systems/DefenseDeviceSystem")
const FORMAL_ROOT_PATH := NodePath("/root/Main/WorldRoot/FormalStationLayout")

var _config: Dictionary = {}
var _source_root: Node3D
var _initialized := false
var _initialization_attempts := 0
var _rng := RandomNumberGenerator.new()
var _recent_history: Array[Dictionary] = []
var _skipped_events: Array[Dictionary] = []
var _budget_frame := -1
var _frame_total := 0
var _frame_group_counts: Dictionary = {}
var _connected_signals: Array[String] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("presentation_only", true)
	set_meta("authority_role", "read_only_combat_audio_projection")
	_config = _load_json_dictionary(CONFIG_PATH)
	_rng.randomize()
	_connect_signals()
	call_deferred("_initialize_audio")


func _exit_tree() -> void:
	_disconnect_signals()


func get_debug_snapshot() -> Dictionary:
	return {
		"initialized": _initialized,
		"schema_version": str(_config.get("schema_version", "")),
		"recent_history": _recent_history.duplicate(true),
		"recent_play_count": _recent_history.size(),
		"skipped_events": _skipped_events.duplicate(true),
		"frame_total": _frame_total,
		"frame_group_counts": _frame_group_counts.duplicate(true),
		"silent_rules": (_config.get("silent_rules", []) as Array).duplicate(),
		"connected_signals": _connected_signals.duplicate(),
		"authority_role": "presentation_only",
	}


func debug_handle_audio_event(event: Dictionary) -> Dictionary:
	if not _initialized:
		_initialize_audio()
	_handle_combat_audio_event(event.duplicate(true))
	return get_debug_snapshot()


func debug_set_rng_seed(value: int) -> void:
	_rng.seed = value


func debug_reset_history() -> void:
	_recent_history.clear()
	_skipped_events.clear()
	_budget_frame = -1
	_frame_total = 0
	_frame_group_counts.clear()


func _initialize_audio() -> void:
	if _initialized:
		return
	_initialization_attempts += 1
	if str(_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		push_error("CombatAudioController invalid config schema: %s" % str(_config.get("schema_version", "")))
		return
	var formal_root := get_node_or_null(FORMAL_ROOT_PATH) as Node3D
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if formal_root == null or audio_manager == null:
		if _initialization_attempts < 8:
			call_deferred("_initialize_audio")
		else:
			push_error("CombatAudioController could not find formal world or AudioManager")
		return
	_source_root = Node3D.new()
	_source_root.name = "CombatAudioSources"
	_source_root.set_meta("presentation_only", true)
	formal_root.add_child(_source_root)
	_initialized = true


func _connect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	var audio_callback := Callable(self, "_on_combat_audio_event")
	if event_bus.has_signal("combat_audio_event") and not event_bus.combat_audio_event.is_connected(audio_callback):
		event_bus.combat_audio_event.connect(audio_callback)
	if event_bus.has_signal("combat_audio_event") and event_bus.combat_audio_event.is_connected(audio_callback):
		_connected_signals.append("combat_audio_event")
	var game_over_callback := Callable(self, "_on_game_over_changed")
	if event_bus.has_signal("game_over_changed") and not event_bus.game_over_changed.is_connected(game_over_callback):
		event_bus.game_over_changed.connect(game_over_callback)
	if event_bus.has_signal("game_over_changed") and event_bus.game_over_changed.is_connected(game_over_callback):
		_connected_signals.append("game_over_changed")


func _disconnect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	var audio_callback := Callable(self, "_on_combat_audio_event")
	if event_bus.has_signal("combat_audio_event") and event_bus.combat_audio_event.is_connected(audio_callback):
		event_bus.combat_audio_event.disconnect(audio_callback)
	var game_over_callback := Callable(self, "_on_game_over_changed")
	if event_bus.has_signal("game_over_changed") and event_bus.game_over_changed.is_connected(game_over_callback):
		event_bus.game_over_changed.disconnect(game_over_callback)
	_connected_signals.clear()


func _on_combat_audio_event(event: Dictionary) -> void:
	if not _initialized:
		call_deferred("_handle_combat_audio_event", event.duplicate(true))
		return
	_handle_combat_audio_event(event)


func _handle_combat_audio_event(event: Dictionary) -> void:
	if not _initialized:
		return
	var event_type := str(event.get("event_type", ""))
	match event_type:
		"attack_swing":
			_play_melee_swing(event)
		"projectile_released":
			_play_projectile_release(event)
		"projectile_hit":
			_play_projectile_impact(event)
		"actor_damaged":
			_play_actor_damage(event)
		"horse_died":
			_play_asset(str(_config.get("horse_death_asset", "")), event, "impact")
		"structure_damaged":
			_play_structure_damage(event)
		"battle_started", "wave_cleared":
			var stingers: Dictionary = _config.get("stingers", {})
			_play_asset(str(stingers.get(event_type, "")), event, "stinger")


func _on_game_over_changed(result: String, _reason: String) -> void:
	if not _initialized:
		call_deferred("_on_game_over_changed", result, _reason)
		return
	if result != "victory" and result != "failure":
		return
	var stingers: Dictionary = _config.get("stingers", {})
	var asset_id := str(stingers.get("victory" if result == "victory" else "failure", ""))
	var position := _get_building_position("main_hall")
	_play_asset(asset_id, {
		"event_type": "game_over_%s" % result,
		"target_type": "building",
		"target_id": "main_hall",
		"world_position": position,
	}, "stinger")


func _play_melee_swing(event: Dictionary) -> void:
	var mapping: Dictionary = _config.get("melee_swing_assets", {})
	_play_asset(str(mapping.get(str(event.get("weapon_type", "")), "")), event, "weapon")


func _play_projectile_release(event: Dictionary) -> void:
	var device_id := str(event.get("device_id", ""))
	var release_asset_id := ""
	if not device_id.is_empty():
		var device_mapping: Dictionary = _config.get("device_release_assets", {})
		release_asset_id = str(device_mapping.get(device_id, ""))
	else:
		var weapon_mapping: Dictionary = _config.get("projectile_release_assets", {})
		release_asset_id = str(weapon_mapping.get(str(event.get("weapon_type", "")), ""))
	_play_asset(release_asset_id, event, "weapon")
	var whoosh_asset_id := str(
		_config.get("ballista_whoosh_asset", "")
		if device_id == "wall_ballista"
		else _config.get("projectile_whoosh_asset", "")
	)
	_play_asset(whoosh_asset_id, event, "weapon", true)


func _play_projectile_impact(event: Dictionary) -> void:
	var asset_id := str(
		_config.get("ballista_impact_asset", "")
		if str(event.get("device_id", "")) == "wall_ballista"
		else _config.get("projectile_impact_asset", "")
	)
	_play_asset(asset_id, event, "impact")


func _play_actor_damage(event: Dictionary) -> void:
	var variants: Array = _config.get("actor_hit_assets", [])
	var hit_asset := _pick_variant(variants)
	_play_asset(hit_asset, event, "impact")
	var target_type := str(event.get("target_type", ""))
	if _rng.randf() <= clampf(float(_config.get("hurt_voice_probability", 0.5)), 0.0, 1.0):
		var voice_asset := ""
		if target_type == "enemy":
			voice_asset = str(_config.get("enemy_hurt_voice_asset", ""))
		elif target_type == "npc":
			var voice_mapping: Dictionary = _config.get("friendly_hurt_voice_assets", {})
			voice_asset = str(voice_mapping.get(_get_npc_gender(str(event.get("target_id", ""))), ""))
		_play_asset(voice_asset, event, "voice")
	if target_type == "npc" and bool(event.get("became_unconscious", false)):
		_play_asset(str(_config.get("unconscious_fall_asset", "")), event, "impact")


func _play_structure_damage(event: Dictionary) -> void:
	var structure: Dictionary = _config.get("structure", {})
	var material := _resolve_structure_material(event)
	var damage_asset := ""
	if material == "stone":
		damage_asset = str(structure.get("stone_damage_asset", ""))
	else:
		damage_asset = _pick_variant(structure.get("wood_damage_assets", []) as Array)
	_play_asset(damage_asset, event, "structure")
	if bool(event.get("destroyed", false)):
		var collapse_asset := str(
			structure.get("stone_collapse_asset", "")
			if material == "stone"
			else structure.get("wood_collapse_asset", "")
		)
		_play_asset(collapse_asset, event, "structure")


func _resolve_structure_material(event: Dictionary) -> String:
	if str(event.get("target_type", "")) == "defense_device":
		return "wood"
	var structure: Dictionary = _config.get("structure", {})
	var stone_ids: Array = structure.get("stone_building_ids", [])
	return "stone" if stone_ids.has(str(event.get("target_id", ""))) else "wood"


func _play_asset(
	asset_id: String,
	event: Dictionary,
	group: String,
	prefer_existing_source := false
) -> AudioStreamPlayer3D:
	if asset_id.is_empty() or not _consume_frame_budget(group, event, asset_id):
		return null
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager == null or not audio_manager.has_asset(asset_id):
		_record_skip(event, asset_id, group, "asset_unavailable")
		return null
	var source: Node3D = null
	var temporary_source := false
	if prefer_existing_source:
		var source_path := NodePath(str(event.get("source_node_path", "")))
		if not source_path.is_empty():
			source = get_node_or_null(source_path) as Node3D
	if source == null:
		source = _make_temporary_source(_resolve_event_position(event), event)
		temporary_source = true
	if source == null:
		_record_skip(event, asset_id, group, "source_unavailable")
		return null
	var player: AudioStreamPlayer3D = audio_manager.play_3d(asset_id, source, Vector3.ZERO, &"Combat")
	if player == null:
		if temporary_source and is_instance_valid(source):
			source.queue_free()
		_record_skip(event, asset_id, group, "playback_failed")
		return null
	if temporary_source:
		player.finished.connect(_free_temporary_source.bind(source), CONNECT_ONE_SHOT)
	_record_play(event, asset_id, group, player, source)
	return player


func _consume_frame_budget(group: String, event: Dictionary, asset_id: String) -> bool:
	var frame := Engine.get_physics_frames()
	if frame != _budget_frame:
		_budget_frame = frame
		_frame_total = 0
		_frame_group_counts.clear()
	var limits: Dictionary = _config.get("frame_limits", {})
	var total_limit := maxi(1, int(limits.get("total", 14)))
	var group_limit := maxi(1, int(limits.get(group, total_limit)))
	if _frame_total >= total_limit or int(_frame_group_counts.get(group, 0)) >= group_limit:
		_record_skip(event, asset_id, group, "frame_budget")
		return false
	_frame_total += 1
	_frame_group_counts[group] = int(_frame_group_counts.get(group, 0)) + 1
	return true


func _make_temporary_source(position: Vector3, event: Dictionary) -> Node3D:
	if _source_root == null:
		return null
	var source := Node3D.new()
	source.name = "Combat%s" % _safe_key(str(event.get("event_type", "sound"))).to_pascal_case()
	source.set_meta("presentation_only", true)
	source.set_meta("combat_audio_event_type", str(event.get("event_type", "")))
	_source_root.add_child(source)
	source.global_position = position
	return source


func _free_temporary_source(source: Node3D) -> void:
	if is_instance_valid(source):
		source.queue_free()


func _resolve_event_position(event: Dictionary) -> Vector3:
	var raw_position: Variant = event.get("world_position", null)
	if raw_position is Vector3:
		return raw_position
	if raw_position is Dictionary:
		return _dict_to_vector3(raw_position)
	var target_type := str(event.get("target_type", ""))
	var target_id := str(event.get("target_id", ""))
	if target_type == "npc":
		var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
		var position: Variant = npc_system.get_npc_world_position(target_id) if npc_system != null else null
		if position is Vector3:
			return position
	elif target_type == "enemy":
		var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
		var position: Variant = combat_system.get_enemy_world_position(target_id) if combat_system != null else null
		if position is Vector3:
			return position
	elif target_type == "building":
		return _get_building_position(target_id)
	elif target_type == "defense_device":
		var device_system := get_node_or_null(DEFENSE_DEVICE_SYSTEM_PATH)
		var deployment: Dictionary = device_system.get_deployment(target_id) if device_system != null else {}
		return _dict_to_vector3(deployment.get("position", {}))
	return Vector3.ZERO


func _get_building_position(building_id: String) -> Vector3:
	var building_system := get_node_or_null(BUILDING_SYSTEM_PATH)
	if building_system != null and building_system.has_method("get_building_entry_position"):
		var position: Variant = building_system.get_building_entry_position(building_id)
		if position is Vector3:
			return position
	return Vector3.ZERO


func _get_npc_gender(npc_id: String) -> String:
	var npc_system := get_node_or_null(NPC_SYSTEM_PATH)
	if npc_system == null or not npc_system.has_method("get_npc"):
		return "male"
	return str((npc_system.get_npc(npc_id) as Dictionary).get("gender", "male"))


func _pick_variant(values: Array) -> String:
	if values.is_empty():
		return ""
	return str(values[_rng.randi_range(0, values.size() - 1)])


func _record_play(event: Dictionary, asset_id: String, group: String, player: Node, source: Node3D) -> void:
	_recent_history.append({
		"event_type": str(event.get("event_type", "")),
		"asset_id": asset_id,
		"group": group,
		"target_type": str(event.get("target_type", "")),
		"target_id": str(event.get("target_id", "")),
		"player_type": player.get_class(),
		"bus": str(player.get("bus")),
		"source_path": str(source.get_path()),
		"world_position": source.global_position,
	})
	_trim_debug_records(_recent_history)


func _record_skip(event: Dictionary, asset_id: String, group: String, reason: String) -> void:
	_skipped_events.append({
		"event_type": str(event.get("event_type", "")),
		"asset_id": asset_id,
		"group": group,
		"reason": reason,
	})
	_trim_debug_records(_skipped_events)


func _trim_debug_records(records: Array[Dictionary]) -> void:
	var limit := maxi(8, int(_config.get("recent_history_limit", 96)))
	while records.size() > limit:
		records.pop_front()


func _dict_to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if not value is Dictionary:
		return Vector3.ZERO
	return Vector3(
		float((value as Dictionary).get("x", 0.0)),
		float((value as Dictionary).get("y", 0.0)),
		float((value as Dictionary).get("z", 0.0))
	)


func _safe_key(value: String) -> String:
	var result := value.to_lower()
	for character in [" ", ":", "/", "\\", ".", "-"]:
		result = result.replace(character, "_")
	return result


func _load_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("CombatAudioController missing config: %s" % path)
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("CombatAudioController could not open config: %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("CombatAudioController config must be a dictionary: %s" % path)
		return {}
	return parsed as Dictionary
