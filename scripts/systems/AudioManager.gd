extends Node

signal volumes_changed(master: float, music: float, click: float, voice: float, combat: float, work: float, ambience: float)
signal music_finished(asset_id: String)

const MANIFEST_PATH := "res://assets/audio/manifests/audio_asset_manifest.csv"
const CATEGORY_CONFIG_PATH := "res://data/presentation/audio_categories.json"
const SETTINGS_PATH := "user://audio_settings.cfg"
const PREVIEW_ASSET_ID := "sfx_ui_button_primary"
const DEFAULT_VOLUME := 0.8
const DEFAULT_MUSIC_VOLUME := DEFAULT_VOLUME * 0.35
const SETTINGS_VERSION := 2
const MAX_ONE_SHOTS := 32
# The camera normally sits tens of metres above the station. The manifest values
# describe the useful gameplay radius on the ground, so a literal max_distance
# made otherwise nearby work and movement sources disappear as soon as the
# camera zoomed out. Keep them positional, but use a gentler shared 3D curve.
const LOCAL_3D_MAX_DISTANCE_MULTIPLIER := 4.0
const LOCAL_3D_UNIT_SIZE_METERS := 12.0
const SPATIAL_PROFILE_LOCAL := &"local"
const SPATIAL_PROFILE_COMBAT_PRIORITY := &"combat_priority"
const SPATIAL_PROFILE_ABILITY_PRIORITY := &"ability_priority"
# Combat one-shots need to survive the normal top-down camera height. A large
# reference distance keeps directional panning while avoiding the steep loss
# caused by measuring the camera's vertical offset as part of 3D distance.
const COMBAT_3D_UNIT_SIZE_METERS := 48.0
const COMBAT_3D_MIN_MAX_DISTANCE_METERS := 480.0
const COMBAT_3D_MAX_DISTANCE_MULTIPLIER := 8.0
# Large abilities remain directional, but their scale should read across the
# whole battlefield even when the camera is high above the impact point.
const ABILITY_3D_UNIT_SIZE_METERS := 120.0
const ABILITY_3D_MIN_MAX_DISTANCE_METERS := 1500.0
const ABILITY_3D_MAX_DISTANCE_MULTIPLIER := 12.0
const AUDIO_BUSES := [
	&"Master", &"Music", &"SFX", &"Ambience", &"Work",
	&"Foley", &"Combat", &"World", &"Voice", &"UI", &"AmbientBed"
]

var _assets: Dictionary = {}
var _asset_category_buses: Dictionary = {}
var _category_asset_counts: Dictionary = {}
var _master_volume := DEFAULT_VOLUME
var _music_volume := DEFAULT_MUSIC_VOLUME
var _click_volume := DEFAULT_VOLUME
var _voice_volume := DEFAULT_VOLUME
var _combat_volume := DEFAULT_VOLUME
var _work_volume := DEFAULT_VOLUME
var _ambience_volume := DEFAULT_VOLUME
var _one_shots: Array[Node] = []
var _loops: Dictionary = {}
var _preview_play_count := 0
var _music_player: AudioStreamPlayer
var _music_asset_id := ""
var _music_transition_players: Array[AudioStreamPlayer] = []
var _player_tweens: Dictionary = {}
var _fading_loop_players: Dictionary = {}


func _ready() -> void:
	_load_manifest()
	_load_category_routes()
	_load_settings()
	_apply_volumes()


func get_asset_count() -> int:
	return _assets.size()


func has_asset(asset_id: String) -> bool:
	return _assets.has(asset_id)


func get_asset_info(asset_id: String) -> Dictionary:
	return (_assets.get(asset_id, {}) as Dictionary).duplicate(true)


func get_volume_snapshot() -> Dictionary:
	return {
		"master": _master_volume,
		"music": _music_volume,
		"click": _click_volume,
		"voice": _voice_volume,
		"combat": _combat_volume,
		"work": _work_volume,
		"ambience": _ambience_volume,
	}


func set_master_volume(value: float, save := true) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"Master", _master_volume)
	_emit_volume_change(save)


func set_music_volume(value: float, save := true) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"Music", _music_volume)
	_emit_volume_change(save)


func set_click_volume(value: float, save := true) -> void:
	_click_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"UI", _click_volume)
	_emit_volume_change(save)


