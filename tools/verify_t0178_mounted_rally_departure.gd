extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const NPC_IDS: Array[String] = [
	"stableman_01",
	"cook_01",
	"gardener_01",
	"blacksmith_01",
	"veteran_deputy_01",
	"priest_01",
	"doctor_01",
	"engineer_01"
]
const RIDER_IDS: Array[String] = [
	"veteran_deputy_01",
	"blacksmith_01",
	"stableman_01",
	"engineer_01"
]
const MAX_PHYSICS_FRAMES := 3000
const TURN_WINDOW_FRAMES := 180

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(8):
		await process_frame
		await physics_frame

	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(equipment_system != null and npc_system != null and combat_system != null, "T0178 runtime dependencies missing")
	if not _failures.is_empty():
		_finish({})
		return
	if time_system != null:
		time_system.set_paused(false)
	var preset: Dictionary = equipment_system.debug_apply_combat_loadout_preset()
	_check(bool(preset.get("ok", false)), "T0178 GM combat preset failed: %s" % preset)
	var alarm: Dictionary = combat_system.trigger_combat_alarm("t0178_shared_waypoint_progression")
	_check(bool(alarm.get("ok", false)), "T0178 combat alarm failed: %s" % alarm)
	if not _failures.is_empty():
		_finish({})
		return

	var metrics := {}
	for npc_id in NPC_IDS:
		var rally := _find_rally(combat_system.get_active_rallies(), npc_id)
		metrics[npc_id] = {
			"formation_position": _to_vector3(rally.get("position", {})),
			"movement_started": false,
			"mounted": false,
			"rallied": false,
			"start_frame": -1,
			"start_position": Vector3.ZERO,
			"last_position": Vector3.ZERO,
			"heading_sample_position": Vector3.ZERO,
			"last_direction": Vector3.ZERO,
			"path_length": 0.0,
			"best_target_distance": INF,
			"maximum_target_regression": 0.0,
			"maximum_target_regression_frame": -1,
			"maximum_target_regression_position": {},
			"maximum_target_regression_motion": {},
			"turn_window": [],
			"turn_window_sum": 0.0,
			"maximum_turn_in_three_seconds": 0.0,
			"maximum_turn_frame": -1,
			"maximum_turn_position": {},
			"maximum_turn_motion": {},
			"maximum_waypoint_advance_count": 0,
			"maximum_missed_waypoint_advance_count": 0,
			"maximum_no_progress_samples": 0,
			"last_result": ""
		}

	for frame in range(MAX_PHYSICS_FRAMES):
		await physics_frame
		var all_rallied := true
		for npc_id in NPC_IDS:
			var entry: Dictionary = metrics[npc_id]
			var state: Dictionary = npc_system.get_npc_state(npc_id)
			entry["mounted"] = bool(entry.get("mounted", false)) or bool(state.get("combat_mounted", false))
			var rally := _find_rally(combat_system.get_active_rallies(), npc_id)
			var rally_status := str(rally.get("status", ""))
			var npc_node := npc_system.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as ActorMotionBody
			var motion: Dictionary = npc_node.debug_get_motion_snapshot() if npc_node != null else {}
			var request_id := str(motion.get("request_id", ""))
			var position_value: Variant = npc_system.get_npc_world_position(npc_id)
			var position: Vector3 = position_value if position_value is Vector3 else Vector3.ZERO
			if request_id.begins_with("combat_rally_") and not bool(entry.get("movement_started", false)):
				entry["movement_started"] = true
				entry["start_frame"] = frame
				entry["start_position"] = position
				entry["last_position"] = position
				entry["heading_sample_position"] = position
				entry["best_target_distance"] = position.distance_to(entry.get("formation_position", position))
			if bool(entry.get("movement_started", false)) and not bool(entry.get("rallied", false)):
				_sample_rally_motion(entry, frame, position, motion)
				entry["maximum_waypoint_advance_count"] = maxi(
					int(entry.get("maximum_waypoint_advance_count", 0)),
					int(motion.get("intermediate_waypoint_advance_count", 0))
				)
				entry["maximum_no_progress_samples"] = maxi(
					int(entry.get("maximum_no_progress_samples", 0)),
					int(motion.get("no_progress_samples", 0))
				)
				entry["maximum_missed_waypoint_advance_count"] = maxi(
					int(entry.get("maximum_missed_waypoint_advance_count", 0)),
					int(motion.get("missed_waypoint_advance_count", 0))
				)
				entry["last_result"] = str(motion.get("last_result", ""))
			if rally_status == "rallied":
				entry["rallied"] = true
			else:
				all_rallied = false
			metrics[npc_id] = entry
		if all_rallied:
			break

	for npc_id in NPC_IDS:
		var entry: Dictionary = metrics[npc_id]
		var start_position: Vector3 = entry.get("start_position", Vector3.ZERO)
		var last_position: Vector3 = entry.get("last_position", start_position)
		var net_displacement := start_position.distance_to(last_position)
		var path_length := float(entry.get("path_length", 0.0))
		entry["net_displacement"] = net_displacement
		entry["path_efficiency"] = net_displacement / maxf(0.001, path_length)
		entry.erase("turn_window")
		entry.erase("turn_window_sum")
		entry.erase("heading_sample_position")
		entry["formation_position"] = _vector3_to_dict(entry.get("formation_position", Vector3.ZERO))
		entry["start_position"] = _vector3_to_dict(start_position)
		entry["last_position"] = _vector3_to_dict(last_position)
		entry["last_direction"] = _vector3_to_dict(entry.get("last_direction", Vector3.ZERO))
		_check(bool(entry.get("movement_started", false)), "%s never started its reserved rally movement" % npc_id)
		_check(bool(entry.get("rallied", false)), "%s never reached its reserved rally position" % npc_id)
		_check(float(entry.get("maximum_target_regression", INF)) <= 0.5, "%s regressed %.3f m from its rally target" % [npc_id, float(entry.get("maximum_target_regression", INF))])
		_check(float(entry.get("maximum_turn_in_three_seconds", INF)) < PI * 1.5, "%s accumulated %.3f rad of turning inside three seconds" % [npc_id, float(entry.get("maximum_turn_in_three_seconds", INF))])
		_check(float(entry.get("path_efficiency", 0.0)) >= 0.82, "%s path efficiency %.3f indicates wandering" % [npc_id, float(entry.get("path_efficiency", 0.0))])
		_check(str(entry.get("last_result", "")) != "stuck_timeout", "%s hit stuck_timeout" % npc_id)
		if npc_id in RIDER_IDS:
			_check(bool(entry.get("mounted", false)), "%s never mounted" % npc_id)
		metrics[npc_id] = entry
	_finish(metrics)


