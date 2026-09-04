extends SceneTree

const MAIN_MENU_SCENE := preload("res://scenes/frontend/MainMenu.tscn")
const MAIN_SCENE := preload("res://scenes/main/Main.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var menu := MAIN_MENU_SCENE.instantiate()
	root.add_child(menu)
	await _settle_layout()
	var compact := _read_main_menu_layout(menu)
	if not _validate_main_menu(compact, "1280x720"):
		return

	root.size = Vector2i(1920, 1080)
	await _settle_layout()
	var maximized := _read_main_menu_layout(menu)
	if not _validate_main_menu(maximized, "1920x1080"):
		return
	if absf(float(compact.title_gap) - float(maximized.title_gap)) > 1.0:
		_fail("Title/subtitle gap changed after resize: %s -> %s" % [compact.title_gap, maximized.title_gap])
		return
	if absf(float(compact.panel_height) - float(maximized.panel_height)) > 1.0:
		_fail("Main menu panel stretched after resize: %s -> %s" % [compact.panel_height, maximized.panel_height])
		return
	menu.queue_free()
	await process_frame

	root.size = Vector2i(1920, 1080)
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	for _index in range(8):
		await process_frame
	var pause_menu := main.get_node_or_null("UI/PauseMenu") as Control
	if pause_menu == null:
		_fail("PauseMenu is missing")
		return
	pause_menu.open_menu()
	await _settle_layout()
	var pause_window := pause_menu.find_child("PauseWindow", true, false) as Control
	var pause_status := pause_menu.find_child("PauseStatus", true, false) as Control
	var quick_button := pause_menu.find_child("QuickSaveButton", true, false) as Button
	if pause_window == null or pause_status == null or quick_button == null:
		_fail("Pause menu layout controls are missing")
		return
	var pause_bottom_gap := pause_window.get_global_rect().end.y - pause_status.get_global_rect().end.y
	if pause_window.size.y > 515.0 or pause_bottom_gap > 30.0:
		_fail("Pause panel still has excessive bottom space: height=%s gap=%s" % [pause_window.size.y, pause_bottom_gap])
		return
	if not _has_transparent_focus(quick_button):
		_fail("Quick save focus style still covers its normal button background")
		return

	var pause_height := pause_window.size.y
	main.queue_free()
	await process_frame
	print("T0356_FRONTEND_RESPONSIVE_LAYOUT_PASS main_panel=%s pause_panel=%s title_gap=%s focus=outline" % [maximized.panel_height, pause_height, maximized.title_gap])
	quit(0)


func _settle_layout() -> void:
	for _index in range(4):
		await process_frame


func _read_main_menu_layout(menu: Control) -> Dictionary:
	var panel := menu.find_child("MenuPanel", true, false) as Control
	var title := menu.find_child("GameTitle", true, false) as Control
	var subtitle := menu.find_child("Subtitle", true, false) as Control
	var exit_button := menu.find_child("ExitButton", true, false) as Control
	var start_button := menu.find_child("StartButton", true, false) as Button
	return {
		"panel_height": panel.size.y,
		"panel_bottom_gap": panel.get_global_rect().end.y - exit_button.get_global_rect().end.y,
		"title_gap": subtitle.get_global_rect().position.y - title.get_global_rect().end.y,
		"panel_inside_viewport": panel.get_global_rect().end.y <= float(root.size.y) + 0.5,
		"start_focus_ok": _has_transparent_focus(start_button),
	}


func _validate_main_menu(layout: Dictionary, size_label: String) -> bool:
	if float(layout.panel_height) > 325.0 or float(layout.panel_bottom_gap) > 34.0:
		_fail("Main menu panel has excess space at %s: %s" % [size_label, layout])
		return false
	if absf(float(layout.title_gap)) > 2.0:
		_fail("Title/subtitle gap is not compact at %s: %s" % [size_label, layout])
		return false
	if not bool(layout.panel_inside_viewport):
		_fail("Main menu panel leaves the viewport at %s: %s" % [size_label, layout])
		return false
	if not bool(layout.start_focus_ok):
		_fail("Start button focus style covers its normal background at %s" % size_label)
		return false
	return true


func _has_transparent_focus(button: Button) -> bool:
	if button == null or button.disabled:
		return false
	var focus := button.get_theme_stylebox("focus") as StyleBoxFlat
	return focus != null and focus.bg_color.a <= 0.01 and focus.border_width_left >= 1


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
