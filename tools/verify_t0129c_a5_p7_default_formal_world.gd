extends SceneTree

const NPC_ID := "gardener_01"
const ACTION_ID := "work_garden"


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	root.add_child(packed.instantiate())
	await process_frame
	await physics_frame
	await physics_frame

	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var merchant_system := root.get_node_or_null("Main/Systems/MerchantSystem")
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if [controller, npc_system, action_system, merchant_system, combat_system, time_system].has(null):
		_fail("A5-P7 runtime dependencies unavailable")
		return

	var layout: Dictionary = controller.get_validation_snapshot()
	var residents: Dictionary = npc_system.get_default_formal_world_snapshot()
	if (
		str(layout.get("migration_phase", "")) != "a5_p7_default_formal_world"
		or not bool(layout.get("formal_layout_active", false))
		or not bool(layout.get("default_formal_world_enabled", false))
		or not bool(layout.get("preview_enabled", false))
		or not bool(layout.get("navigation_enabled", false))
		or not bool(residents.get("active", false))
		or int(residents.get("actor_count", 0)) != 8
	):
		_fail("New game did not boot directly into the formal world: %s / %s" % [JSON.stringify(layout), JSON.stringify(residents)])
		return
	var unique_positions := {}
	for raw_actor in residents.get("actors", []):
		var actor := raw_actor as Dictionary
		var position := actor.get("world_position", Vector3.ZERO) as Vector3
		if (
			absf(position.x) > 80.0
			or absf(position.z) > 100.0
			or not bool(actor.get("navigation_motion_enabled", false))
			or not bool(actor.get("navigation_map_matches", false))
			or str(actor.get("physical_location_phase", "")) != "formal_world_resident"
		):
			_fail("Default resident lacks formal position or navigation authority: %s" % JSON.stringify(actor))
			return
		unique_positions[Vector2(position.x, position.z)] = true
	if unique_positions.size() != 8:
		_fail("Default residents collapsed onto duplicate spawn anchors")
		return

	var market: Dictionary = merchant_system.get_market_snapshot()
	if str(market.get("route_mode", "")) != "formal_rear_trade_default" or int(market.get("route_point_count", 0)) != 6:
		_fail("Merchant did not inherit the default formal rear route: %s" % JSON.stringify(market))
		return
	var escape_route: Dictionary = combat_system._get_escape_route_contract(NPC_ID, npc_system)
	var escape_exit: Vector3 = combat_system._get_escape_exit_position(NPC_ID, npc_system)
	if (
		str(escape_route.get("route_source", "")) != "formal_station_layout"
		or (escape_route.get("path_points", []) as Array).size() != 6
		or absf(escape_exit.x) > 100.0
		or absf(escape_exit.z) < 200.0
	):
		_fail("A non-combat default resident did not inherit the formal map-edge escape route")
		return

	time_system.set_paused(false)
	var actor_node := _get_npc_node(npc_system, NPC_ID)
	if actor_node == null:
		_fail("Garden resident body unavailable")
		return
	actor_node.set("move_speed", 5.0)
	var spawn_position: Vector3 = actor_node.global_position
	if not action_system.debug_assign_action(NPC_ID, ACTION_ID):
		_fail("Default resident garden assignment failed")
		return
	if actor_node.global_position.distance_to(spawn_position) > 0.1:
		_fail("Starting a formal action teleported the default resident")
		return
	if not await _wait_for_active(action_system, time_system):
		_fail("Default resident did not physically reach garden_plot_01: %s" % JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID)))
		return
	var workstation_position: Vector3 = actor_node.global_position
	if workstation_position.distance_to(spawn_position) < 5.0:
		_fail("Garden work became active without a meaningful physical route")
		return
	if not action_system.interrupt_npc_action(NPC_ID, "a5_p7_verify_stop", true):
		_fail("Could not stop default resident garden work")
		return
	await process_frame
	var stopped_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if (
		actor_node.global_position.distance_to(workstation_position) > 0.5
		or str(stopped_state.get("physical_location_phase", "")) != "formal_location_interior"
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or not bool(npc_system.get_default_formal_world_snapshot().get("active", false))
	):
		_fail("Action cleanup returned the resident to compatibility coordinates: %s" % JSON.stringify(stopped_state))
		return

	var pre_combat_position: Vector3 = actor_node.global_position
	var combat_start: Dictionary = npc_system.begin_formal_combat_world([NPC_ID] as Array[String])
	if not bool(combat_start.get("ok", false)) or actor_node.global_position.distance_to(pre_combat_position) > 0.1:
		_fail("Combat takeover teleported the default formal resident")
		return
	var combat_end: Dictionary = npc_system.end_formal_combat_world("a5_p7_verify")
	if (
		not bool(combat_end.get("ok", false))
		or actor_node.global_position.distance_to(pre_combat_position) > 0.1
		or str(npc_system.get_npc_state(NPC_ID).get("physical_location_phase", "")) != "formal_world_resident"
	):
		_fail("Combat cleanup did not retain the resident's formal position")
		return

	var legacy: Dictionary = controller.debug_set_legacy_compatibility_enabled(true)
	if (
		not bool(legacy.get("legacy_compatibility_override", false))
		or bool(npc_system.get_default_formal_world_snapshot().get("active", true))
		or str(merchant_system.get_market_snapshot().get("route_mode", "")) != "legacy_world_compatibility"
	):
		_fail("Explicit legacy compatibility did not suspend formal ownership")
		return
	var restored: Dictionary = controller.debug_set_legacy_compatibility_enabled(false)
	var restored_residents: Dictionary = npc_system.get_default_formal_world_snapshot()
	if (
		bool(restored.get("legacy_compatibility_override", true))
		or not bool(restored_residents.get("active", false))
		or int(restored_residents.get("actor_count", 0)) != 8
		or str(merchant_system.get_market_snapshot().get("route_mode", "")) != "formal_rear_trade_default"
		or absf(actor_node.global_position.x) > 80.0
		or absf(actor_node.global_position.z) > 100.0
	):
		_fail("Restoring the default formal world did not resume all spatial consumers")
		return

	print("T0129C A5-P7 default formal world verification passed")
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node3D:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath(""))) as Node3D


func _wait_for_active(action_system: Node, time_system: Node, max_frames: int = 1800) -> bool:
	for _frame in range(max_frames):
		time_system.set_paused(false)
		await physics_frame
		var runtime: Dictionary = action_system.get_runtime_action_snapshot(NPC_ID)
		if str(runtime.get("phase", "")) == "active" and str(runtime.get("action_id", "")) == ACTION_ID:
			return true
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
