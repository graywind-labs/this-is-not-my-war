extends SceneTree


func _init() -> void:
	var config_file := FileAccess.open("res://data/physics_navigation.json", FileAccess.READ)
	if config_file == null:
		_fail("Failed to load physics navigation config")
		return
	var config: Variant = JSON.parse_string(config_file.get_as_text())
	if (
		not config is Dictionary
		or not is_equal_approx(float((config as Dictionary).get("stuck_recovery", {}).get("fail_after_seconds", 0.0)), 8.0)
	):
		_fail("Production stuck timeout is no longer eight seconds")
		return
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var event_bus := root.get_node_or_null("EventBus")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var npc_panel := root.get_node_or_null("Main/UI/NPCPanel") as Control
	var npc_node := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Cook01")
	if event_bus == null or npc_system == null or npc_panel == null or npc_node == null:
		_fail("Required runtime nodes are missing")
		return
	if not npc_system.debug_select_npc("cook_01"):
		_fail("Failed to open the cook second-person portrait")
		return
	await process_frame
	var portrait := npc_panel.find_child("NPCPortraitView", true, false)
	if portrait == null:
		_fail("NPC portrait view is missing")
		return

	var status_presentations: Array[Dictionary] = []
	var dialogue_presentations: Array[Dictionary] = []
	event_bus.npc_status_emotion_presented.connect(
		func(observed_npc_id: String, presentation: Dictionary) -> void:
			status_presentations.append({
				"npc_id": observed_npc_id,
				"presentation": presentation.duplicate(true),
			})
	)
	event_bus.npc_dialogue_emotion_presented.connect(
		func(observed_npc_id: String, presentation: Dictionary) -> void:
			dialogue_presentations.append({
				"npc_id": observed_npc_id,
				"presentation": presentation.duplicate(true),
			})
	)
	var action_sequence_before := int(npc_node.debug_get_dialogue_emotion_bubble_snapshot().get("emotion_action_sequence", 0))

	# Other navigation failures must remain silent presentation-wise.
	npc_node.call("_on_navigation_motion_failed", "unreachable_probe", "target_unreachable")
	await process_frame
	if not status_presentations.is_empty() or bool(npc_node.debug_get_dialogue_emotion_bubble_snapshot().get("visible", false)):
		_fail("target_unreachable incorrectly presented the stuck emotion")
		return

	var npc_state_before: Dictionary = npc_system.get_npc_state("cook_01").duplicate(true)
	npc_node.call("_on_navigation_motion_stuck_notified", "stuck_probe", "stuck_timeout")
	await process_frame
	var npc_state_after: Dictionary = npc_system.get_npc_state("cook_01")
	var world: Dictionary = npc_node.debug_get_dialogue_emotion_bubble_snapshot()
	var portrait_bubble: Dictionary = (portrait.debug_get_snapshot() as Dictionary).get("emotion_bubble", {})
	var presentation: Dictionary = world.get("presentation", {})
	if (
		status_presentations.size() != 1
		or not dialogue_presentations.is_empty()
		or str(status_presentations[0].get("npc_id", "")) != "cook_01"
		or not bool(world.get("visible", false))
		or str(world.get("emoji", "")) != "😠"
		or not bool(portrait_bubble.get("visible", false))
		or str(portrait_bubble.get("emoji", "")) != "😠"
		or str(presentation.get("source", "")) != "navigation_stuck"
		or bool(presentation.get("play_action", true))
		or not is_equal_approx(float(world.get("hold_seconds", 0.0)), 2.25)
		or not is_equal_approx(float(world.get("fade_seconds", 0.0)), 0.75)
		or not is_equal_approx(float(portrait_bubble.get("hold_seconds", 0.0)), 2.25)
		or not is_equal_approx(float(portrait_bubble.get("fade_seconds", 0.0)), 0.75)
		or npc_state_after != npc_state_before
	):
		_fail("Stuck emotion changed gameplay state or did not reach both bubble surfaces: %s / %s" % [JSON.stringify(world), JSON.stringify(portrait_bubble)])
		return
	if (
		int(world.get("emotion_action_sequence", -1)) != action_sequence_before
		or bool((world.get("emotion_action_result", {}) as Dictionary).get("active", true))
		or str((world.get("emotion_action_result", {}) as Dictionary).get("reason", "")) != "presentation_action_suppressed"
	):
		_fail("Stuck emotion incorrectly played the dialogue angry action")
		return

	npc_node.call("_advance_dialogue_emotion_bubble", 2.3)
	portrait.call("_advance_emotion_bubble", 2.3)
	if not bool(npc_node.debug_get_dialogue_emotion_bubble_snapshot().get("visible", false)):
		_fail("World stuck emotion skipped its existing fade")
		return
	if not bool(((portrait.debug_get_snapshot() as Dictionary).get("emotion_bubble", {}) as Dictionary).get("visible", false)):
		_fail("Portrait stuck emotion skipped its existing fade")
		return
	npc_node.call("_advance_dialogue_emotion_bubble", 0.8)
	portrait.call("_advance_emotion_bubble", 0.8)
	if bool(npc_node.debug_get_dialogue_emotion_bubble_snapshot().get("visible", true)):
		_fail("World stuck emotion remained visible after three seconds")
		return
	if bool(((portrait.debug_get_snapshot() as Dictionary).get("emotion_bubble", {}) as Dictionary).get("visible", true)):
		_fail("Portrait stuck emotion remained visible after three seconds")
		return

	print("T0403-R2 stuck emotion bubble verification passed")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
