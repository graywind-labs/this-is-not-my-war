extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	for _frame in range(3):
		await process_frame
		await physics_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	_check(combat_system != null and npc_system != null and device_system != null, "T0149 combat/NPC/device systems missing")
	_check(building_system != null and resource_system != null, "T0149 building/resource systems missing")
	if not _failures.is_empty():
		_finish()
		return
	if time_system != null:
		time_system.set_paused(true)
	# T0196 gives every enemy a 37.2m unit-awareness radius. This fixture audits
	# fixed building/device leases, so keep all NPCs outside that radius.
	for index in range(npc_system.get_npc_ids().size()):
		var npc_id := str(npc_system.get_npc_ids()[index])
		var npc_node := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node != null:
			npc_node.global_position = Vector3(160.0 + float(index) * 2.0, 0.0, 160.0)

	var started: Dictionary = combat_system.debug_run_formal_dynamic_wave_slice(5, true)
	_check(bool(started.get("ok", false)), "T0149 wave 5 failed to spawn")
	_check(int(started.get("spawned_count", 0)) == 48, "T0149 wave 5 did not create 48 physical enemies")
	await physics_frame
	combat_system.debug_step_enemy_ai(0.1)
	await physics_frame

	var snapshot: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	if str(snapshot.get("schema", "")) == "enemy_attack_guidance_zones_v2":
		_check(int(snapshot.get("guidance_count", 0)) > 0, "T0149/T0243 produced no live fixed-target guidance")
		_check(int(snapshot.get("waiter_count", -1)) == 0, "T0149/T0243 retained a fixed-capacity waiter queue")
		for raw_guidance in snapshot.get("guidance_assignments", []):
			var guidance := raw_guidance as Dictionary
			_check(str(guidance.get("status", "")) in ["guiding", "engaging"], "T0149/T0243 invalid guidance state: %s" % guidance)
			_check(float(guidance.get("guidance_zone_radius", 0.0)) > 0.0, "T0149/T0243 guidance omitted body-sized radius: %s" % guidance)
		combat_system.debug_stop_formal_dynamic_wave_slice("t0149_guidance_replacement_complete")
		await process_frame
		var guidance_cleared: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
		_check(int(guidance_cleared.get("guidance_count", -1)) == 0, "T0149/T0243 clear left guidance residue")
		_finish()
		return
	_check(str(snapshot.get("schema", "")) == "enemy_attack_position_leases_v1", "T0149 lease schema missing")
	_check(int(snapshot.get("lease_count", 0)) + int(snapshot.get("waiter_count", 0)) == 48, "T0149 every wave-5 enemy must own a fixed lease or an unreachable-path wait entry")
	_check(int(snapshot.get("lease_count", 0)) > 0, "T0149 produced no attack-position leases")
	_check_unique_assignments(snapshot)
	_check_tight_non_overlapping_positions(snapshot)
	_check_weapon_roles(snapshot)

	var leased := snapshot.get("leases", []) as Array
	var first_lease := leased[0] as Dictionary if not leased.is_empty() else {}
	var holder_id := str(first_lease.get("enemy_id", ""))
	var holder_enemy: Dictionary = combat_system.get_enemy(holder_id)
	var target_anchor := _to_vector3(first_lease.get("target_position", {}))
	var old_slot_id := str(first_lease.get("slot_id", ""))

	var npc_target := {
		"type": "npc",
		"id": "t0149_npc_target",
		"name": "占位测试 NPC",
		"position": target_anchor,
		"contact_radius": 0.35
	}
	combat_system.debug_release_enemy_attack_position(holder_id, "target_type_audit")
	var npc_assigned: Dictionary = combat_system._ensure_enemy_attack_position(holder_id, holder_enemy, npc_target, true)
	_check(not npc_assigned.has("attack_position_status"), "T0149 NPC target still received a fixed ring position")
	_check(not combat_system._enemy_attack_position_by_enemy.has(holder_id), "T0149 NPC target retained a fixed lease")

	var defense_target := {
		"type": "defense_device",
		"id": "t0149_defense_target",
		"name": "占位测试塔防",
		"position": target_anchor,
		"aim_position": target_anchor + Vector3.UP,
		"facing_direction": Vector3(0.0, 0.0, 1.0),
		"contact_radius": 0.6,
		"host_proxy_hit_radius": 1.2
	}
	var defense_assigned: Dictionary = combat_system._ensure_enemy_attack_position(holder_id, holder_enemy, defense_target, true)
	_check(str(defense_assigned.get("attack_position_status", "")) == "reserved", "T0149 defense host proxy did not provide a reachable front position")
	_check(str(defense_assigned.get("attack_position_target_key", "")) == "defense_device:t0149_defense_target", "T0149 defense lease key mismatch")
	var defense_position := defense_assigned.get("attack_position", target_anchor) as Vector3
	_check(defense_position.z > target_anchor.z, "T0149 defense attack position ignored host facing direction: anchor=%s assigned=%s target=%s" % [target_anchor, defense_position, defense_assigned])

	var unreachable_target := {
		"type": "defense_device",
		"id": "t0149_unreachable_target",
		"name": "不可达测试塔防",
		"position": Vector3(99999.0, 0.0, 99999.0),
		"facing_direction": Vector3(0.0, 0.0, 1.0),
		"contact_radius": 0.6,
		"host_proxy_hit_radius": 1.2
	}
	var unreachable: Dictionary = combat_system._ensure_enemy_attack_position(holder_id, holder_enemy, unreachable_target, true)
	_check(str(unreachable.get("attack_position_status", "")) == "waiting", "T0149 unreachable positions were treated as reservable")
	var unreachable_metrics := combat_system.debug_get_enemy_attack_position_snapshot().get("metrics", {}) as Dictionary
	_check(int(unreachable_metrics.get("unreachable_candidates_rejected", 0)) > 0, "T0149 unreachable rejection metric did not advance")
	combat_system.debug_release_enemy_attack_position(holder_id, "return_to_gate")

	# Rebuild normal fixed-target leases. T0196 deliberately removed capacity
	# waiters: once a fixed target is full, later enemies choose another target.
	combat_system.debug_step_enemy_ai(0.1)
	var full_after: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	_check(int(full_after.get("lease_count", 0)) > 0, "T0149 normal fixed-target selection did not rebuild leases")

	# Stagger and defeat are both authoritative interruption paths and may not
	# retain a position. Defeat also must not leave a waiter entry behind.
	var lifecycle_leases := full_after.get("leases", []) as Array
	var stagger_lease := lifecycle_leases[0] as Dictionary if not lifecycle_leases.is_empty() else {}
	var stagger_id := str(stagger_lease.get("enemy_id", ""))
	var stagger_slot := str(stagger_lease.get("slot_id", ""))
	combat_system.apply_enemy_stagger(stagger_id, 0.8, {"source_type": "t0149_test"})
	var stagger_after: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	# Releasing a slot may synchronously promote a waiter into the same physical
	# slot. Audit ownership, not slot existence: the staggered actor must lose its
	# lease while a valid waiter is allowed to reuse the freed position immediately.
	_check(not _snapshot_has_enemy(stagger_after, stagger_id), "T0149 staggered enemy retained a lease or wait entry at %s" % stagger_slot)

	var defeat_leases := stagger_after.get("leases", []) as Array
	var defeat_lease := defeat_leases[0] as Dictionary if not defeat_leases.is_empty() else {}
	var defeat_id := str(defeat_lease.get("enemy_id", ""))
	var defeat_slot := str(defeat_lease.get("slot_id", ""))
	var defeat_enemy: Dictionary = combat_system.get_enemy(defeat_id)
	combat_system._apply_damage_to_enemy(defeat_id, int(defeat_enemy.get("hp", 1)), "", {"source_type": "t0149_test"})
	var defeat_after: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	_check(not _snapshot_has_enemy(defeat_after, defeat_id), "T0149 defeated enemy retained a lease or wait entry at %s" % defeat_slot)
	_check(old_slot_id != "", "T0149 building lease identity was empty")

	combat_system.debug_stop_formal_dynamic_wave_slice("t0149_complete")
	await process_frame
	var cleared: Dictionary = combat_system.debug_get_enemy_attack_position_snapshot()
	_check(int(cleared.get("lease_count", -1)) == 0 and int(cleared.get("waiter_count", -1)) == 0, "T0149 clear left lease/waiter residue")
	_finish()


