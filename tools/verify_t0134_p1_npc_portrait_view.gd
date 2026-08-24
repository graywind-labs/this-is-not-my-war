extends SceneTree

var _failures: Array[String] = []


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	check(packed != null, "Main.tscn could not be loaded")
	if packed == null:
		finish()
		return
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	await physics_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	var event_bus := root.get_node_or_null("EventBus")
	check(npc_system != null and npc_panel != null and event_bus != null, "Portrait verification dependencies are missing")
	if npc_system == null or npc_panel == null or event_bus == null:
		finish()
		return

	var npc_count_before := int(npc_system.get_npc_count())
	var glen_before: Dictionary = npc_system.get_npc("blacksmith_01")
	var main_camera_before := main.get_viewport().get_camera_3d()
	npc_panel.call("debug_set_layout_viewport_override", Vector2(1280, 720))
	check(bool(npc_system.debug_select_npc("blacksmith_01")), "Could not select Glen")
	for _frame in 5:
		await process_frame

	var portrait := npc_panel.find_child("NPCPortraitView", true, false)
	var portrait_camera := npc_panel.find_child("PortraitCamera", true, false) as Camera3D
	var portrait_viewport := npc_panel.find_child("PortraitSubViewport", true, false) as SubViewport
	var snapshot: Dictionary = npc_panel.call("debug_get_portrait_snapshot")
	check(npc_panel.visible, "NPC panel did not open with the portrait")
	check(portrait != null and portrait_camera != null and portrait_viewport != null, "Portrait frame, viewport, or camera is missing")
	check(bool(snapshot.get("active", false)) and bool(snapshot.get("rendering_enabled", false)), "Portrait renderer is not active while NPCPanel is open")
	check(str(snapshot.get("target_npc_id", "")) == "blacksmith_01", "Portrait target does not follow selected NPC")
	check(bool(snapshot.get("shares_main_world", false)), "Portrait does not share Main World3D")
	check(float(snapshot.get("camera_front_dot", -1.0)) > 0.95, "Portrait camera is not in front of the visible NPC")
	check(float(snapshot.get("configured_camera_distance", 0.0)) >= 3.8, "Portrait camera was not pulled back for full-body margin")
	var target_snapshot: Dictionary = snapshot.get("target_snapshot", {}) if snapshot.get("target_snapshot", {}) is Dictionary else {}
	check(str(target_snapshot.get("npc_id", "")) == "blacksmith_01", "Portrait is not reading Glen's real entity snapshot")
	check(not bool(snapshot.get("status_visible", true)), "Portrait fallback text remained over a valid NPC")
	check(not bool(snapshot.get("has_title_label", true)), "Portrait kept the redundant title label")
	check(not bool(snapshot.get("has_location_label", true)), "Portrait kept the redundant location label")
	check(main.get_viewport().get_camera_3d() == main_camera_before, "Portrait camera replaced the main gameplay camera")
	check(int(npc_system.get_npc_count()) == npc_count_before, "Portrait duplicated an NPC entity")
	check(npc_system.get_npc("blacksmith_01") == glen_before, "Opening the portrait mutated Glen's authoritative profile")
	check_layout(snapshot, Vector2(1280, 720), "1280x720")

	npc_panel.call("show_npc", "gardener_01")
	for _frame in 4:
		await process_frame
	var switched: Dictionary = npc_panel.call("debug_get_portrait_snapshot")
	check(str(switched.get("target_npc_id", "")) == "gardener_01", "Portrait did not switch to Ivo")
	var switched_target: Dictionary = switched.get("target_snapshot", {}) if switched.get("target_snapshot", {}) is Dictionary else {}
	check(str(switched_target.get("npc_id", "")) == "gardener_01", "Portrait still reads the previous NPC entity")
	check(float(switched.get("camera_front_dot", -1.0)) > 0.95, "Portrait did not reframe Ivo from the front")

	npc_panel.call("debug_set_layout_viewport_override", Vector2(1920, 1080))
	root.size = Vector2i(1920, 1080)
	DisplayServer.window_set_size(root.size)
	for _frame in 4:
		await process_frame
	var large_layout: Dictionary = npc_panel.call("debug_get_portrait_snapshot")
	check_layout(large_layout, Vector2(1920, 1080), "1920x1080")

	var close_button := npc_panel.find_child("NPCPanelCloseButton", true, false) as Button
	check(close_button != null, "NPCPanel close button is missing")
	if close_button != null:
		close_button.pressed.emit()
		await process_frame
		var closed: Dictionary = npc_panel.call("debug_get_portrait_snapshot")
		check(not npc_panel.visible, "NPCPanel did not close")
		check(not bool(closed.get("active", true)) and not bool(closed.get("rendering_enabled", true)), "Portrait kept rendering after NPCPanel closed")

	npc_panel.call("show_npc", "blacksmith_01")
	await process_frame
	event_bus.building_clicked.emit("main_hall")
	await process_frame
	var building_closed: Dictionary = npc_panel.call("debug_get_portrait_snapshot")
	check(not npc_panel.visible, "Building selection did not hide NPCPanel")
	check(not bool(building_closed.get("rendering_enabled", true)), "Portrait kept rendering after building selection")
	check(int(npc_system.get_npc_count()) == npc_count_before, "Portrait lifecycle changed the NPC entity count")
	main.queue_free()
	await process_frame
	finish()


func check_layout(snapshot: Dictionary, viewport_size: Vector2, label: String) -> void:
	var panel_rect: Rect2 = snapshot.get("panel_global_rect", Rect2())
	var frame_rect: Rect2 = snapshot.get("frame_global_rect", Rect2())
	var info_rect: Rect2 = snapshot.get("info_global_rect", Rect2())
	print("PORTRAIT_LAYOUT %s panel=%s frame=%s info=%s" % [label, panel_rect, frame_rect, info_rect])
	check(panel_rect.position.x >= -1.0 and panel_rect.end.x <= viewport_size.x + 1.0, "%s portrait panel leaves the horizontal viewport: %s" % [label, panel_rect])
	check(panel_rect.position.y >= -1.0 and panel_rect.end.y <= viewport_size.y + 1.0, "%s portrait panel leaves the vertical viewport" % label)
	check(frame_rect.size.x >= 170.0 and frame_rect.size.x <= 220.0, "%s compact portrait width is outside its intended range: %s" % [label, frame_rect])
	check(frame_rect.size.y >= 280.0, "%s compact portrait is too short for a readable full body" % label)
	check(frame_rect.size.y <= info_rect.size.y * 0.56 + 1.0, "%s portrait no longer stays in the upper half of NPCPanel: frame=%s info=%s" % [label, frame_rect, info_rect])
	check(absf(frame_rect.position.y - info_rect.position.y) <= 1.0, "%s portrait is not aligned to the upper edge of NPCPanel" % label)
	check(frame_rect.end.x + 8.0 <= info_rect.position.x, "%s portrait frame overlaps the NPC information column: frame=%s info=%s" % [label, frame_rect, info_rect])
	check(absf(panel_rect.end.x - (viewport_size.x - 16.0)) <= 2.0, "%s NPCPanel lost its right safe margin: %s" % [label, panel_rect])


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0134_P1_NPC_PORTRAIT_VIEW PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0134_P1_NPC_PORTRAIT_VIEW FAIL count=%d" % _failures.size())
	quit(1)
