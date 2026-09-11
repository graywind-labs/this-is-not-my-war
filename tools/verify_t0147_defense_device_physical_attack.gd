extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const EPSILON_SECONDS := 0.001
const PROJECTILE_STEP_SECONDS := 0.025

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var main := MAIN_SCENE.instantiate()
	var startup := main.get_node_or_null("Systems/GameStartupSystem")
	if startup != null:
		startup._startup_running = true
	root.add_child(main)
	await process_frame
	await physics_frame
	await physics_frame

	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var presenter := root.get_node_or_null("Main/WorldRoot/Station/DefenseDevices")
	_check(device_system != null and combat_system != null and resource_system != null, "T0147 core systems missing")
	_check(building_system != null and time_system != null and presenter != null, "T0147 building/time/presenter dependencies missing")
	if not _failures.is_empty():
		_finish()
		return

	time_system.set_paused(true)
	_set_building_level(building_system, "wall", 2)
	resource_system.add_resource("item_wall_ballista", 1)
	resource_system.add_resource("item_wall_arrow_tower", 1)
	var ballista_result: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	var arrow_result: Dictionary = device_system.deploy_device("wall_arrow_tower", "wall_slot_02")
	_check(bool(ballista_result.get("ok", false)), "T0147 ballista deployment failed")
	_check(bool(arrow_result.get("ok", false)), "T0147 arrow tower deployment failed")
	await process_frame

	var spawn: Dictionary = combat_system.debug_spawn_wave(1, true)
	_check(bool(spawn.get("ok", false)), "T0147 could not spawn a target wave")
	var enemy_id := _keep_one_enemy(combat_system)
	_check(not enemy_id.is_empty(), "T0147 target enemy missing")
	if enemy_id.is_empty():
		_finish()
		return
	_set_enemy_hp(combat_system, enemy_id, 10000)
	var hit_fixture := _make_enemy_hit_fixture(combat_system, enemy_id)
	await physics_frame

	await _verify_device_release(
		device_system,
		combat_system,
		presenter,
		enemy_id,
		hit_fixture,
		str(ballista_result.get("deployment_id", "")),
		"wall_ballista",
		"crossbow",
		"formal_ballista_muzzle"
	)
	await _verify_device_release(
		device_system,
		combat_system,
		presenter,
		enemy_id,
		hit_fixture,
		str(arrow_result.get("deployment_id", "")),
		"wall_arrow_tower",
		"bow",
		"formal_arrow_tower_muzzle"
	)
	await _verify_evasion_and_range_boundary(
		device_system,
		combat_system,
		enemy_id,
		hit_fixture,
		str(arrow_result.get("deployment_id", ""))
	)
	_verify_attack_speed_scaling(device_system)

	combat_system.debug_clear_enemies()
	if is_instance_valid(hit_fixture):
		hit_fixture.queue_free()
	await process_frame
	_finish()