func _check_unique_assignments(snapshot: Dictionary) -> void:
	var slot_ids: Dictionary = {}
	var enemy_ids: Dictionary = {}
	for raw_lease in snapshot.get("leases", []):
		var lease := raw_lease as Dictionary
		var slot_id := str(lease.get("slot_id", ""))
		var enemy_id := str(lease.get("enemy_id", ""))
		_check(not slot_id.is_empty() and not slot_ids.has(slot_id), "T0149 duplicated attack position: %s" % slot_id)
		_check(not enemy_id.is_empty() and not enemy_ids.has(enemy_id), "T0149 enemy owns multiple positions: %s" % enemy_id)
		slot_ids[slot_id] = true
		enemy_ids[enemy_id] = true
	for raw_waiter in snapshot.get("waiters", []):
		var waiter := raw_waiter as Dictionary
		var enemy_id := str(waiter.get("enemy_id", ""))
		_check(not enemy_id.is_empty() and not enemy_ids.has(enemy_id), "T0149 enemy is both leased and waiting: %s" % enemy_id)
		enemy_ids[enemy_id] = true


func _check_tight_non_overlapping_positions(snapshot: Dictionary) -> void:
	var leases := snapshot.get("leases", []) as Array
	for first_index in range(leases.size()):
		var first := leases[first_index] as Dictionary
		for second_index in range(first_index + 1, leases.size()):
			var second := leases[second_index] as Dictionary
			if str(first.get("target_key", "")) != str(second.get("target_key", "")):
				continue
			var first_position := _to_vector3(first.get("position", {}))
			var second_position := _to_vector3(second.get("position", {}))
			var distance := Vector2(first_position.x, first_position.z).distance_to(Vector2(second_position.x, second_position.z))
			var minimum := float(first.get("enemy_radius", 0.42)) + float(second.get("enemy_radius", 0.42)) + 0.08
			_check(distance + 0.02 >= minimum, "T0149 leased positions overlap: %.3f < %.3f" % [distance, minimum])


