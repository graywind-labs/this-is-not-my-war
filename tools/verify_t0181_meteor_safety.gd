extends SceneTree


const BUILDING_MESSAGE := "赖天主仁慈，陨石不能砸到建筑"
const MOVING_NPC_ID := "blacksmith_01"
const UNCONSCIOUS_NPC_ID := "doctor_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _index in range(8):
		await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var hud := root.get_node_or_null("Main/UI/HUD")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var piety_system := root.get_node_or_null("Main/Systems/PietySystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if (
		action_system == null
		or daily_plan_system == null
		or hud == null
		or npc_system == null
		or piety_system == null
		or controller == null
	):
		_fail("T0181 runtime dependencies are missing")
		return
	daily_plan_system.set_auto_execution_enabled(false)
	var origin: Vector3 = controller.get_formal_world_origin()
	var meteor_config: Dictionary = piety_system.get_meteor_config()
	var damage_radius := float(meteor_config.get("radius", 0.0))
	var collision_radius := float(meteor_config.get("body_radius", 0.0)) * 0.78
	var displacement_margin := float(meteor_config.get("friendly_displacement_margin", 0.0))
	if damage_radius <= 0.0 or collision_radius <= 0.0 or displacement_margin <= 0.0:
		_fail("Meteor safety dimensions are not configured")
		return

	var main_hall_center := origin + Vector3(0.0, 0.0, -8.0)
	var main_hall_edge_overlap := origin + Vector3(16.0, 0.0, -8.0)
	var main_hall_clear := origin + Vector3(17.0, 0.0, -8.0)
	var front_gate_center := origin + Vector3(5.0, 0.0, 54.0)
	var wall_center := origin + Vector3(20.0, 0.0, 52.8)
	var latrine_center := origin + Vector3(-47.0, 0.0, -10.0)
	for check in [
		{"position": main_hall_center, "building_ids": ["main_hall"]},
		{"position": main_hall_edge_overlap, "building_ids": ["main_hall"]},
		{"position": latrine_center, "building_ids": ["dormitory_latrine"]},
		{"position": front_gate_center, "building_ids": ["front_gate", "wall"]},
		{"position": wall_center, "building_ids": ["wall"]},
	]:
		var validation: Dictionary = piety_system.get_target_position_validation(check["position"])
		if (
			bool(validation.get("allowed", true))
			or str(validation.get("reason", "")) != "building_overlap"
			or str(validation.get("message", "")) != BUILDING_MESSAGE
			or not (check["building_ids"] as Array).has(str((validation.get("blocker", {}) as Dictionary).get("building_id", "")))
		):
			_fail("Building overlap was not rejected correctly: %s" % JSON.stringify(validation))
			return
	if not bool(piety_system.get_target_position_validation(main_hall_clear).get("allowed", false)):
		_fail("A meteor radius fully outside the main hall was rejected")
		return

	piety_system.debug_fill_piety()
	var rejected: Dictionary = piety_system.request_meteor_cast(main_hall_center)
	if (
		str(rejected.get("error", "")) != "building_overlap"
		or str(rejected.get("message", "")) != BUILDING_MESSAGE
		or not is_equal_approx(float(piety_system.get_current_piety()), float(piety_system.get_max_piety()))
		or not (piety_system.get_piety_snapshot().get("pending_meteors", []) as Array).is_empty()
	):
		_fail("PietySystem did not reject the building target without spending piety: %s" % JSON.stringify(rejected))
		return

	hud._begin_meteor_targeting()
	hud.set("_meteor_target_position", main_hall_center)
	hud._set_meteor_target_validation(piety_system.get_target_position_validation(main_hall_center))
	hud._confirm_meteor_target()
	var hint := hud.find_child("MeteorTargetHint", true, false) as Label
	if (
		hint == null
		or hint.text != BUILDING_MESSAGE
		or not bool(hud.get("_meteor_targeting_active"))
		or not is_equal_approx(float(piety_system.get_current_piety()), float(piety_system.get_max_piety()))
	):
		_fail("HUD did not retain targeting and show the requested building warning")
		return
	hud._end_meteor_targeting()

	var safe_target := origin + Vector3(0.0, 0.0, 15.0)
	if not bool(piety_system.get_target_position_validation(safe_target).get("allowed", false)):
		_fail("Open plaza meteor target is unexpectedly blocked")
		return
	var moving_node := _get_npc_node(npc_system, MOVING_NPC_ID)
	var unconscious_node := _get_npc_node(npc_system, UNCONSCIOUS_NPC_ID)
	if moving_node == null or unconscious_node == null:
		_fail("T0181 test NPC actors are unavailable")
		return
	for npc_id in [MOVING_NPC_ID, UNCONSCIOUS_NPC_ID]:
		action_system.interrupt_npc_action(npc_id, "t0181_setup", true)
	var unconscious_damage: Dictionary = npc_system.debug_damage_npc(UNCONSCIOUS_NPC_ID, 9999)
	if not bool(unconscious_damage.get("ok", false)) or not bool(npc_system.get_npc_state(UNCONSCIOUS_NPC_ID).get("unconscious", false)):
		_fail("Could not prepare the unconscious NPC displacement case")
		return
	moving_node.apply_external_displacement(safe_target + Vector3(0.0, 0.0, 3.1), "t0181_setup")
	unconscious_node.apply_external_displacement(safe_target, "t0181_setup")
	moving_node.move_to_location("t0181_motion_target", safe_target + Vector3(0.0, 0.0, 10.0))
	var moving_before: Dictionary = moving_node.debug_get_motion_snapshot()
	var moving_hp_before := int(npc_system.get_npc_state(MOVING_NPC_ID).get("hp", 0))
	var unconscious_hp_before := int(npc_system.get_npc_state(UNCONSCIOUS_NPC_ID).get("hp", 0))
	if not bool(moving_before.get("active", false)):
		_fail("Moving NPC did not own an active route before meteor impact")
		return

	var cast: Dictionary = piety_system.request_meteor_cast(safe_target)
	if not bool(cast.get("ok", false)):
		_fail("Legal open-ground meteor cast failed: %s" % JSON.stringify(cast))
		return
	piety_system.debug_advance_effects(float(meteor_config.get("fall_duration_seconds", 1.0)) + 1.0)
	var impact: Dictionary = piety_system.get_piety_snapshot().get("last_impact_result", {})
	var displacement: Dictionary = impact.get("friendly_displacement", {})
	if (
		not bool(displacement.get("ok", false))
		or int(displacement.get("affected_count", 0)) < 2
		or int(displacement.get("displaced_count", 0)) != int(displacement.get("affected_count", -1))
		or not (displacement.get("failed", []) as Array).is_empty()
	):
		_fail("Meteor did not displace every affected friendly NPC: %s" % JSON.stringify(displacement))
		return
	for npc_id in [MOVING_NPC_ID, UNCONSCIOUS_NPC_ID]:
		var npc_node := _get_npc_node(npc_system, npc_id)
		var motion: Dictionary = npc_node.debug_get_motion_snapshot()
		var required_distance := collision_radius + float(motion.get("body_radius", 0.35)) + displacement_margin
		var actual_distance := Vector2(
			npc_node.global_position.x - safe_target.x,
			npc_node.global_position.z - safe_target.z
		).length()
		if actual_distance < required_distance - 0.02:
			_fail("%s remained inside the landed meteor collider" % npc_id)
			return
	if (
		int(npc_system.get_npc_state(MOVING_NPC_ID).get("hp", -1)) != moving_hp_before
		or int(npc_system.get_npc_state(UNCONSCIOUS_NPC_ID).get("hp", -1)) != unconscious_hp_before
		or not bool(npc_system.get_npc_state(UNCONSCIOUS_NPC_ID).get("unconscious", false))
	):
		_fail("Friendly displacement changed HP or unconscious authority")
		return
	var moving_after: Dictionary = moving_node.debug_get_motion_snapshot()
	if (
		not bool(moving_after.get("active", false))
		or str(moving_after.get("request_id", "")) != "t0181_motion_target"
		or moving_after.get("target_position", Vector3.ZERO) != moving_before.get("target_position", Vector3.ONE)
	):
		_fail("External displacement did not preserve the NPC movement request")
		return
	var continued_distance_before := Vector2(
		moving_node.global_position.x - (safe_target.x),
		moving_node.global_position.z - (safe_target.z + 10.0)
	).length()
	for _frame in range(90):
		await physics_frame
	var continued_distance_after := Vector2(
		moving_node.global_position.x - (safe_target.x),
		moving_node.global_position.z - (safe_target.z + 10.0)
	).length()
	var continued_motion: Dictionary = moving_node.debug_get_motion_snapshot()
	if (
		continued_distance_after >= continued_distance_before - 0.2
		or str(continued_motion.get("last_result", "")) in ["stuck_timeout", "target_unreachable"]
	):
		_fail("Displaced moving NPC did not continue toward its original target")
		return

	print("T0181_METEOR_SAFETY_OK")
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath()))


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
