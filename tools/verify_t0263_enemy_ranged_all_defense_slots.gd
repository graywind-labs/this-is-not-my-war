extends SceneTree


const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const VALID_SLOT_IDS := [
	"wall_slot_01",
	"wall_slot_02",
	"wall_slot_03",
	"wall_slot_04",
	"main_hall_slot_01",
	"main_hall_slot_02",
	"main_hall_slot_03",
	"main_hall_slot_04",
]
const ITEM_BY_DEVICE := {
	"wall_arrow_tower": "item_wall_arrow_tower",
	"wall_ballista": "item_wall_ballista",
}

var _failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_verification")


func _run_verification() -> void:
	var slot_id := OS.get_environment("T0263_SLOT_ID")
	var device_id := OS.get_environment("T0263_DEVICE_ID")
	_check(VALID_SLOT_IDS.has(slot_id), "T0263 invalid or missing slot id: %s" % slot_id)
	_check(ITEM_BY_DEVICE.has(device_id), "T0263 invalid or missing device id: %s" % device_id)
	if not _failures.is_empty():
		_finish(slot_id, device_id)
		return

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
	_check(combat != null and npc_system != null and device_system != null, "T0263 combat dependencies missing")
	_check(resource_system != null and building_system != null and presenter != null, "T0263 world dependencies missing")
	if not _failures.is_empty():
		_finish(slot_id, device_id)
		return

	_set_building_level(building_system, "wall", 6)
	_set_building_level(building_system, "main_hall", 6)
	for index in range(npc_system.get_npc_ids().size()):
		var npc_id := str(npc_system.get_npc_ids()[index])
		var npc_node := root.get_node_or_null(npc_system._npc_nodes.get(npc_id, NodePath())) as Node3D
		if npc_node != null:
			npc_node.global_position = Vector3(-70.0 + float(index), 0.04, -65.0)

	resource_system.add_resource(str(ITEM_BY_DEVICE[device_id]), 1)
	var deployment_result: Dictionary = device_system.deploy_device(device_id, slot_id)
	_check(bool(deployment_result.get("ok", false)), "T0263 deployment failed: %s" % deployment_result)
	if not _failures.is_empty():
		_finish(slot_id, device_id)
		return
	var deployment_id := str(deployment_result.get("deployment_id", ""))
	await process_frame
	await physics_frame

	var view := presenter.get_view_for_deployment(deployment_id) as Node3D
	var hit_area := view.get_node_or_null("InteractionArea") as Area3D if view != null else null
	var hit_shape := hit_area.get_node_or_null("CollisionShape3D") as CollisionShape3D if hit_area != null else null
	_check(hit_area != null and hit_shape != null and not hit_shape.disabled, "T0263 active projectile hit shape missing")
	if not _failures.is_empty():
		_finish(slot_id, device_id)
		return
	var hit_center := hit_shape.global_position

	var spawned: Dictionary = combat.debug_run_formal_dynamic_wave_slice(3, true)
	_check(bool(spawned.get("ok", false)), "T0263 formal third wave failed: %s" % spawned)
	var archer_id := ""
	for raw_enemy_id in combat.get_active_enemy_ids():
		var candidate_id := str(raw_enemy_id)
		if str(combat.get_enemy(candidate_id).get("weapon_type", "")) == "bow":
			archer_id = candidate_id
			break
	_check(not archer_id.is_empty(), "T0263 formal archer missing")
	if not _failures.is_empty():
		_finish(slot_id, device_id)
		return
	for raw_enemy_id in combat.get_active_enemy_ids().duplicate():
		var enemy_id := str(raw_enemy_id)
		if enemy_id != archer_id:
			combat._remove_enemy_from_combat(enemy_id)

	var enemy: Dictionary = combat.get_enemy(archer_id)
	var target: Dictionary = combat._make_defense_device_enemy_target(deployment_id, enemy.get("position", Vector3.ZERO))
	_check(not target.is_empty(), "T0263 production device target missing")
	var actor := root.get_node_or_null(combat._formal_first_wave_node_paths.get(archer_id, NodePath())) as Node3D
	_check(actor != null, "T0263 formal archer actor missing")
	if not _failures.is_empty():
		_finish(slot_id, device_id)
		return

	var outward: Vector3 = target.get("host_proxy_outward_direction", target.get("facing_direction", Vector3.FORWARD))
	outward.y = 0.0
	outward = outward.normalized() if outward.length_squared() > 0.0001 else Vector3.FORWARD
	# The north-east main-hall proxy faces the clinic. A projectile from that
	# deliberately obstructed lane is correctly blocked by the clinic, so use
	# the open east flank to isolate this matrix's aim/hit-area contract.
	if slot_id == "main_hall_slot_02":
		outward = Vector3.RIGHT
	var proxy_position: Vector3 = target.get("position", hit_center)
	actor.global_position = Vector3(proxy_position.x, actor.global_position.y, proxy_position.z) + outward * 8.0
	enemy["position"] = actor.global_position
	combat._cancel_enemy_attack_timeline(enemy)
	enemy["target"] = {}
	combat._active_enemies[archer_id] = enemy
	combat._release_enemy_attack_position(archer_id, "t0263_case_start", false, false)
	combat._refresh_enemy_node(archer_id)
	await process_frame
	await physics_frame

	var host_building_id := str(device_system.get_slot(slot_id).get("building_id", ""))
	var hp_before := int(device_system.get_deployment(deployment_id).get("hp", 0))
	var host_hp_before := int(building_system.get_building(host_building_id).get("hp", 0))
	var target_selected := false
	var projectile_released := false
	var observed_release: Dictionary = {}
	var damage_step := -1
	for step_index in range(80):
		combat.debug_step_enemy_ai(0.1)
		var current_enemy: Dictionary = combat.get_enemy(archer_id)
		var current_target: Dictionary = current_enemy.get("target", {}) if current_enemy.get("target", {}) is Dictionary else {}
		if str(current_target.get("id", "")) == deployment_id:
			target_selected = true
		for projectile_snapshot in combat.get_active_projectile_snapshots():
			var released_target: Dictionary = projectile_snapshot.get("target_at_release", {}) if projectile_snapshot.get("target_at_release", {}) is Dictionary else {}
			if str(projectile_snapshot.get("source_id", "")) == archer_id and str(released_target.get("id", "")) == deployment_id:
				projectile_released = true
				observed_release = projectile_snapshot.duplicate(true)
		combat.debug_advance_combat_projectiles(0.1)
		if int(device_system.get_deployment(deployment_id).get("hp", 0)) < hp_before:
			damage_step = step_index
			break
	if projectile_released and damage_step < 0:
		combat.debug_advance_combat_projectiles(3.0)
		if int(device_system.get_deployment(deployment_id).get("hp", 0)) < hp_before:
			damage_step = 80

	var hp_after := int(device_system.get_deployment(deployment_id).get("hp", 0))
	var host_hp_after := int(building_system.get_building(host_building_id).get("hp", 0))
	var terminal: Dictionary = combat.debug_get_combat_snapshot().get("last_projectile_result", {})
	var hit_fact: Dictionary = terminal.get("hit_fact", {}) if terminal.get("hit_fact", {}) is Dictionary else {}
	var aim_position: Vector3 = terminal.get("aim_position_at_release", observed_release.get("aim_position_at_release", Vector3.ZERO))
	var diagnostics := {
		"slot_id": slot_id,
		"device_id": device_id,
		"deployment_id": deployment_id,
		"host_building_id": host_building_id,
		"target_selected": target_selected,
		"projectile_released": projectile_released,
		"damage_step": damage_step,
		"hit_area_center": hit_center,
		"aim_position_at_release": aim_position,
		"aim_distance_to_hit_center": aim_position.distance_to(hit_center),
		"aim_target_source": str(terminal.get("aim_target_source", observed_release.get("aim_target_source", ""))),
		"projectile_status": str(terminal.get("status", "")),
		"projectile_reason": str(hit_fact.get("reason", "")),
		"release_position": terminal.get("release_position", observed_release.get("release_position", Vector3.ZERO)),
		"release_velocity": terminal.get("velocity", observed_release.get("velocity", Vector3.ZERO)),
		"enemy_position": actor.global_position,
		"collision_position": terminal.get("collision_position", Vector3.ZERO),
		"collision_identity": hit_fact.get("collision_identity", {}),
		"actual_target_type": str(hit_fact.get("actual_target_type", "")),
		"actual_target_id": str(hit_fact.get("actual_target_id", "")),
		"device_hp_before": hp_before,
		"device_hp_after": hp_after,
		"host_hp_before": host_hp_before,
		"host_hp_after": host_hp_after,
	}
	print("T0263_CASE_DIAGNOSTICS=%s" % JSON.stringify(diagnostics))
	_check(target_selected, "T0263 natural selector did not choose deployment: %s" % diagnostics)
	_check(projectile_released, "T0263 natural timeline did not release at deployment: %s" % diagnostics)
	_check(aim_position.distance_to(hit_center) <= 0.05, "T0263 aim does not match actual hit center: %s" % diagnostics)
	_check(str(diagnostics.get("aim_target_source", "")) == "defense_device_hit_area_center", "T0263 did not use the live device hit area: %s" % diagnostics)
	_check(str(hit_fact.get("actual_target_type", "")) == "defense_device", "T0263 projectile hit wrong target type: %s" % diagnostics)
	_check(str(hit_fact.get("actual_target_id", "")) == deployment_id, "T0263 projectile hit wrong deployment: %s" % diagnostics)
	_check(hp_after < hp_before, "T0263 projectile did not reduce device HP: %s" % diagnostics)
	_check(host_hp_after == host_hp_before, "T0263 projectile also damaged host building: %s" % diagnostics)
	combat.clear_spawned_enemies()
	_finish(slot_id, device_id)


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish(slot_id: String, device_id: String) -> void:
	if _failures.is_empty():
		print("T0263_CASE_OK %s %s" % [slot_id, device_id])
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