func _verify_device_release(
	device_system: Node,
	combat_system: Node,
	presenter: Node,
	enemy_id: String,
	hit_fixture: StaticBody3D,
	deployment_id: String,
	device_id: String,
	weapon_type: String,
	expected_origin_source: String
) -> void:
	combat_system._clear_combat_projectiles("verify_t0147_device_start")
	var deployment: Dictionary = device_system.get_deployment(deployment_id)
	var effect: Dictionary = deployment.get("effect", {}) if deployment.get("effect", {}) is Dictionary else {}
	var timing: Dictionary = effect.get("attack_timing", {}) if effect.get("attack_timing", {}) is Dictionary else {}
	var release_seconds := float(timing.get("release_seconds", 0.0))
	var interval := float(effect.get("attack_interval", 0.0))
	_check(release_seconds > 0.0 and release_seconds < interval, "T0147 %s timing is not data-driven" % device_id)
	var projectile_config: Dictionary = effect.get("projectile", {}) if effect.get("projectile", {}) is Dictionary else {}
	_check(str(projectile_config.get("weapon_type", "")) == weapon_type, "T0147 %s projectile kind drifted" % device_id)
	_check(is_equal_approx(float(projectile_config.get("max_range", -1.0)), float(effect.get("range", 0.0))), "T0147 %s range/projectile boundary uses different data" % device_id)

	var origin := _to_vector3(deployment.get("position", {}))
	var target_position := origin + Vector3(4.0, 0.0, 8.0)
	_move_fixture(hit_fixture, target_position)
	await physics_frame
	_set_enemy_position(combat_system, enemy_id, target_position)
	var hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	var before: Dictionary = device_system._advance_auto_attack(
		deployment_id,
		maxf(0.0001, release_seconds - EPSILON_SECONDS),
		combat_system
	)
	_check(int(before.get("attack_count", -1)) == 0, "T0147 %s released during windup: %s" % [device_id, JSON.stringify(before)])
	_check(combat_system.get_active_projectile_snapshots().is_empty(), "T0147 %s created a projectile before release" % device_id)
	_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == hp_before, "T0147 %s damaged before release" % device_id)
	var windup_snapshot: Dictionary = device_system.get_deployment(deployment_id)
	_check(str(windup_snapshot.get("attack_phase", "")) == "windup", "T0147 %s did not retain windup state: before=%s deployment=%s enemy=%s" % [device_id, JSON.stringify(before), JSON.stringify(windup_snapshot), JSON.stringify(combat_system.get_enemy(enemy_id))])
	var view: Node3D = presenter.get_view_for_deployment(deployment_id)
	var model_before: Dictionary = (view.get_debug_snapshot().get("model", {}) as Dictionary) if view != null else {}
	_check(absf(float(model_before.get("yaw_degrees", 0.0))) > 5.0, "T0147 %s rotatable weapon did not face the side target during windup" % device_id)

	var release_step: Dictionary = device_system._advance_auto_attack(deployment_id, EPSILON_SECONDS * 2.0, combat_system)
	var attacks: Array = release_step.get("attacks", []) if release_step.get("attacks", []) is Array else []
	var released: Dictionary = attacks[0] if not attacks.is_empty() and attacks[0] is Dictionary else {}
	var projectiles: Array[Dictionary] = combat_system.get_active_projectile_snapshots()
	_check(projectiles.size() == 1, "T0147 %s did not create exactly one authoritative projectile" % device_id)
	var projectile: Dictionary = projectiles[0] if projectiles.size() == 1 else {}
	_check(str(projectile.get("source_side", "")) == "defense_device", "T0147 %s projectile source is not the deployed device" % device_id)
	_check(str(projectile.get("release_origin_source", "")) == expected_origin_source, "T0147 %s did not use its real model muzzle" % device_id)
	_check(str(projectile.get("attack_id", "")) == str(released.get("attack_id", "")), "T0147 %s timeline/projectile attack_id mismatch" % device_id)
	_check(is_equal_approx(float(projectile.get("max_range", -1.0)), float(effect.get("range", 0.0))), "T0147 %s projectile lost the shared range boundary" % device_id)
	_check(not bool(projectile.get("tracks_target_after_release", true)), "T0147 %s projectile still tracks after release" % device_id)
	_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == hp_before, "T0147 %s dealt release-time damage" % device_id)
	var model_after: Dictionary = (view.get_debug_snapshot().get("model", {}) as Dictionary) if view != null else {}
	_check(int(model_after.get("shot_count", 0)) >= 1, "T0147 %s release did not drive the formal firing animation" % device_id)
	_check(int(model_after.get("active_projectile_count", -1)) == 0, "T0147 %s production path created a presentation-only projectile" % device_id)

	_advance_until_resolved(combat_system)
	var terminal: Dictionary = combat_system.debug_get_combat_snapshot().get("last_projectile_result", {})
	_check(str(terminal.get("status", "")) == "hit", "T0147 %s physical projectile did not hit: %s" % [device_id, JSON.stringify(terminal)])
	_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) < hp_before, "T0147 %s physical hit applied no damage" % device_id)
	var device_resolution: Dictionary = terminal.get("defense_device_resolution", {}) if terminal.get("defense_device_resolution", {}) is Dictionary else {}
	_check(int(device_resolution.get("damage", 0)) > 0, "T0147 %s hit was not returned to DefenseDeviceSystem" % device_id)
	_check(device_system.resolve_defense_device_projectile(terminal).is_empty(), "T0147 %s duplicate projectile fact resolved twice" % device_id)

	var recovery_state: Dictionary = device_system.get_deployment(deployment_id)
	device_system._advance_auto_attack(deployment_id, float(recovery_state.get("attack_cooldown", interval - release_seconds)), combat_system)
	var recovered: Dictionary = device_system.get_deployment(deployment_id)
	_check(str(recovered.get("attack_phase", "")) == "idle", "T0147 %s did not finish recovery on the same timeline" % device_id)


func _verify_evasion_and_range_boundary(
	device_system: Node,
	combat_system: Node,
	enemy_id: String,
	hit_fixture: StaticBody3D,
	deployment_id: String
) -> void:
	combat_system._clear_combat_projectiles("verify_t0147_evasion_start")
	var deployment: Dictionary = device_system.get_deployment(deployment_id)
	var effect: Dictionary = deployment.get("effect", {})
	var timing: Dictionary = effect.get("attack_timing", {})
	var release_seconds := float(timing.get("release_seconds", 0.0))
	var origin := _to_vector3(deployment.get("position", {}))
	var release_target := origin + Vector3(0.0, 0.0, 9.0)
	_move_fixture(hit_fixture, release_target)
	await physics_frame
	_set_enemy_position(combat_system, enemy_id, release_target)
	var hp_before := int(combat_system.get_enemy(enemy_id).get("hp", 0))
	device_system._advance_auto_attack(deployment_id, release_seconds + EPSILON_SECONDS, combat_system)
	_check(combat_system.get_active_projectile_snapshots().size() == 1, "T0147 evasion setup did not release one arrow")
	var moved_position := release_target + Vector3(12.0, 0.0, 0.0)
	_move_fixture(hit_fixture, moved_position)
	await physics_frame
	_set_enemy_position(combat_system, enemy_id, moved_position)
	_advance_until_resolved(combat_system)
	var terminal: Dictionary = combat_system.debug_get_combat_snapshot().get("last_projectile_result", {})
	_check(str(terminal.get("status", "")) != "hit", "T0147 released arrow followed a moving target")
	_check(int(combat_system.get_enemy(enemy_id).get("hp", 0)) == hp_before, "T0147 evaded arrow still applied damage")

	var interval := float(effect.get("attack_interval", 0.0))
	device_system._advance_auto_attack(deployment_id, interval, combat_system)
	combat_system._clear_combat_projectiles("verify_t0147_range_boundary")
	var out_of_range := origin + Vector3(0.0, 0.0, float(effect.get("range", 0.0)) + 0.2)
	_move_fixture(hit_fixture, out_of_range)
	await physics_frame
	_set_enemy_position(combat_system, enemy_id, out_of_range)
	device_system._advance_auto_attack(deployment_id, release_seconds + EPSILON_SECONDS, combat_system)
	_check(combat_system.get_active_projectile_snapshots().is_empty(), "T0147 target beyond shared range still started an attack")


