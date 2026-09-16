extends SceneTree


const NPC_ID := "veteran_deputy_01"
const BUILDING_ID := "dormitory"


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
	var needs_system := root.get_node_or_null("Main/Systems/NPCNeedsSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if [action_system, needs_system, npc_system, building_system, time_system].has(null):
		_fail("T0422 runtime dependencies unavailable")
		return
	time_system.set_paused(true)
	needs_system.restore_game_save_snapshot({})

	if not await _stage_sleep(action_system, npc_system):
		return
	if not _assert_four_hours(needs_system, npc_system, 100, 100, 92, 50, "level-one"):
		return
	action_system.interrupt_npc_action(NPC_ID, "t0422_upgrade")
	await process_frame

	if not building_system.upgrade_building(BUILDING_ID):
		_fail("Could not upgrade dormitory")
		return
	building_system._on_logical_time_tick(100000.0, 1.0)
	if absf(float(building_system.get_building_activity_efficiency_multiplier(BUILDING_ID, "sleep_recovery")) - 1.2) > 0.0001:
		_fail("Level-two dormitory does not expose 1.2 sleep recovery efficiency")
		return
	if not await _stage_sleep(action_system, npc_system):
		return
	if not _assert_four_hours(needs_system, npc_system, 100, 100, 92, 40, "level-two"):
		return
	action_system.interrupt_npc_action(NPC_ID, "t0422_damage")
	await process_frame

	var upgraded: Dictionary = building_system.get_building(BUILDING_ID)
	var max_hp := int(upgraded.get("max_hp", 1))
	building_system.debug_damage_building(BUILDING_ID, int(round(float(max_hp) * 0.5)))
	var damaged_efficiency := float(
		building_system.get_building_activity_efficiency_multiplier(BUILDING_ID, "sleep_recovery")
	)
	if damaged_efficiency <= 0.0 or damaged_efficiency >= 1.2:
		_fail("Damaged upgraded dormitory has invalid recovery efficiency: %.4f" % damaged_efficiency)
		return
	if not await _stage_sleep(action_system, npc_system):
		return
	npc_system.update_npc_state(NPC_ID, {"fatigue": 100, "satiety": 100})
	var result: Dictionary = needs_system.call("_apply_profile", NPC_ID, "sleep", 4.0 * 3600.0)
	var expected_fatigue := 100 - int(floor(12.5 * damaged_efficiency * 4.0 + 0.0001))
	var state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		int(state.get("fatigue", -1)) != expected_fatigue
		or int(state.get("satiety", -1)) != 92
		or int((result.get("applied_deltas", {}) as Dictionary).get("fatigue", 0)) != expected_fatigue - 100
	):
		_fail("Damaged dormitory recovery did not apply its efficiency exactly once: %s" % JSON.stringify({
			"efficiency": damaged_efficiency,
			"expected_fatigue": expected_fatigue,
			"state": state,
			"result": result,
		}))
		return

	print("T0422 dormitory sleep recovery efficiency verification passed")
	quit(0)


func _stage_sleep(action_system: Node, npc_system: Node) -> bool:
	npc_system.update_npc_state(NPC_ID, {"fatigue": 100, "satiety": 100})
	var result: Dictionary = action_system.stage_npc_sleep_for_tutorial(NPC_ID)
	if not bool(result.get("ok", false)):
		_fail("Could not stage formal dormitory sleep: %s" % JSON.stringify(result))
		return false
	return true


func _assert_four_hours(
	needs_system: Node,
	npc_system: Node,
	satiety_before: int,
	fatigue_before: int,
	expected_satiety: int,
	expected_fatigue: int,
	label: String
) -> bool:
	npc_system.update_npc_state(NPC_ID, {
		"satiety": satiety_before,
		"fatigue": fatigue_before,
	})
	var result: Dictionary = needs_system.call("_apply_profile", NPC_ID, "sleep", 4.0 * 3600.0)
	var state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if int(state.get("satiety", -1)) != expected_satiety or int(state.get("fatigue", -1)) != expected_fatigue:
		_fail("%s sleep recovery mismatch: %s" % [label, JSON.stringify({"state": state, "result": result})])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
