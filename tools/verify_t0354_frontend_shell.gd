extends SceneTree

const MAIN_MENU_SCENE := preload("res://scenes/frontend/MainMenu.tscn")
const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const StationGroundDecorClass := preload("res://scripts/presentation/environment/StationGroundDecor.gd")
const GameSaveStore = preload("res://scripts/systems/GameSaveStore.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	GameSaveStore.set_storage_root_for_tests("user://t0354_verify_frontend_empty")
	root.size = Vector2i(1280, 720)
	var exiting_decor := StationGroundDecorClass.new() as Node3D
	root.add_child(exiting_decor)
	root.remove_child(exiting_decor)
	exiting_decor.call("_sync_lights")
	exiting_decor.free()
	var audio_manager := root.get_node_or_null("AudioManager")
	var client_settings := root.get_node_or_null("ClientSettings")
	if audio_manager == null or client_settings == null:
		_fail("Frontend autoload dependencies are missing")
		return
	var original_audio: Dictionary = audio_manager.get_volume_snapshot()
	var original_client: Dictionary = client_settings.get_snapshot()

	var menu := MAIN_MENU_SCENE.instantiate()
	root.add_child(menu)
	for _index in range(4):
		await process_frame
	var menu_snapshot: Dictionary = menu.debug_get_snapshot()
	if bool(menu_snapshot.get("has_main_instance", true)):
		_fail("MainMenu must not instantiate Main before Start Game")
		return
	if menu_snapshot.get("button_order", []) != ["继续游戏", "开始游戏", "载入游戏", "设置", "退出游戏"]:
		_fail("Main menu button order mismatch: %s" % menu_snapshot)
		return
	if not bool(menu_snapshot.get("hero_animated", false)) or str(menu_snapshot.get("menu_music", "")) != "music_menu":
		_fail("Main menu hero or menu music is missing: %s" % menu_snapshot)
		return
	var exit_button := menu.find_child("ExitButton", true, false) as Button
	var danger_style := exit_button.get_theme_stylebox("normal") as StyleBoxFlat if exit_button != null else null
	if exit_button == null or danger_style == null or danger_style.bg_color.r <= danger_style.bg_color.g:
		_fail("Main menu exit button is not using a red danger style")
		return
	if int(menu_snapshot.get("audio_connected_button_count", 0)) < 4:
		_fail("Main menu buttons are not connected to UI audio: %s" % menu_snapshot)
		return

	var settings_button := menu.find_child("SettingsButton", true, false) as Button
	settings_button.pressed.emit()
	await process_frame
	var click_history: Array = menu.debug_get_snapshot().get("audio_click_history", [])
	if click_history.is_empty() or str((click_history.back() as Dictionary).get("asset_id", "")) != "sfx_ui_button_primary":
		_fail("Main menu settings button did not play the wooden UI click")
		return
	var settings_panel := menu.get_node("SettingsPanel")
	var settings_snapshot: Dictionary = settings_panel.debug_get_snapshot()
	if settings_snapshot.get("tab_names", []) != ["音量", "画面", "AI"]:
		_fail("Shared settings tabs mismatch: %s" % settings_snapshot)
		return
	settings_panel.debug_select_tab(2)
	var api_key := settings_panel.find_child("ApiKeyInput", true, false) as LineEdit
	if api_key == null or not api_key.secret:
		_fail("AI API Key field must exist and be masked")
		return
	api_key.text = "T0354_SECRET_MUST_NOT_PERSIST"
	settings_panel.debug_press_apply()
	await process_frame
	var config := ConfigFile.new()
	if config.load("user://client_settings.cfg") != OK:
		_fail("Client settings were not persisted")
		return
	var stored_text := ""
	var settings_file := FileAccess.open("user://client_settings.cfg", FileAccess.READ)
	if settings_file != null:
		stored_text = settings_file.get_as_text()
		settings_file.close()
	if stored_text.contains("T0354_SECRET_MUST_NOT_PERSIST") or bool(client_settings.debug_get_snapshot().get("contains_api_key", true)):
		_fail("API Key leaked into client settings")
		return
	var close_settings_change_count := [0]
	var on_settings_changed := func(_snapshot: Dictionary) -> void:
		close_settings_change_count[0] += 1
	client_settings.settings_changed.connect(on_settings_changed)
	settings_panel.close_panel(false)
	await process_frame
	client_settings.settings_changed.disconnect(on_settings_changed)
	if int(close_settings_change_count[0]) != 0:
		_fail("Closing SettingsPanel must not reapply display settings or change the native window state")
		return

	menu.debug_open_load_browser()
	await process_frame
	var load_browser := menu.get_node("SaveBrowserPanel")
	var load_snapshot: Dictionary = load_browser.debug_get_snapshot()
	if (
		int(load_snapshot.get("slot_count", 0)) != 11
		or int(load_snapshot.get("manual_slot_count", 0)) != 10
		or int(load_snapshot.get("occupied_count", -1)) != 0
		or not bool(load_snapshot.get("action_disabled", false))
		or bool(load_snapshot.get("reads_spatial_checkpoint", true))
	):
		_fail("Load browser empty-shell contract mismatch: %s" % load_snapshot)
		return
	load_browser.close_panel()
	menu.debug_show_start_loading_state()
	var loading_snapshot: Dictionary = menu.debug_get_snapshot()
	var start_button := menu.find_child("StartButton", true, false) as Button
	if (
		not bool(loading_snapshot.get("launching_game", false))
		or not bool(loading_snapshot.get("loading_visible", false))
		or str(loading_snapshot.get("loading_message", "")).is_empty()
		or int(loading_snapshot.get("loading_mouse_filter", -1)) != Control.MOUSE_FILTER_STOP
		or int(loading_snapshot.get("loading_z_index", 0)) != 4096
		or start_button == null
		or not start_button.disabled
	):
		_fail("Start Game loading feedback/input blocker is incomplete: %s" % str(loading_snapshot))
		return
	menu.debug_publish_new_game_launch_request()
	if not has_meta(&"main_launch_request"):
		_fail("Start Game did not publish the Main launch request")
		return
	menu.queue_free()
	await process_frame

	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _index in range(8):
		await process_frame
	var startup_system := main.get_node_or_null("Systems/GameStartupSystem")
	var startup_snapshot: Dictionary = startup_system.debug_get_startup_snapshot() if startup_system != null else {}
	if str(startup_snapshot.get("launch_source", "")) != "main_menu_new_game" or int(startup_system.startup_mode if startup_system != null else -1) != 2:
		_fail("Main did not consume the menu tutorial launch request: %s" % str(startup_snapshot))
		return
	var pause_menu := main.get_node_or_null("UI/PauseMenu")
	var time_system := main.get_node_or_null("Systems/TimeSystem")
	if pause_menu == null or time_system == null:
		_fail("Main pause-menu dependencies are missing")
		return
	if main.get_node_or_null("UI/HUD/SettingsButton") != null or main.get_node_or_null("UI/AudioSettingsPanel") != null:
		_fail("Legacy HUD settings entry still exists")
		return

	time_system.set_paused(false)
	pause_menu.open_menu()
	var pause_snapshot: Dictionary = pause_menu.debug_get_snapshot()
	if not bool(pause_snapshot.get("visible", false)) or not bool(pause_snapshot.get("gameplay_paused", false)):
		_fail("Opening PauseMenu did not pause gameplay")
		return
	if pause_snapshot.get("button_order", []) != ["固定最近检查点", "保存游戏", "加载游戏", "设置", "退出到主菜单", "退出到桌面"]:
		_fail("Pause menu button order mismatch: %s" % pause_snapshot)
		return
	pause_menu.close_menu()
	if bool(time_system.is_gameplay_paused()):
		_fail("PauseMenu did not restore an originally running game")
		return

	time_system.set_paused(true)
	pause_menu.open_menu()
	pause_menu.close_menu()
	if not bool(time_system.is_gameplay_paused()):
		_fail("PauseMenu incorrectly unpaused a game that was already paused")
		return
	pause_menu.open_menu()
	pause_menu.debug_quick_save()
	if not str(pause_menu.debug_get_snapshot().get("status", "")).contains("尚无可固定"):
		_fail("Checkpoint pin must explain that no stable checkpoint exists yet")
		return
	pause_menu.debug_open_save()
	await process_frame
	var save_snapshot: Dictionary = pause_menu.debug_get_snapshot().get("save_browser", {})
	if str(save_snapshot.get("mode", "")) != "save" or str(save_snapshot.get("selected_slot_id", "")) != "slot_01" or not bool(save_snapshot.get("action_disabled", false)):
		_fail("Save browser shell did not select the first writable empty slot: %s" % save_snapshot)
		return
	var pause_save_browser := pause_menu.get_node("SaveBrowserPanel")
	pause_save_browser.debug_press_action()
	if not str(pause_save_browser.debug_get_snapshot().get("status", "")).contains("保存失败"):
		_fail("Unavailable checkpoint action must not report a fake success")
		return
	pause_save_browser.close_panel()
	pause_menu.debug_open_settings()
	await process_frame
	var pause_settings_snapshot: Dictionary = pause_menu.get_node("SettingsPanel").debug_get_snapshot()
	if pause_settings_snapshot.get("tab_names", []) != ["音量", "画面", "AI"]:
		_fail("Pause menu does not reuse the shared settings panel")
		return
	close_settings_change_count[0] = 0
	client_settings.settings_changed.connect(on_settings_changed)
	pause_menu.get_node("SettingsPanel").close_panel(true)
	await process_frame
	client_settings.settings_changed.disconnect(on_settings_changed)
	if int(close_settings_change_count[0]) != 0:
		_fail("Cancelling SettingsPanel must not reapply display settings or unmaximize the native window")
		return
	pause_menu.close_menu()
	time_system.set_paused(false)

	client_settings.apply_settings(original_client, true)
	var audio_page := main.get_node("UI/PauseMenu/SettingsPanel").find_child("AudioSettingsPage", true, false)
	if audio_page != null:
		audio_page.set_audio_values(original_audio, true)
	audio_manager.stop_music(0.0)
	audio_manager.stop_all_one_shots()
	main.queue_free()
	await process_frame
	await process_frame
	print("T0354_FRONTEND_SHELL_PASS menu=start_gate settings=shared pause=restored saves=checkpoint_backed api_key=not_persisted")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