func _verify_attack_speed_scaling(device_system: Node) -> void:
	var definition: Dictionary = device_system.get_device_definition("wall_arrow_tower")
	var slot: Dictionary = device_system.get_slot("wall_slot_02")
	var base_effect: Dictionary = device_system._make_effective_effect(definition, slot)
	var boosted := definition.duplicate(true)
	var boosted_raw: Dictionary = boosted.get("effect", {}).duplicate(true)
	boosted_raw["attack_speed"] = float(boosted_raw.get("attack_speed", 1.0)) * 2.0
	boosted["effect"] = boosted_raw
	var boosted_effect: Dictionary = device_system._make_effective_effect(boosted, slot)
	var base_timing: Dictionary = base_effect.get("attack_timing", {})
	var boosted_timing: Dictionary = boosted_effect.get("attack_timing", {})
	_check(is_equal_approx(float(boosted_effect.get("attack_interval", 0.0)), float(base_effect.get("attack_interval", 0.0)) * 0.5), "T0147 attack-speed boost did not halve the device period")
	_check(is_equal_approx(float(boosted_timing.get("release_seconds", 0.0)), float(base_timing.get("release_seconds", 0.0)) * 0.5), "T0147 attack-speed boost did not scale the release frame")
	_check(is_equal_approx(float(boosted_timing.get("recovery_seconds", 0.0)), float(base_timing.get("recovery_seconds", 0.0)) * 0.5), "T0147 attack-speed boost did not scale recovery")
	_check(is_equal_approx(float(boosted_timing.get("playback_multiplier", 0.0)), float(base_timing.get("playback_multiplier", 0.0)) * 2.0), "T0147 attack-speed boost did not accelerate presentation playback")


func _keep_one_enemy(combat_system: Node) -> String:
	var ids: Array = combat_system.get_active_enemy_ids()
	if ids.is_empty():
		return ""
	var keep := str(ids[0])
	for index in range(1, ids.size()):
		combat_system._remove_enemy_from_combat(str(ids[index]))
	return keep


func _set_enemy_hp(combat_system: Node, enemy_id: String, hp: int) -> void:
	var active: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active.get(enemy_id, {})
	enemy["hp"] = hp
	enemy["max_hp"] = hp
	enemy["alive"] = true
	active[enemy_id] = enemy
	combat_system.set("_active_enemies", active)


func _set_enemy_position(combat_system: Node, enemy_id: String, position: Vector3) -> void:
	var active: Dictionary = combat_system.get("_active_enemies")
	var enemy: Dictionary = active.get(enemy_id, {})
	enemy["position"] = position
	active[enemy_id] = enemy
	combat_system.set("_active_enemies", active)


func _make_enemy_hit_fixture(combat_system: Node, enemy_id: String) -> StaticBody3D:
	var fixture := StaticBody3D.new()
	fixture.name = "T0147EnemyHitFixture"
	fixture.collision_layer = 2
	fixture.collision_mask = 0
	fixture.set_meta("enemy_id", enemy_id)
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	collision.shape = capsule
	collision.position.y = 0.9
	fixture.add_child(collision)
	combat_system.add_child(fixture)
	return fixture


func _move_fixture(fixture: StaticBody3D, position: Vector3) -> void:
	fixture.global_position = position
	fixture.force_update_transform()
	PhysicsServer3D.body_set_state(fixture.get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, fixture.global_transform)


func _advance_until_resolved(combat_system: Node) -> void:
	for _step in range(400):
		if combat_system.get_active_projectile_snapshots().is_empty():
			return
		combat_system.debug_advance_combat_projectiles(PROJECTILE_STEP_SECONDS)


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


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
		print("T0147_DEFENSE_DEVICE_PHYSICAL_ATTACK PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0147_DEFENSE_DEVICE_PHYSICAL_ATTACK FAIL count=%d" % _failures.size())
	quit(1)
