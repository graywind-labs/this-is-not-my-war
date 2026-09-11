extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	for _frame in range(8):
		await process_frame
	var notice_board := root.get_node_or_null("Main/WorldRoot/FormalStationLayout/PublicProps/NoticeBoard")
	var notice_panel := root.get_node_or_null("Main/UI/NoticeBoardPanel")
	if memory_system == null or npc_system == null or building_system == null or notice_board == null or notice_panel == null:
		_fail("T1506 required nodes or systems are missing")
		return
	if building_system.get_building_ids().has("notice_board"):
		_fail("Notice board must not be registered as a building")
		return
	if root.get_node_or_null("Main/WorldRoot/Station/Buildings/NoticeBoard") != null:
		_fail("Notice board must be an independent prop, not a child of Buildings")
		return
	var art_snapshot: Dictionary = notice_board.get_debug_art_snapshot()
	if str(art_snapshot.get("art_revision", "")) != "t0132_p6" or int(art_snapshot.get("paper_sheet_count", 0)) != 3:
		_fail("Formal standing notice board visual is incomplete")
		return
	if notice_board.get_node_or_null("NoticeBoardClickArea/CollisionShape3D") == null:
		_fail("Notice board click area was not created")
		return

	var plaza_npc_id := "priest_01"
	var indoor_npc_id := "doctor_01"
	npc_system.debug_enter_location_immediately(plaza_npc_id, "plaza")
	npc_system.debug_enter_location_immediately(indoor_npc_id, "clinic")
	var plaza_witness_before: int = memory_system.get_npc_witness_events(plaza_npc_id).size()
	var indoor_witness_before: int = memory_system.get_npc_witness_events(indoor_npc_id).size()
	var plaza_events_before: int = memory_system.get_plaza_events().size()

	var camera := root.get_node_or_null("Main/CameraRig/Camera3D") as Camera3D
	if camera == null:
		_fail("Notice board click verification camera is missing")
		return
	var click_position := camera.unproject_position(notice_board.global_position + Vector3(0.0, 1.65, 0.12))
	if not notice_board._is_notice_board_at_screen_position(click_position):
		_fail("Camera ray did not hit the independent notice board click area")
		return
	var click_event := InputEventMouseButton.new()
	click_event.position = click_position
	click_event.button_index = MOUSE_BUTTON_LEFT
	click_event.pressed = true
	notice_board._unhandled_input(click_event)
	await process_frame
	if not notice_panel.visible:
		_fail("Notice board activation did not open the input panel")
		return
	var text_edit := notice_panel.find_child("NoticeTextEdit", true, false) as TextEdit
	if text_edit == null:
		_fail("Notice board text input is missing")
		return
	var notice_text := "今晚在主厅前集合，守备官会说明防线安排。"
	text_edit.text = notice_text
	notice_panel._on_publish_pressed()

	var plaza_snapshot: Dictionary = memory_system.get_location_snapshot("plaza")
	if str(plaza_snapshot.get("current_notice", "")) != notice_text:
		_fail("Published notice was not stored in plaza current state")
		return
	if memory_system.get_plaza_events().size() != plaza_events_before + 1:
		_fail("Publishing a notice did not create exactly one plaza event")
		return
	var event: Dictionary = memory_system.get_plaza_events()[-1]
	if str(event.get("type", "")) != "plaza_notice_changed":
		_fail("Published notice did not create plaza_notice_changed")
		return
	if not event.get("actor_ids", []).has("guard_officer"):
		_fail("Notice event did not retain guard officer as actor")
		return
	if str(event.get("visibility", "")) != "local_public" or str(event.get("location_id", "")) != "plaza":
		_fail("Notice event did not use plaza local_public visibility")
		return
	if memory_system.get_npc_witness_events(plaza_npc_id).size() != plaza_witness_before + 1:
		_fail("Current plaza NPC did not receive notice witness")
		return
	if memory_system.get_npc_witness_events(indoor_npc_id).size() != indoor_witness_before + 1:
		_fail("Indoor NPC did not receive the all-station notice witness")
		return
	if not str(event.get("summary", "")).contains("守备官更新了通告"):
		_fail("Notice event summary did not identify the guard officer notice update")
		return
	var board_label := notice_board.get_node_or_null("VisualRoot/NoticeBoardLabel") as Label3D
	if board_label == null or not board_label.text.contains("今晚在主厅前集合"):
		_fail("World notice board preview did not refresh")
		return

	var event_count_after_publish: int = memory_system.get_plaza_events().size()
	notice_panel._on_publish_pressed()
	if memory_system.get_plaza_events().size() != event_count_after_publish:
		_fail("Publishing unchanged notice should not duplicate the event")
		return

	text_edit.text = ""
	notice_panel._on_publish_pressed()
	if not str(memory_system.get_location_snapshot("plaza").get("current_notice", "")).is_empty():
		_fail("Publishing blank text did not clear plaza current notice")
		return
	if memory_system.get_plaza_events().size() != event_count_after_publish + 1:
		_fail("Clearing the notice did not create exactly one plaza event")
		return

	print("T1506 notice board input verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
