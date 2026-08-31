extends SceneTree


const MAIN_SCENE := "res://scenes/main/Main.tscn"
const STABLE_HORSE_ID := "horse_chestnut_wind"
const OUTSIDE_HORSE_ID := "horse_gray_mane"
const NORMAL_FILL := "71865aff"
const DANGER_FILL := "a7433bff"
const DANGER_LABEL := "dc6157ff"

var _failures: Array[String] = []


func _init() -> void:
	var packed := load(MAIN_SCENE) as PackedScene
	check(packed != null, "Main.tscn could not be loaded")
	if packed == null:
		finish()
		return
	root.add_child(packed.instantiate())
	for _frame in 8:
		await physics_frame
		await process_frame

	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var stable_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Stable/StableArt") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel") as Control
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel") as Control
	check(
		building_system != null and horse_system != null and stable_art != null and camera != null
		and horse_panel != null and building_panel != null,
		"T0250 runtime dependencies are missing"
	)
	if not _failures.is_empty():
		finish()
		return

	check(horse_panel.find_child("HorseAuthorityNote", true, false) == null, "HorsePanel still contains the redundant authority note")

	var outside_presentation: Dictionary = horse_system.get_horse_presentation_snapshot(OUTSIDE_HORSE_ID)
	var outside_world_position: Variant = outside_presentation.get("world_position", null)
	check(outside_world_position is Vector3, "Outside-click fixture horse position is unavailable")
	if not outside_world_position is Vector3:
		finish()
		return
	var outside_screen := camera.unproject_position((outside_world_position as Vector3) + Vector3.UP * 0.95)
	var horses: Dictionary = horse_system.get("_horses")
	var outside_horse: Dictionary = horses.get(OUTSIDE_HORSE_ID, {})
	outside_horse["location"] = "returning_stable"
	_send_world_click(building_system, outside_screen)
	await process_frame
	await process_frame
	var horse_panel_snapshot: Dictionary = horse_panel.debug_get_snapshot()
	check(
		horse_panel.visible and str(horse_panel_snapshot.get("horse_id", "")) == OUTSIDE_HORSE_ID,
		"Exact outside-horse click did not open HorsePanel: %s" % JSON.stringify(horse_panel_snapshot)
	)
	check(not str(horse_panel_snapshot.get("identity", "")).contains("模板"), "HorsePanel still exposes the horse template")
	check(not str(horse_panel_snapshot.get("status", "")).contains("厩"), "HorsePanel still exposes redundant stable presence text")
	check(not str(horse_panel_snapshot.get("slot", "")).contains("stall_") and not str(horse_panel_snapshot.get("slot", "")).contains("horse_anchor_"), "HorsePanel still exposes an internal stable slot id")
	check(not building_panel.visible, "Exact outside-horse click incorrectly left BuildingPanel visible")

	var stable_horse: Dictionary = horses.get(STABLE_HORSE_ID, {})
	stable_horse["care_bonus_hp"] = 0.0
	building_panel.show_building("stable")
	await process_frame
	await process_frame
	var horse_list := building_panel.find_child("HorseList", true, false) as VBoxContainer
	check(horse_list != null, "Stable horse list is missing")
	if horse_list != null:
		check(horse_list.get_child_count() == 1, "Stable list did not filter the outside horse: count=%d" % horse_list.get_child_count())
		check(horse_list.find_child("HorseBaseHP_%s" % OUTSIDE_HORSE_ID, true, false) == null, "Outside horse remained in the stable card list")
		var compact_header := ""
		for raw_label in horse_list.find_children("*", "Label", true, false):
			var label := raw_label as Label
			if label != null and label.text.begins_with("栗风｜"):
				compact_header = label.text
				break
		check(not compact_header.is_empty(), "Stable horse card compact header is missing")
		check(not compact_header.contains(STABLE_HORSE_ID) and not compact_header.contains("在厩") and not compact_header.contains("离厩"), "Stable horse card still exposes an internal id or redundant location: %s" % compact_header)
		check(compact_header.contains("马槽 1号") and not compact_header.contains("stall_") and not compact_header.contains("horse_anchor_"), "Stable horse card slot was not localized: %s" % compact_header)
		_verify_all_progress_rows(horse_list, false, false, "normal")

	var stable_snapshot: Dictionary = horse_system.get_horse_snapshot(STABLE_HORSE_ID)
	var natural_max_hp := float(stable_snapshot.get("natural_max_hp", 1.0))
	var max_satiety := float(stable_snapshot.get("max_satiety", 1.0))
	stable_horse["hp"] = natural_max_hp * 0.30
	stable_horse["satiety"] = max_satiety * 0.20
	building_panel.call("_refresh_horse_section")
	await process_frame
	await process_frame
	if horse_list != null:
		_verify_all_progress_rows(horse_list, false, false, "boundary")

	stable_horse["hp"] = natural_max_hp * 0.29
	stable_horse["satiety"] = max_satiety * 0.19
	building_panel.call("_refresh_horse_section")
	await process_frame
	await process_frame
	if horse_list != null:
		_verify_all_progress_rows(horse_list, true, true, "danger")

	stable_horse["hp"] = natural_max_hp * 0.30
	stable_horse["satiety"] = max_satiety * 0.20
	building_panel.call("_refresh_horse_section")
	await process_frame
	await process_frame
	if horse_list != null:
		_verify_all_progress_rows(horse_list, false, false, "recovered")

	finish()


func _verify_all_progress_rows(root_node: Node, hp_danger: bool, satiety_danger: bool, phase: String) -> void:
	_verify_progress(root_node, "HorseBaseHP_%s" % STABLE_HORSE_ID, hp_danger, phase)
	_verify_progress(root_node, "HorseSatiety_%s" % STABLE_HORSE_ID, satiety_danger, phase)
	_verify_progress(root_node, "HorseExtraHP_%s" % STABLE_HORSE_ID, false, phase)
	_verify_progress(root_node, "HorseGrowth_%s" % STABLE_HORSE_ID, false, phase)
	_verify_progress(root_node, "HorseBreedingProbability_%s" % STABLE_HORSE_ID, false, phase)


func _verify_progress(root_node: Node, control_name: String, expected_danger: bool, phase: String) -> void:
	var progress := root_node.find_child(control_name, true, false) as ProgressBar
	var label := root_node.find_child("%sLabel" % control_name, true, false) as Label
	check(progress != null and label != null, "%s progress row is missing" % control_name)
	if progress == null or label == null:
		return
	check(label.get_parent() == progress.get_parent() and label.get_index() < progress.get_index(), "%s label should be above its progress bar" % control_name)
	var fill := progress.get_theme_stylebox("fill") as StyleBoxFlat
	var fill_color := fill.bg_color.to_html(true) if fill != null else ""
	check(bool(progress.get_meta("danger_state", false)) == expected_danger, "%s danger state mismatch during %s" % [control_name, phase])
	check(fill_color == (DANGER_FILL if expected_danger else NORMAL_FILL), "%s fill color mismatch during %s: %s" % [control_name, phase, fill_color])
	var label_color := label.get_theme_color("font_color").to_html(true)
	if expected_danger:
		check(label_color == DANGER_LABEL, "%s danger label color mismatch: %s" % [control_name, label_color])
	else:
		check(label_color != DANGER_LABEL, "%s normal label stayed red" % control_name)


func _send_world_click(building_system: Node, screen_position: Vector2) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = screen_position
	event.pressed = true
	building_system.call("_unhandled_input", event)


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0250_STABLE_HORSE_UI_AND_CLICK PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0250_STABLE_HORSE_UI_AND_CLICK FAIL count=%d" % _failures.size())
	quit(1)
