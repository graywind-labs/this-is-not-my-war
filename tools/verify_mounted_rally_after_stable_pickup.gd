extends SceneTree


const NPC_ID := "veteran_deputy_01"
const MAX_PHYSICS_FRAMES := 3000


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _index in range(6):
		await physics_frame

	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if horse_system == null or npc_system == null or combat_system == null:
		_fail("Mounted rally verification dependencies are missing")
		return
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)

	var horse_ids: Array = horse_system.get_horse_ids()
	if horse_ids.is_empty():
		_fail("Mounted rally verification requires an initial horse")
		return
	var horse_id := str(horse_ids[0])
	npc_system.set_npc_behavior_mode(NPC_ID, "work", "mounted_rally_test_reset", {"force_idle": true})
	var assigned: Dictionary = horse_system.assign_horse_to_npc(NPC_ID, horse_id, "private")
	if not bool(assigned.get("ok", false)):
		_fail("Could not assign mounted rally horse: %s" % JSON.stringify(assigned))
		return
	var alarm: Dictionary = combat_system.trigger_combat_alarm("mounted_rally_after_pickup_test")
	if not bool(alarm.get("ok", false)):
		_fail("Could not trigger mounted rally test alarm: %s" % JSON.stringify(alarm))
		return

	var rally := _find_rally(combat_system.get_active_rallies(), NPC_ID)
	if rally.is_empty() or str(rally.get("status", "")) != "mounting" or not str(rally.get("formation_row", "")).begins_with("cavalry_"):
		_fail("Assigned melee rider did not retain its cavalry-wing formation reservation: %s" % JSON.stringify(rally))
		return
	var formation_position := _to_vector3(rally.get("position", {}))
	var mounted_position := Vector3.ZERO
	var mounted_observed := false
	var rally_motion_observed := false
	var rallied := false
	for _frame in range(MAX_PHYSICS_FRAMES):
		await physics_frame
		var state: Dictionary = npc_system.get_npc_state(NPC_ID)
		var raw_position: Variant = npc_system.get_npc_world_position(NPC_ID)
		var npc_position: Vector3 = raw_position if raw_position is Vector3 else Vector3.ZERO
		if bool(state.get("combat_mounted", false)) and not mounted_observed:
			mounted_observed = true
			mounted_position = npc_position
		if mounted_observed and str(state.get("movement_target", "")) == "combat_rally_%s" % NPC_ID:
			rally_motion_observed = true
		rally = _find_rally(combat_system.get_active_rallies(), NPC_ID)
		if str(rally.get("status", "")) == "rallied" and npc_position.distance_to(formation_position) <= 0.3:
			rallied = true
			break

	if not mounted_observed:
		_fail("Rider never mounted the assigned stable horse")
		return
	if not rally_motion_observed:
		_fail("Mounted rider never resumed the reserved front-gate rally movement")
		return
	if mounted_position.distance_to(formation_position) < 8.0:
		_fail("Test setup did not prove a meaningful post-mount rally leg")
		return
	if not rallied:
		var final_state: Dictionary = npc_system.get_npc_state(NPC_ID)
		var final_position: Variant = npc_system.get_npc_world_position(NPC_ID)
		var npc_node := root.get_node_or_null("Main/World/NPCs/VeteranDeputy01")
		var motion_snapshot: Dictionary = npc_node.debug_get_motion_snapshot() if npc_node != null and npc_node.has_method("debug_get_motion_snapshot") else {}
		_fail("Mounted rider stopped before reaching the reserved formation point: mounted=%s final=%s rally=%s motion=%s state=%s" % [mounted_position, final_position, JSON.stringify(rally), JSON.stringify(motion_snapshot), JSON.stringify(final_state)])
		return

	print("T0138-R2 mounted rider resumed front-gate formation after stable pickup.")
	quit(0)


func _find_rally(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _to_vector3(raw_value: Variant) -> Vector3:
	if raw_value is Vector3:
		return raw_value
	if raw_value is Dictionary:
		return Vector3(
			float((raw_value as Dictionary).get("x", 0.0)),
			float((raw_value as Dictionary).get("y", 0.0)),
			float((raw_value as Dictionary).get("z", 0.0))
		)
	return Vector3.ZERO


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
