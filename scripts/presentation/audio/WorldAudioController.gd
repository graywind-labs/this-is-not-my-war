class_name WorldAudioController
extends Node

const CONFIG_PATH := "res://data/presentation/world_audio.json"
const FORMAL_ROOT_PATH := NodePath("/root/Main/WorldRoot/FormalStationLayout")
const COMBAT_SYSTEM_PATH := NodePath("/root/Main/Systems/CombatSystem")
const AUDIO_MANAGER_PATH := NodePath("/root/AudioManager")
const CAMERA_RIG_PATH := NodePath("/root/Main/CameraRig")
const FIRE_ASSET_ID := "sfx_ambience_active_fire_loop"
const LOOP_KEY_PREFIX := "world_ambience_"
const FIRE_LOOP_KEY_PREFIX := "world_ambience_fire_"
const EXPECTED_SCHEMA := "world_audio_v1"
const GLOBAL_BED_BUS := &"AmbientBed"
const FIRE_RELEVANT_NPC_STATE_FIELDS: Array[String] = [
	"current_action", "current_location", "unconscious", "escaped",
]

var _config: Dictionary = {}
var _source_root: Node3D
var _sources: Dictionary = {}
var _owned_loop_keys: Dictionary = {}
var _fire_loop_keys: Dictionary = {}
var _random_states: Dictionary = {}
var _night_stagger_due: Dictionary = {}
var _daily_trigger_counts: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _elapsed_realtime := 0.0
var _period := "day"
var _current_day := 1
var _dawn_active := false
var _combat_active := false
var _initialized := false
var _initialization_attempts := 0
var _fire_refresh_queued := false
var _time_signal_connected := false
var _combat_signal_connected := false
var _npc_signal_connected := false
var _building_signal_connected := false
var _music_signal_connected := false
var _global_bed_gain_linear := 1.0
var _last_global_bed_gain_linear := -1.0
var _next_playlist_indices := {"day": 0, "night": 0}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_meta("presentation_only", true)
	set_meta("authority_role", "read_only_audio_projection")
	_rng.randomize()
	_config = _load_json_dictionary(CONFIG_PATH)
	_connect_signals()
	call_deferred("_initialize_audio")


func _exit_tree() -> void:
	_disconnect_signals()
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager != null:
		audio_manager.stop_loops_with_prefix(LOOP_KEY_PREFIX, true)
		audio_manager.stop_music(0.0)
	_set_global_bed_bus_gain(1.0, true)
	_owned_loop_keys.clear()
	_fire_loop_keys.clear()


func _process(delta: float) -> void:
	if not _initialized:
		return
	_elapsed_realtime += maxf(0.0, delta)
	_refresh_global_bed_zoom_gain()
	_service_night_staggered_loops()
	_service_random_groups()


func get_debug_snapshot() -> Dictionary:
	var source_snapshots: Dictionary = {}
	for raw_id in _sources.keys():
		var source_id := str(raw_id)
		var source := _sources.get(source_id) as Node3D
		if is_instance_valid(source):
			source_snapshots[source_id] = {
				"path": str(source.get_path()),
				"position": source.position,
				"asset_id": str(source.get_meta("asset_id", "")),
				"source_kind": str(source.get_meta("source_kind", "")),
			}
	var random_snapshots: Dictionary = {}
	for raw_group_id in _random_states.keys():
		var group_id := str(raw_group_id)
		var state := _random_states.get(group_id, {}) as Dictionary
		random_snapshots[group_id] = state.duplicate(true)
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	return {
		"initialized": _initialized,
		"schema_version": str(_config.get("schema_version", "")),
		"period": _period,
		"combat_active": _combat_active,
		"current_music_asset_id": (
			audio_manager.get_current_music_asset_id()
			if audio_manager != null and audio_manager.has_method("get_current_music_asset_id")
			else ""
		),
		"source_count": source_snapshots.size(),
		"sources": source_snapshots,
		"owned_loop_keys": _owned_loop_keys.keys(),
		"global_bed_gain_linear": _global_bed_gain_linear,
		"global_bed_bus": str(GLOBAL_BED_BUS),
		"fire_loop_keys": _fire_loop_keys.keys(),
		"night_stagger_due": _night_stagger_due.duplicate(true),
		"daily_trigger_counts": _daily_trigger_counts.duplicate(true),
		"current_day": _current_day,
		"dawn_active": _dawn_active,
		"random_groups": random_snapshots,
		"time_signal_connected": _time_signal_connected,
		"combat_signal_connected": _combat_signal_connected,
		"npc_signal_connected": _npc_signal_connected,
		"building_signal_connected": _building_signal_connected,
		"music_signal_connected": _music_signal_connected,
		"day_playlist": _music_playlist_for_period("day"),
		"night_playlist": _music_playlist_for_period("night"),
		"next_playlist_indices": _next_playlist_indices.duplicate(true),
		"menu_music_integration": str(
			(_config.get("music", {}) as Dictionary).get(
				"menu_integration",
				"deferred_until_start_menu_exists"
			)
		),
		"authority_role": "presentation_only",
	}


