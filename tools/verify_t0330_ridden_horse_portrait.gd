extends SceneTree


func _init() -> void:
	root.size = Vector2i(1152, 648)
	DisplayServer.window_set_size(root.size)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("T0330 could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var horse_panel := root.get_node_or_null("Main/UI/HorsePanel")
	if [npc_system, horse_system, horse_panel].has(null):
		_fail("T0330 required systems or HorsePanel are missing")
		return

	var npc_id := "veteran_deputy_01"
	var available: Array = horse_system.get_available_horses_for_npc(npc_id)
	if available.is_empty():
		_fail("T0330 fixture has no assignable adult horse")
		return
	var horse_id := str((available[0] as Dictionary).get("horse_id", ""))
	var assign_result: Dictionary = horse_system.assign_horse_to_npc(npc_id, horse_id, "private")
	if not bool(assign_result.get("ok", false)):
		_fail("T0330 could not assign fixture horse: %s" % JSON.stringify(assign_result))
		return
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

	var target: Dictionary = horse_system.get_horse_presentation_snapshot(horse_id)
	if (
		str(target.get("source_location", "")) != "mounted_rider"
		or str(target.get("target_kind", "")) != "mounted_horse_head"
		or str(target.get("focus_source", "")) != "Head"
		or str(target.get("rider_npc_id", "")) != npc_id
		or not str(target.get("target_node_path", "")).contains("CombatMountVisual/HorseModel")
	):
		_fail("T0330 mounted presentation did not resolve the rider-owned horse head: %s" % JSON.stringify(target))
		return

	var event_bus := root.get_node("EventBus")
	event_bus.horse_clicked.emit(horse_id)
	await process_frame
	await process_frame
	var panel_snapshot: Dictionary = horse_panel.debug_get_snapshot()
	var portrait: Dictionary = panel_snapshot.get("portrait", {})
	var portrait_target: Dictionary = portrait.get("target_snapshot", {})
	if (
		not bool(panel_snapshot.get("visible", false))
		or bool(portrait.get("status_visible", true))
		or str(portrait_target.get("target_kind", "")) != "mounted_horse_head"
		or float(portrait.get("camera_front_dot", 0.0)) < 0.98
		or (portrait.get("focus_position", Vector3.ZERO) as Vector3).distance_to(target.get("focus_world_position", Vector3.ZERO)) > 0.01
	):
		_fail("T0330 HorsePanel did not frame the mounted horse head from the front: %s" % JSON.stringify(panel_snapshot))
		return

	var npc_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/VeteranDeputy01") as Node3D
	var mount_visual := npc_node.get_node_or_null("CombatMountVisual") as Node3D if npc_node != null else null
	if npc_node == null or not npc_node.is_visible_in_tree() or mount_visual == null or not mount_visual.is_visible_in_tree():
		_fail("T0330 hid the rider or the real mounted horse while opening HorsePanel")
		return

	horse = horse_system._horses[horse_id]
	horse["location"] = "stable"
	horse["ridden_by_npc_id"] = ""
	horse_system._horses[horse_id] = horse
	npc_system.update_npc_state(npc_id, {
		"combat_mounted": false,
		"combat_mount_phase": "",
		"behavior_mode": "work",
	})
	event_bus.horse_state_changed.emit(horse_id)
	await process_frame
	await process_frame
	var stable_target: Dictionary = horse_system.get_horse_presentation_snapshot(horse_id)
	if stable_target.is_empty() or str(stable_target.get("source_location", "")) != "stable":
		_fail("T0330 did not restore the independent horse presentation after unmount: %s" % JSON.stringify(stable_target))
		return

	print("T0330 ridden horse head portrait verification passed.")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
