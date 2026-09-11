extends SceneTree


func _init() -> void:
	await process_frame
	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager == null:
		_fail("AudioManager autoload is missing")
		return
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _index in range(12):
		await process_frame

	var controller := root.get_node_or_null("Main/Presentation/WorldAudioController")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	if controller == null or time_system == null or combat_system == null:
		_fail("World audio authority dependencies are missing")
		return
	var initial: Dictionary = controller.get_debug_snapshot()
	if not bool(initial.get("initialized", false)) or str(initial.get("schema_version", "")) != "world_audio_v1":
		_fail("World audio controller did not initialize: %s" % JSON.stringify(initial))
		return
	var day_bed_info := audio_manager.get_asset_info("sfx_ambience_day_loop") as Dictionary
	var night_bed_info := audio_manager.get_asset_info("sfx_ambience_night_loop") as Dictionary
	if (
		str(day_bed_info.get("review_pack", "")) != "sample_pack_v26_ambient_nature_beds"
		or str(day_bed_info.get("source_title", "")) != "ambience birds loop.wav"
		or str(day_bed_info.get("target_lufs", "")) != "-28.0"
	):
		_fail("Day global ambience bed is not the confirmed v26-04 selection: %s" % JSON.stringify(day_bed_info))
		return
	if (
		str(night_bed_info.get("review_pack", "")) != "sample_pack_v26_ambient_nature_beds"
		or str(night_bed_info.get("source_title", "")) != "Quiet Night Atmosphere – Soft Crickets"
		or str(night_bed_info.get("target_lufs", "")) != "-30.0"
	):
		_fail("Night global ambience bed is not the confirmed v26-01 selection: %s" % JSON.stringify(night_bed_info))
		return
	if int(initial.get("source_count", 0)) != 12:
		_fail("Expected 12 configured local positional sources: %s" % JSON.stringify(initial.get("sources", {})))
		return
	var expected_day_playlist := [
		"music_day_playlist_01",
		"music_day_playlist_03",
		"music_day_playlist_04",
		"music_day_playlist_05",
		"music_day_playlist_07",
		"music_day_playlist_12",
	]
	var expected_night_playlist := [
		"music_night_playlist_05",
		"music_night_playlist_06",
		"music_night_playlist_10",
	]
	if initial.get("day_playlist", []) != expected_day_playlist or initial.get("night_playlist", []) != expected_night_playlist:
		_fail("Configured day/night music pools do not match the nine user selections")
		return
	for asset_id in expected_day_playlist + expected_night_playlist:
		var info := audio_manager.get_asset_info(asset_id) as Dictionary
		if info.is_empty() or str(info.get("loop", "true")) != "false":
			_fail("Playlist music must be a registered non-looping asset: %s" % asset_id)
			return
		if int(info.get("runtime_fade_in_ms", 0)) != 2000 or int(info.get("runtime_fade_out_ms", 0)) != 2000 or str(info.get("fade_mode", "")) != "baked_track_edges":
			_fail("Playlist music is missing baked 2-second edge fades: %s" % asset_id)
			return
	if str(initial.get("period", "")) != "day" or audio_manager.get_current_music_asset_id() != expected_day_playlist[0]:
		_fail("Initial gameplay audio state is not daytime/noncombat")
		return
	if bool(audio_manager.debug_get_snapshot().get("current_music_looping", true)):
		_fail("Day/night playlist track was forced back into single-track looping")
		return
	audio_manager.debug_finish_current_music()
	await process_frame
	if audio_manager.get_current_music_asset_id() != expected_day_playlist[1]:
		_fail("A naturally completed daytime track did not advance in configured order")
		return
	var initial_loops: Dictionary = audio_manager.get_loop_snapshot()
	for loop_key in [
		"world_ambience_day_station_bed",
		"world_ambience_river_north_bank",
		"world_ambience_river_south_bank",
	]:
		if not initial_loops.has(loop_key):
			_fail("Initial positional loop is missing: %s" % loop_key)
			return
	_assert_world_loop_routing(initial_loops)
	if _failed:
		return
	var camera_rig := root.get_node_or_null("Main/CameraRig")
	if camera_rig == null:
		_fail("CameraRig is missing for global ambience zoom mix")
		return
	camera_rig.call("_zoom", 1000.0)
	await process_frame
	var far_gain := db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("AmbientBed")))
	camera_rig.call("_zoom", -1000.0)
	await process_frame
	var near_gain := db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("AmbientBed")))
	if far_gain <= 0.0 or near_gain <= far_gain:
		_fail("Global ambience zoom mix must stay audible and grow toward the near camera: far=%.3f near=%.3f" % [far_gain, near_gain])
		return

	controller.debug_advance_ambient_seconds(240.0)
	var day_random: Dictionary = controller.get_debug_snapshot().get("random_groups", {})
	if int((day_random.get("day_birds", {}) as Dictionary).get("trigger_count", 0)) < 1:
		_fail("Day bird pool did not trigger from its configured positional emitters")
		return
	if not is_equal_approx(float((day_random.get("day_birds", {}) as Dictionary).get("last_gain_db", 0.0)), -7.0):
		_fail("Day bird pool did not apply the configured -7 dB wildlife reduction")
		return
	var rooster_state := day_random.get("dawn_rooster", {}) as Dictionary
	if int(rooster_state.get("trigger_count", 0)) != 1 or int(rooster_state.get("daily_trigger_count", 0)) != 1:
		_fail("Dawn rooster pool did not trigger near the stable/dining hall")
		return
	controller.debug_advance_ambient_seconds(600.0)
	rooster_state = (controller.get_debug_snapshot().get("random_groups", {}) as Dictionary).get("dawn_rooster", {}) as Dictionary
	if int(rooster_state.get("trigger_count", 0)) != 1 or not is_inf(float(rooster_state.get("next_due_seconds", 0.0))):
		_fail("Dawn rooster repeated within the same game day")
		return
	audio_manager.stop_all_one_shots()
	await process_frame

	time_system.set_current_time(2, 5, 30, 0)
	await process_frame
	controller.debug_advance_ambient_seconds(30.0)
	var next_day_rooster := (controller.get_debug_snapshot().get("random_groups", {}) as Dictionary).get("dawn_rooster", {}) as Dictionary
	if int(next_day_rooster.get("trigger_count", 0)) != 1 or int(next_day_rooster.get("daily_trigger_count", 0)) != 1:
		_fail("Dawn rooster did not reset to exactly one trigger on the next game day")
		return
	audio_manager.stop_all_one_shots()
	await process_frame

	time_system.set_current_time(2, 19, 0, 0)
	await process_frame
	controller.debug_advance_ambient_seconds(240.0)
	var night: Dictionary = controller.get_debug_snapshot()
	var night_loops: Dictionary = audio_manager.get_loop_snapshot()
	if str(night.get("period", "")) != "night":
		_fail("19:00 did not select the night ambience period")
		return
	if night_loops.has("world_ambience_day_station_bed") or not night_loops.has("world_ambience_night_station_bed"):
		_fail("Day/night ambience bed did not switch at 18:00 boundary")
		return
	for suffix in ["west_grass", "east_grass", "south_grass"]:
		if night_loops.has("world_ambience_night_insects_%s" % suffix):
			_fail("Night insect ambience still owns a continuous loop: %s" % suffix)
			return
	var night_random: Dictionary = night.get("random_groups", {})
	var insect_state := night_random.get("night_insects", {}) as Dictionary
	if int(insect_state.get("trigger_count", 0)) < 1 or not is_equal_approx(float(insect_state.get("last_gain_db", 0.0)), -8.0):
		_fail("Night insects did not use intermittent -8 dB positional playback")
		return
	var insect_players := main.find_children("Audio3D_sfx_ambience_night_insects_*", "AudioStreamPlayer3D", true, false)
	if insect_players.size() != 1:
		_fail("Night insect random group must own exactly one active one-shot: %s" % insect_players.size())
		return
	var insect_stream := (insect_players[0] as AudioStreamPlayer3D).stream as AudioStreamOggVorbis
	if insect_stream == null or insect_stream.loop:
		_fail("Night insect OGG retained its authored loop flag during intermittent one-shot playback")
		return
	if audio_manager.get_current_music_asset_id() != expected_night_playlist[0]:
		_fail("Night boundary did not start the first configured night track")
		return
	audio_manager.debug_finish_current_music()
	await process_frame
	if audio_manager.get_current_music_asset_id() != expected_night_playlist[1]:
		_fail("A naturally completed night track did not advance in configured order")
		return
	if int((night_random.get("night_owl", {}) as Dictionary).get("trigger_count", 0)) < 1:
		_fail("Night owl pool did not trigger from a forest source")
		return
	audio_manager.stop_all_one_shots()
	await process_frame

	var formal_fire_source: Node = null
	for raw_source in get_nodes_in_group("environment_fire_audio_source"):
		var source := raw_source as Node
		if (
			source != null
			and str(source.get_path()).contains("FormalStationLayout")
			and str(source.get_meta("environment_fire_kind", "")) == "blacksmith_forge"
		):
			formal_fire_source = source
			break
	if formal_fire_source == null:
		_fail("Formal blacksmith fire state source is missing")
		return
	var workstation_ids: Array[String] = ["forge_audio_test"]
	var npc_ids: Array[String] = ["audio_test"]
	var empty_ids: Array[String] = []
	formal_fire_source.call("_set_forge_active", true, workstation_ids, npc_ids)
	controller.call("_refresh_fire_audio")
	var active_fire_keys: Array = controller.get_debug_snapshot().get("fire_loop_keys", [])
	if active_fire_keys.size() != 1:
		_fail("Active formal forge did not own exactly one positional fire loop")
		return
	var fire_loop: Dictionary = audio_manager.get_loop_snapshot().get(str(active_fire_keys[0]), {})
	if str(fire_loop.get("asset_id", "")) != "sfx_ambience_active_fire_loop" or str(fire_loop.get("player_type", "")) != "AudioStreamPlayer3D":
		_fail("Forge fire loop did not use the confirmed positional fire asset")
		return
	formal_fire_source.call("_set_forge_active", false, empty_ids, empty_ids)
	controller.call("_refresh_fire_audio")
	if not (controller.get_debug_snapshot().get("fire_loop_keys", []) as Array).is_empty():
		_fail("Forge fire loop did not stop after the visual work state ended")
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, false, true)
	await process_frame
	if not bool(spawn_result.get("ok", false)) or combat_system.get_active_enemy_count() <= 0:
		_fail("Formal wave did not create the enemy-presence authority fact")
		return
	if audio_manager.get_current_music_asset_id() != "music_battle" or not bool(controller.get_debug_snapshot().get("combat_active", false)):
		_fail("Enemy presence did not switch to the confirmed battle music")
		return
	var clear_result: Dictionary = combat_system.debug_clear_enemies()
	await process_frame
	if not bool(clear_result.get("ok", false)) or combat_system.get_active_enemy_count() != 0:
		_fail("Formal enemy clear did not remove the enemy-presence authority fact")
		return
	if audio_manager.get_current_music_asset_id() != expected_night_playlist[2] or bool(controller.get_debug_snapshot().get("combat_active", true)):
		_fail("Clearing the last enemy did not resume the current night playlist")
		return
	audio_manager.stop_all_one_shots()
	await process_frame

	main.queue_free()
	for _index in range(4):
		await process_frame
	packed = null
	if audio_manager.get_current_music_asset_id() != "" or not audio_manager.get_loop_snapshot().is_empty():
		_fail("World audio players survived Main scene teardown")
		return
	print("T0135_P10B_WORLD_AUDIO_PASS local_sources=12 global_bed=zoom_scaled wildlife=intermittent_reduced rooster=daily_once playlists=6+3 ordered_fades=pass combat_music=pass fire=pass")
	quit(0)


var _failed := false


func _assert_world_loop_routing(loops: Dictionary) -> void:
	for raw_key in loops.keys():
		var loop_key := str(raw_key)
		if not loop_key.begins_with("world_ambience_"):
			continue
		var entry := loops.get(loop_key, {}) as Dictionary
		if loop_key.ends_with("station_bed"):
			if str(entry.get("player_type", "")) != "AudioStreamPlayer" or str(entry.get("bus", "")) != "AmbientBed":
				_fail("Day/night station bed is not global/AmbientBed-routed: %s" % JSON.stringify(entry))
				return
		elif str(entry.get("player_type", "")) != "AudioStreamPlayer3D" or str(entry.get("bus", "")) != "Ambience":
			_fail("Local world ambience loop is not positional/Ambience-routed: %s" % JSON.stringify(entry))
			return


func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	quit(1)