func set_voice_volume(value: float, save := true) -> void:
	_voice_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"Voice", _voice_volume)
	_emit_volume_change(save)


func set_combat_volume(value: float, save := true) -> void:
	_combat_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"Combat", _combat_volume)
	_emit_volume_change(save)


func set_work_volume(value: float, save := true) -> void:
	_work_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"Work", _work_volume)
	_emit_volume_change(save)


func set_ambience_volume(value: float, save := true) -> void:
	_ambience_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"Ambience", _ambience_volume)
	_emit_volume_change(save)


func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("audio", "settings_version", SETTINGS_VERSION)
	config.set_value("audio", "master", _master_volume)
	config.set_value("audio", "music", _music_volume)
	config.set_value("audio", "click", _click_volume)
	config.set_value("audio", "voice", _voice_volume)
	config.set_value("audio", "combat", _combat_volume)
	config.set_value("audio", "work", _work_volume)
	config.set_value("audio", "ambience", _ambience_volume)
	return config.save(SETTINGS_PATH) == OK


func preview_sfx_volume() -> AudioStreamPlayer:
	_preview_play_count += 1
	return play_2d(PREVIEW_ASSET_ID, &"UI")


func play_2d(asset_id: String, bus_override: StringName = &"", gain_db := 0.0) -> AudioStreamPlayer:
	var info := _assets.get(asset_id, {}) as Dictionary
	var stream := _load_stream(info, false)
	if stream == null:
		return null
	_prune_one_shots()
	if _one_shots.size() >= MAX_ONE_SHOTS:
		var oldest: Node = _one_shots.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var player := AudioStreamPlayer.new()
	player.name = "Audio2D_%s" % asset_id
	player.stream = stream
	player.bus = bus_override if not bus_override.is_empty() else _bus_for(info)
	player.volume_db = gain_db
	add_child(player)
	_one_shots.append(player)
	player.finished.connect(_on_one_shot_finished.bind(player))
	player.play()
	return player


func play_3d(
	asset_id: String,
	source: Node3D,
	local_position := Vector3.ZERO,
	bus_override: StringName = &"",
	spatial_profile: StringName = SPATIAL_PROFILE_LOCAL,
	gain_db := 0.0
) -> AudioStreamPlayer3D:
	if source == null or not is_instance_valid(source):
		return null
	var info := _assets.get(asset_id, {}) as Dictionary
	var stream := _load_stream(info, false)
	if stream == null:
		return null
	_prune_one_shots()
	if _one_shots.size() >= MAX_ONE_SHOTS:
		var oldest: Node = _one_shots.pop_front()
		if is_instance_valid(oldest):
			oldest.queue_free()
	var player := AudioStreamPlayer3D.new()
	player.name = "Audio3D_%s" % asset_id
	player.stream = stream
	player.bus = bus_override if not bus_override.is_empty() else _bus_for(info)
	player.position = local_position
	_configure_3d_player(player, info, spatial_profile)
	player.volume_db = gain_db
	source.add_child(player)
	_one_shots.append(player)
	player.finished.connect(_on_one_shot_finished.bind(player))
	player.play()
	return player


func start_loop_2d(
	loop_key: String,
	asset_id: String,
	bus_override: StringName = &"",
	start_position_seconds := 0.0
) -> AudioStreamPlayer:
	stop_loop(loop_key, true)
	var info := _assets.get(asset_id, {}) as Dictionary
	var stream := _load_stream(info, true)
	if stream == null:
		return null
	var player := AudioStreamPlayer.new()
	player.name = "AudioLoop2D_%s" % loop_key
	player.stream = stream
	player.bus = bus_override if not bus_override.is_empty() else _bus_for(info)
	add_child(player)
	_register_and_start_loop(loop_key, player, info, start_position_seconds)
	return player


