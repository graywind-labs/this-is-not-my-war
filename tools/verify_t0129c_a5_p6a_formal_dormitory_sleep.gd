extends SceneTree


const NPC_ID := "veteran_deputy_01"
const BUILDING_ID := "dormitory"
const ACTION_ID := "sleep_in_dormitory"
const BED_ID := "dormitory_bed_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var needs_system := root.get_node_or_null("Main/Systems/NPCNeedsSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var reflection_system := root.get_node_or_null("Main/Systems/DailyReflectionSystem")
	var daily_plan_system := root.get_node_or_null("Main/Systems/DailyPlanSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var run_button := gm_window.find_child("FormalDormitorySleepButton", true, false) as Button if gm_window != null else null
	var stop_button := gm_window.find_child("FormalDormitorySleepStopButton", true, false) as Button if gm_window != null else null
	var ada := _get_npc_node(npc_system, NPC_ID) if npc_system != null else null
	if [action_system, npc_system, building_system, needs_system, memory_system, reflection_system, daily_plan_system, time_system, gm_window, run_button, stop_button, ada].has(null):
		_fail("A5-P6a runtime dependencies unavailable")
		return

	time_system.set_paused(false)
	daily_plan_system.set_auto_execution_enabled(false)
	ada.set("move_speed", 5.0)
	npc_system.update_npc_state(NPC_ID, {
		"fatigue": 80,
		"satiety": 100,
		"current_action": "idle",
		"last_action_result": "verify_a5_p6a_ready"
	})

	var action: Dictionary = action_system.get_action(ACTION_ID)
	var bed: Dictionary = _get_bed(building_system)
	if not bool(action.get("formal_spatial_route", false)):
		_fail("sleep_in_dormitory is not configured for formal spatial authority")
		return
	if str(bed.get("assigned_npc_id", "")) != NPC_ID:
		_fail("dormitory_bed_01 is not assigned to Ada")
		return

	var sleep_started_before := _count_event(memory_system.get_npc_daily_events(NPC_ID), "sleep_started")
	var reflection_before: Dictionary = reflection_system.get_async_reflection_snapshot()
	var fatigue_before_travel := float(npc_system.get_npc_state(NPC_ID).get("fatigue", -1.0))
	gm_window.visible = true
	run_button.pressed.emit()
	await process_frame
	var pending: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	var pending_attachment: Dictionary = ada.debug_get_spatial_attachment_snapshot()
	if (
		gm_window.visible
		or str(pending.get("phase", "")) != "pending"
		or not _bed_reserved_by(building_system, NPC_ID)
		or bool(pending_attachment.get("active", false))
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "sleep_started") != sleep_started_before
	):
		_fail("Sleep departure did not remain reservation-only before physical arrival")
		return

	needs_system._on_logical_time_tick(3600.0, 1.0)
	var fatigue_during_travel := float(npc_system.get_npc_state(NPC_ID).get("fatigue", -1.0))
	var reflection_during_travel: Dictionary = reflection_system.get_async_reflection_snapshot()
	if (
		fatigue_during_travel < fatigue_before_travel
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "sleep_started") != sleep_started_before
		or reflection_during_travel.get("sleep_window_states_by_npc", {}) != reflection_before.get("sleep_window_states_by_npc", {})
	):
		_fail("Travelling to bed restored fatigue or opened the first-sleep window")
		return

	if not await _wait_for_active(action_system, time_system):
		_fail("Ada did not physically reach her assigned bed: %s" % JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID)))
		return
	await create_timer(0.12).timeout
	var active_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var attachment: Dictionary = ada.debug_get_spatial_attachment_snapshot()
	var character_art: Dictionary = ada.debug_get_character_art_snapshot()
	var pose_offset := character_art.get("presentation_pose_offset", Vector3.ZERO) as Vector3
	var active_bed: Dictionary = _get_bed(building_system)
	if (
		str(active_state.get("current_workstation_id", "")) != BED_ID
		or str(active_state.get("spatial_route_phase", "")) != "occupant_attached"
		or str(active_state.get("physical_location_phase", "")) != "occupant_anchor"
		or str(active_bed.get("occupied_by", "")) != NPC_ID
		or not bool(attachment.get("active", false))
		or str(attachment.get("pose", "")) != "sleeping_supine"
		or not bool(attachment.get("body_collision_disabled", false))
		or not bool(attachment.get("interaction_enabled", false))
		or absf(pose_offset.y + 0.18) > 0.001
		or absf(Vector2(pose_offset.x, pose_offset.z).length() - 0.22) > 0.001
		or absf((character_art.get("visual_root_local_position", Vector3.ZERO) as Vector3).y + 0.18) > 0.001
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "sleep_started") != sleep_started_before + 1
	):
		_fail("Bed commit did not atomically attach Ada and start real sleep: %s" % JSON.stringify({
			"state": active_state,
			"bed": active_bed,
			"attachment": attachment
		}))
		return

	var fatigue_before_sleep_tick := float(active_state.get("fatigue", -1.0))
	needs_system._on_logical_time_tick(3600.0, 1.0)
	var fatigue_after_sleep_tick := float(npc_system.get_npc_state(NPC_ID).get("fatigue", -1.0))
	if fatigue_after_sleep_tick >= fatigue_before_sleep_tick:
		_fail("Active bed sleep did not restore fatigue")
		return

	# The visible GM stop path must not award extra recovery and must restore the
	# character's physical collision and the fixed bed's availability.
	var fatigue_before_stop := fatigue_after_sleep_tick
	gm_window.visible = true
	stop_button.pressed.emit()
	await process_frame
	await physics_frame
	if (
		float(npc_system.get_npc_state(NPC_ID).get("fatigue", -1.0)) != fatigue_before_stop
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or not _bed_is_clear(building_system)
		or bool(ada.debug_get_spatial_attachment_snapshot().get("active", false))
		or bool(ada.debug_get_spatial_attachment_snapshot().get("body_collision_disabled", false))
	):
		_fail("GM sleep interruption changed needs or left bed/session/collision dirty")
		return

	# A second real route validates normal completion cleanup and the existing
	# 6.5-hour duration without invoking the reflection provider in this test.
	gm_window.visible = true
	run_button.pressed.emit()
	await process_frame
	if not await _wait_for_active(action_system, time_system):
		_fail("Ada did not reach her bed for completion verification")
		return
	var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
	action_system._on_logical_time_tick(float(runtime.get("duration_seconds", 23400.0)) + 1.0, 1.0)
	await process_frame
	await physics_frame
	if (
		bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or not _bed_is_clear(building_system)
		or bool(ada.debug_get_spatial_attachment_snapshot().get("active", false))
		or bool(ada.debug_get_spatial_attachment_snapshot().get("body_collision_disabled", false))
		or _count_event(memory_system.get_npc_daily_events(NPC_ID), "sleep_ended") < 1
	):
		_fail("Normal sleep completion did not release the bed, attachment, collision, and formal session")
		return

	print("T0129C A5-P6a formal dormitory sleep verification passed")
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_active(action_system: Node, time_system: Node, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == ACTION_ID:
			return true
	return false


func _count_event(events: Array, event_type: String) -> int:
	var count := 0
	for raw_event in events:
		if raw_event is Dictionary and str(raw_event.get("type", "")) == event_type:
			count += 1
	return count


func _get_bed(building_system: Node) -> Dictionary:
	for raw_workstation in building_system.get_building(BUILDING_ID).get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("id", "")) == BED_ID:
			return raw_workstation
	return {}


func _bed_reserved_by(building_system: Node, npc_id: String) -> bool:
	var bed := _get_bed(building_system)
	var occupied_by: Variant = bed.get("occupied_by")
	return str(bed.get("reserved_by", "")) == npc_id and (occupied_by == null or str(occupied_by).is_empty())


func _bed_is_clear(building_system: Node) -> bool:
	var bed := _get_bed(building_system)
	var occupied_by: Variant = bed.get("occupied_by")
	var reserved_by: Variant = bed.get("reserved_by")
	return (occupied_by == null or str(occupied_by).is_empty()) and (reserved_by == null or str(reserved_by).is_empty())


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
