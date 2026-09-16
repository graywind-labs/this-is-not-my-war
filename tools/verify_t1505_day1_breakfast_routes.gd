extends SceneTree


const ACTION_ID := "eat_at_dining_hall"
const ASSIGNED_DINING_SEATS := {
	"stableman_01": "dining_seat_01",
	"cook_01": "dining_seat_02",
	"gardener_01": "dining_seat_03",
	"blacksmith_01": "dining_seat_04",
	"veteran_deputy_01": "dining_seat_05",
	"priest_01": "dining_seat_06",
	"doctor_01": "dining_seat_07",
	"engineer_01": "dining_seat_08",
}


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await physics_frame

	var tutorial := root.get_node_or_null("Main/Systems/TutorialDirector")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var layout_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if [tutorial, action_system, npc_system, building_system, memory_system, time_system, layout_controller].has(null):
		_fail("Breakfast regression dependencies unavailable")
		return
	var door_queue_snapshots: Array = layout_controller.debug_get_building_door_queue_snapshots()
	if door_queue_snapshots.size() != 10:
		_fail("Expected one queue for each of the ten enterable building doors: %s" % JSON.stringify(door_queue_snapshots))
		return
	for door_queue_snapshot in door_queue_snapshots:
		if (
			int(door_queue_snapshot.get("token_count", 0)) != 8
			or (door_queue_snapshot.get("range_size", Vector3.ZERO) as Vector3).distance_to(Vector3(2.6, 2.8, 3.0)) > 0.001
		):
			_fail("Unexpected building door queue contract: %s" % JSON.stringify(door_queue_snapshot))
			return

	var handoff: Dictionary = tutorial.debug_skip_tutorial()
	if not bool(handoff.get("ok", false)):
		_fail("Tutorial handoff failed: %s" % JSON.stringify(handoff))
		return
	time_system.set_paused(false)

	var npc_ids: Array = npc_system.get_npc_ids()
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		var expected_seat_id := str(ASSIGNED_DINING_SEATS.get(npc_id, ""))
		var assigned_seat := _get_workstation(building_system, expected_seat_id)
		if expected_seat_id.is_empty() or str(assigned_seat.get("assigned_npc_id", "")) != npc_id:
			_fail("Dining seat assignment missing for %s: %s" % [npc_id, JSON.stringify(assigned_seat)])
			return
	var active_ids: Array[String] = []
	var breakfast_started_ids: Array[String] = []
	var failure_details := {}
	var last_route_details := {}
	var baseline_reevaluation_requests := {}
	var queued_npc_ids: Array[String] = []
	var maximum_dining_queue_size := 0
	var dining_queue_samples: Array[Dictionary] = []
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		baseline_reevaluation_requests[npc_id] = npc_system.get_plan_reevaluation_request(npc_id)
	var marcel_route_samples: Array[Dictionary] = []
	var marcel_last_phase := ""
	var marcel_left_dining_after_entry := false
	var marcel_crossing_min_progress := INF
	var marcel_route: Dictionary = layout_controller.get_building_spatial_route("dining_hall", "dining_seat_06")
	var marcel_entry_outside: Vector3 = marcel_route.get("entry_outside_position", Vector3.ZERO)
	var marcel_entry_inside: Vector3 = marcel_route.get("interior_position", Vector3.ZERO)
	var marcel_entry_direction := (marcel_entry_inside - marcel_entry_outside).normalized()
	for _frame in range(3600):
		await physics_frame
		var dining_queue_snapshot: Dictionary = {}
		for queue_snapshot in layout_controller.debug_get_building_door_queue_snapshots():
			if str(queue_snapshot.get("building_id", "")) == "dining_hall":
				dining_queue_snapshot = queue_snapshot
				break
		if dining_queue_snapshot.is_empty():
			failure_details["dining_queue_missing"] = true
		else:
			var entries := dining_queue_snapshot.get("entries", []) as Array
			maximum_dining_queue_size = maxi(maximum_dining_queue_size, entries.size())
			if entries.size() > 1 and dining_queue_samples.size() < 12:
				dining_queue_samples.append(dining_queue_snapshot.duplicate(true))
			var moving_count := 0
			for entry_index in range(entries.size()):
				var entry := entries[entry_index] as Dictionary
				var expected_token := entry_index + 1 if entry_index < 8 else 0
				if int(entry.get("token_number", -1)) != expected_token:
					failure_details["non_compact_dining_tokens"] = dining_queue_snapshot
				if not bool(entry.get("paused", true)):
					moving_count += 1
			if moving_count > 1:
				failure_details["multiple_dining_queue_heads"] = dining_queue_snapshot
		var marcel_state: Dictionary = npc_system.get_npc_state("priest_01")
		var marcel_phase := str(marcel_state.get("spatial_route_phase", ""))
		var marcel_position: Vector3 = npc_system.get_npc_world_position("priest_01")
		if marcel_phase != marcel_last_phase:
			marcel_last_phase = marcel_phase
			marcel_route_samples.append({
				"phase": marcel_phase,
				"location": str(marcel_state.get("current_location", "")),
				"position": marcel_position,
			})
		if marcel_phase == "crossing_entry" and marcel_entry_direction.length_squared() > 0.0:
			marcel_crossing_min_progress = minf(
				marcel_crossing_min_progress,
				(marcel_position - marcel_entry_outside).dot(marcel_entry_direction)
			)
		if (
			str(marcel_state.get("current_location", "")) == "dining_hall"
			and marcel_phase == "moving_to_workstation"
			and not layout_controller.is_world_position_inside_enterable_building(
				"dining_hall",
				npc_system.get_npc_world_position("priest_01")
			)
		):
			marcel_left_dining_after_entry = true
		for raw_npc_id in npc_ids:
			var npc_id := str(raw_npc_id)
			var spatial_snapshot: Dictionary = npc_system.debug_get_spatial_migration_snapshot(npc_id)
			var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
			var route_phase := str(npc_state.get("spatial_route_phase", ""))
			var motion_snapshot := spatial_snapshot.get("motion", {}) as Dictionary
			var door_memberships := motion_snapshot.get("door_queue_memberships", {}) as Dictionary
			if door_memberships.has("building_door:dining_hall"):
				if not queued_npc_ids.has(npc_id):
					queued_npc_ids.append(npc_id)
				var queued_reservation: Dictionary = spatial_snapshot.get("reservation", {})
				if str(queued_reservation.get("workstation_id", "")) != str(ASSIGNED_DINING_SEATS.get(npc_id, "")):
					failure_details[npc_id] = {
						"reason": "queued_reservation_lost",
						"snapshot": spatial_snapshot,
					}
			if route_phase == "navigation_failed":
				failure_details[npc_id] = {
					"reason": "entry_route_navigation_failed",
					"state": npc_state,
					"snapshot": spatial_snapshot,
				}
			var formal_session: Dictionary = spatial_snapshot.get("formal_workstation_action_session", {})
			if not formal_session.is_empty():
				last_route_details[npc_id] = {
					"workstation_id": str(formal_session.get("workstation_id", "")),
					"route_step": spatial_snapshot.get("route_step", {}),
					"world_position": spatial_snapshot.get("world_position"),
					"motion": spatial_snapshot.get("motion", {}),
				}
			for raw_event in memory_system.get_npc_daily_events(npc_id):
				if not raw_event is Dictionary:
					continue
				var event: Dictionary = raw_event
				if (
					str(event.get("type", "")) == "eat_started"
					and str((event.get("payload", {}) as Dictionary).get("action_id", "")) == ACTION_ID
					and not breakfast_started_ids.has(npc_id)
				):
					breakfast_started_ids.append(npc_id)
			if active_ids.has(npc_id) or failure_details.has(npc_id):
				continue
			var runtime: Dictionary = action_system.get_runtime_action_snapshot(npc_id)
			if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == ACTION_ID:
				var active_seat_id := str(runtime.get("workstation_id", ""))
				if active_seat_id != str(ASSIGNED_DINING_SEATS.get(npc_id, "")):
					failure_details[npc_id] = {
						"reason": "unexpected_dining_seat",
						"expected": ASSIGNED_DINING_SEATS.get(npc_id, ""),
						"actual": active_seat_id,
					}
					continue
				active_ids.append(npc_id)
				continue
			for raw_event in memory_system.get_npc_daily_events(npc_id):
				if not raw_event is Dictionary:
					continue
				var event: Dictionary = raw_event
				if str(event.get("type", "")) == "work_failed" and str(event.get("summary", "")).contains("食堂座位挂接失败"):
					var failed_state: Dictionary = npc_system.get_npc_state(npc_id)
					failure_details[npc_id] = {
						"event": event.get("payload", {}),
						"last_action_failure_context": failed_state.get("last_action_failure_context", {}),
						"world_position": npc_system.get_npc_world_position(npc_id),
					}
					break
		if breakfast_started_ids.size() == npc_ids.size():
			break
	for raw_npc_id in npc_ids:
		var npc_id := str(raw_npc_id)
		if npc_system.get_plan_reevaluation_request(npc_id) != baseline_reevaluation_requests[npc_id]:
			failure_details[npc_id] = {
				"reason": "unexpected_plan_reevaluation",
				"before": baseline_reevaluation_requests[npc_id],
				"after": npc_system.get_plan_reevaluation_request(npc_id),
			}

	var marcel_reversed_out_of_door := marcel_crossing_min_progress < -0.5
	if (
		not failure_details.is_empty()
		or breakfast_started_ids.size() != npc_ids.size()
		or queued_npc_ids.is_empty()
		# The generic 10-actor queue test owns simultaneous wait/overflow coverage.
		# A narrower NPC capsule can let this natural breakfast sample drain the
		# doorway quickly enough that only one membership is observed at a time.
		or maximum_dining_queue_size < 1
		or marcel_left_dining_after_entry
		or marcel_reversed_out_of_door
	):
		var unresolved := []
		for raw_npc_id in npc_ids:
			var npc_id := str(raw_npc_id)
			if not active_ids.has(npc_id) and not failure_details.has(npc_id):
				var unresolved_state: Dictionary = npc_system.get_npc_state(npc_id)
				unresolved.append({
					"npc_id": npc_id,
					"runtime": action_system.get_runtime_action_snapshot(npc_id),
					"current_action": unresolved_state.get("current_action"),
					"current_location": unresolved_state.get("current_location"),
					"spatial_route_phase": unresolved_state.get("spatial_route_phase"),
					"physical_location_phase": unresolved_state.get("physical_location_phase"),
					"world_position": npc_system.get_npc_world_position(npc_id),
					"last_action_failure_context": unresolved_state.get("last_action_failure_context", {}),
					"last_route": last_route_details.get(npc_id, {}),
				})
		_fail("Breakfast routes failed: %s" % JSON.stringify({
			"active_ids": active_ids,
			"breakfast_started_ids": breakfast_started_ids,
			"failures": failure_details,
			"unresolved": unresolved,
			"marcel_left_dining_after_entry": marcel_left_dining_after_entry,
			"marcel_reversed_out_of_door": marcel_reversed_out_of_door,
			"marcel_crossing_min_progress": marcel_crossing_min_progress,
			"marcel_route_samples": marcel_route_samples,
			"queued_npc_ids": queued_npc_ids,
			"maximum_dining_queue_size": maximum_dining_queue_size,
			"dining_queue_samples": dining_queue_samples,
		}))
		return

	# A pending formal route owns a workstation id before it reaches or mounts the
	# target. Ending that route must not use the destination stand as a cleanup
	# point; doing so was the apparent workshop/blacksmith teleport after replans.
	action_system.interrupt_npc_action("engineer_01", "breakfast_route_regression_cleanup")
	var owen_before_unattached_cleanup: Vector3 = npc_system.get_npc_world_position("engineer_01")
	var owen_begin: Dictionary = npc_system.begin_formal_workstation_action(
		"engineer_01",
		"regression_unattached_route",
		"workshop",
		true
	)
	if (
		not bool(owen_begin.get("ok", false))
		or not npc_system.move_npc_to_building_workstation("engineer_01", "workshop", "workbench_01")
	):
		_fail("Could not stage Owen's unattached cleanup regression")
		return
	npc_system.end_formal_workstation_action("engineer_01", "regression_route_failure", true)
	var owen_after_unattached_cleanup: Vector3 = npc_system.get_npc_world_position("engineer_01")
	if owen_before_unattached_cleanup.distance_to(owen_after_unattached_cleanup) > 0.001:
		_fail("Unattached formal cleanup teleported Owen: %s" % JSON.stringify({
			"before": owen_before_unattached_cleanup,
			"after": owen_after_unattached_cleanup,
		}))
		return

	print("T1505-P6R38 day-one breakfast door token queue verification passed: %s" % JSON.stringify({
		"active_ids": active_ids,
		"breakfast_started_ids": breakfast_started_ids,
		"queued_npc_ids": queued_npc_ids,
		"maximum_dining_queue_size": maximum_dining_queue_size,
		"marcel_crossing_min_progress": marcel_crossing_min_progress,
		"owen_unattached_cleanup_displacement": owen_before_unattached_cleanup.distance_to(owen_after_unattached_cleanup),
		"marcel_route_samples": marcel_route_samples,
	}))
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)


func _get_workstation(building_system: Node, workstation_id: String) -> Dictionary:
	for raw_workstation in building_system.get_building("dining_hall").get("workstations", []):
		if raw_workstation is Dictionary and str(raw_workstation.get("id", "")) == workstation_id:
			return raw_workstation
	return {}