func debug_advance_ambient_seconds(seconds: float) -> Dictionary:
	if seconds > 0.0:
		_elapsed_realtime += seconds
		_service_night_staggered_loops()
		_service_random_groups()
	return get_debug_snapshot()


func debug_force_refresh() -> Dictionary:
	_sync_authority_state()
	_refresh_period_audio(true)
	_refresh_global_bed_zoom_gain(true)
	_refresh_music()
	_refresh_fire_audio()
	return get_debug_snapshot()


func _initialize_audio() -> void:
	if _initialized:
		return
	_initialization_attempts += 1
	if str(_config.get("schema_version", "")) != EXPECTED_SCHEMA:
		push_error("WorldAudioController invalid config schema: %s" % str(_config.get("schema_version", "")))
		return
	var formal_root := get_node_or_null(FORMAL_ROOT_PATH) as Node3D
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if formal_root == null or audio_manager == null:
		if _initialization_attempts < 8:
			call_deferred("_initialize_audio")
		else:
			push_error("WorldAudioController could not find formal world or AudioManager")
		return
	_connect_music_signal(audio_manager)
	_source_root = Node3D.new()
	_source_root.name = "WorldAudioSources"
	_source_root.set_meta("presentation_only", true)
	formal_root.add_child(_source_root)
	_build_sources()
	_sync_authority_state()
	_initialized = true
	_refresh_period_audio(true)
	_refresh_music()
	_queue_fire_refresh()


func _build_sources() -> void:
	for raw_loop in _config.get("loop_emitters", []):
		if raw_loop is Dictionary:
			var loop_config := raw_loop as Dictionary
			if str(loop_config.get("scope", "positional")) != "global_zoom":
				_create_source(loop_config, "loop")
	for raw_group in _config.get("random_groups", []):
		if not raw_group is Dictionary:
			continue
		var group := raw_group as Dictionary
		for raw_emitter in group.get("emitters", []):
			if raw_emitter is Dictionary:
				_create_source(raw_emitter as Dictionary, "random_%s" % str(group.get("id", "")))


func _create_source(config: Dictionary, source_kind: String) -> void:
	if _source_root == null:
		return
	var source_id := str(config.get("id", "")).strip_edges()
	if source_id.is_empty() or _sources.has(source_id):
		return
	var source := Node3D.new()
	source.name = source_id.to_pascal_case()
	source.position = _vector3(config.get("position", []))
	source.set_meta("source_id", source_id)
	source.set_meta("asset_id", str(config.get("asset_id", "")))
	source.set_meta("source_kind", source_kind)
	source.set_meta("presentation_only", true)
	_source_root.add_child(source)
	_sources[source_id] = source


