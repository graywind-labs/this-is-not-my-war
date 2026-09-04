extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_ID := "veteran_deputy_01"
const MAX_RALLY_FRAMES := 1800
const RETURN_TRAVEL_FRAMES := 90
const MAX_COMBAT_HANDOFF_FRAMES := 600
const MAX_RUN_SAMPLE_FRAMES := 240
const RUN_SPEED_FLOOR := 3.25

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
	_check(horse_system != null and npc_system != null and combat_system != null, "T0316 runtime dependencies missing")
	if not _failures.is_empty():
		_finish({})
		return
	if time_system != null:
		time_system.set_paused(false)

	var horse_ids: Array = horse_system.get_horse_ids()
	_check(not horse_ids.is_empty(), "T0316 requires an initial horse")
	if not _failures.is_empty():
		_finish({})
		return
	var horse_id := str(horse_ids[0])
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "t0316_reset", {"force_idle": true})
	var assignment: Dictionary = horse_system.assign_horse_to_npc(NPC_ID, horse_id, "private")
	_check(bool(assignment.get("ok", false)), "T0316 horse assignment failed: %s" % assignment)
	var alarm: Dictionary = combat_system.trigger_combat_alarm("t0316_initial_rally")
	_check(bool(alarm.get("ok", false)), "T0316 initial alarm failed: %s" % alarm)
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
	_check(reached_rally, "T0316 rider never reached the initial mounted rally")
	if not _failures.is_empty():
		_finish({})
		return

	var dismiss: Dictionary = combat_system.dismiss_combat_rally("t0316_manual_dismiss")
	_check(bool(dismiss.get("ok", false)), "T0316 manual rally dismiss failed: %s" % dismiss)
	for _frame in range(RETURN_TRAVEL_FRAMES):
		await physics_frame
	var returning_horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	var returning_movement: Dictionary = returning_horse.get("movement_state", {})
	_check(str(returning_horse.get("location", "")) == "returning_stable", "Dismiss did not leave the horse returning to the stable")
	_check(str(returning_movement.get("phase", "")) == "returning_stable", "Dismissed horse return phase is missing")
	var stopped_position: Vector3 = returning_horse.get("world_position", Vector3.ZERO)

	var spawn: Dictionary = combat_system.debug_spawn_wave(1, true, true)
	_check(bool(spawn.get("ok", false)), "T0316 enemy wave spawn failed: %s" % spawn)
	var entered_combat := false
	for _frame in range(MAX_COMBAT_HANDOFF_FRAMES):
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		if (
			str(state.get("behavior_mode", "")) == "combat"
			and str(state.get("combat_mount_phase", "")) == "going_to_returning_horse"
		):
			entered_combat = true
			break
	_check(entered_combat, "Returning-horse rider did not enter the direct enemy-contact pickup branch")
	if not _failures.is_empty():
		_finish({"spawn": spawn})
		return

	var maximum_actual_speed := 0.0
	var observed_run_locomotion := false
	var observed_run_presentation := false
	var observed_active_motion := false
	var waiting_frames := 0
	var maximum_horse_wait_drift := 0.0
	var waiting_horse_position := Vector3.ZERO
	var last_locomotion: Dictionary = {}
	var last_presentation: Dictionary = {}
	var last_motion: Dictionary = {}
	for _frame in range(MAX_RUN_SAMPLE_FRAMES):
		await physics_frame
		var horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
		var movement: Dictionary = horse.get("movement_state", {})
		if str(movement.get("phase", "")) != "waiting_for_rider_at_return_position":
			break
		if waiting_frames == 0:
			waiting_horse_position = horse.get("world_position", stopped_position)
		waiting_frames += 1
		maximum_horse_wait_drift = maxf(
			maximum_horse_wait_drift,
			(horse.get("world_position", waiting_horse_position) as Vector3).distance_to(waiting_horse_position)
		)
		last_locomotion = npc_system.get_npc_locomotion_needs_snapshot(NPC_ID)
		maximum_actual_speed = maxf(maximum_actual_speed, float(last_locomotion.get("actual_horizontal_speed", 0.0)))
		observed_run_locomotion = observed_run_locomotion or str(last_locomotion.get("locomotion_state", "")) == "run"
		observed_active_motion = observed_active_motion or bool(last_locomotion.get("movement_active", false))
		var npc_node := npc_system.get_node_or_null(npc_system._npc_nodes.get(NPC_ID, NodePath()))
		last_presentation = npc_node.debug_get_character_art_snapshot() if npc_node != null else {}
		last_motion = npc_node.debug_get_motion_snapshot() if npc_node != null else {}
		observed_run_presentation = observed_run_presentation or (
			str(last_presentation.get("desired_state", "")) == "run"
			and str(last_presentation.get("locomotion_state", "")) == "run"
			and bool(last_presentation.get("current_animation_playing", false))
		)

	_check(waiting_frames > 0, "Returning horse never exposed a stationary direct-contact pickup interval")
	_check(maximum_horse_wait_drift <= 0.01, "Returning horse drifted while waiting for its rider: %.4f" % maximum_horse_wait_drift)
	_check(observed_active_motion, "Direct-contact pickup never activated NPC navigation")
	_check(observed_run_locomotion, "Direct-contact pickup did not use run locomotion")
	_check(maximum_actual_speed > RUN_SPEED_FLOOR, "Direct-contact pickup remained below the run-speed floor: %.3f" % maximum_actual_speed)
	_check(observed_run_presentation, "Direct-contact pickup did not play the run presentation")
	var final_horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	var final_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	_check(str(final_horse.get("location", "")) == "ridden", "Rider did not complete the stopped-horse remount")
	_check(bool(final_state.get("combat_mounted", false)), "NPC combat state did not commit the completed remount")
	_check(str(final_state.get("behavior_mode", "")) in ["combat", "rally"], "Remounted NPC left wartime control unexpectedly")
	_finish({
		"waiting_frames": waiting_frames,
		"maximum_actual_speed": maximum_actual_speed,
		"maximum_horse_wait_drift": maximum_horse_wait_drift,
		"final_horse_location": final_horse.get("location", ""),
		"final_behavior_mode": final_state.get("behavior_mode", ""),
		"final_combat_mounted": final_state.get("combat_mounted", false),
		"last_locomotion": last_locomotion,
		"last_motion": {
			"state": last_motion.get("state", ""),
			"request_id": last_motion.get("request_id", ""),
			"elapsed_seconds": last_motion.get("elapsed_seconds", 0.0),
			"speed_limit_reason": last_motion.get("speed_limit_reason", ""),
			"requested_speed": last_motion.get("requested_speed", 0.0),
			"desired_speed": last_motion.get("desired_speed", 0.0),
			"candidate_speed": last_motion.get("candidate_speed", 0.0),
			"rvo_safe_speed": last_motion.get("rvo_safe_speed", 0.0),
			"actual_speed": last_motion.get("actual_speed", 0.0),
			"target_desired_distance": last_motion.get("target_desired_distance", 0.0),
			"minimum_target_distance": last_motion.get("minimum_target_distance", 0.0),
			"remaining_path_distance": last_motion.get("remaining_path_distance", 0.0),
			"target_position": last_motion.get("target_position", Vector3.ZERO),
			"world_position": last_motion.get("world_position", Vector3.ZERO),
		},
		"last_presentation": {
			"current_state": last_presentation.get("current_state", ""),
			"desired_state": last_presentation.get("desired_state", ""),
			"locomotion_state": last_presentation.get("locomotion_state", ""),
			"current_animation_playing": last_presentation.get("current_animation_playing", false),
			"locomotion_animation_speed_scale": last_presentation.get("locomotion_animation_speed_scale", 0.0),
		}
	})


func _find_rally(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(metrics: Dictionary) -> void:
	print("T0316_RETURNING_HORSE_ENEMY_REMOUNT_METRICS=%s" % JSON.stringify(metrics))
	if _failures.is_empty():
		print("T0316 returning-horse enemy remount verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
