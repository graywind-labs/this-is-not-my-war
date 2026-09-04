extends SceneTree


func _init() -> void:
	await process_frame
	var audio_manager := root.get_node_or_null("AudioManager")
	if audio_manager == null:
		_fail("AudioManager autoload is missing")
		return
	if absf(float(audio_manager.DEFAULT_MUSIC_VOLUME) - 0.56) > 0.001:
		_fail("Default music volume must be 30% below the previous 80% default")
		return
	for bus_name in ["Master", "Music", "SFX", "Ambience", "Work", "Foley", "Combat", "World", "Voice", "UI", "AmbientBed"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			_fail("Audio bus is missing: %s" % bus_name)
			return
	for child_bus in ["Work", "Foley", "Combat", "World", "Voice"]:
		var bus_index := AudioServer.get_bus_index(child_bus)
		if str(AudioServer.get_bus_send(bus_index)) != "SFX":
			_fail("%s must route through SFX" % child_bus)
			return
	for independent_bus in ["Ambience", "UI"]:
		var independent_index := AudioServer.get_bus_index(independent_bus)
		if str(AudioServer.get_bus_send(independent_index)) != "Master":
			_fail("%s must route directly through Master" % independent_bus)
			return
	if AudioServer.get_bus_send(AudioServer.get_bus_index("AmbientBed")) != &"Ambience":
		_fail("AmbientBed must route through Ambience")
		return
	if audio_manager.get_asset_count() != 90:
		_fail("Confirmed manifest count mismatch: %d" % audio_manager.get_asset_count())
		return
	for asset_id in ["sfx_ui_button_primary", "music_day_night", "sfx_work_blacksmith_loop", "sfx_meteor_impact_one_shot"]:
		if not audio_manager.has_asset(asset_id):
			_fail("Confirmed asset is missing from AudioManager: %s" % asset_id)
			return

	var original: Dictionary = audio_manager.get_volume_snapshot()
	audio_manager.set_master_volume(0.63, false)
	audio_manager.set_music_volume(0.47, false)
	audio_manager.set_sfx_volume(0.37, false)
	audio_manager.set_ambience_volume(0.29, false)
	audio_manager.set_ui_volume(0.53, false)
	if absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX"))) - 0.37) > 0.002:
		_fail("SFX bus did not receive the requested linear volume")
		return
	if absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Ambience"))) - 0.29) > 0.002:
		_fail("Ambience bus did not receive the requested independent volume")
		return
	if absf(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("UI"))) - 0.53) > 0.002:
		_fail("UI bus did not receive the requested independent volume")
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
	if absf(float(panel_snapshot.get("sfx", -1.0)) - 0.37) > 0.001 or str(panel_snapshot.get("sfx_text", "")) != "37%":
		_fail("Audio settings panel did not project the active SFX volume: %s" % JSON.stringify(panel_snapshot))
		return
	if absf(float(panel_snapshot.get("ambience", -1.0)) - 0.29) > 0.001 or str(panel_snapshot.get("ambience_text", "")) != "29%":
		_fail("Audio settings panel did not project the Ambience volume: %s" % JSON.stringify(panel_snapshot))
		return
	if absf(float(panel_snapshot.get("ui", -1.0)) - 0.53) > 0.001 or str(panel_snapshot.get("ui_text", "")) != "53%":
		_fail("Audio settings panel did not project the UI volume: %s" % JSON.stringify(panel_snapshot))
		return
	var preview_count := int(audio_manager.debug_get_snapshot().get("preview_play_count", 0))
	audio_page.debug_finish_slider_drag("sfx")
	await process_frame
	if int(audio_manager.debug_get_snapshot().get("preview_play_count", 0)) != preview_count + 1:
		_fail("Slider mouse-release path did not play the wooden preview click")
		return
	var saved_config := ConfigFile.new()
	if (
		saved_config.load("user://audio_settings.cfg") != OK
		or absf(float(saved_config.get_value("audio", "sfx", -1.0)) - 0.37) > 0.001
		or absf(float(saved_config.get_value("audio", "ambience", -1.0)) - 0.29) > 0.001
		or absf(float(saved_config.get_value("audio", "ui", -1.0)) - 0.53) > 0.001
	):
		_fail("Slider mouse-release path did not persist the adjusted SFX volume")
		return
	var preview_player: AudioStreamPlayer = audio_manager.preview_sfx_volume()
	if preview_player == null or preview_player.bus != &"UI" or preview_player.stream == null:
		_fail("Wooden UI click could not be loaded and routed to the UI bus")
		return

	audio_manager.set_master_volume(float(original.get("master", 0.8)), false)
	audio_manager.set_music_volume(float(original.get("music", 0.8)), false)
	audio_manager.set_sfx_volume(float(original.get("sfx", 0.8)), false)
	audio_manager.set_ambience_volume(float(original.get("ambience", 0.8)), false)
	audio_manager.set_ui_volume(float(original.get("ui", 0.8)), false)
	audio_manager.save_settings()
	audio_manager.stop_all_one_shots()
	await process_frame
	preview_player = null
	main.queue_free()
	await process_frame
	await process_frame
	packed = null
	print("T0135_P10A_AUDIO_FOUNDATION_PASS assets=90 buses=11 sliders=5 preview=pass")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
