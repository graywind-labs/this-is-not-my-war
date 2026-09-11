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

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var alert := root.get_node_or_null("Main/UI/HUD/NpcRevivedAlertDialog") as AcceptDialog
	if npc_system == null or alert == null:
		_fail("T0310 revive alert required nodes not found")
		return
	if alert.visible or alert.get_ok_button().text != "太好了":
		_fail("T0310 revive alert initial state or button text mismatch")
		return

	var first_id := "cook_01"
	var second_id := "priest_01"
	var first_name := str(npc_system.get_npc(first_id).get("name", first_id))
	var second_name := str(npc_system.get_npc(second_id).get("name", second_id))
	if not _make_unconscious(npc_system, first_id) or not _make_unconscious(npc_system, second_id):
		return

	var first_recovery: Dictionary = npc_system.debug_advance_unconscious_recovery(first_id, 200000.0)
	await process_frame
	if (
		not (first_recovery.get("revived", []) as Array).has(first_id)
		or not alert.visible
		or alert.dialog_text != "%s从昏迷中苏醒了。" % first_name
	):
		_fail("T0310 first formal revive did not display the correct alert: %s" % JSON.stringify(first_recovery))
		return

	var second_recovery: Dictionary = npc_system.debug_advance_unconscious_recovery(second_id, 200000.0)
	await process_frame
	if not (second_recovery.get("revived", []) as Array).has(second_id) or alert.dialog_text != "%s从昏迷中苏醒了。" % first_name:
		_fail("T0310 second revive did not queue behind the visible alert")
		return

	alert.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	if not alert.visible or alert.dialog_text != "%s从昏迷中苏醒了。" % second_name:
		_fail("T0310 queued revive alert did not advance after clicking 太好了")
		return

	alert.get_ok_button().pressed.emit()
	await process_frame
	await process_frame
	if alert.visible:
		_fail("T0310 revive alert queue did not close after the final 太好了 click")
		return

	print("T0310_NPC_REVIVE_ALERT_OK")
	quit(0)


func _make_unconscious(npc_system: Node, npc_id: String) -> bool:
	var damage_result: Dictionary = npc_system.debug_damage_npc(npc_id, 9999, "private")
	if not bool(damage_result.get("ok", false)) or not bool(npc_system.get_npc_state(npc_id).get("unconscious", false)):
		_fail("T0310 could not make %s unconscious" % npc_id)
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
