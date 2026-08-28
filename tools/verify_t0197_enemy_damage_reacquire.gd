extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const UNIFIED_RANGE := 37.2
const TEST_WEAPON := {
	"id": "sword_shield",
	"name": "测试剑盾",
	"type": "sword_shield",
	"weapon_class": "sword_shield"
}

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(4):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and npc_system != null and device_system != null, "T0197 combat systems missing")
	_check(building_system != null and resource_system != null and time_system != null, "T0197 world systems missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0197 formal wave failed to spawn: %s" % started)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	var npc_ids: Array[String] = npc_system.get_npc_ids()
	_check(not enemy_ids.is_empty(), "T0197 needs one production enemy")
	_check(npc_ids.size() >= 3, "T0197 needs three production NPCs")
	if not _failures.is_empty():
		_finish()
		return
	for index in range(1, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	var enemy_id := enemy_ids[0]
	var actor := root.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_id, NodePath())) as Node3D
	_check(actor != null, "T0197 production enemy actor missing")
	if not _failures.is_empty():
		_finish()
		return

	var npc_a := npc_ids[0]
	var npc_b := npc_ids[1]
	var npc_c := npc_ids[2]
	for npc_id in npc_ids:
		npc_system.set_npc_equipment_slot(npc_id, "main_weapon", {})
	_set_building_level(building_system, "wall", 4)
	resource_system.add_resource("item_wall_ballista", 1)
	var deployed: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	_check(bool(deployed.get("ok", false)), "T0197 ballista deployment failed: %s" % deployed)
	var deployment_id := str(deployed.get("deployment_id", ""))
	var device_target := _find_target(device_system.get_active_defense_targets(), deployment_id)
	_check(not device_target.is_empty(), "T0197 active defense target missing")
	if not _failures.is_empty():
		_finish()
		return
	var device_position := _to_vector3(device_target.get("position", {}))
	var outward := _to_vector3(device_target.get("facing_direction", {"z": 1.0})).normalized()
	if outward.length_squared() <= 0.0001:
		outward = Vector3.FORWARD
	var origin := device_position + outward * 8.0
	_set_enemy_position(combat_system, enemy_id, actor, origin)
	_move_all_npcs_far(npc_system, npc_ids, origin)
	for npc_id in [npc_a, npc_b, npc_c]:
		npc_system.set_npc_equipment_slot(npc_id, "main_weapon", TEST_WEAPON)

	var targeting_snapshot: Dictionary = combat_system.debug_get_enemy_targeting_snapshot()
	var policy := targeting_snapshot.get("policy", {}) as Dictionary
	_check(str(policy.get("schema", "")) == "enemy_unified_presence_lock_v3", "T0197 targeting schema mismatch: %s" % policy)
	_check(str(policy.get("different_attacker_damage_policy", "")) == "one_shot_nearest_high_threat_reacquire", "T0197 damage reacquire policy missing: %s" % policy)

	# A different armed NPC can break the current high-threat presence lock once.
	_set_npc_position(npc_system, npc_a, origin + Vector3(7.0, 0.0, 0.0))
	_set_npc_position(npc_system, npc_b, origin + Vector3(2.0, 0.0, 0.0))
	_set_npc_position(npc_system, npc_c, origin + Vector3(20.0, 0.0, 0.0))
	_set_current_target(combat_system, enemy_id, combat_system._make_npc_enemy_target(npc_a, origin))
	var damage_result: Dictionary = combat_system._apply_damage_to_enemy(enemy_id, 1, npc_b, {"source_type": "weapon"})
	_check(int(damage_result.get("damage", 0)) == 1, "T0197 NPC actual damage was not committed: %s" % damage_result)
	_check(combat_system._enemy_high_threat_reacquire_requests.has(enemy_id), "T0197 different NPC damage did not create a one-shot request")
	var selected: Dictionary = combat_system._select_formal_dynamic_enemy_target(enemy_id, combat_system.get_enemy(enemy_id))
	_check(str(selected.get("id", "")) == npc_b, "T0197 did not reacquire the nearest armed NPC: %s" % selected)
	_check(str(selected.get("target_selection_reason", "")) == "different_attacker_damage_nearest_high_threat_reacquire", "T0197 reacquire reason missing: %s" % selected)
	_check(not combat_system._enemy_high_threat_reacquire_requests.has(enemy_id), "T0197 one-shot request was not consumed")
	_set_current_target(combat_system, enemy_id, selected)
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_id, combat_system.get_enemy(enemy_id))
	_check(str(selected.get("id", "")) == npc_b and str(selected.get("target_selection_reason", "")) == "locked_high_threat_present", "T0197 did not restore the presence lock after one-shot reacquire: %s" % selected)

	# Damage from the currently locked target is not a different-attacker signal.
	_set_current_target(combat_system, enemy_id, combat_system._make_npc_enemy_target(npc_b, origin))
	combat_system._apply_damage_to_enemy(enemy_id, 1, npc_b, {"source_type": "weapon"})
	_check(not combat_system._enemy_high_threat_reacquire_requests.has(enemy_id), "T0197 current target damage incorrectly unlocked itself")

	# Re-evaluation is real even if it selects the same current target again.
	_set_npc_position(npc_system, npc_a, origin + Vector3(1.5, 0.0, 0.0))
	_set_npc_position(npc_system, npc_b, origin + Vector3(6.0, 0.0, 0.0))
	_set_current_target(combat_system, enemy_id, combat_system._make_npc_enemy_target(npc_a, origin))
	combat_system._apply_damage_to_enemy(enemy_id, 1, npc_b, {"source_type": "weapon"})
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_id, combat_system.get_enemy(enemy_id))
	_check(str(selected.get("id", "")) == npc_a, "T0197 nearest-current target was not allowed to win reacquisition: %s" % selected)
	_check(str(selected.get("target_selection_reason", "")) == "different_attacker_damage_nearest_high_threat_reacquire", "T0197 same-result reacquisition was not observable: %s" % selected)

	# Defense device -> NPC and NPC -> defense-device cross-source cases both use
	# the same nearest pool, never an exact retaliation shortcut.
	_move_all_npcs_far(npc_system, npc_ids, origin)
	_set_npc_position(npc_system, npc_a, origin + Vector3(13.0, 0.0, 0.0))
	_set_current_target(combat_system, enemy_id, combat_system._make_npc_enemy_target(npc_a, origin))
	damage_result = combat_system.apply_defense_device_attack(enemy_id, 1.0, {
		"deployment_id": deployment_id,
		"device_id": "wall_ballista",
		"device_name": "测试弩床"
	})
	_check(int(damage_result.get("damage", 0)) >= 1, "T0197 defense device actual damage was not committed: %s" % damage_result)
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_id, combat_system.get_enemy(enemy_id))
	_check(str(selected.get("id", "")) == deployment_id, "T0197 defense damage did not reacquire the nearer defense target: %s" % selected)

	_set_npc_position(npc_system, npc_b, origin + Vector3(2.0, 0.0, 0.0))
	_set_current_target(combat_system, enemy_id, combat_system._make_defense_device_enemy_target(deployment_id, origin))
	combat_system._apply_damage_to_enemy(enemy_id, 1, npc_b, {"source_type": "weapon"})
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_id, combat_system.get_enemy(enemy_id))
	_check(str(selected.get("id", "")) == npc_b, "T0197 NPC damage did not reacquire the nearer armed NPC from defense lock: %s" % selected)

	# Lower-priority building / unarmed locks must also wake on actual damage from
	# a high threat. They rescan the whole unified pool instead of exact-retaliating.
	_set_current_target(combat_system, enemy_id, combat_system._make_building_target("front_gate"))
	combat_system._apply_damage_to_enemy(enemy_id, 1, npc_b, {"source_type": "weapon"})
	_check(combat_system._enemy_high_threat_reacquire_requests.has(enemy_id), "T0199 building target did not produce a damage reacquire request")
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_id, combat_system.get_enemy(enemy_id))
	_check(str(selected.get("id", "")) == npc_b, "T0199 building damage rescan did not choose nearest high threat: %s" % selected)
	npc_system.set_npc_equipment_slot(npc_a, "main_weapon", {})
	_set_current_target(combat_system, enemy_id, combat_system._make_npc_enemy_target(npc_a, origin))
	combat_system._apply_damage_to_enemy(enemy_id, 1, npc_b, {"source_type": "weapon"})
	_check(combat_system._enemy_high_threat_reacquire_requests.has(enemy_id), "T0199 unarmed current target did not produce a damage reacquire request")
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_id, combat_system.get_enemy(enemy_id))
	_check(str(selected.get("id", "")) == npc_b, "T0199 unarmed damage rescan did not choose nearest high threat: %s" % selected)
	npc_system.set_npc_equipment_slot(npc_a, "main_weapon", TEST_WEAPON)
	_set_current_target(combat_system, enemy_id, combat_system._make_npc_enemy_target(npc_a, origin))
	combat_system._apply_damage_to_enemy(enemy_id, 0, npc_b, {"source_type": "weapon"})
	_check(not combat_system._enemy_high_threat_reacquire_requests.has(enemy_id), "T0197 zero damage incorrectly produced a request")
	combat_system._apply_damage_to_enemy(enemy_id, 1, "", {"source_type": "meteor"})
	_check(not combat_system._enemy_high_threat_reacquire_requests.has(enemy_id), "T0197 noncombat damage incorrectly produced a request")

	# An out-of-range attacker can cause the one-shot unlock but can never become a
	# forced target. The selector still chooses the nearest in-range high threat.
	_set_npc_position(npc_system, npc_a, origin + Vector3(8.0, 0.0, 0.0))
	_set_npc_position(npc_system, npc_b, origin + Vector3(UNIFIED_RANGE + 1.0, 0.0, 0.0))
	_set_npc_position(npc_system, npc_c, origin + Vector3(3.0, 0.0, 0.0))
	_set_current_target(combat_system, enemy_id, combat_system._make_npc_enemy_target(npc_a, origin))
	combat_system._apply_damage_to_enemy(enemy_id, 1, npc_b, {"source_type": "weapon"})
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_id, combat_system.get_enemy(enemy_id))
	_check(str(selected.get("id", "")) == npc_c, "T0197 out-of-range attacker bypassed the unified candidate pool: %s" % selected)

	# A target change may cancel the current phase, but the T0191 earliest-next-start
	# timestamp remains authoritative and cannot be reset by this new rule.
	_set_npc_position(npc_system, npc_a, origin + Vector3(7.0, 0.0, 0.0))
	_set_npc_position(npc_system, npc_b, origin + Vector3(2.0, 0.0, 0.0))
	_set_npc_position(npc_system, npc_c, origin + Vector3(20.0, 0.0, 0.0))
	var current_a: Dictionary = _set_current_target(combat_system, enemy_id, combat_system._make_npc_enemy_target(npc_a, origin))
	var cadence_enemy: Dictionary = combat_system.get_enemy(enemy_id)
	cadence_enemy["attack_sequence"] = 3
	cadence_enemy["attack_cycle_phase"] = "windup"
	cadence_enemy["attack_cycle_target"] = current_a.duplicate(true)
	cadence_enemy["attack_windup_target"] = current_a.duplicate(true)
	cadence_enemy["attack_cycle_elapsed"] = 0.1
	cadence_enemy["attack_cycle_duration"] = 2.6
	cadence_enemy["attack_impact_seconds"] = 0.8
	var next_sequence_time := float(combat_system._combat_timeline_seconds) + 2.0
	cadence_enemy["attack_next_sequence_time"] = next_sequence_time
	combat_system._active_enemies[enemy_id] = cadence_enemy
	combat_system._apply_damage_to_enemy(enemy_id, 1, npc_b, {"source_type": "weapon"})
	cadence_enemy = combat_system.get_enemy(enemy_id)
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_id, cadence_enemy)
	combat_system._advance_enemy_attack(
		cadence_enemy,
		selected,
		0.2,
		float(combat_system._combat_timeline_seconds) + 0.2
	)
	_check(int(cadence_enemy.get("attack_sequence", 0)) == 3, "T0197 target switch bypassed enemy attack cadence: %s" % cadence_enemy)
	_check(is_equal_approx(float(cadence_enemy.get("attack_next_sequence_time", 0.0)), next_sequence_time), "T0197 target switch cleared earliest next start: %s" % cadence_enemy)

	# Requests are transient targeting evidence: snapshot-visible but absent from the
	# formal spatial checkpoint and removed by the next target evaluation.
	_set_current_target(combat_system, enemy_id, combat_system._make_npc_enemy_target(npc_a, origin))
	combat_system._apply_damage_to_enemy(enemy_id, 1, npc_b, {"source_type": "weapon"})
	targeting_snapshot = combat_system.debug_get_enemy_targeting_snapshot()
	_check((targeting_snapshot.get("different_attacker_damage_reacquire_requests", []) as Array).size() == 1, "T0197 pending request missing from read-only snapshot: %s" % targeting_snapshot)
	var checkpoint: Dictionary = combat_system.create_formal_spatial_checkpoint()
	_check(not JSON.stringify(checkpoint).contains("enemy_high_threat_damage_reacquire_request"), "T0197 transient request leaked into formal checkpoint: %s" % checkpoint)
	_check(combat_system._enemy_high_threat_reacquire_requests.has(enemy_id), "T0197 checkpoint capture unexpectedly consumed the request")
	combat_system._select_formal_dynamic_enemy_target(enemy_id, combat_system.get_enemy(enemy_id))

	var final_snapshot: Dictionary = combat_system.debug_get_enemy_targeting_snapshot()
	var metrics := final_snapshot.get("metrics", {}) as Dictionary
	_check(int(metrics.get("different_attacker_damage_signals", 0)) >= 7, "T0197 damage signal metric missing: %s" % metrics)
	_check(int(metrics.get("different_attacker_damage_reacquisitions", 0)) >= 7, "T0197 reacquisition metric missing: %s" % metrics)
	_check((final_snapshot.get("different_attacker_damage_reacquire_requests", []) as Array).is_empty(), "T0197 request remained after consumption: %s" % final_snapshot)
	print("T0197_DAMAGE_REACQUIRE_DIAGNOSTICS %s" % JSON.stringify({
		"schema": final_snapshot.get("schema", ""),
		"metrics": metrics,
		"last_target": selected,
		"cadence_next_sequence_time": next_sequence_time
	}))
	combat_system.clear_spawned_enemies()
	_finish()


