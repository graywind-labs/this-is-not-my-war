extends SceneTree


func _init() -> void:
	root.size = Vector2i(1152, 648)
	DisplayServer.window_set_size(root.size)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("T0331 could not load Main.tscn")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel")
	if npc_system == null or npc_panel == null:
		_fail("T0331 required NPCSystem or NPCPanel is missing")
		return
	var npc_id := "veteran_deputy_01"
	var npc_node := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath()))
	var panel_action_label := npc_panel.find_child("NPCActionLabel", true, false) as Label
	var panel_behavior_label := npc_panel.find_child("NPCBehaviorModeLabel", true, false) as Label
	if npc_node == null or panel_action_label == null or panel_behavior_label == null:
		_fail("T0331 visible status controls or NPC node are missing")
		return

	var cases := [
		{"action": "idle", "expected": "空闲"},
		{"action": "work_garden", "expected": "照料菜园"},
		{"action": "moving_to_stable", "expected": "前往马厩"},
		{"action": "assist_heal_doctor_01", "expected": "协助治疗莉娜"},
		{"action": "winding_up_enemy_test", "expected": "准备攻击"},
	]
	for raw_case in cases:
		var test_case: Dictionary = raw_case
		var action_id := str(test_case.get("action", ""))
		var expected := str(test_case.get("expected", ""))
		npc_system.update_npc_state(npc_id, {
			"current_action": action_id,
			"behavior_mode": "work",
			"unconscious": false,
			"escaped": false,
		})
		npc_system.debug_select_npc(npc_id)
		await process_frame
		await process_frame
		var overhead: Dictionary = npc_node.debug_get_overhead_ui_snapshot()
		var panel_text := panel_action_label.text
		var overhead_text := str(overhead.get("action_text", ""))
		if panel_text != expected or overhead_text != expected:
			_fail("T0331 action %s mismatch: panel=%s overhead=%s expected=%s" % [action_id, panel_text, overhead_text, expected])
			return
		if str(npc_system.get_npc_state(npc_id).get("current_action", "")) != action_id:
			_fail("T0331 display formatting changed the authority action: %s" % action_id)
			return
		if _contains_ascii_word(panel_text) or _contains_ascii_word(overhead_text):
			_fail("T0331 leaked an English state: panel=%s overhead=%s" % [panel_text, overhead_text])
			return
	if panel_behavior_label.text != "工作":
		_fail("T0331 NPCPanel behavior mode is not Chinese: %s" % panel_behavior_label.text)
		return
	var unknown_text := str(npc_system.get_npc_action_display_text("unknown_internal_state"))
	if unknown_text != "其他行动" or _contains_ascii_word(unknown_text):
		_fail("T0331 unknown internal state did not use the Chinese fallback: %s" % unknown_text)
		return

	print("T0331 NPC visible Chinese status verification passed.")
	quit(0)


func _contains_ascii_word(text: String) -> bool:
	for character in text:
		var code := character.unicode_at(0)
		if (code >= 65 and code <= 90) or (code >= 97 and code <= 122):
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
