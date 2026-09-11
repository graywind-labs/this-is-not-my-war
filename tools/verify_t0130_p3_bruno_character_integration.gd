extends SceneTree


const NPC_ID := "cook_01"
const WORK_ACTION_ID := "work_dining_hall"
const EAT_ACTION_ID := "eat_at_dining_hall"

var _failures: Array[String] = []


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_failures.append("Main.tscn unavailable")
		finish()
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var bruno := _get_npc_node(npc_system, NPC_ID) if npc_system != null else null
	if [npc_system, action_system, resource_system, daily_plan_system, time_system, gm, bruno].has(null):
		_failures.append("T0130-P3 runtime dependencies unavailable")
		finish()
		return

	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(false)
	# Keep the production dining approach speed: doubling it can overshoot the
	# narrow stove stand-off and make an otherwise valid route oscillate at the edge.
	bruno.set("move_speed", 5.0)
	npc_system.update_npc_state(NPC_ID, {
		"unconscious": false,
		"satiety": 35,
		"current_action": "idle",
		"last_action_result": "verify_t0130_p3_ready"
	})
	await process_frame

	var initial_art: Dictionary = bruno.debug_get_character_art_snapshot()
	check(bool(initial_art.get("ready", false)), "Bruno chibi art did not become ready")
	check(str(initial_art.get("appearance_id", "")) == "bruno_cook_chibi_v1", "Bruno still uses the Quaternius fallback")
	check(str(initial_art.get("equipment_mode", "")) == "cook_spoon", "Bruno does not use the cooking utensil contract")
	check(str((initial_art.get("state_clips", {}) as Dictionary).get("work", "")) == "Working_C", "Bruno work clip is not the cooking loop")
	check(not bool(initial_art.get("cook_spoon_visible", true)), "Bruno displays the cooking spoon while idle")
	check(not bruno.get_node("BodyCollision").disabled, "Bruno body collision was replaced by art")
	check(not bruno.get_node("InteractionArea/InteractionCollision").disabled, "Bruno interaction collision was replaced by art")
	check(not bruno.get_node("LegacyVisuals").visible, "Bruno legacy mesh is still visible")
	check(bruno.find_child("SelectionArea", true, false) == null, "Bruno production art added a duplicate selection collider")

	var action_before_preview := str(npc_system.get_npc_state(NPC_ID).get("current_action", ""))
	var talk_art: Dictionary = bruno.debug_force_character_animation("talk")
	check(str(talk_art.get("current_clip", "")) == "Waving", "Bruno talk state is unavailable")
	var seated_preview: Dictionary = bruno.debug_force_character_animation("seated_eating")
	check(str(seated_preview.get("current_state", "")) == "seated_eating", "Bruno seated eating state is unavailable")
	check(str(seated_preview.get("current_clip", "")) == "Seated_Eating", "Bruno seated eating still uses the standing Use_Item clip")
	check(float((seated_preview.get("presentation_pose_offset", Vector3.ZERO) as Vector3).y) < -0.3, "Bruno seated eating pose has no seat offset")
	check(not bool(seated_preview.get("cook_spoon_visible", true)), "Bruno carries the stove spoon while seated")
	check(str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == action_before_preview, "Animation preview changed Bruno's authoritative action")
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle"})
	_ensure_resource(resource_system, "grain", 12)
	await process_frame

	check(bool(action_system.debug_assign_work(NPC_ID, "dining_hall")), "Could not dispatch Bruno to formal cooking")
	var reached_kitchen := await _wait_for_action(action_system, time_system, WORK_ACTION_ID)
	check(reached_kitchen, "Bruno did not physically reach the kitchen station")
	if not reached_kitchen:
		print("T0130-P3 kitchen failure: %s" % JSON.stringify({
			"runtime": action_system.get_runtime_action_snapshot(NPC_ID),
			"spatial": npc_system.debug_get_spatial_migration_snapshot(NPC_ID),
			"art": bruno.debug_get_character_art_snapshot()
		}))
		finish()
		return
	await create_timer(0.3).timeout
	var work_art: Dictionary = bruno.debug_get_character_art_snapshot()
	var work_spatial: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	check(int(work_art.get("movement_activation_count", 0)) > 0, "Formal kitchen route never activated Bruno locomotion")
	check(str(work_spatial.get("path_phase", "")) == "active_workstation", "Bruno kitchen occupancy was not committed")
	check(str(work_art.get("desired_state", "")) == "work" and str(work_art.get("current_clip", "")) == "Working_C", "Cooking authority did not select Working_C")
	check(int(work_art.get("work_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Bruno cooking clip is not cyclic")
	check(bool(work_art.get("cook_spoon_visible", false)), "Cooking spoon is not visible after kitchen arrival")
	check(str(work_art.get("cook_spoon_parent", "")) == "RightHand", "Cooking spoon is not attached to RightHand")
	check(float(work_art.get("cook_spoon_grip_hand_distance", 1.0)) < 0.01, "Cooking spoon handle end is not seated in Bruno's hand")
	check(float(work_art.get("cook_spoon_palm_inward_offset", 0.0)) >= 0.07, "Cooking spoon is still aligned to the outer hand bone instead of the visible palm center")
	check(float(work_art.get("cook_spoon_forward_dot", -1.0)) > 0.85, "Cooking spoon does not point toward the stove pot")
	check(float(work_art.get("cook_spoon_down_dot", -1.0)) > 0.25, "Cooking spoon does not angle down into the stove pot")
	check(not bool(work_art.get("hammer_visible", true)) and not bool(work_art.get("stable_broom_visible", true)), "Bruno carries another profession's tool")
	check(facing_dot(work_art) > 0.9, "Bruno visible front is opposite the kitchen station")
	var observed_wrap := await _observe_work_wrap(bruno)
	check(observed_wrap, "Bruno cooking did not repeat across an animation boundary")

	action_system.interrupt_npc_action(NPC_ID, "verify_t0130_p3_switch_to_eating", true)
	await process_frame
	_ensure_resource(resource_system, "meal", 3)
	npc_system.update_npc_state(NPC_ID, {"satiety": 35, "current_action": "idle"})
	var eat_button := gm.find_child("FormalDiningEatButton", true, false) as Button
	check(eat_button != null, "GM dining-eat entry is missing")
	if eat_button != null:
		gm.visible = true
		eat_button.pressed.emit()
		await process_frame
		var reached_seat := await _wait_for_action(action_system, time_system, EAT_ACTION_ID)
		check(reached_seat, "Bruno did not physically reach a dining seat")
		if not reached_seat:
			print("T0130-P3 seat failure: %s" % JSON.stringify({
				"runtime": action_system.get_runtime_action_snapshot(NPC_ID),
				"spatial": npc_system.debug_get_spatial_migration_snapshot(NPC_ID),
				"art": bruno.debug_get_character_art_snapshot()
			}))
			finish()
			return
		await create_timer(0.18).timeout
		var eat_art: Dictionary = bruno.debug_get_character_art_snapshot()
		var attachment: Dictionary = bruno.debug_get_spatial_attachment_snapshot()
		check(str(eat_art.get("desired_state", "")) == "seated_eating", "Real meal did not select seated eating")
		check(not bool(eat_art.get("cook_spoon_visible", true)), "Stove spoon remained visible while Bruno ate")
		check(bool(attachment.get("active", false)) and str(attachment.get("pose", "")) == "sitting", "Real meal did not mount Bruno to a seat")
		action_system.interrupt_npc_action(NPC_ID, "verify_t0130_p3_eating_complete", true)
		await process_frame

	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, 9999)
	check(bool(damage_result.get("ok", false)), "Bruno authoritative damage entry failed")
	await process_frame
	var unconscious_art: Dictionary = bruno.debug_get_character_art_snapshot()
	check(str(unconscious_art.get("desired_state", "")) == "unconscious", "Bruno unconscious state did not select the fall clip")
	check(not bool(unconscious_art.get("cook_spoon_visible", true)), "Bruno retained the cooking spoon while unconscious")
	var recovery_result: Dictionary = npc_system.debug_advance_unconscious_recovery(NPC_ID, 100.0 * 3600.0)
	check(not (recovery_result.get("revived", []) as Array).is_empty(), "Bruno did not revive through the authority recovery API")
	await process_frame
	check(str(bruno.debug_get_character_art_snapshot().get("desired_state", "")) == "get_up", "Bruno revival did not select get-up")
	check(gm.find_child("FormalDiningWorkButton", true, false) != null, "GM formal cooking entry is missing")
	finish()


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_action(action_system: Node, time_system: Node, action_id: String, max_frames: int = 3000) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		await process_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _observe_work_wrap(bruno: Node) -> bool:
	var previous := float(bruno.debug_get_character_art_snapshot().get("work_cycle_position", -1.0))
	for _sample in range(320):
		await create_timer(0.02).timeout
		var current := float(bruno.debug_get_character_art_snapshot().get("work_cycle_position", -1.0))
		if current >= 0.0 and previous >= 0.0 and current + 0.04 < previous:
			return true
		previous = current
	return false


func _ensure_resource(resource_system: Node, resource_id: String, minimum: int) -> void:
	var current := int(resource_system.get_resource(resource_id))
	if current < minimum:
		resource_system.add_resource(resource_id, minimum - current)


func facing_dot(snapshot: Dictionary) -> float:
	var visible_forward: Vector3 = snapshot.get("visual_forward", Vector3.ZERO)
	var target_forward: Vector3 = snapshot.get("target_facing_direction", Vector3.ZERO)
	if visible_forward.length_squared() <= 0.0001 or target_forward.length_squared() <= 0.0001:
		return -1.0
	return visible_forward.normalized().dot(target_forward.normalized())


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0130_P3_BRUNO_CHARACTER_INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0130_P3_BRUNO_CHARACTER_INTEGRATION FAIL count=%d" % _failures.size())
	quit(1)