func _set_current_target(combat_system: Node, enemy_id: String, target: Dictionary) -> Dictionary:
	combat_system._release_enemy_attack_position(enemy_id, "t0197_set_current", false, false)
	combat_system._enemy_high_threat_reacquire_requests.erase(enemy_id)
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var decorated := target.duplicate(true)
	decorated["target_priority"] = combat_system._enemy_target_priority(decorated, enemy)
	decorated = combat_system._ensure_enemy_attack_position(enemy_id, enemy, decorated, true)
	enemy["target"] = decorated
	enemy["target_priority"] = int(decorated.get("target_priority", 0))
	enemy["attack_cycle_phase"] = "idle"
	enemy["attack_cycle_target"] = {}
	enemy["attack_windup_target"] = {}
	enemy["attack_impact_committed"] = false
	combat_system._active_enemies[enemy_id] = enemy
	return decorated


func _move_all_npcs_far(npc_system: Node, npc_ids: Array[String], origin: Vector3) -> void:
	for index in range(npc_ids.size()):
		_set_npc_position(npc_system, npc_ids[index], origin + Vector3(70.0 + float(index) * 2.0, 0.0, 0.0))


func _set_enemy_position(combat_system: Node, enemy_id: String, actor: Node3D, position: Vector3) -> void:
	actor.global_position = position
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["position"] = position
	enemy["hp"] = maxi(10000, int(enemy.get("hp", 0)))
	enemy["max_hp"] = maxi(10000, int(enemy.get("max_hp", 0)))
	combat_system._active_enemies[enemy_id] = enemy


func _set_npc_position(npc_system: Node, npc_id: String, position: Vector3) -> void:
	var node := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
	if node != null:
		node.global_position = position


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _find_target(targets: Array[Dictionary], target_id: String) -> Dictionary:
	for target in targets:
		if str(target.get("id", "")) == target_id:
			return target
	return {}


func _to_vector3(raw: Variant) -> Vector3:
	if raw is Vector3:
		return raw
	if not raw is Dictionary:
		return Vector3.ZERO
	return Vector3(float(raw.get("x", 0.0)), float(raw.get("y", 0.0)), float(raw.get("z", 0.0)))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0197_ENEMY_DAMAGE_REACQUIRE_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
