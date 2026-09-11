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

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var alert := root.get_node_or_null("Main/UI/HUD/EscapeStartedAlertDialog") as AcceptDialog
	if combat_system == null or npc_system == null or memory_system == null or alert == null:
		_fail("T0286 escape alert required nodes not found")
		return
	if alert.get_ok_button().text != "好的" or alert.visible:
		_fail("T0286 escape alert initial state or button text mismatch")
		return

	npc_system.update_npc_state("engineer_01", {
		"first_sleep_summary_active": true,
		"current_action": "first_sleep_summary"
	})
	var blocked: Dictionary = combat_system.debug_start_npc_escape("engineer_01", "t0286_blocked")
	if bool(blocked.get("ok", false)) or alert.visible:
		_fail("A rejected escape request displayed the alert: %s" % JSON.stringify(blocked))
		return
	npc_system.update_npc_state("engineer_01", {
		"first_sleep_summary_active": false,
		"current_action": "idle"
	})

	var cook_result: Dictionary = combat_system.debug_start_npc_escape("cook_01", "t0286_first")
	if (
		not bool(cook_result.get("ok", false))
		or not bool(cook_result.get("applied", false))
		or not alert.visible
		or not alert.dialog_text.contains("布鲁诺正在逃离驿站")
		or _latest_event(memory_system.get_npc_daily_events("cook_01"), "escape_started").is_empty()
	):
		_fail("A committed escape did not display the correct alert and event: %s" % JSON.stringify(cook_result))
		return

	var priest_result: Dictionary = combat_system.debug_start_npc_escape("priest_01", "t0286_queued")
	if not bool(priest_result.get("applied", false)) or not alert.dialog_text.contains("布鲁诺正在逃离驿站"):
		_fail("Second escape did not queue behind the visible alert")
		return
	alert.get_ok_button().pressed.emit()
	await process_frame
	if not alert.visible or not alert.dialog_text.contains("马塞尔正在逃离驿站"):
		_fail("Queued escape alert did not advance after clicking 好的")
		return
	alert.get_ok_button().pressed.emit()
	await process_frame
	if alert.visible:
		_fail("Escape alert queue did not close after the final 好的 click")
		return

	var duplicate: Dictionary = combat_system.debug_start_npc_escape("cook_01", "t0286_duplicate")
	if not bool(duplicate.get("ok", false)) or bool(duplicate.get("applied", true)) or alert.visible:
		_fail("Already-escaping duplicate request displayed another alert: %s" % JSON.stringify(duplicate))
		return

	print("T0286_ESCAPE_ALERT_OK")
	quit(0)


func _latest_event(events: Array, event_type: String) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index] if events[index] is Dictionary else {}
		if str(event.get("type", "")) == event_type:
			return event
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
