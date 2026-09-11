extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const RIDER_IDS: Array[String] = [
	"veteran_deputy_01",
	"blacksmith_01",
	"stableman_01",
	"engineer_01",
]
const MAX_PHYSICS_FRAMES := 3000
const MAX_OUTWARD_REGRESSION := 0.45

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(10):
		await process_frame
		await physics_frame

	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var station_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(
		equipment_system != null and npc_system != null and combat_system != null and station_controller != null,
		"T0221 mounted stable-exit dependencies missing"
	)
	if not _failures.is_empty():
		_finish({})
		return
	if time_system != null:
		time_system.set_paused(false)
	var preset: Dictionary = equipment_system.debug_apply_combat_loadout_preset()
	_check(bool(preset.get("ok", false)), "T0221 combat loadout preset failed: %s" % preset)
	var alarm: Dictionary = combat_system.trigger_combat_alarm("t0221_mounted_stable_exit")
	_check(bool(alarm.get("ok", false)), "T0221 combat alarm failed: %s" % alarm)
	if not _failures.is_empty():
		_finish({})
		return

	var stable_route: Dictionary = station_controller.get_building_spatial_route("stable")
	var interior: Vector3 = stable_route.get("interior_position", Vector3.ZERO)
	var door_outside: Vector3 = stable_route.get("door_outside_position", Vector3.ZERO)
	var entry_outside: Vector3 = stable_route.get("entry_outside_position", Vector3.ZERO)
	var forward := entry_outside - interior
	forward.y = 0.0
	forward = forward.normalized()
	var door_outside_progress := (door_outside - interior).dot(forward)
	var metrics := {}
	for npc_id in RIDER_IDS:
		metrics[npc_id] = {
			"mounted": false,
			"crossed_door_outside": false,
			"rallied": false,
			"maximum_progress": -INF,
			"minimum_progress_after_crossing": INF,
			"maximum_outward_regression": 0.0,
			"maximum_prefix_stage": -1,
			"prefix_stage_regressed": false,
			"maximum_prefix_generation_count": 0,
		}

	for _frame in range(MAX_PHYSICS_FRAMES):
		await physics_frame
		var all_rallied := true
		for npc_id in RIDER_IDS:
			var metric: Dictionary = metrics[npc_id]
			var state: Dictionary = npc_system.get_npc_state(npc_id)
			var rally := _find_rally(combat_system.get_active_rallies(), npc_id)
			if bool(state.get("combat_mounted", false)):
				metric["mounted"] = true
				var position_value: Variant = npc_system.get_npc_world_position(npc_id)
				var position: Vector3 = position_value if position_value is Vector3 else Vector3.ZERO
				var progress := (position - interior).dot(forward)
				var maximum_progress := maxf(float(metric.get("maximum_progress", -INF)), progress)
				metric["maximum_progress"] = maximum_progress
				if progress >= door_outside_progress + 0.10:
					metric["crossed_door_outside"] = true
				if bool(metric.get("crossed_door_outside", false)):
					metric["minimum_progress_after_crossing"] = minf(
						float(metric.get("minimum_progress_after_crossing", INF)),
						progress
					)
					metric["maximum_outward_regression"] = maxf(
						float(metric.get("maximum_outward_regression", 0.0)),
						maximum_progress - progress
					)
				var actor := _get_npc_actor(npc_system, npc_id)
				var motion: Dictionary = actor.debug_get_motion_snapshot() if actor != null else {}
				metric["maximum_prefix_generation_count"] = maxi(
					int(metric.get("maximum_prefix_generation_count", 0)),
					int(motion.get("indoor_exit_prefix_generation_count", 0))
				)
				var point_id := str(motion.get("indoor_exit_prefix_current_point_id", ""))
				var stage := _prefix_stage(point_id, bool(motion.get("indoor_exit_prefix_active", false)))
				if stage >= 0:
					if stage < int(metric.get("maximum_prefix_stage", -1)):
						metric["prefix_stage_regressed"] = true
					metric["maximum_prefix_stage"] = maxi(int(metric.get("maximum_prefix_stage", -1)), stage)
			if str(rally.get("status", "")) == "rallied":
				metric["rallied"] = true
			else:
				all_rallied = false
			metrics[npc_id] = metric
		if all_rallied:
			break

	for npc_id in RIDER_IDS:
		var metric: Dictionary = metrics[npc_id]
		_check(bool(metric.get("mounted", false)), "T0221 %s never mounted" % npc_id)
		_check(bool(metric.get("crossed_door_outside", false)), "T0221 %s never crossed the stable doorway" % npc_id)
		_check(bool(metric.get("rallied", false)), "T0221 %s never reached rally after leaving the stable" % npc_id)
		_check(not bool(metric.get("prefix_stage_regressed", true)), "T0221 %s exit prefix stage moved backwards" % npc_id)
		_check(
			float(metric.get("maximum_outward_regression", INF)) <= MAX_OUTWARD_REGRESSION,
			"T0221 %s moved %.3f m back toward the stable after crossing the doorway" % [
				npc_id,
				float(metric.get("maximum_outward_regression", INF)),
			]
		)
	_finish(metrics)


func _prefix_stage(point_id: String, active: bool) -> int:
	if not active:
		return 4
	return ["interior", "door_inside", "door_outside", "entry_outside"].find(point_id)


func _get_npc_actor(npc_system: Node, npc_id: String) -> Node:
	var paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(paths.get(npc_id, NodePath("")))


func _find_rally(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(metrics: Dictionary) -> void:
	print("T0221_MOUNTED_STABLE_EXIT_METRICS=%s" % JSON.stringify(metrics))
	if _failures.is_empty():
		print("T0221_MOUNTED_STABLE_EXIT_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
