extends SceneTree


const MAIN_SCENE := "res://scenes/main/Main.tscn"
const HORSE_ID := "horse_gray_mane"

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
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var stable_art := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/BuildingRoots/Stable/StableArt") as Node3D
	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel") as Control
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel") as Control
	check(
		building_system != null and horse_system != null and npc_system != null
		and stable_art != null and camera != null and horse_panel != null and building_panel != null,
		"T0170 runtime dependencies are missing"
	)
	if not _failures.is_empty():
		finish()
		return

	var horse_presentation: Dictionary = horse_system.get_horse_presentation_snapshot(HORSE_ID)
	var horse_position: Variant = horse_presentation.get("world_position", null)
	check(horse_position is Vector3, "Gray Mane world position is unavailable")
	if not horse_position is Vector3:
		finish()
		return
	var horse_screen := camera.unproject_position((horse_position as Vector3) + Vector3.UP * 0.95)

	stable_art.apply_roof_camera_distance(56.0, 1.0)
	await process_frame
	check(stable_art.is_interior_revealed_for_selection(), "Near transparent stable did not enable unit-first selection")
	var transparent_art_hit: Dictionary = building_system.call("_pick_specific_building_art_view_at_screen_position", horse_screen, "stable")
	check(
		str(transparent_art_hit.get("building_id", "")) == "stable" and bool(transparent_art_hit.get("interior_revealed", false)),
		"Horse screen point did not resolve to the transparent stable bounds: %s" % JSON.stringify(transparent_art_hit)
	)
	var horse_hit: Dictionary = horse_system.get_world_click_interaction(horse_screen)
	check(str(horse_hit.get("horse_id", "")) == HORSE_ID, "Exact horse ray did not identify Gray Mane: %s" % JSON.stringify(horse_hit))
	_send_world_click(building_system, horse_screen)
	await process_frame
	await process_frame
	var horse_panel_snapshot: Dictionary = horse_panel.debug_get_snapshot()
	check(
		horse_panel.visible and str(horse_panel_snapshot.get("horse_id", "")) == HORSE_ID,
		"Transparent stable click did not open Gray Mane HorsePanel: %s" % JSON.stringify(horse_panel_snapshot)
	)
	check(not building_panel.visible, "Transparent exact horse click also left BuildingPanel visible")

	var empty_screen := _find_empty_stable_screen(stable_art, camera, horse_system, npc_system)
	check(empty_screen != Vector2.INF, "Could not find an empty stable screen point")
	if empty_screen != Vector2.INF:
		_send_world_click(building_system, empty_screen)
		await process_frame
		await process_frame
		check(building_panel.visible and str(building_panel.get("_current_building_id")) == "stable", "Transparent stable empty-space click did not open BuildingPanel")
		check(not horse_panel.visible, "Transparent stable empty-space click left HorsePanel visible")

	stable_art.apply_roof_camera_distance(72.0, 0.0)
	await process_frame
	check(not stable_art.is_interior_revealed_for_selection(), "Opaque stable still exposes unit-first selection")
	_send_world_click(building_system, horse_screen)
	await process_frame
	await process_frame
	check(building_panel.visible and str(building_panel.get("_current_building_id")) == "stable", "Opaque stable horse point did not select the building")
	check(not horse_panel.visible, "Opaque stable horse point incorrectly opened HorsePanel")

	finish()


func _find_empty_stable_screen(stable_art: Node3D, camera: Camera3D, horse_system: Node, npc_system: Node) -> Vector2:
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	for local_position in [
		Vector3(0.0, 0.2, 5.2), Vector3(0.0, 0.2, 3.8), Vector3(0.0, 0.2, 2.2),
		Vector3(0.0, 0.2, 0.0), Vector3(0.0, 0.2, -2.2), Vector3(0.0, 0.2, -4.0)
	]:
		var screen_position := camera.unproject_position(stable_art.to_global(local_position))
		if not horse_system.get_world_click_interaction(screen_position).is_empty():
			continue
		if not npc_system.get_world_click_interaction(screen_position).is_empty():
			continue
		var art_hit: Dictionary = building_system.call("_pick_building_art_view_at_screen_position", screen_position)
		if str(art_hit.get("building_id", "")) != "stable":
			continue
		return screen_position
	return Vector2.INF


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
		print("T0170_TRANSPARENT_STABLE_HORSE_CLICK PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0170_TRANSPARENT_STABLE_HORSE_CLICK FAIL count=%d" % _failures.size())
	quit(1)
