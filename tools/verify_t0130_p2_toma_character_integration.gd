extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "stableman_01"
const ACTION_ID := "work_stable"

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("run_verification")


func run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm := root.get_node_or_null("Main/UI/GMPanel")
	check(not [npc_system, action_system, time_system, gm].has(null), "Main production dependencies are incomplete")
	if not _failures.is_empty():
		finish()
		return
	time_system.set_paused(false)

	var npc_paths: Dictionary = npc_system.get("_npc_nodes")
	var toma := npc_system.get_node_or_null(npc_paths.get(NPC_ID, NodePath("")))
	check(toma != null, "Formal Toma body is missing")
	if toma == null:
		finish()
		return
	var initial_art: Dictionary = toma.debug_get_character_art_snapshot()
	check(bool(initial_art.get("ready", false)), "Toma chibi art did not become ready")
	check(str(initial_art.get("appearance_id", "")) == "toma_stableman_chibi_v1", "Toma still uses the Quaternius fallback")
	check(str(initial_art.get("equipment_mode", "")) == "stable_broom", "Toma does not use the stable tool contract")
	check(str((initial_art.get("state_clips", {}) as Dictionary).get("work", "")) == "Working_B", "Toma work clip is not the stable-care loop")
	check(not bool(initial_art.get("stable_broom_visible", true)), "Toma displays the stable broom while idle")
	check(not toma.get_node("BodyCollision").disabled, "Toma body collision was replaced by art")
	check(not toma.get_node("InteractionArea/InteractionCollision").disabled, "Toma interaction collision was replaced by art")
	check(not toma.get_node("LegacyVisuals").visible, "Toma legacy mesh is still visible")
	check(toma.find_child("SelectionArea", true, false) == null, "Toma production art added a duplicate selection collider")

	var action_before_preview := str(npc_system.get_npc_state(NPC_ID).get("current_action", ""))
	var talk_art: Dictionary = toma.debug_force_character_animation("talk")
	check(str(talk_art.get("current_state", "")) == "talk" and str(talk_art.get("current_clip", "")) == "Waving", "Toma talk state is unavailable")
	var seated_art: Dictionary = toma.debug_force_character_animation("vehicle_seated")
	check(str(seated_art.get("current_state", "")) == "vehicle_seated", "Toma vehicle seated state is unavailable")
	check(float((seated_art.get("presentation_pose_offset", Vector3.ZERO) as Vector3).y) < -0.3, "Toma vehicle seated pose has no seat offset")
	check(str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == action_before_preview, "Presentation preview changed Toma's authoritative action")
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle"})
	await process_frame

	toma.set("move_speed", 10.0)
	check(bool(action_system.debug_assign_work(NPC_ID, "stable")), "Could not dispatch Toma to formal stable care")
	for _frame in range(900):
		var moving_art: Dictionary = toma.debug_get_character_art_snapshot()
		if bool(moving_art.get("logical_moving", false)) and facing_dot(moving_art) > 0.75:
			break
		time_system.set_paused(false)
		await physics_frame
		await process_frame
	var route_art: Dictionary = toma.debug_get_character_art_snapshot()
	check(int(route_art.get("movement_activation_count", 0)) > 0, "Formal stable route never activated Toma locomotion")
	check(["walk", "run", "work"].has(str(route_art.get("desired_state", ""))), "Formal route did not drive a production animation")
	if bool(route_art.get("logical_moving", false)):
		check(facing_dot(route_art) > 0.75, "Toma visible front is opposite the formal route")

	for _frame in range(1800):
		if str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == ACTION_ID:
			break
		time_system.set_paused(false)
		await physics_frame
		await process_frame
	await create_timer(0.35).timeout
	var active_art: Dictionary = toma.debug_get_character_art_snapshot()
	var active_spatial: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	check(str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == ACTION_ID, "Toma did not physically reach stable care")
	check(str(active_spatial.get("path_phase", "")) == "active_workstation", "Toma stable occupancy was not committed")
	check(str(active_art.get("desired_state", "")) == "work", "Stable authority did not select Toma work state")
	check(str(active_art.get("current_clip", "")) == "Working_B", "Toma reused the blacksmith hammering clip")
	check(int(active_art.get("work_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Toma stable care clip is not cyclic")
	check(bool(active_art.get("stable_broom_visible", false)), "Toma stable tool is not visible during care")
	check(str(active_art.get("stable_broom_parent", "")) == "RightHand", "Toma stable tool is not attached to RightHand")
	check(float(active_art.get("stable_tool_grip_hand_distance", 1.0)) < 0.01, "Toma stable tool handle end is not seated in his hand")
	check(float(active_art.get("stable_tool_forward_dot", -1.0)) > 0.85, "Toma stable tool head does not point forward")
	check(float(active_art.get("stable_tool_down_dot", -1.0)) > 0.3, "Toma stable tool does not angle down toward the horse")
	check(not bool(active_art.get("hammer_visible", true)), "Toma incorrectly carries Glen's hammer")
	check(facing_dot(active_art) > 0.9, "Toma visible front is opposite the stable workstation")
	var observed_wrap := false
	var previous_cycle_position := float(active_art.get("work_cycle_position", -1.0))
	for _sample in range(300):
		await create_timer(0.02).timeout
		var cycle_snapshot: Dictionary = toma.debug_get_character_art_snapshot()
		var cycle_position := float(cycle_snapshot.get("work_cycle_position", -1.0))
		if cycle_position >= 0.0 and previous_cycle_position >= 0.0 and cycle_position + 0.04 < previous_cycle_position:
			observed_wrap = true
			break
		previous_cycle_position = cycle_position
	check(observed_wrap, "Toma stable care did not visibly repeat across an animation boundary")

	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, 9999)
	check(bool(damage_result.get("ok", false)), "Toma authoritative damage entry failed")
	await process_frame
	var unconscious_art: Dictionary = toma.debug_get_character_art_snapshot()
	check(bool(npc_system.get_npc_state(NPC_ID).get("unconscious", false)), "Toma did not become authoritatively unconscious")
	check(str(unconscious_art.get("desired_state", "")) == "unconscious", "Toma unconscious state did not select the fall clip")
	check(not bool(unconscious_art.get("stable_broom_visible", true)), "Toma retained the stable tool while unconscious")
	check((npc_system.debug_get_spatial_migration_snapshot(NPC_ID).get("occupancy", {}) as Dictionary).is_empty(), "Unconscious Toma retained stable occupancy")

	var recovery_result: Dictionary = npc_system.debug_advance_unconscious_recovery(NPC_ID, 100.0 * 3600.0)
	check(not (recovery_result.get("revived", []) as Array).is_empty(), "Toma did not revive through the authority recovery API")
	await process_frame
	check(str(toma.debug_get_character_art_snapshot().get("desired_state", "")) == "get_up", "Toma revival did not select get-up")

	check(gm.find_child("FormalStableWorkButton", true, false) != null, "GM stable-care entry is missing")
	finish()


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
		print("T0130_P2_TOMA_CHARACTER_INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0130_P2_TOMA_CHARACTER_INTEGRATION FAIL count=%d" % _failures.size())
	quit(1)