func start_loop_3d(
	loop_key: String,
	asset_id: String,
	source: Node3D,
	local_position := Vector3.ZERO,
	bus_override: StringName = &"",
	start_position_seconds := 0.0,
	spatial_profile: StringName = SPATIAL_PROFILE_LOCAL,
	gain_db := 0.0
) -> AudioStreamPlayer3D:
	if source == null or not is_instance_valid(source):
		return null
	stop_loop(loop_key, true)
	var info := _assets.get(asset_id, {}) as Dictionary
	var stream := _load_stream(info, true)
	if stream == null:
		return null
	var player := AudioStreamPlayer3D.new()
	player.name = "AudioLoop3D_%s" % loop_key
	player.stream = stream
	player.bus = bus_override if not bus_override.is_empty() else _bus_for(info)
	player.position = local_position
	_configure_3d_player(player, info, spatial_profile)
	source.add_child(player)
	_register_and_start_loop(loop_key, player, info, start_position_seconds, gain_db)
	return player


func is_loop_active(loop_key: String) -> bool:
	var entry := _loops.get(loop_key, {}) as Dictionary
	var player := entry.get("player") as Node
	return is_instance_valid(player) and not player.is_queued_for_deletion()


func get_loop_snapshot() -> Dictionary:
	var result := {}
	for raw_key in _loops.keys():
		var loop_key := str(raw_key)
		var entry := _loops.get(loop_key, {}) as Dictionary
		var player := entry.get("player") as Node
		if not is_instance_valid(player) or player.is_queued_for_deletion():
			continue
		result[loop_key] = {
			"asset_id": str(entry.get("asset_id", "")),
			"player_type": player.get_class(),
			"player_path": str(player.get_path()),
			"source_path": str(player.get_parent().get_path()) if player.get_parent() != null else "",
			"playing": bool(player.get("playing")),
			"bus": str(player.get("bus")),
			"spatial_profile": str(player.get_meta("audio_spatial_profile", &"")) if player is AudioStreamPlayer3D else "global_2d",
			"unit_size_m": float(player.get("unit_size")) if player is AudioStreamPlayer3D else 0.0,
			"max_distance_m": float(player.get("max_distance")) if player is AudioStreamPlayer3D else 0.0,
			"target_gain_db": float(entry.get("target_gain_db", 0.0)),
			"volume_db": float(player.get("volume_db")),
		}
	return result


func switch_music(asset_id: String, fade_seconds := 2.0, loop_track := true) -> AudioStreamPlayer:
	if asset_id == _music_asset_id and is_instance_valid(_music_player):
		return _music_player
	var info := _assets.get(asset_id, {}) as Dictionary
	var stream := _load_stream(info, loop_track)
	if stream == null:
		return null
	_prune_music_transitions()
	var previous := _music_player
	var player := AudioStreamPlayer.new()
	player.name = "Music_%s" % asset_id
	player.stream = stream
	player.bus = &"Music"
	player.volume_db = -60.0 if fade_seconds > 0.0 else 0.0
	add_child(player)
	_music_player = player
	_music_asset_id = asset_id
	player.finished.connect(_on_music_player_finished.bind(player, asset_id))
	player.play()
	if fade_seconds > 0.0:
		var fade_in := create_tween()
		fade_in.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		fade_in.tween_property(player, "volume_db", 0.0, fade_seconds)
		_track_player_tween(player, fade_in)
	if is_instance_valid(previous):
		_kill_player_tweens(previous)
		_music_transition_players.append(previous)
		if fade_seconds <= 0.0:
			_finish_music_transition(previous)
		else:
			var fade_out := create_tween()
			fade_out.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
			fade_out.tween_property(previous, "volume_db", -60.0, fade_seconds)
			fade_out.tween_callback(_finish_music_transition.bind(previous))
			_track_player_tween(previous, fade_out)
	return player


func stop_music(fade_seconds := 2.0) -> void:
	var previous := _music_player
	_music_player = null
	_music_asset_id = ""
	if fade_seconds <= 0.0:
		if is_instance_valid(previous):
			_kill_player_tweens(previous)
			previous.free()
		for transition_player in _music_transition_players:
			if is_instance_valid(transition_player):
				_kill_player_tweens(transition_player)
				transition_player.free()
		_music_transition_players.clear()
		return
	if not is_instance_valid(previous):
		return
	_kill_player_tweens(previous)
	_music_transition_players.append(previous)
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(previous, "volume_db", -60.0, fade_seconds)
	tween.tween_callback(_finish_music_transition.bind(previous))
	_track_player_tween(previous, tween)


