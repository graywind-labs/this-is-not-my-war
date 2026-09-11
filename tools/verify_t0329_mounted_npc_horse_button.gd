extends SceneTree


func _init() -> void:
	root.size = Vector2i(1152, 648)
	DisplayServer.window_set_size(root.size)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("T0329 could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel")
	if [npc_system, horse_system, npc_panel, horse_panel].has(null):
		_fail("T0329 required systems or panels are missing")
		return

	var npc_id := "veteran_deputy_01"
	npc_panel.debug_set_layout_viewport_override(Vector2(1152, 648))
	npc_system.debug_select_npc(npc_id)
	await process_frame
	await process_frame
	await process_frame
	var unmounted: Dictionary = npc_panel.debug_get_equipment_window_snapshot()
	if bool(unmounted.get("mount_view_button_visible", true)):
		_fail("T0329 unmounted NPC exposed the horse button")
		return

	var available: Array = horse_system.get_available_horses_for_npc(npc_id)
	if available.is_empty():
		_fail("T0329 fixture has no assignable adult horse")
		return
	var horse_id := str((available[0] as Dictionary).get("horse_id", ""))
	var assign_result: Dictionary = horse_system.assign_horse_to_npc(npc_id, horse_id, "private")
	if not bool(assign_result.get("ok", false)):
		_fail("T0329 could not assign fixture horse: %s" % JSON.stringify(assign_result))
		return
	await process_frame
	var assigned_only: Dictionary = npc_panel.debug_get_equipment_window_snapshot()
	if bool(assigned_only.get("mount_view_button_visible", true)):
		_fail("T0329 assigned-but-unmounted NPC exposed the horse button")
		return

	# This is a UI fixture for the already-covered riding lifecycle: commit the
	# same matched horse/NPC fields that HorseSystem writes at rendezvous completion.
	var horse: Dictionary = horse_system._horses[horse_id]
	horse["location"] = "ridden"
	horse["ridden_by_npc_id"] = npc_id
	horse_system._horses[horse_id] = horse
	npc_system.update_npc_state(npc_id, {
		"combat_mounted": true,
		"combat_mount_phase": "mounted",
		"behavior_mode": "combat",
	})
	await process_frame
	await process_frame

	var mounted: Dictionary = npc_panel.debug_get_equipment_window_snapshot()
	if (
		not bool(mounted.get("mount_view_button_visible", false))
		or str(mounted.get("mount_view_button_horse_id", "")) != horse_id
	):
		_fail("T0329 mounted NPC horse button mismatch: %s" % JSON.stringify(mounted))
		return

	var opened: Dictionary = npc_panel.debug_toggle_equipment_window()
	await process_frame
	if not bool(opened.get("visible", false)):
		_fail("T0329 equipment window did not open")
		return
	if not _verify_layout(npc_panel.debug_get_equipment_window_snapshot()):
		return

	root.size = Vector2i(2048, 1109)
	DisplayServer.window_set_size(root.size)
	npc_panel.debug_set_layout_viewport_override(Vector2(2048, 1109))
	await process_frame
	await process_frame
	await process_frame
	if not _verify_layout(npc_panel.debug_get_equipment_window_snapshot()):
		return

	var horse_before: Dictionary = horse_system.get_horse_snapshot(horse_id)
	var npc_state_before: Dictionary = npc_system.get_npc_state(npc_id)
	npc_panel.debug_press_mount_view_button()
	await process_frame
	var horse_panel_snapshot: Dictionary = horse_panel.debug_get_snapshot()
	if npc_panel.visible or not bool(horse_panel_snapshot.get("visible", false)) or str(horse_panel_snapshot.get("horse_id", "")) != horse_id:
		_fail("T0329 horse button did not reproduce direct horse selection: %s" % JSON.stringify(horse_panel_snapshot))
		return
	var horse_after: Dictionary = horse_system.get_horse_snapshot(horse_id)
	var npc_state_after: Dictionary = npc_system.get_npc_state(npc_id)
	if (
		str(horse_after.get("location", "")) != str(horse_before.get("location", ""))
		or str(horse_after.get("assigned_npc_id", "")) != str(horse_before.get("assigned_npc_id", ""))
		or str(horse_after.get("ridden_by_npc_id", "")) != str(horse_before.get("ridden_by_npc_id", ""))
		or bool(npc_state_after.get("combat_mounted", false)) != bool(npc_state_before.get("combat_mounted", false))
	):
		_fail("T0329 UI navigation changed riding authority state")
		return

	print("T0329 mounted NPC horse button verification passed.")
	quit(0)


func _verify_layout(snapshot: Dictionary) -> bool:
	var equipment_rect: Rect2 = snapshot.get("global_rect", Rect2())
	var info_rect: Rect2 = snapshot.get("info_panel_rect", Rect2())
	var button_rect: Rect2 = snapshot.get("mount_view_button_rect", Rect2())
	var npc_panel := root.get_node("Main/UI/NPCPanel")
	var portrait := npc_panel.find_child("NPCPortraitView", true, false) as Control
	var portrait_rect := portrait.get_global_rect() if portrait != null else Rect2()
	if equipment_rect.size != Vector2(316.0, 332.0):
		_fail("T0329 changed equipment window size: %s" % equipment_rect)
		return false
	if absf(equipment_rect.end.y - info_rect.end.y) > 1.0:
		_fail("T0329 equipment and NPC panel bottoms are not aligned: equipment=%s info=%s" % [equipment_rect, info_rect])
		return false
	if (
		button_rect.position.y < portrait_rect.end.y - 1.0
		or button_rect.end.y > equipment_rect.position.y + 1.0
		or absf(button_rect.end.x - portrait_rect.end.x) > 1.0
	):
		_fail("T0329 horse button is not between the portrait and equipment or next to the info panel: button=%s portrait=%s equipment=%s" % [button_rect, portrait_rect, equipment_rect])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