func _connect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus == null:
		return
	var time_callback := Callable(self, "_on_time_changed")
	if event_bus.has_signal("time_changed") and not event_bus.time_changed.is_connected(time_callback):
		event_bus.time_changed.connect(time_callback)
	_time_signal_connected = event_bus.has_signal("time_changed") and event_bus.time_changed.is_connected(time_callback)
	var combat_callback := Callable(self, "_on_combat_enemy_presence_changed")
	if event_bus.has_signal("combat_enemy_presence_changed") and not event_bus.combat_enemy_presence_changed.is_connected(combat_callback):
		event_bus.combat_enemy_presence_changed.connect(combat_callback)
	_combat_signal_connected = event_bus.has_signal("combat_enemy_presence_changed") and event_bus.combat_enemy_presence_changed.is_connected(combat_callback)
	var npc_callback := Callable(self, "_on_npc_state_changed")
	if event_bus.has_signal("npc_state_changed") and not event_bus.npc_state_changed.is_connected(npc_callback):
		event_bus.npc_state_changed.connect(npc_callback)
	_npc_signal_connected = event_bus.has_signal("npc_state_changed") and event_bus.npc_state_changed.is_connected(npc_callback)
	var building_callback := Callable(self, "_on_building_state_changed")
	if event_bus.has_signal("building_state_changed") and not event_bus.building_state_changed.is_connected(building_callback):
		event_bus.building_state_changed.connect(building_callback)
	_building_signal_connected = event_bus.has_signal("building_state_changed") and event_bus.building_state_changed.is_connected(building_callback)


func _disconnect_signals() -> void:
	var event_bus := get_node_or_null("/root/EventBus")
	if event_bus != null:
		for pair in [
			["time_changed", "_on_time_changed"],
			["combat_enemy_presence_changed", "_on_combat_enemy_presence_changed"],
			["npc_state_changed", "_on_npc_state_changed"],
			["building_state_changed", "_on_building_state_changed"],
		]:
			var signal_name := str(pair[0])
			var callback := Callable(self, str(pair[1]))
			if event_bus.has_signal(signal_name) and event_bus.is_connected(signal_name, callback):
				event_bus.disconnect(signal_name, callback)
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	var music_callback := Callable(self, "_on_music_finished")
	if audio_manager != null and audio_manager.has_signal("music_finished") and audio_manager.music_finished.is_connected(music_callback):
		audio_manager.music_finished.disconnect(music_callback)
	_music_signal_connected = false


func _connect_music_signal(audio_manager: Node) -> void:
	var callback := Callable(self, "_on_music_finished")
	if audio_manager.has_signal("music_finished") and not audio_manager.music_finished.is_connected(callback):
		audio_manager.music_finished.connect(callback)
	_music_signal_connected = audio_manager.has_signal("music_finished") and audio_manager.music_finished.is_connected(callback)


func _sync_authority_state() -> void:
	var game_state := get_node_or_null("/root/GameState")
	if game_state != null:
		_current_day = int(game_state.current_day)
		_period = _resolve_period(
			int(game_state.current_hour),
			int(game_state.current_minute)
		)
		_dawn_active = _time_is_dawn(int(game_state.current_hour), int(game_state.current_minute))
	var combat_system := get_node_or_null(COMBAT_SYSTEM_PATH)
	_combat_active = (
		combat_system != null
		and combat_system.has_method("get_active_enemy_count")
		and int(combat_system.get_active_enemy_count()) > 0
	)


func _on_time_changed(day: int, hour: int, minute: int, _second: int) -> void:
	var next_period := _resolve_period(hour, minute)
	var next_dawn_active := _time_is_dawn(hour, minute)
	var day_changed := day != _current_day
	var period_changed := next_period != _period
	var dawn_changed := next_dawn_active != _dawn_active
	_current_day = day
	_period = next_period
	_dawn_active = next_dawn_active
	if day_changed:
		_daily_trigger_counts.clear()
	if period_changed:
		_refresh_period_audio(false)
		_refresh_music()
	if day_changed or period_changed or dawn_changed:
		_reset_random_schedules()


