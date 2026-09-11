extends SceneTree


const NPC_ID := "veteran_deputy_01"
const MAIN_HALL_CENTER := Vector2(0.0, -8.0)
const MAIN_HALL_HALF_ENVELOPE := Vector2(11.0, 9.0)
const MAX_PHYSICS_FRAMES := 900


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _index in range(5):
		await physics_frame

	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var formal_root := root.get_node_or_null("Main/WorldRoot/FormalStationLayout") as Node3D
	if horse_system == null or npc_system == null or formal_root == null:
		_fail("Stable pickup navigation verification dependencies are missing")
		return
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)

	var horse_ids: Array = horse_system.get_horse_ids()
	if horse_ids.is_empty():
		_fail("Stable pickup navigation verification requires an initial horse")
		return
	var horse_id := str(horse_ids[0])
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "stable_pickup_test_reset", {"force_idle": true})
	var assigned: Dictionary = horse_system.assign_horse_to_npc(NPC_ID, horse_id, "private")
	if not bool(assigned.get("ok", false)):
		_fail("Could not assign the stable pickup test horse: %s" % JSON.stringify(assigned))
		return

	var mode_result: Dictionary = npc_system.set_npc_behavior_mode(NPC_ID, "combat", "stable_pickup_navigation_test", {
		"state_changes": {"current_action": "combat_ready"},
		"request_plan_reevaluation": false
	})
	if not bool(mode_result.get("ok", false)):
		_fail("Could not start stable pickup combat mode")
		return

	var waiting_horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	var movement: Dictionary = waiting_horse.get("movement_state", {})
	var stationary_position: Vector3 = waiting_horse.get("world_position", Vector3.ZERO)
	var pickup_position: Vector3 = movement.get("target_position", Vector3.ZERO)
	var pickup_local := formal_root.to_local(pickup_position)
	var state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		str(waiting_horse.get("location", "")) != "stable"
		or str(movement.get("phase", "")) != "waiting_for_rider_at_stable"
		or not bool(movement.get("horse_stationary", false))
		or str(state.get("combat_mount_phase", "")) != "going_to_stable_horse"
		or str(state.get("movement_target", "")) != "stable"
	):
		_fail("Combat did not start the stationary stable pickup flow: horse=%s state=%s" % [JSON.stringify(waiting_horse), JSON.stringify(state)])
		return
	if pickup_position.distance_to(stationary_position) > 4.01:
		_fail("Pickup point is not beside the assigned horse")
		return
	if _inside_main_hall_envelope(Vector2(pickup_local.x, pickup_local.z)):
		_fail("Stable pickup target was placed inside the non-enterable main hall")
		return

	var entered_main_hall := false
	var max_horse_drift := 0.0
	var mounted := false
	for _frame in range(MAX_PHYSICS_FRAMES):
		await physics_frame
		var horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
		var horse_movement: Dictionary = horse.get("movement_state", {})
		if str(horse_movement.get("phase", "")) == "waiting_for_rider_at_stable":
			var horse_position: Vector3 = horse.get("world_position", stationary_position)
			max_horse_drift = maxf(max_horse_drift, horse_position.distance_to(stationary_position))
		var raw_npc_position: Variant = npc_system.get_npc_world_position(NPC_ID)
		if raw_npc_position is Vector3:
			var npc_local := formal_root.to_local(raw_npc_position as Vector3)
			if _inside_main_hall_envelope(Vector2(npc_local.x, npc_local.z)):
				entered_main_hall = true
				break
		state = npc_system.get_npc_state(NPC_ID)
		if bool(state.get("combat_mounted", false)):
			mounted = true
			break

	if max_horse_drift > 0.01:
		_fail("Assigned horse moved before mounting; max drift %.4f m" % max_horse_drift)
		return
	if entered_main_hall:
		_fail("Rider navigation entered the non-enterable main hall envelope")
		return
	if not mounted:
		_fail("Rider did not reach the assigned stable horse within the navigation timeout: %s" % JSON.stringify(state))
		return
	var mounted_horse: Dictionary = horse_system.get_horse_snapshot(horse_id)
	if str(mounted_horse.get("location", "")) != "ridden" or str(mounted_horse.get("ridden_by_npc_id", "")) != NPC_ID:
		_fail("Physical arrival did not complete mounting: %s" % JSON.stringify(mounted_horse))
		return

	print("T0138-R1 stationary stable horse pickup navigation verification passed. max_horse_drift=%.4f" % max_horse_drift)
	quit(0)


func _inside_main_hall_envelope(point: Vector2) -> bool:
	return (
		absf(point.x - MAIN_HALL_CENTER.x) < MAIN_HALL_HALF_ENVELOPE.x - 0.05
		and absf(point.y - MAIN_HALL_CENTER.y) < MAIN_HALL_HALF_ENVELOPE.y - 0.05
	)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
