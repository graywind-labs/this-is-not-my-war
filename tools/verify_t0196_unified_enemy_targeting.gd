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
	_check(combat_system != null and npc_system != null and device_system != null, "T0196 combat systems missing")
	_check(building_system != null and resource_system != null and time_system != null, "T0196 world systems missing")
	if not _failures.is_empty():
		_finish()
		return
	time_system.set_paused(true)

	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(1, true)
	_check(bool(started.get("ok", false)), "T0196 formal wave failed to spawn: %s" % started)
	var enemy_ids: Array[String] = combat_system.get_active_enemy_ids()
	_check(enemy_ids.size() >= 2, "T0196 needs two production enemies")
	var npc_ids: Array[String] = npc_system.get_npc_ids()
	_check(npc_ids.size() >= 3, "T0196 needs three production NPCs")
	if not _failures.is_empty():
		_finish()
		return
	for index in range(2, enemy_ids.size()):
		combat_system._remove_enemy_from_combat(enemy_ids[index])
	var enemy_a := enemy_ids[0]
	var enemy_b := enemy_ids[1]
	var actor_a := root.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_a, NodePath())) as Node3D
	var actor_b := root.get_node_or_null(combat_system._formal_first_wave_node_paths.get(enemy_b, NodePath())) as Node3D
	_check(actor_a != null and actor_b != null, "T0196 production enemy actors missing")
	if not _failures.is_empty():
		_finish()
		return

	var npc_a := npc_ids[0]
	var npc_b := npc_ids[1]
	var npc_c := npc_ids[2]
	for npc_id in npc_ids:
		npc_system.set_npc_equipment_slot(npc_id, "main_weapon", {})
	var origin := Vector3(0.0, 0.0, 18.0)
	_set_enemy_position(combat_system, enemy_a, actor_a, origin)
	_set_enemy_position(combat_system, enemy_b, actor_b, origin + Vector3(0.6, 0.0, 0.0))
	_move_all_npcs_far(npc_system, npc_ids, origin)

	var policy: Dictionary = combat_system.debug_get_enemy_targeting_snapshot()
	_check(str(policy.get("schema", "")) == "enemy_unified_presence_lock_v3", "T0196 targeting schema mismatch: %s" % policy)
	_check(is_equal_approx(float((policy.get("policy", {}) as Dictionary).get("detection_range", 0.0)), UNIFIED_RANGE), "T0196 unified detection range is not 37.2m: %s" % policy)

	# The same 37.2m radius applies to every NPC. No intent, projectile, weapon
	# range, or device-specific multiplier expands it.
	npc_system.set_npc_equipment_slot(npc_a, "main_weapon", TEST_WEAPON)
	_set_npc_position(npc_system, npc_a, origin + Vector3(UNIFIED_RANGE - 0.1, 0.0, 0.0))
	var selected := _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == npc_a and int(selected.get("target_priority", 0)) == 1, "T0196 armed NPC inside unified radius was not acquired: %s" % selected)
	_set_npc_position(npc_system, npc_a, origin + Vector3(UNIFIED_RANGE + 0.1, 0.0, 0.0))
	selected = _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == "front_gate", "T0196 NPC outside unified radius did not disappear: %s" % selected)

	# Armed NPCs and defense devices share one tier; acquisition uses horizontal
	# distance. Once acquired, a live in-range target remains locked even when a
	# peer later becomes nearer.
	npc_system.set_npc_equipment_slot(npc_b, "main_weapon", TEST_WEAPON)
	_set_npc_position(npc_system, npc_a, origin + Vector3(8.0, 0.0, 0.0))
	_set_npc_position(npc_system, npc_b, origin + Vector3(4.0, 0.0, 0.0))
	selected = _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == npc_b, "T0196 nearest armed NPC was not selected: %s" % selected)
	_set_current_target(combat_system, enemy_a, combat_system._make_npc_enemy_target(npc_a, origin))
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_a, combat_system.get_enemy(enemy_a))
	_check(str(selected.get("id", "")) == npc_a and str(selected.get("target_selection_reason", "")) == "locked_high_threat_present", "T0196 locked armed NPC was displaced by a nearer peer: %s" % selected)
	_set_npc_position(npc_system, npc_a, origin + Vector3(UNIFIED_RANGE + 0.1, 0.0, 0.0))
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_a, combat_system.get_enemy(enemy_a))
	_check(str(selected.get("id", "")) == npc_b, "T0196 out-of-range locked NPC did not trigger reacquisition: %s" % selected)

	# NPCs have no capacity or lease. Two enemies can select the same NPC and the
	# attack-position authority remains empty for both.
	_move_all_npcs_far(npc_system, npc_ids, origin)
	_set_npc_position(npc_system, npc_b, origin + Vector3(2.0, 0.0, 0.0))
	for enemy_id in [enemy_a, enemy_b]:
		var enemy: Dictionary = combat_system.get_enemy(enemy_id)
		var npc_choice := _fresh_select(combat_system, enemy_id)
		npc_choice = combat_system._ensure_enemy_attack_position(enemy_id, enemy, npc_choice, true)
		_check(str(npc_choice.get("id", "")) == npc_b, "T0196 multiple enemies did not share the NPC target: %s" % npc_choice)
		_check(not npc_choice.has("attack_position_status"), "T0196 NPC target still received a fixed attack position: %s" % npc_choice)
		_check(not combat_system._enemy_attack_position_by_enemy.has(enemy_id), "T0196 NPC target created an attack-position lease for %s" % enemy_id)
		_check(combat_system._find_enemy_attack_wait_entry(enemy_id, "npc:%s" % npc_b).is_empty(), "T0196 NPC target created a waiter for %s" % enemy_id)

	# An unarmed NPC is pursued only while there is no armed NPC or defense device.
	npc_system.set_npc_equipment_slot(npc_a, "main_weapon", {})
	npc_system.set_npc_equipment_slot(npc_b, "main_weapon", {})
	npc_system.set_npc_equipment_slot(npc_c, "main_weapon", {})
	selected = _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == npc_b and int(selected.get("target_priority", 0)) == 2, "T0196 lone unarmed NPC was not pursued: %s" % selected)
	_set_current_target(combat_system, enemy_a, selected)
	_set_npc_position(npc_system, npc_a, origin + Vector3(1.0, 0.0, 0.0))
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_a, combat_system.get_enemy(enemy_a))
	_check(str(selected.get("id", "")) == npc_b and str(selected.get("target_selection_reason", "")) == "locked_unarmed_npc_no_high_threat", "T0196 locked unarmed NPC was displaced without a high threat: %s" % selected)
	_set_npc_position(npc_system, npc_a, origin + Vector3(70.0, 0.0, 0.0))
	npc_system.set_npc_equipment_slot(npc_c, "main_weapon", TEST_WEAPON)
	_set_npc_position(npc_system, npc_c, origin + Vector3(9.0, 0.0, 0.0))
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_a, combat_system.get_enemy(enemy_a))
	_check(str(selected.get("id", "")) == npc_c and int(selected.get("target_priority", 0)) == 1, "T0196 armed NPC did not preempt an unarmed target: %s" % selected)

	# A defense device uses the same radius and competes by distance. A full fixed
	# target disappears for this enemy instead of creating the old strict queue.
	_set_building_level(building_system, "wall", 4)
	resource_system.add_resource("item_wall_ballista", 1)
	var deployed: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	_check(bool(deployed.get("ok", false)), "T0196 ballista deployment failed: %s" % deployed)
	var deployment_id := str(deployed.get("deployment_id", ""))
	var device_target := _find_target(device_system.get_active_defense_targets(), deployment_id)
	_check(not device_target.is_empty(), "T0196 active defense target missing")
	var device_position := _to_vector3(device_target.get("position", {}))
	var outward := _to_vector3(device_target.get("facing_direction", {"z": 1.0})).normalized()
	if outward.length_squared() <= 0.0001:
		outward = Vector3.FORWARD
	_set_enemy_position(combat_system, enemy_a, actor_a, device_position + outward * (UNIFIED_RANGE + 0.1))
	_move_all_npcs_far(npc_system, npc_ids, device_position)
	selected = _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == "front_gate", "T0196 defense outside the shared 37.2m radius was still acquired: %s" % selected)
	var device_origin := device_position + outward * 8.0
	_set_enemy_position(combat_system, enemy_a, actor_a, device_origin)
	_move_all_npcs_far(npc_system, npc_ids, device_origin)
	npc_system.set_npc_equipment_slot(npc_c, "main_weapon", TEST_WEAPON)
	_set_npc_position(npc_system, npc_c, device_origin + Vector3(12.0, 0.0, 0.0))
	selected = _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == deployment_id and int(selected.get("target_priority", 0)) == 1, "T0196 nearer defense did not beat armed NPC in the shared tier: %s" % selected)
	_set_current_target(combat_system, enemy_a, selected)
	_set_npc_position(npc_system, npc_c, device_origin + Vector3(1.0, 0.0, 0.0))
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_a, combat_system.get_enemy(enemy_a))
	_check(str(selected.get("id", "")) == deployment_id, "T0196 locked defense was displaced by a nearer armed NPC: %s" % selected)
	combat_system._release_enemy_attack_position(enemy_a, "t0196_fill_defense", false, false)
	var defense_slots := _fill_target_positions(combat_system, enemy_a, combat_system.get_enemy(enemy_a), device_target, "t0196_defense_full")
	selected = combat_system._select_formal_dynamic_enemy_target(enemy_a, combat_system.get_enemy(enemy_a))
	var guided_schema := str(combat_system._formal_attack_position_policy.get("schema", "")) == "enemy_attack_guidance_zones_v2"
	_check(str(selected.get("id", "")) == (deployment_id if guided_schema else npc_c), "T0196 fixed-target capacity contract mismatch after synthetic reservations: %s" % selected)
	_check(combat_system._find_enemy_attack_wait_entry(enemy_a, "defense_device:%s" % deployment_id).is_empty(), "T0196 full defense created the removed strict waiter")
	_erase_fake_leases(combat_system, defense_slots)

	# With no unit in range, use the surviving building sequence. The front gate is
	# the mandatory breach exception: full capacity keeps it selected and waiting.
	# Other fixed targets can become absent through capacity; NPCs never do.
	device_system.apply_damage_to_device(deployment_id, 100000, {"attacker_id": "t0196"})
	_move_all_npcs_far(npc_system, npc_ids, device_origin)
	selected = _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == "front_gate", "T0196 building fallback did not start at front gate: %s" % selected)
	var gate_target: Dictionary = combat_system._make_building_target("front_gate")
	var gate_slots := _fill_target_positions(combat_system, enemy_a, combat_system.get_enemy(enemy_a), gate_target, "t0196_gate_full")
	selected = _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == "front_gate", "T0196 full front gate incorrectly disappeared from targeting: %s" % selected)
	selected = combat_system._ensure_enemy_attack_position(enemy_a, combat_system.get_enemy(enemy_a), selected, true)
	_check(str(selected.get("attack_position_status", "")) == ("guiding" if guided_schema else "waiting"), "T0196 front-gate assignment contract mismatch: %s" % selected)
	_erase_fake_leases(combat_system, gate_slots)
	_damage_building_to_zero(building_system, "front_gate")
	selected = _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == "warehouse", "T0196 destroyed gate did not advance to warehouse: %s" % selected)
	var warehouse_target: Dictionary = combat_system._make_building_target("warehouse")
	var warehouse_slots := _fill_target_positions(combat_system, enemy_a, combat_system.get_enemy(enemy_a), warehouse_target, "t0196_warehouse_full")
	selected = _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == ("warehouse" if guided_schema else "main_hall"), "T0196 warehouse capacity contract mismatch: %s" % selected)
	_erase_fake_leases(combat_system, warehouse_slots)
	_damage_building_to_zero(building_system, "warehouse")
	selected = _fresh_select(combat_system, enemy_a)
	_check(str(selected.get("id", "")) == "main_hall", "T0196 destroyed warehouse did not advance to main hall: %s" % selected)

	var final_snapshot: Dictionary = combat_system.debug_get_enemy_targeting_snapshot()
	var metrics := final_snapshot.get("metrics", {}) as Dictionary
	_check(int(metrics.get("locked_high_target_holds", 0)) >= 2, "T0196 high target hold metric missing: %s" % metrics)
	_check(int(metrics.get("locked_unarmed_target_holds", 0)) >= 1, "T0196 unarmed target hold metric missing: %s" % metrics)
	_check(int(metrics.get("high_threat_preemptions", 0)) >= 1, "T0196 high target preemption metric missing: %s" % metrics)
	_check(int(metrics.get("fixed_target_full_skips", 0)) == 0 if guided_schema else int(metrics.get("fixed_target_full_skips", 0)) >= 2, "T0196 fixed target full-skip metric mismatch: %s" % metrics)
	_check(int(metrics.get("gate_full_holds", 0)) == 0 if guided_schema else int(metrics.get("gate_full_holds", 0)) >= 1, "T0196 mandatory gate full-hold metric mismatch: %s" % metrics)
	print("T0196_UNIFIED_TARGETING_DIAGNOSTICS %s" % JSON.stringify({
		"schema": final_snapshot.get("schema", ""),
		"detection_range": (final_snapshot.get("policy", {}) as Dictionary).get("detection_range", 0.0),
		"metrics": metrics,
		"npc_leases": _count_target_leases(combat_system, "npc:"),
		"last_target": selected
	}))
	combat_system.clear_spawned_enemies()
	_finish()


