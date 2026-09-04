extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _frame in 4:
		await process_frame
		await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var presenter := root.get_node_or_null("Main/UI/NPCSkillPointAlerts")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	if npc_system == null or presenter == null or npc_panel == null:
		_fail("T0351 required system, presenter, or panel is missing")
		return

	var npc_id := "cook_01"
	_set_unspent_points(npc_system, npc_id, 0)
	presenter.call("_position_markers")
	await process_frame
	var empty_snapshot: Dictionary = presenter.debug_get_marker_snapshot(npc_id)
	if int(empty_snapshot.get("assignable_points", -1)) != 0 or bool(empty_snapshot.get("visible", true)):
		_fail("NPC without unspent points should not show a skill-point star")
		return

	_set_unspent_points(npc_system, npc_id, 1)
	presenter.call("_position_markers")
	await process_frame
	var marker_snapshot: Dictionary = presenter.debug_get_marker_snapshot(npc_id)
	if (
		int(marker_snapshot.get("assignable_points", 0)) != 1
		or str(marker_snapshot.get("text", "")) != "⭐"
		or str(marker_snapshot.get("tooltip", "")) != "有可分配技能点"
		or marker_snapshot.get("size", Vector2.ZERO) != Vector2(34.0, 34.0)
	):
		_fail("Skill-point star content or tooltip contract mismatch: %s" % marker_snapshot)
		return

	presenter.debug_press_marker(npc_id)
	await process_frame
	if not npc_panel.visible or str(npc_panel.get("_current_npc_id")) != npc_id:
		_fail("Clicking the skill-point star should open the matching NPCPanel")
		return
	if int(npc_system.get_npc_progression(npc_id).get("unspent_skill_points", 0)) != 1:
		_fail("Clicking the star must not consume a skill point")
		return

	var strength_button := npc_panel.find_child("NPCStrengthPointButton", true, false) as Button
	var intelligence_button := npc_panel.find_child("NPCIntelligencePointButton", true, false) as Button
	if strength_button == null or intelligence_button == null or not strength_button.visible or not intelligence_button.visible:
		_fail("Available attribute buttons should be visible in NPCPanel")
		return
	npc_panel.call("_update_attribute_point_button_pulse", 0.0)
	var transparent_alpha := strength_button.modulate.a
	npc_panel.call("_update_attribute_point_button_pulse", 0.6)
	var opaque_alpha := strength_button.modulate.a
	if transparent_alpha > 0.34 or opaque_alpha < 0.98 or not is_equal_approx(opaque_alpha, intelligence_button.modulate.a):
		_fail("Attribute +1 buttons should pulse together between transparent and opaque states")
		return

	strength_button.pressed.emit()
	await process_frame
	if int(npc_system.get_npc_progression(npc_id).get("unspent_skill_points", -1)) != 0:
		_fail("The formal +1 button should consume exactly the final skill point")
		return
	if strength_button.visible or intelligence_button.visible:
		_fail("Attribute +1 buttons should hide after the final point is spent")
		return
	await process_frame
	presenter.call("_position_markers")
	var spent_snapshot: Dictionary = presenter.debug_get_marker_snapshot(npc_id)
	if int(spent_snapshot.get("assignable_points", -1)) != 0 or bool(spent_snapshot.get("visible", true)):
		_fail("Skill-point star should disappear after the final point is spent")
		return
	if not is_equal_approx(strength_button.modulate.a, 1.0) or not is_equal_approx(intelligence_button.modulate.a, 1.0):
		_fail("Hidden attribute buttons should reset to fully opaque")
		return

	main.free()
	for _frame in 2:
		await process_frame
	print("T0351 NPC skill-point alert verification passed.")
	quit(0)


func _set_unspent_points(npc_system: Node, npc_id: String, amount: int) -> void:
	var profile: Dictionary = npc_system.get_npc(npc_id)
	var progression: Dictionary = profile.get("progression", {}).duplicate(true)
	progression["unspent_skill_points"] = maxi(0, amount)
	profile["progression"] = progression
	npc_system._profiles[npc_id] = profile
	npc_system._refresh_npc_node(npc_id)
	npc_system._emit_npc_state_changed(npc_id)


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