func get_current_music_asset_id() -> String:
	return _music_asset_id


func debug_finish_current_music() -> void:
	if is_instance_valid(_music_player):
		_on_music_player_finished(_music_player, _music_asset_id)


func stop_loop(loop_key: String, immediate := false) -> void:
	var entry := _loops.get(loop_key, {}) as Dictionary
	if entry.is_empty():
		return
	_loops.erase(loop_key)
	var player := entry.get("player") as Node
	if not is_instance_valid(player):
		return
	_kill_player_tweens(player)
	var fade_seconds := 0.0 if immediate else float(entry.get("fade_out_seconds", 0.0))
	if fade_seconds <= 0.0:
		player.free()
		return
	var tween := create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(player, "volume_db", -60.0, fade_seconds)
	tween.tween_callback(_finish_audio_player.bind(player))
	_track_player_tween(player, tween)
	_fading_loop_players[player.get_instance_id()] = {
		"player": player,
		"loop_key": loop_key,
	}


func stop_all_loops(immediate := false) -> void:
	for raw_key in _loops.keys().duplicate():
		stop_loop(str(raw_key), immediate)
	if immediate:
		for raw_entry in _fading_loop_players.values():
			var entry := raw_entry as Dictionary
			var player := entry.get("player") as Node
			if is_instance_valid(player):
				_kill_player_tweens(player)
				player.free()
		_fading_loop_players.clear()


func stop_loops_with_prefix(prefix: String, immediate := false) -> void:
	for raw_key in _loops.keys().duplicate():
		var loop_key := str(raw_key)
		if loop_key.begins_with(prefix):
			stop_loop(loop_key, immediate)
	if not immediate:
		return
	for raw_player_id in _fading_loop_players.keys().duplicate():
		var player_id := int(raw_player_id)
		var entry := _fading_loop_players.get(player_id, {}) as Dictionary
		if not str(entry.get("loop_key", "")).begins_with(prefix):
			continue
		var player := entry.get("player") as Node
		if is_instance_valid(player):
			_kill_player_tweens(player)
			player.free()
		_fading_loop_players.erase(player_id)


func stop_all_one_shots() -> void:
	for player in _one_shots:
		if is_instance_valid(player):
			player.queue_free()
	_one_shots.clear()


func debug_get_snapshot() -> Dictionary:
	return {
		"asset_count": _assets.size(),
		"volumes": get_volume_snapshot(),
		"active_one_shots": _one_shots.size(),
		"active_loops": _loops.size(),
		"preview_play_count": _preview_play_count,
		"current_music_asset_id": _music_asset_id,
		"current_music_looping": _is_stream_looping(_music_player.stream) if is_instance_valid(_music_player) else false,
		"active_music_player_count": int(is_instance_valid(_music_player)) + _music_transition_players.size(),
		"loops": get_loop_snapshot(),
		"buses": AUDIO_BUSES.duplicate(),
		"category_asset_counts": _category_asset_counts.duplicate(true),
		"categorized_asset_count": _asset_category_buses.size(),
		"local_3d_policy": {
			"attenuation_model": "inverse_distance",
			"unit_size_m": LOCAL_3D_UNIT_SIZE_METERS,
			"max_distance_multiplier": LOCAL_3D_MAX_DISTANCE_MULTIPLIER,
		},
		"priority_3d_profiles": {
			str(SPATIAL_PROFILE_COMBAT_PRIORITY): _spatial_profile_snapshot(SPATIAL_PROFILE_COMBAT_PRIORITY),
			str(SPATIAL_PROFILE_ABILITY_PRIORITY): _spatial_profile_snapshot(SPATIAL_PROFILE_ABILITY_PRIORITY),
		},
	}