func _on_combat_enemy_presence_changed(active: bool, _enemy_count: int, _reason: String) -> void:
	if _combat_active == active:
		return
	_combat_active = active
	_refresh_music()


func _on_npc_state_changed(npc_id: String) -> void:
	var npc_system := get_node_or_null("/root/Main/Systems/NPCSystem")
	if (
		npc_system != null
		and npc_system.has_method("is_active_npc_state_change_relevant")
		and not npc_system.is_active_npc_state_change_relevant(npc_id, FIRE_RELEVANT_NPC_STATE_FIELDS)
	):
		return
	_queue_fire_refresh()


func _on_building_state_changed(_building_id: String) -> void:
	_queue_fire_refresh()


func _refresh_music() -> void:
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager == null:
		return
	var music := _config.get("music", {}) as Dictionary
	var fade_seconds := maxf(0.0, float(music.get("crossfade_seconds", 2.0)))
	if _combat_active:
		audio_manager.switch_music(str(music.get("battle_asset_id", "music_battle")), fade_seconds, true)
		return
	var playlist := _music_playlist_for_period(_period)
	var current_asset_id := str(audio_manager.get_current_music_asset_id())
	if current_asset_id in playlist:
		return
	_play_next_playlist_track(audio_manager, fade_seconds)


func _on_music_finished(asset_id: String) -> void:
	if not _initialized or _combat_active:
		return
	if asset_id not in _music_playlist_for_period(_period):
		return
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager != null:
		_play_next_playlist_track(audio_manager, maxf(0.0, float((_config.get("music", {}) as Dictionary).get("track_start_fade_seconds", 0.0))))


func _play_next_playlist_track(audio_manager: Node, transition_fade_seconds: float) -> void:
	var playlist := _music_playlist_for_period(_period)
	if playlist.is_empty():
		return
	var index := posmod(int(_next_playlist_indices.get(_period, 0)), playlist.size())
	var asset_id := str(playlist[index])
	_next_playlist_indices[_period] = (index + 1) % playlist.size()
	audio_manager.switch_music(asset_id, transition_fade_seconds, false)


func _music_playlist_for_period(period: String) -> Array:
	var music := _config.get("music", {}) as Dictionary
	var key := "%s_playlist" % period
	var configured := music.get(key, []) as Array
	var playlist: Array = []
	for raw_asset_id in configured:
		var asset_id := str(raw_asset_id).strip_edges()
		if not asset_id.is_empty():
			playlist.append(asset_id)
	if playlist.is_empty():
		playlist.append(str(music.get("gameplay_asset_id", "music_day_night")))
	return playlist


func _refresh_period_audio(reset_random_schedules: bool) -> void:
	if not _initialized:
		return
	for raw_loop in _config.get("loop_emitters", []):
		if not raw_loop is Dictionary:
			continue
		var loop_config := raw_loop as Dictionary
		var mode := str(loop_config.get("mode", "always"))
		var enabled := mode == "always" or mode == _period
		if mode == "night_staggered":
			enabled = _period == "night"
			if enabled:
				var source_id := str(loop_config.get("id", ""))
				var loop_key := LOOP_KEY_PREFIX + source_id
				if not _owned_loop_keys.has(loop_key):
					_night_stagger_due[source_id] = _elapsed_realtime + maxf(0.0, float(loop_config.get("stagger_seconds", 0.0)))
			else:
				_stop_config_loop(loop_config)
				_night_stagger_due.erase(str(loop_config.get("id", "")))
			continue
		if enabled:
			_start_config_loop(loop_config)
		else:
			_stop_config_loop(loop_config)
	if reset_random_schedules:
		_reset_random_schedules()


