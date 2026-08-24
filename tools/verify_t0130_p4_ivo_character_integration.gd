extends SceneTree


const NPC_ID := "gardener_01"
const WORK_ACTION_ID := "work_garden"
const PRAYER_ACTION_ID := "pray_at_chapel"

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
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var ivo := _get_npc_node(npc_system, NPC_ID) if npc_system != null else null
	if [npc_system, action_system, daily_plan_system, time_system, gm, ivo].has(null):
		_failures.append("T0130-P4 runtime dependencies unavailable")
		finish()
		return

	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(false)
	ivo.set("move_speed", 5.0)
	npc_system.update_npc_state(NPC_ID, {
		"unconscious": false,
		"fatigue": 0,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_t0130_p4_ready"
	})
	await process_frame

	var initial_art: Dictionary = ivo.debug_get_character_art_snapshot()
	check(bool(initial_art.get("ready", false)), "Ivo chibi art did not become ready")
	check(str(initial_art.get("appearance_id", "")) == "ivo_gardener_chibi_v1", "Ivo still uses the Quaternius fallback")
	check(str(initial_art.get("equipment_mode", "")) == "garden_hoe", "Ivo does not use the garden-tool contract")
	check(str((initial_art.get("state_clips", {}) as Dictionary).get("work", "")) == "Digging", "Ivo work clip is not the digging loop")
	check(bool(initial_art.get("use_imported_character_material", false)), "Ivo does not preserve the authored Deckhand material settings")
	check(str(initial_art.get("palette_path", "")).ends_with("PolygonMinis_Texture_01_A.png"), "Ivo does not use the authored neutral Albedo palette")
	var target_mesh := ivo.find_child("SK_Pirates_Deckhand_01", true, false) as MeshInstance3D
	var authored_material := target_mesh.material_override as BaseMaterial3D if target_mesh != null else null
	check(authored_material != null and authored_material.vertex_color_use_as_albedo, "Ivo lost the Deckhand authored vertex-color face details")
	check(authored_material != null and authored_material.albedo_texture != null and authored_material.albedo_texture.resource_path.ends_with("PolygonMinis_Texture_01_A.png"), "Ivo imported material does not bind the neutral authored Albedo")
	check(not bool(initial_art.get("garden_hoe_visible", true)), "Ivo displays the garden hoe while idle")
	check(not ivo.get_node("BodyCollision").disabled, "Ivo body collision was replaced by art")
	check(not ivo.get_node("InteractionArea/InteractionCollision").disabled, "Ivo interaction collision was replaced by art")
	check(not ivo.get_node("LegacyVisuals").visible, "Ivo legacy mesh is still visible")
	check(ivo.find_child("SelectionArea", true, false) == null, "Ivo production art added a duplicate selection collider")

	var action_before_preview := str(npc_system.get_npc_state(NPC_ID).get("current_action", ""))
	var talk_art: Dictionary = ivo.debug_force_character_animation("talk")
	check(str(talk_art.get("current_clip", "")) == "Waving", "Ivo talk state is unavailable")
	var prayer_preview: Dictionary = ivo.debug_force_character_animation("seated_prayer")
	check(str(prayer_preview.get("current_state", "")) == "seated_prayer", "Ivo seated-prayer state is unavailable")
	check(float((prayer_preview.get("presentation_pose_offset", Vector3.ZERO) as Vector3).y) < -0.3, "Ivo seated-prayer pose has no bench offset")
	check(not bool(prayer_preview.get("garden_hoe_visible", true)), "Ivo carries the hoe during prayer preview")
	check(str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == action_before_preview, "Animation preview changed Ivo's authoritative action")
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle"})
	await process_frame

	check(bool(action_system.debug_assign_work(NPC_ID, "garden")), "Could not dispatch Ivo to formal garden work")
	var reached_plot := await _wait_for_action(action_system, time_system, WORK_ACTION_ID)
	check(reached_plot, "Ivo did not physically reach a garden plot")
	if not reached_plot:
		print("T0130-P4 garden failure: %s" % JSON.stringify({
			"runtime": action_system.get_runtime_action_snapshot(NPC_ID),
			"spatial": npc_system.debug_get_spatial_migration_snapshot(NPC_ID),
			"art": ivo.debug_get_character_art_snapshot()
		}))
		finish()
		return
	await create_timer(0.25).timeout
	var work_art: Dictionary = ivo.debug_get_character_art_snapshot()
	var work_spatial: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	check(int(work_art.get("movement_activation_count", 0)) > 0, "Formal garden route never activated Ivo locomotion")
	check(str(work_spatial.get("path_phase", "")) == "active_workstation", "Ivo garden occupancy was not committed")
	check(str(work_art.get("desired_state", "")) == "work" and str(work_art.get("current_clip", "")) == "Digging", "Garden authority did not select Digging")
	check(int(work_art.get("work_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Ivo digging clip is not cyclic")
	check(bool(work_art.get("garden_hoe_visible", false)), "Garden hoe is not visible after plot arrival")
	check(str(work_art.get("garden_hoe_parent", "")) == "RightHand", "Garden hoe is not attached to RightHand")
	check(not bool(work_art.get("hammer_visible", true)) and not bool(work_art.get("stable_broom_visible", true)) and not bool(work_art.get("cook_spoon_visible", true)), "Ivo carries another profession's tool")
	check(facing_dot(work_art) > 0.9, "Ivo visible front is opposite the garden plot")
	var work_cycle_quality := await _observe_work_cycle_quality(ivo)
	check(bool(work_cycle_quality.get("wrapped", false)), "Ivo digging did not repeat across an animation boundary")
	check(float(work_cycle_quality.get("minimum_blade_front_offset", -1.0)) > 0.12, "Garden hoe blade trails behind Ivo during the digging cycle")
	check(float(work_cycle_quality.get("two_hand_grip_ratio", 0.0)) >= 0.7, "Garden hoe shaft does not stay within Ivo's two-hand working area")

	action_system.interrupt_npc_action(NPC_ID, "verify_t0130_p4_switch_to_prayer", true)
	await process_frame
	npc_system.update_npc_state(NPC_ID, {"current_action": "idle"})
	var prayer_button := gm.find_child("FormalChapelPrayerButton", true, false) as Button
	check(prayer_button != null, "GM formal-prayer entry is missing")
	if prayer_button != null:
		gm.visible = true
		prayer_button.pressed.emit()
		await process_frame
		var reached_prayer_seat := await _wait_for_action(action_system, time_system, PRAYER_ACTION_ID)
		check(reached_prayer_seat, "Ivo did not physically reach a chapel prayer seat")
		if not reached_prayer_seat:
			finish()
			return
		await create_timer(0.18).timeout
		var prayer_art: Dictionary = ivo.debug_get_character_art_snapshot()
		var attachment: Dictionary = ivo.debug_get_spatial_attachment_snapshot()
		check(str(prayer_art.get("desired_state", "")) == "seated_prayer", "Real prayer did not select seated-prayer")
		check(int(prayer_art.get("seated_prayer_clip_loop_mode", Animation.LOOP_NONE)) == Animation.LOOP_LINEAR, "Ivo prayer clip is not cyclic")
		check(not bool(prayer_art.get("garden_hoe_visible", true)), "Garden hoe remained visible in the chapel")
		check(bool(attachment.get("active", false)) and str(attachment.get("pose", "")) == "seated_prayer", "Real prayer did not mount Ivo to a chapel bench")
		action_system.interrupt_npc_action(NPC_ID, "verify_t0130_p4_prayer_complete", true)
		await process_frame

	var damage_result: Dictionary = npc_system.debug_damage_npc(NPC_ID, 9999)
	check(bool(damage_result.get("ok", false)), "Ivo authoritative damage entry failed")
	await process_frame
	var unconscious_art: Dictionary = ivo.debug_get_character_art_snapshot()
	check(str(unconscious_art.get("desired_state", "")) == "unconscious", "Ivo unconscious state did not select the fall clip")
	check(not bool(unconscious_art.get("garden_hoe_visible", true)), "Ivo retained the garden hoe while unconscious")
	var recovery_result: Dictionary = npc_system.debug_advance_unconscious_recovery(NPC_ID, 100.0 * 3600.0)
	check(not (recovery_result.get("revived", []) as Array).is_empty(), "Ivo did not revive through the authority recovery API")
	await process_frame
	check(str(ivo.debug_get_character_art_snapshot().get("desired_state", "")) == "get_up", "Ivo revival did not select get-up")
	check(gm.find_child("FormalGardenWorkButton", true, false) != null, "GM formal-garden entry is missing")
	finish()


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_action(action_system: Node, time_system: Node, action_id: String, max_frames: int = 3600) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		await process_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == action_id:
			return true
	return false


func _observe_work_cycle_quality(ivo: Node) -> Dictionary:
	var previous := float(ivo.debug_get_character_art_snapshot().get("work_cycle_position", -1.0))
	var wrapped := false
	var minimum_blade_front_offset := INF
	var grip_samples := 0
	var sample_count := 0
	for _sample in range(320):
		await create_timer(0.02).timeout
		var snapshot: Dictionary = ivo.debug_get_character_art_snapshot()
		var current := float(snapshot.get("work_cycle_position", -1.0))
		minimum_blade_front_offset = minf(minimum_blade_front_offset, float(snapshot.get("garden_hoe_front_offset", -1.0)))
		if float(snapshot.get("garden_hoe_left_hand_distance", INF)) <= 0.28:
			grip_samples += 1
		sample_count += 1
		if current >= 0.0 and previous >= 0.0 and current + 0.04 < previous:
			wrapped = true
			if sample_count >= 80:
				break
		previous = current
	return {
		"wrapped": wrapped,
		"minimum_blade_front_offset": minimum_blade_front_offset,
		"two_hand_grip_ratio": float(grip_samples) / maxf(1.0, float(sample_count)),
	}


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
		print("T0130_P4_IVO_CHARACTER_INTEGRATION PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0130_P4_IVO_CHARACTER_INTEGRATION FAIL count=%d" % _failures.size())
	quit(1)