func _is_stream_looping(stream: AudioStream) -> bool:
	if stream is AudioStreamOggVorbis:
		return (stream as AudioStreamOggVorbis).loop
	if stream is AudioStreamWAV:
		return (stream as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
	return false


func _configure_3d_player(player: AudioStreamPlayer3D, info: Dictionary, spatial_profile: StringName) -> void:
	var authored_distance := maxf(1.0, float(info.get("suggested_max_distance_m", 40.0)))
	var profile := spatial_profile if spatial_profile in [
		SPATIAL_PROFILE_COMBAT_PRIORITY,
		SPATIAL_PROFILE_ABILITY_PRIORITY,
	] else SPATIAL_PROFILE_LOCAL
	match profile:
		SPATIAL_PROFILE_ABILITY_PRIORITY:
			player.max_distance = maxf(ABILITY_3D_MIN_MAX_DISTANCE_METERS, authored_distance * ABILITY_3D_MAX_DISTANCE_MULTIPLIER)
			player.unit_size = ABILITY_3D_UNIT_SIZE_METERS
			player.attenuation_filter_db = 0.0
		SPATIAL_PROFILE_COMBAT_PRIORITY:
			player.max_distance = maxf(COMBAT_3D_MIN_MAX_DISTANCE_METERS, authored_distance * COMBAT_3D_MAX_DISTANCE_MULTIPLIER)
			player.unit_size = COMBAT_3D_UNIT_SIZE_METERS
			player.attenuation_filter_db = 0.0
		_:
			player.max_distance = authored_distance * LOCAL_3D_MAX_DISTANCE_MULTIPLIER
			player.unit_size = LOCAL_3D_UNIT_SIZE_METERS
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	player.set_meta("audio_spatial_profile", profile)


func _spatial_profile_snapshot(spatial_profile: StringName) -> Dictionary:
	match spatial_profile:
		SPATIAL_PROFILE_ABILITY_PRIORITY:
			return {
				"attenuation_model": "inverse_distance",
				"unit_size_m": ABILITY_3D_UNIT_SIZE_METERS,
				"minimum_max_distance_m": ABILITY_3D_MIN_MAX_DISTANCE_METERS,
				"max_distance_multiplier": ABILITY_3D_MAX_DISTANCE_MULTIPLIER,
				"attenuation_filter_db": 0.0,
			}
		SPATIAL_PROFILE_COMBAT_PRIORITY:
			return {
				"attenuation_model": "inverse_distance",
				"unit_size_m": COMBAT_3D_UNIT_SIZE_METERS,
				"minimum_max_distance_m": COMBAT_3D_MIN_MAX_DISTANCE_METERS,
				"max_distance_multiplier": COMBAT_3D_MAX_DISTANCE_MULTIPLIER,
				"attenuation_filter_db": 0.0,
			}
	return {
		"attenuation_model": "inverse_distance",
		"unit_size_m": LOCAL_3D_UNIT_SIZE_METERS,
		"max_distance_multiplier": LOCAL_3D_MAX_DISTANCE_MULTIPLIER,
	}


func _load_manifest() -> void:
	_assets.clear()
	var file := FileAccess.open(MANIFEST_PATH, FileAccess.READ)
	if file == null:
		push_error("AudioManager could not open %s" % MANIFEST_PATH)
		return
	var headers := file.get_csv_line()
	while not file.eof_reached():
		var values := file.get_csv_line()
		if values.is_empty() or (values.size() == 1 and values[0].is_empty()):
			continue
		var row := {}
		for index in range(mini(headers.size(), values.size())):
			row[str(headers[index])] = values[index]
		var asset_id := str(row.get("asset_id", ""))
		if not asset_id.is_empty():
			_assets[asset_id] = row


func _load_category_routes() -> void:
	_asset_category_buses.clear()
	_category_asset_counts.clear()
	var file := FileAccess.open(CATEGORY_CONFIG_PATH, FileAccess.READ)
	if file == null:
		push_error("AudioManager could not open %s" % CATEGORY_CONFIG_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		push_error("AudioManager invalid category config: %s" % CATEGORY_CONFIG_PATH)
		return
	var categories := (parsed as Dictionary).get("categories", {}) as Dictionary
	for raw_category_id in categories.keys():
		var category_id := str(raw_category_id)
		var category := categories.get(raw_category_id, {}) as Dictionary
		var bus := str(category.get("bus", ""))
		var count := 0
		for raw_asset_id in category.get("asset_ids", []):
			var asset_id := str(raw_asset_id)
			if not _assets.has(asset_id):
				push_error("Audio category %s references unknown asset: %s" % [category_id, asset_id])
				continue
			if _asset_category_buses.has(asset_id):
				push_error("Audio asset is assigned to multiple categories: %s" % asset_id)
				continue
			_asset_category_buses[asset_id] = bus
			count += 1
		_category_asset_counts[category_id] = count
	for raw_asset_id in _assets.keys():
		if not _asset_category_buses.has(raw_asset_id):
			push_error("Audio asset has no settings category: %s" % str(raw_asset_id))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_master_volume = clampf(float(config.get_value("audio", "master", DEFAULT_VOLUME)), 0.0, 1.0)
	var settings_version := int(config.get_value("audio", "settings_version", 1))
	if settings_version < SETTINGS_VERSION:
		var legacy_sfx := clampf(float(config.get_value("audio", "sfx", DEFAULT_VOLUME)), 0.0, 1.0)
		_music_volume = clampf(float(config.get_value("audio", "music", DEFAULT_VOLUME * 0.7)) * 0.5, 0.0, 1.0)
		_click_volume = clampf(float(config.get_value("audio", "ui", DEFAULT_VOLUME)), 0.0, 1.0)
		_voice_volume = legacy_sfx
		_combat_volume = legacy_sfx
		_work_volume = legacy_sfx
		_ambience_volume = clampf(float(config.get_value("audio", "ambience", DEFAULT_VOLUME)), 0.0, 1.0)
		save_settings()
		return
	_music_volume = clampf(float(config.get_value("audio", "music", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	_click_volume = clampf(float(config.get_value("audio", "click", DEFAULT_VOLUME)), 0.0, 1.0)
	_voice_volume = clampf(float(config.get_value("audio", "voice", DEFAULT_VOLUME)), 0.0, 1.0)
	_combat_volume = clampf(float(config.get_value("audio", "combat", DEFAULT_VOLUME)), 0.0, 1.0)
	_work_volume = clampf(float(config.get_value("audio", "work", DEFAULT_VOLUME)), 0.0, 1.0)
	_ambience_volume = clampf(float(config.get_value("audio", "ambience", DEFAULT_VOLUME)), 0.0, 1.0)


func _apply_volumes() -> void:
	_apply_bus_volume(&"Master", _master_volume)
	_apply_bus_volume(&"Music", _music_volume)
	_apply_bus_volume(&"SFX", 1.0)
	_apply_bus_volume(&"UI", _click_volume)
	_apply_bus_volume(&"Voice", _voice_volume)
	_apply_bus_volume(&"Combat", _combat_volume)
	_apply_bus_volume(&"Work", _work_volume)
	_apply_bus_volume(&"Ambience", _ambience_volume)
	volumes_changed.emit(_master_volume, _music_volume, _click_volume, _voice_volume, _combat_volume, _work_volume, _ambience_volume)


func _apply_bus_volume(bus_name: StringName, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		push_error("AudioManager missing audio bus: %s" % bus_name)
		return
	AudioServer.set_bus_mute(index, linear <= 0.0001)
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))


func _emit_volume_change(save: bool) -> void:
	if save:
		save_settings()
	volumes_changed.emit(_master_volume, _music_volume, _click_volume, _voice_volume, _combat_volume, _work_volume, _ambience_volume)


func _load_stream(info: Dictionary, loop_override: Variant = null) -> AudioStream:
	if info.is_empty():
		return null
	var path := str(info.get("relative_path", ""))
	if path.is_empty() or not ResourceLoader.exists(path):
		push_error("AudioManager missing runtime audio: %s" % path)
		return null
	var stream := load(path) as AudioStream
	if stream == null:
		push_error("AudioManager failed to load runtime audio: %s" % path)
		return null
	var should_loop := (
		str(info.get("loop", "false")).to_lower() == "true"
		if loop_override == null
		else bool(loop_override)
	)
	stream = stream.duplicate()
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = should_loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = (
			AudioStreamWAV.LOOP_FORWARD
			if should_loop
			else AudioStreamWAV.LOOP_DISABLED
		)
	return stream


func _bus_for(info: Dictionary) -> StringName:
	var asset_id := str(info.get("asset_id", ""))
	if _asset_category_buses.has(asset_id):
		return StringName(str(_asset_category_buses.get(asset_id, "World")))
	var category := str(info.get("category", ""))
	if asset_id.begins_with("music_") or category.begins_with("bgm_"):
		return &"Music"
	if asset_id.begins_with("voice_emotion_"):
		return &"Voice"
	if asset_id.begins_with("voice_combat_"):
		return &"Combat"
	if asset_id.begins_with("sfx_ui_"):
		return &"UI"
	if asset_id.begins_with("sfx_ambience_"):
		return &"Ambience"
	if asset_id in ["sfx_world_door_open", "sfx_world_door_close", "sfx_merchant_cart_arrival_departure"]:
		return &"Ambience"
	if asset_id in ["sfx_work_repair_and_upgrade_start", "sfx_work_blacksmith_target_selected"]:
		return &"UI"
	if asset_id.begins_with("sfx_work_"):
		return &"Work"
	if asset_id.begins_with("sfx_chapel_") or asset_id.begins_with("sfx_daily_"):
		return &"Work"
	if asset_id.begins_with("sfx_foley_") or category.begins_with("foley_"):
		return &"Combat"
	if asset_id.begins_with("sfx_combat_") or asset_id.begins_with("sfx_meteor_"):
		return &"Combat"
	if asset_id in ["sfx_horse_run", "sfx_piety_ready_sacred_chant", "sfx_world_battle_alert_one_shot"]:
		return &"Combat"
	if category.ends_with("stinger") or category.ends_with("severe_collapse"):
		return &"Combat"
	return &"World"


func _register_and_start_loop(
	loop_key: String,
	player: Node,
	info: Dictionary,
	start_position_seconds := 0.0,
	target_gain_db := 0.0
) -> void:
	var fade_in_seconds := maxf(0.0, float(info.get("runtime_fade_in_ms", 0.0)) / 1000.0)
	var fade_out_seconds := maxf(0.0, float(info.get("runtime_fade_out_ms", 0.0)) / 1000.0)
	_loops[loop_key] = {
		"player": player,
		"asset_id": str(info.get("asset_id", "")),
		"fade_out_seconds": fade_out_seconds,
		"target_gain_db": target_gain_db,
	}
	player.set("volume_db", -60.0 if fade_in_seconds > 0.0 else target_gain_db)
	player.call("play", maxf(0.0, start_position_seconds))
	if fade_in_seconds > 0.0:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(player, "volume_db", target_gain_db, fade_in_seconds)
		_track_player_tween(player, tween)


func _prune_one_shots() -> void:
	var active: Array[Node] = []
	for player in _one_shots:
		if is_instance_valid(player) and not player.is_queued_for_deletion():
			active.append(player)
	_one_shots = active


func _on_one_shot_finished(player: Node) -> void:
	_one_shots.erase(player)
	if is_instance_valid(player):
		player.queue_free()


func _on_music_player_finished(player: AudioStreamPlayer, asset_id: String) -> void:
	if player != _music_player:
		return
	_kill_player_tweens(player)
	_music_player = null
	_music_asset_id = ""
	player.queue_free()
	music_finished.emit(asset_id)


func _prune_music_transitions() -> void:
	var active: Array[AudioStreamPlayer] = []
	for player in _music_transition_players:
		if is_instance_valid(player) and not player.is_queued_for_deletion():
			active.append(player)
	_music_transition_players = active


func _finish_music_transition(player: AudioStreamPlayer) -> void:
	if is_instance_valid(player):
		_player_tweens.erase(player.get_instance_id())
	_music_transition_players.erase(player)
	if is_instance_valid(player):
		player.queue_free()


func _finish_audio_player(player: Node) -> void:
	if is_instance_valid(player):
		var player_id := player.get_instance_id()
		_player_tweens.erase(player_id)
		_fading_loop_players.erase(player_id)
		player.queue_free()


func _track_player_tween(player: Node, tween: Tween) -> void:
	if not is_instance_valid(player) or not is_instance_valid(tween):
		return
	var key := player.get_instance_id()
	var tweens: Array = _player_tweens.get(key, [])
	tweens.append(tween)
	_player_tweens[key] = tweens


func _kill_player_tweens(player: Node) -> void:
	if not is_instance_valid(player):
		return
	var key := player.get_instance_id()
	for raw_tween in _player_tweens.get(key, []):
		var tween := raw_tween as Tween
		if is_instance_valid(tween):
			tween.kill()
	_player_tweens.erase(key)