func _fresh_select(combat_system: Node, enemy_id: String) -> Dictionary:
	combat_system._release_enemy_attack_position(enemy_id, "t0196_fresh_select", false, false)
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	enemy["target"] = {}
	enemy["target_priority"] = 0
	enemy["target_selection_reason"] = ""
	enemy["attack_cycle_phase"] = "idle"
	enemy["attack_impact_committed"] = false
	combat_system._active_enemies[enemy_id] = enemy
	return combat_system._select_formal_dynamic_enemy_target(enemy_id, enemy)


func _set_current_target(combat_system: Node, enemy_id: String, target: Dictionary) -> Dictionary:
	combat_system._release_enemy_attack_position(enemy_id, "t0196_set_current", false, false)
	var enemy: Dictionary = combat_system.get_enemy(enemy_id)
	var decorated := target.duplicate(true)
	decorated["target_priority"] = combat_system._enemy_target_priority(decorated, enemy)
	decorated = combat_system._ensure_enemy_attack_position(enemy_id, enemy, decorated, true)
	enemy["target"] = decorated
	enemy["target_priority"] = int(decorated.get("target_priority", 0))
	enemy["attack_cycle_phase"] = "idle"
	enemy["attack_impact_committed"] = false
	combat_system._active_enemies[enemy_id] = enemy
	return decorated


