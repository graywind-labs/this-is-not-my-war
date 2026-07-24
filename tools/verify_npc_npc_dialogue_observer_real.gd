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
	var dialog_system := root.get_node_or_null("Main/Systems/DialogSystem")
	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var dialog_panel := root.get_node_or_null("Main/UI/DialogPanel") as Control
	var status_label := root.get_node_or_null("Main/UI/DialogPanel/PanelContainer/MarginContainer/Content/DialogStatusLabel") as Label
	if [npc_system, dialog_system, llm_bridge, time_system, dialog_panel, status_label].has(null):
		_fail("Real observer verification required nodes not found")
		return
	var backend_url := OS.get_environment("TEST_BACKEND_URL").strip_edges()
	if backend_url.is_empty():
		backend_url = "http://127.0.0.1:5000"
	llm_bridge.set_backend_base_url(backend_url)
	time_system.set_paused(false)
	time_system.set_time_scale(4.0)

	if not npc_system.debug_enter_location_immediately("doctor_01", "plaza") or not npc_system.debug_enter_location_immediately("cook_01", "plaza"):
		_fail("Could not place real-dialogue participants in plaza")
		return
	var start_result: Dictionary = dialog_system.start_autonomous_npc_dialogue(
		"doctor_01",
		"cook_01",
		"布鲁诺，能接受一次很短的交谈吗？只确认今晚的面包放在食堂；确认后我们就告别，各自回去做事。",
		"local_public",
		5,
		true
	)
	if not bool(start_result.get("ok", false)) or not bool(start_result.get("pending", false)):
		_fail("Could not start real autonomous NPC dialogue: %s" % JSON.stringify(start_result))
		return
	await process_frame
	var runtime_snapshot: Dictionary = llm_bridge.debug_get_llm_runtime_snapshot()
	if int(runtime_snapshot.get("pending_slowdown_count", 0)) != 1:
		_fail("Real autonomous dialogue did not register exactly one slowdown")
		return
	var active_audits: Dictionary = runtime_snapshot.get("active_slowdown_audit", {})
	var invitation_request_id := str(start_result.get("request_id", ""))
	var active_audit: Dictionary = active_audits.get(invitation_request_id, {}) if active_audits.get(invitation_request_id, {}) is Dictionary else {}
	if str(active_audit.get("call_type", "")) != "dialogue" or str(active_audit.get("reason", "")) != "llm_dialogue_wait":
		_fail("Real autonomous dialogue slowdown audit mismatch: %s" % JSON.stringify(active_audit))
		return
	if float(time_system.get_effective_time_scale()) >= 1.0:
		_fail("Real autonomous dialogue did not reduce effective time scale")
		return

	var doctor_node := _find_npc_node("doctor_01")
	var accept_deadline := Time.get_ticks_msec() + 180000
	while (
		dialog_system.has_active_dialogue()
		and (
			doctor_node == null
			or not bool(doctor_node.debug_get_dialogue_bubble_snapshot().get("visible", false))
		)
		and Time.get_ticks_msec() < accept_deadline
	):
		await create_timer(0.02).timeout
		doctor_node = _find_npc_node("doctor_01")
	if doctor_node == null or not bool(doctor_node.debug_get_dialogue_bubble_snapshot().get("visible", false)):
		_fail("Accepted real autonomous dialogue did not show a participant bubble")
		return
	doctor_node.debug_click_dialogue_bubble()
	await process_frame
	if not dialog_panel.visible:
		_fail("Real autonomous dialogue bubble did not open observer UI")
		return

	var deadline := Time.get_ticks_msec() + 180000
	while dialog_system.has_active_dialogue() and Time.get_ticks_msec() < deadline:
		await create_timer(0.02).timeout
	if dialog_system.has_active_dialogue():
		_fail("Timed out waiting for real autonomous dialogue to finish")
		return
	await process_frame
	runtime_snapshot = llm_bridge.debug_get_llm_runtime_snapshot()
	var last_audit: Dictionary = runtime_snapshot.get("last_slowdown_audit", {})
	if (
		int(runtime_snapshot.get("pending_slowdown_count", -1)) != 0
		or str(last_audit.get("request_id", "")).is_empty()
		or str(last_audit.get("request_id", "")) == invitation_request_id
		or str(last_audit.get("call_type", "")) != "dialogue"
		or not bool(last_audit.get("registered", false))
		or not bool(last_audit.get("released", false))
	):
		_fail("Real invitation plus formal reply did not release both dialogue slowdowns: %s" % JSON.stringify(runtime_snapshot))
		return
	if absf(float(time_system.get_effective_time_scale()) - 4.0) > 0.001:
		_fail("Real autonomous dialogue did not restore player time scale")
		return
	if not dialog_panel.visible or not status_label.text.contains("已结束"):
		_fail("Real observer UI did not preserve the completed transcript")
		return

	main.queue_free()
	await process_frame
	print("T0030 real NPC-NPC observer, soft-round ending, and slowdown verification passed.")
	quit(0)


func _find_npc_node(npc_id: String) -> Node:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return null
	for child in npc_root.get_children():
		if str(child.get_meta("npc_id", "")) == npc_id:
			return child
	return null


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