func _start_config_loop(loop_config: Dictionary) -> void:
	var source_id := str(loop_config.get("id", ""))
	var loop_key := LOOP_KEY_PREFIX + source_id
	if _owned_loop_keys.has(loop_key):
		return
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager == null:
		return
	if str(loop_config.get("scope", "positional")) == "global_zoom":
		var global_player: AudioStreamPlayer = audio_manager.start_loop_2d(
			loop_key,
			str(loop_config.get("asset_id", "")),
			GLOBAL_BED_BUS,
			maxf(0.0, float(loop_config.get("start_offset_seconds", 0.0)))
		)
		if global_player != null:
			_owned_loop_keys[loop_key] = "global_zoom"
		return
	var source := _sources.get(source_id) as Node3D
	if source == null:
		return
	var player: AudioStreamPlayer3D = audio_manager.start_loop_3d(
		loop_key,
		str(loop_config.get("asset_id", "")),
		source,
		Vector3.ZERO,
		&"Ambience",
		maxf(0.0, float(loop_config.get("start_offset_seconds", 0.0)))
	)
	if player != null:
		_owned_loop_keys[loop_key] = source_id


func _refresh_global_bed_zoom_gain(force := false) -> void:
	var camera_rig := get_node_or_null(CAMERA_RIG_PATH)
	if camera_rig == null:
		return
	var mix := _config.get("global_bed_zoom_mix", {}) as Dictionary
	var near_distance := float(mix.get("near_distance", camera_rig.get("min_zoom_distance")))
	var far_distance := maxf(near_distance + 0.001, float(mix.get("far_distance", camera_rig.get("max_zoom_distance"))))
	var zoom_distance := (
		float(camera_rig.call("get_zoom_distance"))
		if camera_rig.has_method("get_zoom_distance")
		else far_distance
	)
	var near_gain := clampf(float(mix.get("near_gain_linear", 1.0)), 0.0001, 1.0)
	var far_gain := clampf(float(mix.get("far_gain_linear", 0.3)), 0.0001, near_gain)
	var near_weight := 1.0 - inverse_lerp(near_distance, far_distance, clampf(zoom_distance, near_distance, far_distance))
	var response_curve := maxf(0.01, float(mix.get("response_curve", 1.0)))
	_global_bed_gain_linear = lerpf(far_gain, near_gain, pow(near_weight, response_curve))
	if force or not is_equal_approx(_global_bed_gain_linear, _last_global_bed_gain_linear):
		_set_global_bed_bus_gain(_global_bed_gain_linear)


func _set_global_bed_bus_gain(linear: float, force := false) -> void:
	var bus_index := AudioServer.get_bus_index(GLOBAL_BED_BUS)
	if bus_index < 0:
		return
	var checked := clampf(linear, 0.0001, 1.0)
	if not force and is_equal_approx(checked, _last_global_bed_gain_linear):
		return
	AudioServer.set_bus_mute(bus_index, false)
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(checked))
	_last_global_bed_gain_linear = checked


func _stop_config_loop(loop_config: Dictionary) -> void:
	var loop_key := LOOP_KEY_PREFIX + str(loop_config.get("id", ""))
	if not _owned_loop_keys.has(loop_key):
		return
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager != null:
		audio_manager.stop_loop(loop_key)
	_owned_loop_keys.erase(loop_key)


func _service_night_staggered_loops() -> void:
	if _period != "night" or _night_stagger_due.is_empty():
		return
	for raw_source_id in _night_stagger_due.keys().duplicate():
		var source_id := str(raw_source_id)
		if _elapsed_realtime + 0.0001 < float(_night_stagger_due.get(source_id, INF)):
			continue
		for raw_loop in _config.get("loop_emitters", []):
			if raw_loop is Dictionary and str((raw_loop as Dictionary).get("id", "")) == source_id:
				_start_config_loop(raw_loop as Dictionary)
				break
		_night_stagger_due.erase(source_id)


