extends SceneTree


func _init() -> void:
	await process_frame
	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager == null:
		_fail("AudioManager autoload is missing")
		return
	if absf(float(audio_manager.DEFAULT_MUSIC_VOLUME) - 0.28) > 0.001:
		_fail("Default music volume must be half of the previous 56% default")
		return
	for bus_name in ["Master", "Music", "SFX", "Ambience", "Work", "Foley", "Combat", "World", "Voice", "UI", "AmbientBed"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			_fail("Audio bus is missing: %s" % bus_name)
			return
	for child_bus in ["Work", "Combat", "World", "Voice"]:
		var bus_index := AudioServer.get_bus_index(child_bus)
		if str(AudioServer.get_bus_send(bus_index)) != "Master":
			_fail("%s must route directly through Master" % child_bus)
			return
	for independent_bus in ["Ambience", "UI"]:
		var independent_index := AudioServer.get_bus_index(independent_bus)
		if str(AudioServer.get_bus_send(independent_index)) != "Master":
			_fail("%s must route directly through Master" % independent_bus)
			return
	if AudioServer.get_bus_send(AudioServer.get_bus_index("AmbientBed")) != &"Ambience":
		_fail("AmbientBed must route through Ambience")
		return
	if AudioServer.get_bus_send(AudioServer.get_bus_index("Foley")) != &"Combat":
		_fail("Legacy Foley bus must route through Combat")
		return
	if audio_manager.get_asset_count() != 102:
		_fail("Confirmed manifest count mismatch: %d" % audio_manager.get_asset_count())
		return
	var category_snapshot: Dictionary = audio_manager.debug_get_snapshot()
	var category_counts: Dictionary = category_snapshot.get("category_asset_counts", {})
	var expected_counts := {"music": 12, "click": 7, "voice": 19, "combat": 33, "work": 16, "ambience": 15}
	if int(category_snapshot.get("categorized_asset_count", 0)) != 102 or category_counts != expected_counts:
		_fail("All 102 assets must have exactly one settings category: %s" % JSON.stringify(category_counts))
		return
	for asset_id in ["sfx_ui_button_primary", "music_day_night", "music_day_playlist_01", "music_night_playlist_10", "sfx_work_blacksmith_loop", "sfx_work_repair_and_upgrade_start", "sfx_work_blacksmith_target_selected", "sfx_piety_ready_sacred_chant", "sfx_meteor_impact_one_shot"]:
		if not audio_manager.has_asset(asset_id):
			_fail("Confirmed asset is missing from AudioManager: %s" % asset_id)
			return

	var original: Dictionary = audio_manager.get_volume_snapshot()
	audio_manager.set_master_volume(0.63, false)
	audio_manager.set_music_volume(0.47, false)
	audio_manager.set_click_volume(0.53, false)
	audio_manager.set_voice_volume(0.41, false)
	audio_manager.set_combat_volume(0.37, false)
	audio_manager.set_work_volume(0.33, false)
	audio_manager.set_ambience_volume(0.29, false)
	for bus_and_value in [["UI", 0.53], ["Voice", 0.41], ["Combat", 0.37], ["Work", 0.33], ["Ambience", 0.29]]:
		if absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index(bus_and_value[0]))) - float(bus_and_value[1])) > 0.002:
			_fail("Category bus did not receive its independent volume: %s" % bus_and_value[0])
			return

	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Audio foundation could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _index in range(8):
		await process_frame
	var pause_menu := root.get_node_or_null("Main/UI/PauseMenu")
	var settings_panel := root.get_node_or_null("Main/UI/PauseMenu/SettingsPanel")
	if pause_menu == null or settings_panel == null:
		_fail("Formal pause menu or shared settings panel is missing")
		return
	pause_menu.debug_open_settings()
	await process_frame
	var audio_page := settings_panel.find_child("AudioSettingsPage", true, false)
	if audio_page == null:
		_fail("Shared settings panel audio page is missing")
		return
	var panel_snapshot: Dictionary = audio_page.debug_get_snapshot()
	if not bool(panel_snapshot.get("visible", false)):
		_fail("Settings button did not open the audio settings panel")
		return
	for kind_and_value in [["click", 0.53], ["voice", 0.41], ["combat", 0.37], ["work", 0.33], ["ambience", 0.29]]:
		var kind := str(kind_and_value[0])
		var expected := float(kind_and_value[1])
		if absf(float(panel_snapshot.get(kind, -1.0)) - expected) > 0.001 or str(panel_snapshot.get("%s_text" % kind, "")) != "%d%%" % roundi(expected * 100.0):
			_fail("Audio settings panel did not project category %s: %s" % [kind, JSON.stringify(panel_snapshot)])
			return
	var preview_count := int(audio_manager.debug_get_snapshot().get("preview_play_count", 0))
	audio_page.debug_finish_slider_drag("combat")
	await process_frame
	if int(audio_manager.debug_get_snapshot().get("preview_play_count", 0)) != preview_count + 1:
		_fail("Slider mouse-release path did not play the wooden preview click")
		return
	var saved_config := ConfigFile.new()
	if (
		saved_config.load("user://audio_settings.cfg") != OK
		or int(saved_config.get_value("audio", "settings_version", 0)) != 2
		or absf(float(saved_config.get_value("audio", "click", -1.0)) - 0.53) > 0.001
		or absf(float(saved_config.get_value("audio", "voice", -1.0)) - 0.41) > 0.001
		or absf(float(saved_config.get_value("audio", "combat", -1.0)) - 0.37) > 0.001
		or absf(float(saved_config.get_value("audio", "work", -1.0)) - 0.33) > 0.001
		or absf(float(saved_config.get_value("audio", "ambience", -1.0)) - 0.29) > 0.001
	):
		_fail("Slider mouse-release path did not persist all category volumes")
		return
	var preview_player: AudioStreamPlayer = audio_manager.preview_sfx_volume()
	if preview_player == null or preview_player.bus != &"UI" or preview_player.stream == null:
		_fail("Wooden UI click could not be loaded and routed to the UI bus")
		return
	var spatial_policy: Dictionary = audio_manager.debug_get_snapshot().get("local_3d_policy", {})
	if (
		absf(float(spatial_policy.get("max_distance_multiplier", 0.0)) - 4.0) > 0.001
		or absf(float(spatial_policy.get("unit_size_m", 0.0)) - 12.0) > 0.001
	):
		_fail("Shared local 3D attenuation policy is not the reduced-rolloff T0375 policy")
		return
	var spatial_source := Node3D.new()
	spatial_source.name = "T0375SpatialAudioProbe"
	main.add_child(spatial_source)
	var spatial_player: AudioStreamPlayer3D = audio_manager.play_3d("sfx_foley_run_unified_loop", spatial_source)
	if spatial_player == null or absf(spatial_player.max_distance - 72.0) > 0.01 or absf(spatial_player.unit_size - 12.0) > 0.01:
		_fail("Local movement audio did not receive the expanded 3D hearing range")
		return

	audio_manager.set_master_volume(float(original.get("master", 0.8)), false)
	audio_manager.set_music_volume(float(original.get("music", 0.8)), false)
	audio_manager.set_click_volume(float(original.get("click", 0.8)), false)
	audio_manager.set_voice_volume(float(original.get("voice", 0.8)), false)
	audio_manager.set_combat_volume(float(original.get("combat", 0.8)), false)
	audio_manager.set_work_volume(float(original.get("work", 0.8)), false)
	audio_manager.set_ambience_volume(float(original.get("ambience", 0.8)), false)
	audio_manager.save_settings()
	audio_manager.stop_all_one_shots()
	await process_frame
	preview_player = null
	main.queue_free()
	await process_frame
	await process_frame
	packed = null
	print("T0135_P10A_AUDIO_FOUNDATION_PASS assets=102 buses=11 sliders=7 categories=6 preview=pass local_3d=4x")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
