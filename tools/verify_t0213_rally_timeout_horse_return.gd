extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
const MAX_RALLY_FRAMES := 1800
const RETURN_SAMPLE_FRAMES := 90
const MAX_REMOUNT_FRAMES := 1200
const EXPECTED_WALK_SPEED := 3.2

var _failures: PackedStringArray = []


func _init() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(horse_system != null and npc_system != null and combat_system != null, "T0213 runtime dependencies missing")
	if not _failures.is_empty():
		_finish({})
		return
	if time_system != null:
		time_system.set_paused(false)

	var horse_ids: Array = horse_system.get_horse_ids()
	_check(not horse_ids.is_empty(), "T0213 requires an initial horse")
	if not _failures.is_empty():
		_finish({})
		return
	var horse_id := str(horse_ids[0])
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "t0213_reset", {"force_idle": true})
	var assignment: Dictionary = horse_system.assign_horse_to_npc(NPC_ID, horse_id, "private")
	_check(bool(assignment.get("ok", false)), "T0213 horse assignment failed: %s" % assignment)
	var first_alarm: Dictionary = combat_system.trigger_combat_alarm("t0213_initial_rally")
	_check(bool(first_alarm.get("ok", false)), "T0213 initial alarm failed: %s" % first_alarm)
	if not _failures.is_empty():
		_finish({})
		return

	var reached_rally := false
	for _frame in range(MAX_RALLY_FRAMES):
		await physics_frame
		var rally := _find_rally(combat_system.get_active_rallies(), NPC_ID)
		if str(rally.get("status", "")) == "rallied" and bool(npc_system.get_npc_state(NPC_ID).get("combat_mounted", false)):
			reached_rally = true
			break
	_check(reached_rally, "Mounted rider never reached the initial rally position")
	if not _failures.is_empty():
		_finish({})
		return

	var mounted_position: Vector3 = horse_system.get_horse_snapshot(horse_id).get("world_position", Vector3.ZERO)
	var timeout_result: Dictionary = combat_system.debug_advance_rally_wait(3600.0)
	var returning_horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	var returning_movement: Dictionary = returning_horse.get("movement_state", {})
	var return_start: Vector3 = returning_horse.get("world_position", Vector3.ZERO)
	var initial_motion: Dictionary = horse_system.get_horse_motion_snapshot(horse_id)
	_check(str(npc_system.get_npc_state(NPC_ID).get("behavior_mode", "")) == "work", "Rally timeout did not restore work mode")
	_check(str(returning_horse.get("location", "")) == "returning_stable", "Rally timeout did not start physical horse return")
	_check(str(returning_movement.get("phase", "")) == "returning_stable", "Horse return phase is missing")
	_check(str(returning_movement.get("locomotion_mode", "")) == "walk", "Horse return is not marked as walking")
	_check(str(returning_horse.get("assigned_npc_id", "")) == NPC_ID, "Rally timeout cleared the retained horse assignment")
	_check(return_start.distance_to(mounted_position) <= 0.01, "Horse teleported on the rally-timeout dismount frame")
	_check(str(initial_motion.get("movement_authority", "")) == "ActorMotionBody", "Horse return is not using the shared ActorMotionBody navigation authority")
	_check(str(initial_motion.get("movement_purpose", "")) == "horse_return_to_stable", "Horse return motion purpose is incorrect")
	_check(absf(float(initial_motion.get("profile_base_speed", 0.0)) - EXPECTED_WALK_SPEED) <= 0.01, "Horse return speed is not the configured walk speed")
	if not _failures.is_empty():
		_finish({"timeout": timeout_result})
		return

	var previous_position := return_start
	var maximum_frame_displacement := 0.0
	var return_distance := 0.0
	for _frame in range(RETURN_SAMPLE_FRAMES):
		await physics_frame
		var current_horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
		if str(current_horse.get("location", "")) != "returning_stable":
			break
		var current_position: Vector3 = current_horse.get("world_position", previous_position)
		var displacement := Vector2(current_position.x - previous_position.x, current_position.z - previous_position.z).length()
		maximum_frame_displacement = maxf(maximum_frame_displacement, displacement)
		return_distance += displacement
		previous_position = current_position
	var sampled_motion: Dictionary = horse_system.get_horse_motion_snapshot(horse_id)
	var return_presentation: Dictionary = horse_system.get_horse_presentation_snapshot(horse_id)
	_check(return_distance > 0.5, "Horse did not physically walk along its return route")
	_check(maximum_frame_displacement <= EXPECTED_WALK_SPEED / 60.0 + 0.025, "Horse return exceeded the walk-speed frame bound: %.4f" % maximum_frame_displacement)
	_check(str(sampled_motion.get("path_plan_mode", "pending")) != "pending", "Horse return never acquired a production navigation path")
	_check(bool(return_presentation.get("moving_animation", false)), "Returning horse presentation is not playing a moving animation")
	_check(str(return_presentation.get("motion_animation", "")).ends_with("Walk"), "Returning horse presentation is not using the Walk clip")
	_check(str(horse_system.get_horse_snapshot(horse_id).get("location", "")) == "returning_stable", "Horse reached the stable before the return-interruption check")
	if not _failures.is_empty():
		_finish({"return_distance": return_distance, "maximum_frame_displacement": maximum_frame_displacement})
		return

	var stopped_position: Vector3 = horse_system.get_horse_snapshot(horse_id).get("world_position", Vector3.ZERO)
	var second_alarm: Dictionary = combat_system.trigger_combat_alarm("t0213_return_interrupted")
	var waiting_horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	var waiting_movement: Dictionary = waiting_horse.get("movement_state", {})
	_check(bool(second_alarm.get("ok", false)), "T0213 second alarm failed: %s" % second_alarm)
	_check(str(waiting_movement.get("phase", "")) == "waiting_for_rider_at_return_position", "Returning horse did not stop for its rider")
	_check(bool(waiting_movement.get("horse_stationary", false)), "Interrupted returning horse is not stationary")
	_check(str(waiting_movement.get("pickup_source", "")) == "return_path_current_position", "Return-path pickup source is incorrect")
	_check(str(npc_system.get_npc_state(NPC_ID).get("combat_mount_phase", "")) == "going_to_returning_horse", "Rider was not redirected to the stopped horse")
	_check(waiting_horse.get("world_position", Vector3.ZERO).distance_to(stopped_position) <= 0.01, "Horse moved when the second alarm interrupted its return")
	if not _failures.is_empty():
		_finish({})
		return

	var maximum_wait_drift := 0.0
	var waiting_frames := 0
	var remounted := false
	for _frame in range(MAX_REMOUNT_FRAMES):
		await physics_frame
		var horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
		var movement: Dictionary = horse.get("movement_state", {})
		if str(movement.get("phase", "")) == "waiting_for_rider_at_return_position":
			waiting_frames += 1
			maximum_wait_drift = maxf(maximum_wait_drift, (horse.get("world_position", stopped_position) as Vector3).distance_to(stopped_position))
		if str(horse.get("location", "")) == "ridden" and bool(npc_system.get_npc_state(NPC_ID).get("combat_mounted", false)):
			remounted = true
			break
	_check(waiting_frames > 0, "Interrupted horse never exposed a stationary waiting interval")
	_check(maximum_wait_drift <= 0.01, "Horse drifted while waiting for its rider: %.4f" % maximum_wait_drift)
	_check(remounted, "Rider did not reach and remount the stopped horse")
	var resumed_rally := _find_rally(combat_system.get_active_rallies(), NPC_ID)
	_check(str(resumed_rally.get("status", "")) == "moving", "Mounted rider did not resume the second rally route")
	var rider_motion := _get_npc_motion_snapshot(npc_system, NPC_ID)
	_check(str(rider_motion.get("request_id", "")).begins_with("combat_rally_"), "Mounted rider did not resume the authoritative rally movement request")
	var presentation: Dictionary = horse_system.get_horse_presentation_snapshot(horse_id)
	_finish({
		"return_distance": return_distance,
		"maximum_frame_displacement": maximum_frame_displacement,
		"maximum_wait_drift": maximum_wait_drift,
		"waiting_frames": waiting_frames,
		"return_motion": initial_motion,
		"sampled_return_motion": sampled_motion,
		"return_presentation": return_presentation,
		"resumed_rally": resumed_rally,
		"presentation": presentation
	})


func _get_npc_motion_snapshot(npc_system: Node, npc_id: String) -> Dictionary:
	var npc_node := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as ActorMotionBody
	return npc_node.debug_get_motion_snapshot() if npc_node != null else {}


func _find_rally(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(metrics: Dictionary) -> void:
	print("T0213_RALLY_TIMEOUT_HORSE_RETURN_METRICS=%s" % JSON.stringify(metrics))
	if _failures.is_empty():
		print("T0213 rally-timeout horse return verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