func _sample_rally_motion(entry: Dictionary, frame: int, position: Vector3, motion: Dictionary) -> void:
	var target: Vector3 = entry.get("formation_position", position)
	var target_distance := position.distance_to(target)
	var best_distance := minf(float(entry.get("best_target_distance", INF)), target_distance)
	entry["best_target_distance"] = best_distance
	var regression := target_distance - best_distance
	if regression > float(entry.get("maximum_target_regression", 0.0)):
		entry["maximum_target_regression"] = regression
		entry["maximum_target_regression_frame"] = frame
		entry["maximum_target_regression_position"] = _vector3_to_dict(position)
		entry["maximum_target_regression_motion"] = _motion_diagnostic(motion)
	var displacement := position - (entry.get("last_position", position) as Vector3)
	displacement.y = 0.0
	var displacement_length := displacement.length()
	if displacement_length > 0.002:
		entry["path_length"] = float(entry.get("path_length", 0.0)) + displacement_length
	# Derive heading from meaningful 0.25 m chords. Per-frame RVO corrections can
	# alternate by large angles while still producing one smooth visible stride;
	# summing those raw micro-directions misclassifies ordinary avoidance as a loop.
	var heading_origin: Vector3 = entry.get("heading_sample_position", position)
	var heading_displacement := position - heading_origin
	heading_displacement.y = 0.0
	if heading_displacement.length() >= 0.25 and target_distance > 3.0:
		var direction := heading_displacement.normalized()
		var last_direction: Vector3 = entry.get("last_direction", Vector3.ZERO)
		if last_direction.length_squared() > 0.5:
			var turn := absf(last_direction.signed_angle_to(direction, Vector3.UP))
			var turn_window: Array = entry.get("turn_window", [])
			turn_window.append({"frame": frame, "turn": turn})
			var turn_sum := float(entry.get("turn_window_sum", 0.0)) + turn
			while not turn_window.is_empty() and frame - int((turn_window[0] as Dictionary).get("frame", frame)) > TURN_WINDOW_FRAMES:
				turn_sum -= float((turn_window.pop_front() as Dictionary).get("turn", 0.0))
			entry["turn_window"] = turn_window
			entry["turn_window_sum"] = turn_sum
			if turn_sum > float(entry.get("maximum_turn_in_three_seconds", 0.0)):
				entry["maximum_turn_in_three_seconds"] = turn_sum
				entry["maximum_turn_frame"] = frame
				entry["maximum_turn_position"] = _vector3_to_dict(position)
				entry["maximum_turn_motion"] = _motion_diagnostic(motion)
		entry["last_direction"] = direction
		entry["heading_sample_position"] = position
	entry["last_position"] = position


func _motion_diagnostic(motion: Dictionary) -> Dictionary:
	var velocity: Vector3 = motion.get("velocity", Vector3.ZERO)
	var waypoint: Vector3 = motion.get("last_waypoint_position", Vector3.ZERO)
	return {
		"path_index": int(motion.get("current_path_index", -1)),
		"waypoint_distance": float(motion.get("last_waypoint_distance", INF)),
		"waypoint_position": _vector3_to_dict(waypoint),
		"waypoint_tolerance": float(motion.get("last_adaptive_waypoint_tolerance", 0.0)),
		"shortcut_clear": bool(motion.get("last_waypoint_shortcut_clear", false)),
		"missed_waypoint_advances": int(motion.get("missed_waypoint_advance_count", 0)),
		"remaining_path_distance": float(motion.get("remaining_path_distance", INF)),
		"velocity": _vector3_to_dict(velocity)
	}


func _find_rally(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	if value is Dictionary:
		return Vector3(float(value.get("x", 0.0)), float(value.get("y", 0.0)), float(value.get("z", 0.0)))
	return Vector3.ZERO


func _vector3_to_dict(value: Vector3) -> Dictionary:
	return {"x": value.x, "y": value.y, "z": value.z}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(metrics: Dictionary) -> void:
	print("T0178_SHARED_WAYPOINT_METRICS=%s" % JSON.stringify(metrics))
	if _failures.is_empty():
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