func _reset_random_schedules() -> void:
	_random_states.clear()
	for raw_group in _config.get("random_groups", []):
		if not raw_group is Dictionary:
			continue
		var group := raw_group as Dictionary
		if not _random_group_enabled(group):
			continue
		var group_id := str(group.get("id", ""))
		var max_triggers_per_day := maxi(0, int(group.get("max_triggers_per_day", 0)))
		var daily_count := _daily_trigger_count(group_id)
		_random_states[group_id] = {
			"next_due_seconds": (
				INF
				if max_triggers_per_day > 0 and daily_count >= max_triggers_per_day
				else _elapsed_realtime + _random_range(group.get("initial_delay_range_seconds", [10.0, 30.0]))
			),
			"last_emitter_index": -1,
			"trigger_count": 0,
			"daily_trigger_count": daily_count,
			"last_asset_id": "",
			"last_source_id": "",
			"last_gain_db": 0.0,
		}


func _service_random_groups() -> void:
	for raw_group in _config.get("random_groups", []):
		if not raw_group is Dictionary:
			continue
		var group := raw_group as Dictionary
		if not _random_group_enabled(group):
			continue
		var group_id := str(group.get("id", ""))
		var state := _random_states.get(group_id, {}) as Dictionary
		if state.is_empty() or _elapsed_realtime + 0.0001 < float(state.get("next_due_seconds", INF)):
			continue
		_trigger_random_group(group, state)
		_random_states[group_id] = state


func _trigger_random_group(group: Dictionary, state: Dictionary) -> void:
	var emitters := group.get("emitters", []) as Array
	if emitters.is_empty():
		return
	var group_id := str(group.get("id", ""))
	var max_triggers_per_day := maxi(0, int(group.get("max_triggers_per_day", 0)))
	var daily_count := _daily_trigger_count(group_id)
	if max_triggers_per_day > 0 and daily_count >= max_triggers_per_day:
		state["daily_trigger_count"] = daily_count
		state["next_due_seconds"] = INF
		return
	var previous_index := int(state.get("last_emitter_index", -1))
	var selected_index := _rng.randi_range(0, emitters.size() - 1)
	if emitters.size() > 1 and selected_index == previous_index:
		selected_index = (selected_index + 1 + _rng.randi_range(0, emitters.size() - 2)) % emitters.size()
	var emitter := emitters[selected_index] as Dictionary
	var source_id := str(emitter.get("id", ""))
	var asset_id := str(emitter.get("asset_id", ""))
	var source := _sources.get(source_id) as Node3D
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	var played := false
	if source != null and audio_manager != null:
		var player: AudioStreamPlayer3D = audio_manager.play_3d(asset_id, source, Vector3.ZERO, &"Ambience")
		if player != null:
			player.volume_db = float(group.get("gain_db", 0.0)) + float(emitter.get("gain_db", 0.0))
			played = true
	if not played:
		state["next_due_seconds"] = _elapsed_realtime + 5.0
		return
	state["last_emitter_index"] = selected_index
	state["trigger_count"] = int(state.get("trigger_count", 0)) + 1
	state["last_asset_id"] = asset_id
	state["last_source_id"] = source_id
	state["last_gain_db"] = float(group.get("gain_db", 0.0)) + float(emitter.get("gain_db", 0.0))
	var duration := 0.0
	if audio_manager != null and audio_manager.has_method("get_asset_info"):
		duration = float((audio_manager.get_asset_info(asset_id) as Dictionary).get("duration_seconds", 0.0))
	daily_count += 1
	_daily_trigger_counts[group_id] = {"day": _current_day, "count": daily_count}
	state["daily_trigger_count"] = daily_count
	state["next_due_seconds"] = (
		INF
		if max_triggers_per_day > 0 and daily_count >= max_triggers_per_day
		else _elapsed_realtime + duration + _random_range(group.get("gap_range_seconds", [30.0, 60.0]))
	)


func _daily_trigger_count(group_id: String) -> int:
	var entry := _daily_trigger_counts.get(group_id, {}) as Dictionary
	if int(entry.get("day", -1)) != _current_day:
		return 0
	return maxi(0, int(entry.get("count", 0)))


func _queue_fire_refresh() -> void:
	if _fire_refresh_queued:
		return
	_fire_refresh_queued = true
	call_deferred("_refresh_fire_audio")


