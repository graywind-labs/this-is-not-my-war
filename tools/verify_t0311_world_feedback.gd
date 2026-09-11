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

	var event_bus := root.get_node_or_null("EventBus")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var needs_system := root.get_node_or_null("Main/Systems/NPCNeedsSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var presenter := root.get_node_or_null("Main/UI/WorldFeedbackPresenter")
	if (
		event_bus == null
		or action_system == null
		or needs_system == null
		or npc_system == null
		or resource_system == null
		or presenter == null
	):
		_fail("T0311 required systems or presenter not found")
		return
	if presenter.process_mode != Node.PROCESS_MODE_ALWAYS:
		_fail("World feedback must keep real-time presentation processing while paused")
		return

	var npc_id := "gardener_01"
	var npc: Dictionary = npc_system.get_npc(npc_id)
	var farming_before := int(npc.get("skills", {}).get("耕种", 0))
	var growth_result: Dictionary = npc_system.increase_npc_skill(npc_id, "耕种", 1)
	if int(growth_result.get("amount", 0)) != 1:
		_fail("Direct authoritative skill growth did not succeed")
		return
	var growth_snapshot: Array = presenter.debug_get_snapshot()
	if growth_snapshot.size() != 1 or str(growth_snapshot[0].get("channel", "")) != "growth":
		_fail("Direct skill growth did not create one growth feedback group")
		return
	if not _has_entry(growth_snapshot[0], "耕种", "growth", 1):
		_fail("Growth feedback did not contain the actual skill delta")
		return
	if not _has_entry(growth_snapshot[0], "经验", "growth", 1):
		_fail("Growth feedback did not contain the actual experience delta")
		return
	if not is_equal_approx(float(growth_snapshot[0].get("anchor_height", 0.0)), 4.25):
		_fail("NPC feedback anchor is not above the existing 3.72m overhead stack")
		return

	presenter.debug_advance_feedback(1.2)
	var stable_snapshot: Array = presenter.debug_get_snapshot()
	if stable_snapshot.size() != 1 or not is_equal_approx(float(stable_snapshot[0].get("alpha", 0.0)), 1.0):
		_fail("Feedback must remain fully opaque for the first 1.2 real seconds")
		return
	presenter.debug_advance_feedback(0.4)
	var fading_snapshot: Array = presenter.debug_get_snapshot()
	if fading_snapshot.size() != 1 or not (float(fading_snapshot[0].get("alpha", 1.0)) < 1.0 and float(fading_snapshot[0].get("alpha", 0.0)) > 0.0):
		_fail("Feedback did not fade during the final 0.8 real seconds")
		return
	presenter.debug_advance_feedback(0.4)
	if not presenter.debug_get_snapshot().is_empty():
		_fail("Feedback did not disappear at two real seconds")
		return

	var garden_action: Dictionary = action_system.get_action("work_garden")
	var expected_outputs: Dictionary = action_system._get_work_output_resources(garden_action, npc_id)
	var expected_grain := int(expected_outputs.get("grain", 0))
	var grain_before := int(resource_system.get_resource("grain"))
	var capacity := int(resource_system.get_resource_capacity("grain"))
	if grain_before + expected_grain > capacity:
		resource_system.add_resource("grain", -(grain_before + expected_grain - capacity))
		grain_before = int(resource_system.get_resource("grain"))
	var work_skill_before := int(npc_system.get_npc(npc_id).get("skills", {}).get("耕种", farming_before))
	action_system._complete_work(npc_id, {
		"action": garden_action,
		"duration_seconds": float(garden_action.get("duration_seconds", 3600.0)),
		"building_id": "garden",
		"workstation_id": "",
		"state_deltas": {},
		"applied_state_deltas": {}
	})
	if int(resource_system.get_resource("grain")) != grain_before + expected_grain:
		_fail("Ordinary work authority did not commit the expected output")
		return
	if int(npc_system.get_npc(npc_id).get("skills", {}).get("耕种", 0)) != work_skill_before + 1:
		_fail("Ordinary work authority did not commit its skill growth")
		return
	var work_snapshot: Array = presenter.debug_get_snapshot()
	if work_snapshot.size() != 1 or str(work_snapshot[0].get("channel", "")) != "work_transaction":
		_fail("Ordinary work did not merge output and growth into one group")
		return
	if not _has_entry(work_snapshot[0], "粮食", "gain", expected_grain, true):
		_fail("Ordinary work feedback did not reuse the grain icon and actual output")
		return
	if not _has_entry(work_snapshot[0], "耕种", "growth", 1):
		_fail("Ordinary work feedback did not include bundled growth")
		return
	presenter.debug_advance_feedback(2.1)

	var failed_group_count: int = presenter.debug_get_snapshot().size()
	var fill_amount := capacity - int(resource_system.get_resource("grain"))
	if fill_amount > 0:
		resource_system.add_resource("grain", fill_amount)
	action_system._complete_work(npc_id, {
		"action": garden_action,
		"duration_seconds": float(garden_action.get("duration_seconds", 3600.0)),
		"building_id": "garden",
		"workstation_id": "",
		"state_deltas": {},
		"applied_state_deltas": {}
	})
	if presenter.debug_get_snapshot().size() != failed_group_count:
		_fail("Storage-capacity failure fabricated a success feedback group")
		return

	var eater_id := "cook_01"
	resource_system.add_resource("meal", 1)
	npc_system.debug_enter_location_immediately(eater_id, "dining_hall")
	npc_system.update_npc_state(eater_id, {"satiety": 0})
	var eat_action: Dictionary = action_system.get_action("eat_at_dining_hall")
	eat_action["formal_spatial_route"] = false
	if not action_system._start_eat(eater_id, eat_action):
		_fail("Prepared eat action did not start")
		return
	var eat_snapshot: Array = presenter.debug_get_snapshot()
	if eat_snapshot.size() != 1 or not _has_entry(eat_snapshot[0], "餐食", "consume", -1, true):
		_fail("Eat start did not display the actually consumed food")
		return
	presenter.debug_advance_feedback(2.1)
	var active_eat: Dictionary = action_system._active_actions.get(eater_id, {})
	active_eat["elapsed_seconds"] = float(active_eat.get("duration_seconds", 1200.0)) * 0.5
	action_system._apply_progress_state_deltas(eater_id, active_eat)
	var satiety_snapshot: Array = presenter.debug_get_snapshot()
	if satiety_snapshot.size() != 1 or not _has_entry(satiety_snapshot[0], "饱食", "neutral", 25):
		_fail("Eat progress did not display the actual satiety increase")
		return
	presenter.debug_advance_feedback(2.1)

	var sleeper_id := "veteran_deputy_01"
	npc_system.update_npc_state(sleeper_id, {"fatigue": 50, "satiety": 50})
	var sleep_result: Dictionary = needs_system._apply_profile(sleeper_id, "sleep", 3600.0)
	var actual_fatigue_delta := int(sleep_result.get("applied_deltas", {}).get("fatigue", 0))
	var sleep_snapshot: Array = presenter.debug_get_snapshot()
	if actual_fatigue_delta >= 0 or sleep_snapshot.size() != 1:
		_fail("Sleep did not produce a real fatigue decrease feedback")
		return
	if not _has_entry(sleep_snapshot[0], "疲劳", "neutral", actual_fatigue_delta):
		_fail("Sleep feedback did not use the actual fatigue delta")
		return
	needs_system._apply_profile(sleeper_id, "sleep", 3600.0)
	if presenter.debug_get_snapshot().size() != 1:
		_fail("Repeated needs feedback did not replace its old channel entry")
		return
	presenter.debug_advance_feedback(2.1)
	event_bus.world_feedback_requested.emit({
		"anchor_type": "npc",
		"anchor_id": sleeper_id,
		"anchor_height": 4.25,
		"channel": "pause_lifecycle",
		"entries": [{
			"display_name": "疲劳",
			"amount": -1,
			"color_role": "neutral"
		}]
	})
	paused = true
	await create_timer(2.25, true, false, true).timeout
	await process_frame
	paused = false
	if not presenter.debug_get_snapshot().is_empty():
		_fail("Paused gameplay stopped the two-real-second feedback lifecycle")
		return

	main.queue_free()
	await process_frame
	print("T0311 world feedback verification passed.")
	quit(0)


func _has_entry(
	group: Dictionary,
	display_name: String,
	color_role: String,
	amount: int,
	require_icon: bool = false
) -> bool:
	for raw_entry in group.get("entries", []):
		if not raw_entry is Dictionary:
			continue
		var entry: Dictionary = raw_entry
		if (
			str(entry.get("display_name", "")) == display_name
			and str(entry.get("color_role", "")) == color_role
			and int(entry.get("amount", 0)) == amount
			and (not require_icon or not str(entry.get("icon_path", "")).is_empty())
		):
			return true
		for raw_component in entry.get("components", []):
			if not raw_component is Dictionary:
				continue
			var component: Dictionary = raw_component
			if (
				str(component.get("display_name", "")) == display_name
				and str(component.get("color_role", "")) == color_role
				and int(component.get("amount", 0)) == amount
				and not require_icon
			):
				return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
