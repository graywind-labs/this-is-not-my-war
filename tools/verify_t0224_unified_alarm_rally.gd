extends SceneTree


const RESPONDERS := [
	"stableman_01",
	"cook_01",
	"gardener_01",
	"blacksmith_01",
	"veteran_deputy_01",
	"priest_01",
]
const LOCKED_NPC_ID := "doctor_01"


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn could not be loaded")
		return
	root.add_child(packed.instantiate())
	for _frame in range(6):
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var horse_system := root.get_node_or_null("Main/Systems/HorseSystem")
	if (
		combat_system == null
		or npc_system == null
		or resource_system == null
		or equipment_system == null
		or horse_system == null
	):
		_fail("T0224 dependencies are missing")
		return

	# First put the veteran on an assigned horse through the production rendezvous.
	resource_system.add_resource("item_sword_shield", RESPONDERS.size() + 1)
	npc_system.set_npc_recruited("veteran_deputy_01", true)
	if not bool(equipment_system.equip_npc_main_weapon("veteran_deputy_01", "sword_shield", "private").get("ok", false)):
		_fail("Could not equip the veteran")
		return
	var veteran_horse_id := _assign_available_horse(equipment_system, horse_system, "veteran_deputy_01")
	if veteran_horse_id.is_empty():
		return

	# Equip the remaining mode-matrix actors and give the priest an unmounted horse.
	for npc_id in RESPONDERS + [LOCKED_NPC_ID]:
		npc_system.set_npc_recruited(npc_id, true)
		var equipment: Dictionary = equipment_system.get_unit_type_snapshot(npc_id)
		if not bool(equipment.get("has_main_weapon", false)):
			var equip_result: Dictionary = equipment_system.equip_npc_main_weapon(npc_id, "sword_shield", "private")
			if not bool(equip_result.get("ok", false)):
				_fail("Could not equip %s: %s" % [npc_id, JSON.stringify(equip_result)])
				return
	var priest_horse_id := _assign_available_horse(equipment_system, horse_system, "priest_01")
	if priest_horse_id.is_empty():
		return

	var spawn: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn.get("ok", false)) or combat_system.get_active_enemy_ids().is_empty():
		_fail("Could not spawn an external target-lock fixture")
		return
	var locked_enemy_id := str(combat_system.get_active_enemy_ids()[0])
	var initial_alarm: Dictionary = combat_system.trigger_combat_alarm("t0224_mount_setup")
	if not bool(initial_alarm.get("ok", false)):
		_fail("Could not start the mounted setup rally")
		return
	if not bool(horse_system.debug_complete_horse_transition(veteran_horse_id).get("ok", false)):
		_fail("Could not complete the veteran's production mount rendezvous")
		return
	await process_frame
	if not bool(npc_system.get_npc_state("veteran_deputy_01").get("combat_mounted", false)):
		_fail("Veteran did not become mounted during setup")
		return

	# Arrange every explicitly requested source mode before the same bell command.
	npc_system.set_npc_behavior_mode("stableman_01", "work", "t0224_sleeping_work", {
		"force_idle": true,
		"state_changes": {"current_action": "sleeping"}
	})
	npc_system.set_npc_behavior_mode("cook_01", "avoid_combat", "t0224_avoid", {
		"state_changes": {
			"combat_target_enemy_id": locked_enemy_id,
			"avoidance_target_id": "old_avoid_target",
			"avoidance_target_name": "旧避战点"
		}
	})
	npc_system.set_npc_behavior_mode("gardener_01", "rally", "t0224_old_rally")
	npc_system.set_npc_behavior_mode("blacksmith_01", "combat", "t0224_combat_without_lock", {
		"state_changes": {
			"combat_target_enemy_id": "",
			"combat_strategy_move_enemy_id": "",
			"combat_strategy_move_target_id": "old_strategy_target"
		}
	})
	npc_system.set_npc_behavior_mode("veteran_deputy_01", "combat", "t0224_mounted_without_lock", {
		"state_changes": {
			"combat_target_enemy_id": "",
			"combat_mounted": true,
			"combat_mount_phase": "mounted"
		}
	})
	npc_system.set_npc_behavior_mode("priest_01", "avoid_combat", "t0224_unmounted_rider", {
		"state_changes": {"combat_target_enemy_id": locked_enemy_id}
	})
	npc_system.set_npc_behavior_mode(LOCKED_NPC_ID, "combat", "t0224_locked_combat", {
		"state_changes": {
			"current_action": "combat_ready",
			"combat_target_enemy_id": locked_enemy_id,
			"combat_target_selection_reason": "t0224_fixture_lock",
			"combat_attack_sequence": 17,
			"movement_target": "locked_target_motion"
		}
	})

	var avoidances: Dictionary = combat_system.get("_active_avoidances")
	avoidances["cook_01"] = {"npc_id": "cook_01", "status": "moving", "fixture": "old_avoidance"}
	combat_system.set("_active_avoidances", avoidances)
	var old_rallies: Dictionary = combat_system.get("_active_rallies")
	old_rallies["gardener_01"] = {"npc_id": "gardener_01", "status": "moving", "fixture": "old_rally"}
	old_rallies[LOCKED_NPC_ID] = {"npc_id": LOCKED_NPC_ID, "status": "combat_ready", "fixture": "preserve_locked"}
	combat_system.set("_active_rallies", old_rallies)

	var locked_before: Dictionary = npc_system.get_npc_state(LOCKED_NPC_ID)
	var alarm: Dictionary = combat_system.trigger_combat_alarm("t0224_unified_rule")
	if not bool(alarm.get("ok", false)):
		_fail("Unified alarm failed: %s" % JSON.stringify(alarm))
		return
	if int(alarm.get("eligible_count", 0)) != RESPONDERS.size() or int(alarm.get("rallied_count", 0)) != RESPONDERS.size():
		_fail("All six unlocked armed recruits must receive one rally command: %s" % JSON.stringify(alarm))
		return
	if int(alarm.get("target_locked_count", 0)) != 1 or not _ignored_reason(alarm, LOCKED_NPC_ID, "target_locked"):
		_fail("The one valid attack-target lock must be the only armed-recruit exclusion: %s" % JSON.stringify(alarm))
		return

	for npc_id in RESPONDERS:
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("behavior_mode", "")) != "rally":
			_fail("%s did not transition into the unified rally from its prior mode" % npc_id)
			return
		if not str(state.get("combat_target_enemy_id", "")).is_empty():
			_fail("%s retained a stale target while accepting the rally command" % npc_id)
			return
	if (combat_system.get("_active_avoidances") as Dictionary).has("cook_01"):
		_fail("Alarm did not atomically clear the responder's old avoidance runtime")
		return
	var gardener_rally := _find_rally(combat_system.get_active_rallies(), "gardener_01")
	if gardener_rally.is_empty() or gardener_rally.has("fixture"):
		_fail("Alarm did not replace the responder's old rally reservation")
		return
	var blacksmith_state: Dictionary = npc_system.get_npc_state("blacksmith_01")
	if not str(blacksmith_state.get("combat_strategy_move_target_id", "")).is_empty():
		_fail("No-target combat responder retained an old tactical movement target")
		return

	var locked_after: Dictionary = npc_system.get_npc_state(LOCKED_NPC_ID)
	if (
		str(locked_after.get("behavior_mode", "")) != str(locked_before.get("behavior_mode", ""))
		or str(locked_after.get("combat_target_enemy_id", "")) != locked_enemy_id
		or int(locked_after.get("combat_attack_sequence", 0)) != int(locked_before.get("combat_attack_sequence", 0))
		or str(locked_after.get("movement_target", "")) != str(locked_before.get("movement_target", ""))
	):
		_fail("Bell mutated the locked combatant: before=%s after=%s" % [JSON.stringify(locked_before), JSON.stringify(locked_after)])
		return
	var preserved_locked_rally := _find_rally(combat_system.get_active_rallies(), LOCKED_NPC_ID)
	if str(preserved_locked_rally.get("fixture", "")) != "preserve_locked":
		_fail("Bell cleared the locked combatant's existing rally record")
		return

	var veteran_state: Dictionary = npc_system.get_npc_state("veteran_deputy_01")
	var veteran_rally := _find_rally(combat_system.get_active_rallies(), "veteran_deputy_01")
	var veteran_horse: Dictionary = horse_system.get_horse_snapshot(veteran_horse_id)
	if (
		not bool(veteran_state.get("combat_mounted", false))
		or str(veteran_state.get("combat_mount_phase", "")) != "mounted"
		or str(veteran_rally.get("status", "")) != "moving"
		or str(veteran_horse.get("location", "")) != "ridden"
	):
		_fail("Already-mounted unlocked rider did not rally directly: state=%s rally=%s horse=%s" % [JSON.stringify(veteran_state), JSON.stringify(veteran_rally), JSON.stringify(veteran_horse)])
		return
	var priest_state: Dictionary = npc_system.get_npc_state("priest_01")
	var priest_rally := _find_rally(combat_system.get_active_rallies(), "priest_01")
	if (
		bool(priest_state.get("combat_mounted", true))
		or str(priest_state.get("combat_mount_phase", "")) != "going_to_stable_horse"
		or str(priest_rally.get("status", "")) != "mounting"
	):
		_fail("Assigned unmounted rider did not go to the horse first: state=%s rally=%s" % [JSON.stringify(priest_state), JSON.stringify(priest_rally)])
		return

	# Put a rallying unit outside the station, beyond the removed 5 m contact rule
	# but within the normal 37.2 m friendly target domain.
	var enemy: Dictionary = combat_system.get_enemy(locked_enemy_id)
	var npc_paths: Dictionary = npc_system.get("_npc_nodes")
	var stableman_node := npc_system.get_node_or_null(npc_paths.get("stableman_01", NodePath(""))) as Node3D
	if stableman_node == null:
		_fail("Stableman world node is missing")
		return
	stableman_node.global_position = (enemy.get("position", Vector3.ZERO) as Vector3) + Vector3(0.0, 0.0, -15.0)
	combat_system.debug_step_enemy_ai(0.1)
	var encounter_state: Dictionary = npc_system.get_npc_state("stableman_01")
	var encounter_rally := _find_rally(combat_system.get_active_rallies(), "stableman_01")
	if (
		str(encounter_state.get("behavior_mode", "")) != "combat"
		or str(encounter_state.get("combat_target_enemy_id", "")).is_empty()
		or str(encounter_rally.get("status", "")) != "combat_ready"
		or float(encounter_rally.get("encounter_distance", 0.0)) <= 5.0
	):
		_fail("Normal target range did not interrupt rally beyond 5 m: state=%s rally=%s" % [JSON.stringify(encounter_state), JSON.stringify(encounter_rally)])
		return

	var result_snapshot := {
		"responders": RESPONDERS.size(),
		"target_locked_count": alarm.get("target_locked_count", 0),
		"mounted_status": veteran_rally.get("status", ""),
		"unmounted_status": priest_rally.get("status", ""),
		"encounter_distance": encounter_rally.get("encounter_distance", 0.0),
	}
	combat_system.debug_clear_enemies()
	root.get_node("Main").queue_free()
	await process_frame
	print("T0224_UNIFIED_ALARM_RALLY_OK %s" % JSON.stringify(result_snapshot))
	quit(0)


func _assign_available_horse(equipment_system: Node, horse_system: Node, npc_id: String) -> String:
	var available: Array = horse_system.get_available_horses_for_npc(npc_id)
	if available.is_empty():
		_fail("No available horse for %s" % npc_id)
		return ""
	var horse_id := str((available[0] as Dictionary).get("horse_id", ""))
	var result: Dictionary = equipment_system.equip_npc_mount(npc_id, horse_id, "private")
	if not bool(result.get("ok", false)):
		_fail("Could not assign %s to %s: %s" % [horse_id, npc_id, JSON.stringify(result)])
		return ""
	return horse_id


func _ignored_reason(alarm: Dictionary, npc_id: String, reason: String) -> bool:
	for raw_item in alarm.get("ignored", []):
		var item: Dictionary = raw_item
		if str(item.get("npc_id", "")) == npc_id and str(item.get("reason", "")) == reason:
			return true
	return false


func _find_rally(entries: Array, npc_id: String) -> Dictionary:
	for raw_entry in entries:
		if raw_entry is Dictionary and str((raw_entry as Dictionary).get("npc_id", "")) == npc_id:
			return (raw_entry as Dictionary).duplicate(true)
	return {}


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