func _check_weapon_roles(snapshot: Dictionary) -> void:
	var melee_seen := false
	var ranged_seen := false
	for raw_lease in snapshot.get("leases", []):
		var role := str((raw_lease as Dictionary).get("role", ""))
		melee_seen = melee_seen or role.begins_with("melee_")
		ranged_seen = ranged_seen or role.begins_with("ranged_")
	_check(melee_seen, "T0149 produced no close melee positions")
	_check(ranged_seen, "T0149 produced no ranged firing positions")


func _snapshot_has_slot(snapshot: Dictionary, slot_id: String) -> bool:
	for raw_lease in snapshot.get("leases", []):
		if str((raw_lease as Dictionary).get("slot_id", "")) == slot_id:
			return true
	return false


func _snapshot_has_enemy(snapshot: Dictionary, enemy_id: String) -> bool:
	for collection_name in ["leases", "waiters"]:
		for raw_entry in snapshot.get(collection_name, []):
			if str((raw_entry as Dictionary).get("enemy_id", "")) == enemy_id:
				return true
	return false


func _to_vector3(value: Variant) -> Vector3:
	if value is Vector3:
		return value
	var data := value as Dictionary if value is Dictionary else {}
	return Vector3(float(data.get("x", 0.0)), float(data.get("y", 0.0)), float(data.get("z", 0.0)))


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0149_ENEMY_ATTACK_POSITION_LEASES_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