func _fill_target_positions(combat_system: Node, enemy_id: String, enemy: Dictionary, target: Dictionary, prefix: String) -> Array[String]:
	combat_system._release_enemy_attack_position(enemy_id, "%s_prepare" % prefix, false, false)
	var inserted: Array[String] = []
	var target_key: String = combat_system._enemy_attack_target_key(target)
	var index := 0
	for raw_candidate in combat_system._get_enemy_attack_position_candidates(enemy_id, enemy, target):
		var candidate := (raw_candidate as Dictionary).duplicate(true)
		var fake_slot_id := "%s:%03d" % [prefix, index]
		candidate["slot_id"] = fake_slot_id
		candidate["enemy_id"] = "%s_enemy_%03d" % [prefix, index]
		candidate["target_key"] = target_key
		candidate["status"] = "occupied"
		combat_system._enemy_attack_position_leases[fake_slot_id] = candidate
		inserted.append(fake_slot_id)
		index += 1
	return inserted


func _erase_fake_leases(combat_system: Node, slot_ids: Array[String]) -> void:
	for slot_id in slot_ids:
		combat_system._enemy_attack_position_leases.erase(slot_id)


func _count_target_leases(combat_system: Node, prefix: String) -> int:
	var count := 0
	for raw_lease in combat_system._enemy_attack_position_leases.values():
		if str((raw_lease as Dictionary).get("target_key", "")).begins_with(prefix):
			count += 1
	return count


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


func _damage_building_to_zero(building_system: Node, building_id: String) -> void:
	var hp := int(building_system.get_building(building_id).get("hp", 0))
	if hp > 0:
		building_system.apply_damage_to_building(building_id, hp, "t0196_test", "system")


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
		print("T0196_UNIFIED_ENEMY_TARGETING_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
