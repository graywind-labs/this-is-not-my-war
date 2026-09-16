extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const EquipmentWindowScript = preload("res://scripts/ui/NPCEquipmentWindow.gd")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _index in range(8):
		await process_frame
	var controller := main.get_node_or_null("Presentation/InteractionAudioController")
	var audio_manager := root.get_node_or_null("AudioManager")
	var ui_root := main.get_node_or_null("UI")
	if [controller, audio_manager, ui_root].has(null):
		_fail("required audio or UI nodes are missing")
		return

	_assert(audio_manager.has_asset("sfx_work_blacksmith_target_selected"), "blacksmith strike asset is missing")
	_assert(audio_manager.has_asset("sfx_ui_equipment_mount_selected"), "selected horse sound asset is missing")
	var horse_info: Dictionary = audio_manager.get_asset_info("sfx_ui_equipment_mount_selected")
	var horse_duration := float(horse_info.get("duration_seconds", 0.0))
	_assert(horse_duration >= 0.64 and horse_duration <= 0.66, "horse selection sound is not confirmed option 02")

	var equipment_window := EquipmentWindowScript.new() as Control
	equipment_window.name = "T0399EquipmentWindow"
	ui_root.add_child(equipment_window)
	equipment_window.set_options({
		"main_weapon": [{"id": "sword_shield", "name": "剑盾"}],
		"mount": [{"horse_id": "horse_chestnut_wind", "horse_name": "栗风"}],
	})
	await process_frame

	equipment_window.open_picker("main_weapon")
	await process_frame
	var weapon_button := equipment_window.get_picker_item_button("sword_shield") as Button
	_assert(weapon_button != null, "weapon picker button is missing")
	controller.debug_clear_history()
	weapon_button.pressed.emit()
	_assert_single_ui_sound(controller, "equipment_item_selected", "sfx_work_blacksmith_target_selected", 2.0)

	equipment_window.open_picker("mount")
	await process_frame
	var horse_button := equipment_window.get_picker_item_button("horse_chestnut_wind") as Button
	_assert(horse_button != null, "horse picker button is missing")
	controller.debug_clear_history()
	horse_button.pressed.emit()
	_assert_single_ui_sound(controller, "equipment_mount_selected", "sfx_ui_equipment_mount_selected", 0.0)

	equipment_window.queue_free()
	audio_manager.stop_all_one_shots()
	main.queue_free()
	await process_frame
	print("T0399_EQUIPMENT_SELECTION_AUDIO_PASS metal=UI+2dB horse=option02 duration=%.3fs overlap=none" % horse_duration)
	quit(0)


func _assert_single_ui_sound(controller: Node, semantic: String, asset_id: String, gain_db: float) -> void:
	var history: Array = controller.get_debug_snapshot().get("recent_history", [])
	_assert(history.size() == 1, "%s must replace, not overlap, the generic wood click" % semantic)
	if history.is_empty():
		return
	var entry: Dictionary = history.back()
	_assert(str(entry.get("kind", "")) == "ui", "%s is not a global UI sound" % semantic)
	_assert(str(entry.get("semantic", "")) == semantic, "wrong semantic for %s" % semantic)
	_assert(str(entry.get("asset_id", "")) == asset_id, "wrong asset for %s" % semantic)
	_assert(str(entry.get("bus", "")) == "UI", "%s is not controlled by click volume" % semantic)
	_assert(is_equal_approx(float(entry.get("gain_db", -999.0)), gain_db), "wrong gain for %s" % semantic)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)


func _fail(message: String) -> bool:
	push_error("T0399 equipment selection audio verification failed: %s" % message)
	quit(1)
	return false
