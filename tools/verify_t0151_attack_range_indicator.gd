extends SceneTree

const MAIN_SCENE := preload("res://scenes/main/Main.tscn")
const EPSILON := 0.001

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

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var equipment_system := root.get_node_or_null("Main/Systems/EquipmentSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var presenter := root.get_node_or_null("Main/WorldRoot/Station/DefenseDevices")
	var indicator := root.get_node_or_null("Main/WorldRoot/Station/Effects/AttackRangeIndicator")
	_check(npc_system != null and combat_system != null and equipment_system != null, "T0151 NPC range dependencies missing")
	_check(device_system != null and resource_system != null and building_system != null, "T0151 defense range dependencies missing")
	_check(presenter != null and indicator != null, "T0151 production presentation nodes missing")
	if not _failures.is_empty():
		_finish()
		return

	var npc_id := "stableman_01"
	var bow: Dictionary = equipment_system.get_weapon_def("bow")
	var crossbow: Dictionary = equipment_system.get_weapon_def("crossbow")
	var sword: Dictionary = equipment_system.get_weapon_def("sword_shield")
	_check(not bow.is_empty() and not crossbow.is_empty() and not sword.is_empty(), "T0151 weapon definitions missing")
	npc_system.set_npc_equipment_slot(npc_id, "main_weapon", bow)
	npc_system.update_npc_state(npc_id, {
		"behavior_mode": "rally",
		"combat_mode": "rally",
		"hp": 100,
		"max_hp": 100,
		"unconscious": false,
		"escaped": false
	})
	npc_system.debug_select_npc(npc_id)
	await process_frame
	_verify_npc_ring(indicator, combat_system, npc_system, npc_id, "bow")

	var npc_actor := root.get_node_or_null("Main/WorldRoot/Station/NPCs/Stableman01") as Node3D
	_check(npc_actor != null, "T0151 selected NPC actor missing")
	if npc_actor != null:
		npc_actor.global_position += Vector3(2.5, 0.0, -1.75)
		await process_frame
		var moved_snapshot: Dictionary = indicator.get_debug_snapshot()
		var indicator_position: Vector3 = moved_snapshot.get("world_position", Vector3.ZERO)
		_check(Vector2(indicator_position.x, indicator_position.z).distance_to(Vector2(npc_actor.global_position.x, npc_actor.global_position.z)) <= EPSILON, "T0151 ring did not follow selected NPC")

	npc_system.update_npc_state(npc_id, {"behavior_mode": "work", "combat_mode": ""})
	await process_frame
	_check(not bool(indicator.get_debug_snapshot().get("visible", true)), "T0151 work-mode NPC kept the range ring")

	npc_system.set_npc_equipment_slot(npc_id, "main_weapon", crossbow)
	npc_system.update_npc_state(npc_id, {"behavior_mode": "combat", "combat_mode": "combat"})
	await process_frame
	_verify_npc_ring(indicator, combat_system, npc_system, npc_id, "crossbow")

	npc_system.set_npc_equipment_slot(npc_id, "main_weapon", sword)
	await process_frame
	_check(not bool(indicator.get_debug_snapshot().get("visible", true)), "T0151 melee NPC kept the range ring")

	npc_system.set_npc_equipment_slot(npc_id, "main_weapon", bow)
	npc_system.update_npc_state(npc_id, {"unconscious": true})
	await process_frame
	_check(not bool(indicator.get_debug_snapshot().get("visible", true)), "T0151 unconscious NPC kept the range ring")
	npc_system.update_npc_state(npc_id, {"unconscious": false, "behavior_mode": "combat", "combat_mode": "combat"})

	_set_building_level(building_system, "wall", 2)
	resource_system.add_resource("item_wall_ballista", 1)
	resource_system.add_resource("item_wall_arrow_tower", 1)
	var ballista_result: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	var arrow_result: Dictionary = device_system.deploy_device("wall_arrow_tower", "wall_slot_02")
	_check(bool(ballista_result.get("ok", false)) and bool(arrow_result.get("ok", false)), "T0151 defense deployment failed")
	await process_frame

	var ballista_id := str(ballista_result.get("deployment_id", ""))
	var ballista_view: Node = presenter.get_view_for_deployment(ballista_id)
	_check(ballista_view != null and ballista_view.has_method("debug_emit_clicked"), "T0151 deployed device is not clickable")
	if ballista_view != null:
		_check(bool(ballista_view.debug_emit_clicked()), "T0151 device click event was not emitted")
	await process_frame
	_verify_device_ring(indicator, device_system, ballista_id, "wall_ballista")

	var arrow_id := str(arrow_result.get("deployment_id", ""))
	indicator.debug_select_defense_device(arrow_id)
	await process_frame
	_verify_device_ring(indicator, device_system, arrow_id, "wall_arrow_tower")

	device_system.apply_damage_to_device(arrow_id, 99999, {"attacker_id": "verify_t0151"})
	await process_frame
	_check(not bool(indicator.get_debug_snapshot().get("visible", true)), "T0151 destroyed defense device left a range ring")

	indicator.debug_select_npc(npc_id)
	await process_frame
	var event_bus := root.get_node_or_null("EventBus")
	if event_bus != null:
		event_bus.world_selection_cleared.emit()
	await process_frame
	var cleared: Dictionary = indicator.get_debug_snapshot()
	_check(not bool(cleared.get("visible", true)) and str(cleared.get("selection_id", "")).is_empty(), "T0151 clear selection left a stale ring")

	_finish()


func _verify_npc_ring(indicator: Node, combat_system: Node, npc_system: Node, npc_id: String, weapon_id: String) -> void:
	var authority: Dictionary = combat_system.get_npc_attack_range_indicator_snapshot(npc_id)
	var displayed: Dictionary = indicator.get_debug_snapshot()
	_check(bool(authority.get("ready", false)), "T0151 %s NPC authority snapshot not ready" % weapon_id)
	_check(bool(displayed.get("visible", false)), "T0151 %s NPC ring not visible" % weapon_id)
	_check(str(displayed.get("selection_type", "")) == "npc" and str(displayed.get("selection_id", "")) == npc_id, "T0151 NPC selection identity drifted")
	_check(is_equal_approx(float(displayed.get("displayed_range", -1.0)), float(authority.get("effective_range", 0.0))), "T0151 %s NPC ring copied the wrong range" % weapon_id)
	_check(str(authority.get("range_authority", "")) == "combat_system.final.range", "T0151 NPC ring did not use CombatSystem authority")
	_check(str(authority.get("range_semantics", "")) == "maximum_attack_initiation_ballistic_distance", "T0151 NPC ballistic range semantics missing")
	_verify_ring_geometry(indicator, float(authority.get("effective_range", 0.0)))
	var npc_position: Vector3 = npc_system.get_npc_world_position(npc_id)
	var ring_position: Vector3 = displayed.get("world_position", Vector3.ZERO)
	_check(Vector2(npc_position.x, npc_position.z).distance_to(Vector2(ring_position.x, ring_position.z)) <= EPSILON, "T0151 NPC ring center drifted")


func _verify_device_ring(indicator: Node, device_system: Node, deployment_id: String, device_id: String) -> void:
	var authority: Dictionary = device_system.get_attack_range_indicator_snapshot(deployment_id)
	var displayed: Dictionary = indicator.get_debug_snapshot()
	_check(bool(authority.get("ready", false)), "T0151 %s authority snapshot not ready" % device_id)
	_check(bool(displayed.get("visible", false)), "T0151 %s ring not visible" % device_id)
	_check(str(displayed.get("selection_type", "")) == "defense_device" and str(displayed.get("selection_id", "")) == deployment_id, "T0151 defense selection identity drifted")
	_check(is_equal_approx(float(displayed.get("displayed_range", -1.0)), float(authority.get("effective_range", 0.0))), "T0151 %s ring ignored effective host range" % device_id)
	_check(str(authority.get("range_authority", "")) == "defense_device_system.effect.range", "T0151 defense ring did not use DefenseDeviceSystem authority")
	_verify_ring_geometry(indicator, float(authority.get("effective_range", 0.0)))


func _verify_ring_geometry(indicator: Node, radius: float) -> void:
	var ring_mesh := indicator.get_node_or_null("RangeRingMesh") as MeshInstance3D
	_check(ring_mesh != null and ring_mesh.mesh != null, "T0151 procedural ring mesh missing")
	if ring_mesh == null or ring_mesh.mesh == null:
		return
	var bounds := ring_mesh.mesh.get_aabb()
	_check(absf(bounds.size.x - radius * 2.0) <= 0.02 and absf(bounds.size.z - radius * 2.0) <= 0.02, "T0151 ring mesh radius does not match authority")
	_check(indicator.find_children("*", "CollisionObject3D", true, false).is_empty(), "T0151 range ring introduced collision")
	var snapshot: Dictionary = indicator.get_debug_snapshot()
	var color: Color = snapshot.get("color", Color.WHITE)
	_check(color.b > color.r and color.b > color.g * 0.95 and color.a > 0.0 and color.a < 0.6, "T0151 ring is not pale-blue translucent")


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _finish() -> void:
	if _failures.is_empty():
		print("T0151_ATTACK_RANGE_INDICATOR_OK")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	quit(1)
