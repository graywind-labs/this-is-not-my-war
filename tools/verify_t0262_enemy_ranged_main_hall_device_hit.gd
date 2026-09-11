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
	for _frame in range(8):
		await process_frame
		await physics_frame

	var combat := root.get_node_or_null("Main/Systems/CombatSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var presenter := root.get_node_or_null("Main/WorldRoot/Station/DefenseDevices")
	_check(combat != null and npc_system != null and device_system != null, "T0262 combat dependencies missing")
	_check(resource_system != null and building_system != null and presenter != null, "T0262 world dependencies missing")
	if not _failures.is_empty():
		_finish()
		return

	# Keep ordinary residents outside the unified enemy awareness pool so the
	# production selector naturally chooses the deployed high-threat device.
	for index in range(npc_system.get_npc_ids().size()):
		var npc_id := str(npc_system.get_npc_ids()[index])
		var npc_node := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node != null:
			npc_node.global_position = Vector3(-70.0 + float(index), 0.04, -65.0)

	resource_system.add_resource("item_wall_arrow_tower", 1)
	var deployment_result: Dictionary = device_system.deploy_device("wall_arrow_tower", "main_hall_slot_03")
	_check(bool(deployment_result.get("ok", false)), "T0262 main-hall tower deployment failed: %s" % deployment_result)
	if not _failures.is_empty():
		_finish()
		return
	var deployment_id := str(deployment_result.get("deployment_id", ""))
	await process_frame
	await physics_frame

	var view := presenter.get_view_for_deployment(deployment_id) as Node3D
	var hit_area := view.get_node_or_null("InteractionArea") as Area3D if view != null else null
	var hit_shape := hit_area.get_node_or_null("CollisionShape3D") as CollisionShape3D if hit_area != null else null
	_check(hit_area != null and hit_shape != null, "T0262 tower projectile hit area missing")
	if not _failures.is_empty():
		_finish()
		return

	var spawned: Dictionary = combat.debug_run_formal_dynamic_wave_slice(3, true)
	_check(bool(spawned.get("ok", false)), "T0262 formal third wave failed: %s" % spawned)
	var archer_id := ""
	for raw_enemy_id in combat.get_active_enemy_ids():
		var enemy_id := str(raw_enemy_id)
		if str(combat.get_enemy(enemy_id).get("weapon_type", "")) == "bow":
			archer_id = enemy_id
			break
	_check(not archer_id.is_empty(), "T0262 formal archer missing")
	if not _failures.is_empty():
		_finish()
		return
	for raw_enemy_id in combat.get_active_enemy_ids().duplicate():
		var enemy_id := str(raw_enemy_id)
		if enemy_id != archer_id:
			combat._remove_enemy_from_combat(enemy_id)

	var enemy: Dictionary = combat.get_enemy(archer_id)
	var target: Dictionary = combat._make_defense_device_enemy_target(
		deployment_id,
		enemy.get("position", Vector3.ZERO)
	)
	_check(not target.is_empty(), "T0262 production device target missing")
	if not _failures.is_empty():
		_finish()
		return
	var outward: Vector3 = target.get("host_proxy_outward_direction", Vector3.FORWARD)
	outward.y = 0.0
	outward = outward.normalized() if outward.length_squared() > 0.0001 else Vector3.FORWARD
	var proxy_position: Vector3 = target.get("position", hit_shape.global_position)
	var actor := root.get_node_or_null(combat._formal_first_wave_node_paths.get(archer_id, NodePath())) as Node3D
	_check(actor != null, "T0262 formal archer actor missing")
	if actor == null:
		_finish()
		return
	actor.global_position = Vector3(proxy_position.x, actor.global_position.y, proxy_position.z) + outward * 8.0
	enemy["position"] = actor.global_position
	enemy["target"] = target.duplicate(true)
	combat._active_enemies[archer_id] = enemy
	combat._refresh_enemy_node(archer_id)
	await process_frame
	await physics_frame

	enemy = combat.get_enemy(archer_id)
	target = combat._make_defense_device_enemy_target(deployment_id, enemy.get("position", Vector3.ZERO))
	var legacy_proxy_aim: Vector3 = target.get("aim_position", Vector3.ZERO)
	var resolved_aim: Vector3 = combat._get_projectile_target_aim_position(target)
	var hit_center := hit_shape.global_position
	var hp_before := int(device_system.get_deployment(deployment_id).get("hp", 0))
	var hall_hp_before := int(building_system.get_building("main_hall").get("hp", 0))
	var release: Dictionary = combat._release_enemy_projectile(enemy, target)
	_check(not release.is_empty(), "T0262 production enemy projectile release failed: %s" % combat.debug_get_combat_snapshot().get("last_projectile_result", {}))
	var terminal: Dictionary = combat.debug_advance_combat_projectiles(3.0)
	var hp_after := int(device_system.get_deployment(deployment_id).get("hp", 0))
	var hall_hp_after := int(building_system.get_building("main_hall").get("hp", 0))
	var last_result: Dictionary = terminal.get("last_result", {}) if terminal.get("last_result", {}) is Dictionary else {}
	var hit_fact: Dictionary = last_result.get("hit_fact", {}) if last_result.get("hit_fact", {}) is Dictionary else {}
	var diagnostics := {
		"deployment_id": deployment_id,
		"archer_id": archer_id,
		"release_position": (release.get("projectile", {}) as Dictionary).get("release_position", Vector3.ZERO),
		"legacy_proxy_aim": legacy_proxy_aim,
		"resolved_aim": resolved_aim,
		"hit_area_center": hit_center,
		"resolved_aim_to_hit_center": resolved_aim.distance_to(hit_center),
		"legacy_aim_to_hit_center": legacy_proxy_aim.distance_to(hit_center),
		"device_hp_before": hp_before,
		"device_hp_after": hp_after,
		"main_hall_hp_before": hall_hp_before,
		"main_hall_hp_after": hall_hp_after,
		"projectile_status": str(last_result.get("status", "")),
		"aim_target_source": str(last_result.get("aim_target_source", "")),
		"aim_position_at_release": last_result.get("aim_position_at_release", Vector3.ZERO),
		"collision_position": last_result.get("collision_position", Vector3.ZERO),
		"collision_identity": hit_fact.get("collision_identity", {}),
		"actual_target_type": str(hit_fact.get("actual_target_type", "")),
		"actual_target_id": str(hit_fact.get("actual_target_id", "")),
		"damage_applied": bool(hit_fact.get("damage_applied", false))
	}
	print("T0262_ENEMY_RANGED_MAIN_HALL_DEVICE_DIAGNOSTICS=%s" % JSON.stringify(diagnostics))
	_check(resolved_aim.distance_to(hit_center) <= 0.05, "T0262 enemy projectile did not aim at the real device hit area: %s" % diagnostics)
	_check(hp_after < hp_before, "T0262 enemy projectile did not reduce main-hall device HP: %s" % diagnostics)
	_check(hall_hp_after == hall_hp_before, "T0262 enemy projectile also damaged the main hall: %s" % diagnostics)
	_check(str(hit_fact.get("actual_target_id", "")) == deployment_id, "T0262 projectile resolved to the wrong target: %s" % diagnostics)

	# Re-enter through the production selector and authored enemy windup/release.
	# The fixture only places the already-formal actor at a legal ranged distance;
	# target choice, attack phase, projectile creation, collision and HP all remain
	# on their normal runtime paths.
	enemy = combat.get_enemy(archer_id)
	combat._cancel_enemy_attack_timeline(enemy)
	enemy["target"] = {}
	combat._active_enemies[archer_id] = enemy
	var natural_hp_before := int(device_system.get_deployment(deployment_id).get("hp", 0))
	var natural_target_selected := false
	var natural_projectile_released := false
	var natural_damage_step := -1
	for step_index in range(40):
		combat.debug_step_enemy_ai(0.1)
		var current_enemy: Dictionary = combat.get_enemy(archer_id)
		var current_target: Dictionary = current_enemy.get("target", {}) if current_enemy.get("target", {}) is Dictionary else {}
		if str(current_target.get("id", "")) == deployment_id:
			natural_target_selected = true
		for projectile_snapshot in combat.get_active_projectile_snapshots():
			if (
				str(projectile_snapshot.get("source_id", "")) == archer_id
				and str((projectile_snapshot.get("target_at_release", {}) as Dictionary).get("id", "")) == deployment_id
			):
				natural_projectile_released = true
		combat.debug_advance_combat_projectiles(0.1)
		if int(device_system.get_deployment(deployment_id).get("hp", 0)) < natural_hp_before:
			natural_damage_step = step_index
			break
	if natural_projectile_released and natural_damage_step < 0:
		combat.debug_advance_combat_projectiles(3.0)
		if int(device_system.get_deployment(deployment_id).get("hp", 0)) < natural_hp_before:
			natural_damage_step = 40
	var natural_hp_after := int(device_system.get_deployment(deployment_id).get("hp", 0))
	var natural_last: Dictionary = combat.debug_get_combat_snapshot().get("last_projectile_result", {})
	var natural_hit: Dictionary = natural_last.get("hit_fact", {}) if natural_last.get("hit_fact", {}) is Dictionary else {}
	var natural_diagnostics := {
		"target_selected": natural_target_selected,
		"projectile_released": natural_projectile_released,
		"damage_step": natural_damage_step,
		"hp_before": natural_hp_before,
		"hp_after": natural_hp_after,
		"status": str(natural_last.get("status", "")),
		"aim_target_source": str(natural_last.get("aim_target_source", "")),
		"actual_target_id": str(natural_hit.get("actual_target_id", ""))
	}
	print("T0262_NATURAL_ATTACK_DIAGNOSTICS=%s" % JSON.stringify(natural_diagnostics))
	_check(natural_target_selected, "T0262 natural enemy selector did not choose the main-hall device: %s" % natural_diagnostics)
	_check(natural_projectile_released, "T0262 natural enemy attack timeline did not release a projectile: %s" % natural_diagnostics)
	_check(natural_hp_after < natural_hp_before, "T0262 natural enemy projectile did not damage the main-hall device: %s" % natural_diagnostics)
	_check(str(natural_hit.get("actual_target_id", "")) == deployment_id, "T0262 natural projectile resolved to the wrong target: %s" % natural_diagnostics)
	combat.clear_spawned_enemies()
	_finish()


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0262 enemy ranged main-hall device verification passed.")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