func _refresh_fire_audio() -> void:
	_fire_refresh_queued = false
	if not _initialized:
		return
	var audio_manager := get_node_or_null(AUDIO_MANAGER_PATH)
	if audio_manager == null:
		return
	var desired_keys: Dictionary = {}
	for raw_controller in get_tree().get_nodes_in_group("environment_fire_audio_source"):
		var controller := raw_controller as Node
		if controller == null or not controller.has_method("get_active_fire_audio_sources"):
			continue
		for raw_source in controller.get_active_fire_audio_sources():
			var source := raw_source as Node3D
			if source == null or not source.is_visible_in_tree():
				continue
			var loop_key := FIRE_LOOP_KEY_PREFIX + str(source.get_instance_id())
			desired_keys[loop_key] = source
			if not _fire_loop_keys.has(loop_key):
				var asset_info := audio_manager.get_asset_info(FIRE_ASSET_ID) as Dictionary
				var duration := maxf(1.0, float(asset_info.get("duration_seconds", 60.0)))
				var start_offset := fposmod(float(hash(str(source.get_path()))), duration)
				if audio_manager.start_loop_3d(
					loop_key,
					FIRE_ASSET_ID,
					source,
					Vector3.ZERO,
					&"Ambience",
					start_offset
				) != null:
					_fire_loop_keys[loop_key] = str(source.get_path())
	for raw_key in _fire_loop_keys.keys().duplicate():
		var loop_key := str(raw_key)
		if desired_keys.has(loop_key):
			continue
		audio_manager.stop_loop(loop_key)
		_fire_loop_keys.erase(loop_key)


func _random_group_enabled(group: Dictionary) -> bool:
	match str(group.get("period", "day")):
		"night":
			return _period == "night"
		"dawn":
			return _dawn_active
		_:
			return _period == "day"


func _resolve_period(hour: int, minute: int) -> String:
	return "night" if _time_in_wrapped_range(
		hour,
		minute,
		_config.get("night_start_time", [18, 0]) as Array,
		_config.get("night_end_time", [6, 0]) as Array
	) else "day"


func _is_dawn_time() -> bool:
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		return false
	return _time_is_dawn(int(game_state.current_hour), int(game_state.current_minute))


func _time_is_dawn(hour: int, minute: int) -> bool:
	return _time_in_wrapped_range(
		hour,
		minute,
		_config.get("dawn_start_time", [5, 0]) as Array,
		_config.get("dawn_end_time", [8, 0]) as Array
	)


func _time_in_wrapped_range(hour: int, minute: int, start: Array, finish: Array) -> bool:
	var current_seconds := clampi(hour, 0, 23) * 3600 + clampi(minute, 0, 59) * 60
	var start_seconds := _time_array_seconds(start)
	var finish_seconds := _time_array_seconds(finish)
	if start_seconds == finish_seconds:
		return true
	if start_seconds < finish_seconds:
		return current_seconds >= start_seconds and current_seconds < finish_seconds
	return current_seconds >= start_seconds or current_seconds < finish_seconds


func _time_array_seconds(value: Array) -> int:
	if value.size() < 2:
		return 0
	return clampi(int(value[0]), 0, 23) * 3600 + clampi(int(value[1]), 0, 59) * 60


func _random_range(value: Variant) -> float:
	var range_values := value as Array
	if range_values == null or range_values.size() < 2:
		return 0.0
	var minimum := maxf(0.0, float(range_values[0]))
	var maximum := maxf(minimum, float(range_values[1]))
	return _rng.randf_range(minimum, maximum)


func _vector3(value: Variant) -> Vector3:
	var items := value as Array
	if items == null or items.size() < 3:
		return Vector3.ZERO
	return Vector3(float(items[0]), float(items[1]), float(items[2]))


func _load_json_dictionary(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("WorldAudioController could not open %s" % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("WorldAudioController invalid JSON: %s" % path)
		return {}
	return (parsed as Dictionary).duplicate(true)
