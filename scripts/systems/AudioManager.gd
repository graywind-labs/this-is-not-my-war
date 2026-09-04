extends Node

signal volumes_changed(master: float, music: float, sfx: float, ambience: float, ui: float)

const MANIFEST_PATH := "res://assets/audio/manifests/audio_asset_manifest.csv"
const SETTINGS_PATH := "user://audio_settings.cfg"
const PREVIEW_ASSET_ID := "sfx_ui_button_primary"
const DEFAULT_VOLUME := 0.8
const DEFAULT_MUSIC_VOLUME := DEFAULT_VOLUME * 0.7
const MAX_ONE_SHOTS := 32
const AUDIO_BUSES := [
	&"Master", &"Music", &"SFX", &"Ambience", &"Work",
	&"Foley", &"Combat", &"World", &"Voice", &"UI", &"AmbientBed"
]

var _assets: Dictionary = {}
var _master_volume := DEFAULT_VOLUME
var _music_volume := DEFAULT_MUSIC_VOLUME
var _sfx_volume := DEFAULT_VOLUME
var _ambience_volume := DEFAULT_VOLUME
var _ui_volume := DEFAULT_VOLUME
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
		"sfx": _sfx_volume,
		"ambience": _ambience_volume,
		"ui": _ui_volume
	}


func set_master_volume(value: float, save := true) -> void:
	_master_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"Master", _master_volume)
	_emit_volume_change(save)


func set_music_volume(value: float, save := true) -> void:
	_music_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"Music", _music_volume)
	_emit_volume_change(save)


func set_sfx_volume(value: float, save := true) -> void:
	_sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"SFX", _sfx_volume)
	_emit_volume_change(save)


func set_ambience_volume(value: float, save := true) -> void:
	_ambience_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"Ambience", _ambience_volume)
	_emit_volume_change(save)


func set_ui_volume(value: float, save := true) -> void:
	_ui_volume = clampf(value, 0.0, 1.0)
	_apply_bus_volume(&"UI", _ui_volume)
	_emit_volume_change(save)


func save_settings() -> bool:
	var config := ConfigFile.new()
	config.set_value("audio", "master", _master_volume)
	config.set_value("audio", "music", _music_volume)
	config.set_value("audio", "sfx", _sfx_volume)
	config.set_value("audio", "ambience", _ambience_volume)
	config.set_value("audio", "ui", _ui_volume)
	return config.save(SETTINGS_PATH) == OK


func preview_sfx_volume() -> AudioStreamPlayer:
	_preview_play_count += 1
	return play_2d(PREVIEW_ASSET_ID, &"UI")


func play_2d(asset_id: String, bus_override: StringName = &"") -> AudioStreamPlayer:
	var info := _assets.get(asset_id, {}) as Dictionary
	var stream := _load_stream(info)
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
	add_child(player)
	_one_shots.append(player)
	player.finished.connect(_on_one_shot_finished.bind(player))
	player.play()
	return player


func play_3d(asset_id: String, source: Node3D, local_position := Vector3.ZERO, bus_override: StringName = &"") -> AudioStreamPlayer3D:
	if source == null or not is_instance_valid(source):
		return null
	var info := _assets.get(asset_id, {}) as Dictionary
	var stream := _load_stream(info)
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
	player.max_distance = maxf(1.0, float(info.get("suggested_max_distance_m", 40.0)))
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
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
	start_position_seconds := 0.0
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
	player.max_distance = maxf(1.0, float(info.get("suggested_max_distance_m", 40.0)))
	player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	source.add_child(player)
	_register_and_start_loop(loop_key, player, info, start_position_seconds)
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
		}
	return result


func switch_music(asset_id: String, fade_seconds := 2.0) -> AudioStreamPlayer:
	if asset_id == _music_asset_id and is_instance_valid(_music_player):
		return _music_player
	var info := _assets.get(asset_id, {}) as Dictionary
	var stream := _load_stream(info, true)
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
		"active_music_player_count": int(is_instance_valid(_music_player)) + _music_transition_players.size(),
		"loops": get_loop_snapshot(),
		"buses": AUDIO_BUSES.duplicate()
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


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	_master_volume = clampf(float(config.get_value("audio", "master", DEFAULT_VOLUME)), 0.0, 1.0)
	_music_volume = clampf(float(config.get_value("audio", "music", DEFAULT_MUSIC_VOLUME)), 0.0, 1.0)
	_sfx_volume = clampf(float(config.get_value("audio", "sfx", DEFAULT_VOLUME)), 0.0, 1.0)
	_ambience_volume = clampf(float(config.get_value("audio", "ambience", DEFAULT_VOLUME)), 0.0, 1.0)
	_ui_volume = clampf(float(config.get_value("audio", "ui", DEFAULT_VOLUME)), 0.0, 1.0)


func _apply_volumes() -> void:
	_apply_bus_volume(&"Master", _master_volume)
	_apply_bus_volume(&"Music", _music_volume)
	_apply_bus_volume(&"SFX", _sfx_volume)
	_apply_bus_volume(&"Ambience", _ambience_volume)
	_apply_bus_volume(&"UI", _ui_volume)
	volumes_changed.emit(_master_volume, _music_volume, _sfx_volume, _ambience_volume, _ui_volume)


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
	volumes_changed.emit(_master_volume, _music_volume, _sfx_volume, _ambience_volume, _ui_volume)


func _load_stream(info: Dictionary, force_loop := false) -> AudioStream:
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
	if force_loop or str(info.get("loop", "false")).to_lower() == "true":
		stream = stream.duplicate()
		if stream is AudioStreamOggVorbis:
			(stream as AudioStreamOggVorbis).loop = true
		elif stream is AudioStreamWAV:
			(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	return stream


func _bus_for(info: Dictionary) -> StringName:
	var asset_id := str(info.get("asset_id", ""))
	var category := str(info.get("category", ""))
	if asset_id.begins_with("music_") or category.begins_with("bgm_"):
		return &"Music"
	if asset_id.begins_with("voice_"):
		return &"Voice"
	if asset_id.begins_with("sfx_ui_"):
		return &"UI"
	if asset_id.begins_with("sfx_ambience_"):
		return &"Ambience"
	if asset_id.begins_with("sfx_work_"):
		return &"Work"
	if asset_id.begins_with("sfx_foley_") or category.begins_with("foley_"):
		return &"Foley"
	if asset_id.begins_with("sfx_combat_"):
		return &"Combat"
	return &"World"


func _register_and_start_loop(
	loop_key: String,
	player: Node,
	info: Dictionary,
	start_position_seconds := 0.0
) -> void:
	var fade_in_seconds := maxf(0.0, float(info.get("runtime_fade_in_ms", 0.0)) / 1000.0)
	var fade_out_seconds := maxf(0.0, float(info.get("runtime_fade_out_ms", 0.0)) / 1000.0)
	_loops[loop_key] = {
		"player": player,
		"asset_id": str(info.get("asset_id", "")),
		"fade_out_seconds": fade_out_seconds,
	}
	player.set("volume_db", -60.0 if fade_in_seconds > 0.0 else 0.0)
	player.call("play", maxf(0.0, start_position_seconds))
	if fade_in_seconds > 0.0:
		var tween := create_tween()
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(player, "volume_db", 0.0, fade_in_seconds)
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
