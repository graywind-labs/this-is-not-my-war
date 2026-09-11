extends SceneTree

const CHECKPOINT_PATH := "user://verify_t0129c_a5_p8_formal_spatial_save.json"
const NPC_ID := "gardener_01"


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
	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var merchant_system := root.get_node_or_null("Main/Systems/MerchantSystem")
	var save_system := root.get_node_or_null("Main/Systems/SpatialSaveSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	if [controller, npc_system, action_system, combat_system, merchant_system, save_system, time_system].has(null):
		_fail("A5-P8 dependencies unavailable")
		return
	time_system.set_paused(false)
	var npc_node := _get_npc_node(npc_system, NPC_ID)
	if npc_node == null:
		_fail("formal NPC body unavailable")
		return

	# In-flight work is intentionally rolled back at its saved safe coordinate.
	if not action_system.debug_assign_action(NPC_ID, "work_garden"):
		_fail("could not start pending formal work")
		return
	await physics_frame
	var pending_saved_position: Vector3 = npc_node.global_position
	var pending_save: Dictionary = save_system.save_formal_spatial_checkpoint(CHECKPOINT_PATH)
	if not bool(pending_save.get("ok", false)):
		_fail("pending action checkpoint save failed: %s" % JSON.stringify(pending_save))
		return
	npc_node.global_position += Vector3(18.0, 0.0, 0.0)
	var pending_load: Dictionary = save_system.load_formal_spatial_checkpoint(CHECKPOINT_PATH)
	if (
		not bool(pending_load.get("ok", false))
		or action_system.has_active_action(NPC_ID)
		or bool(npc_system.get_formal_workstation_action_snapshot(NPC_ID).get("active", true))
		or npc_node.global_position.distance_to(pending_saved_position) > 0.6
	):
		_fail("in-flight action did not roll back safely: %s" % JSON.stringify(pending_load))
		return

	# One checkpoint simultaneously carries a live wave, a travelling merchant and
	# a map-edge escape. Each consumer rebuilds its own runtime authority.
	var wave_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(wave_result.get("ok", false)):
		_fail("could not start formal wave: %s" % JSON.stringify(wave_result))
		return
	var merchant_start: Dictionary = merchant_system.debug_force_wagon_arrival()
	if str(merchant_start.get("wagon_state", "")) != "arriving":
		_fail("merchant did not enter arriving phase")
		return
	var escape_start: Dictionary = combat_system.debug_start_npc_escape(NPC_ID, "a5_p8_verify")
	if not bool(escape_start.get("ok", false)):
		_fail("could not start formal escape: %s" % JSON.stringify(escape_start))
		return
	for _frame in range(8):
		await physics_frame
	var saved_npc_position: Vector3 = npc_node.global_position
	var saved_combat: Dictionary = combat_system.create_formal_spatial_checkpoint()
	var saved_merchant: Dictionary = merchant_system.create_formal_spatial_checkpoint()
	var combined_save: Dictionary = save_system.save_formal_spatial_checkpoint(CHECKPOINT_PATH)
	if (
		not bool(combined_save.get("ok", false))
		or int(saved_combat.get("enemy_count", 0)) != 8
		or str(saved_merchant.get("wagon_state", "")) != "arriving"
	):
		_fail("combined spatial checkpoint save failed: %s" % JSON.stringify(combined_save))
		return

	# Destroy and recreate Main to prove the checkpoint does not depend on old
	# NodePaths or RIDs and waits for the newly built production authority.
	var old_main := root.get_node_or_null("Main")
	old_main.queue_free()
	await process_frame
	await process_frame
	root.add_child(packed.instantiate())
	await process_frame
	await physics_frame
	await physics_frame
	controller = root.get_node_or_null("Main/Presentation/StationLayoutController")
	npc_system = root.get_node_or_null("Main/Systems/NPCSystem")
	action_system = root.get_node_or_null("Main/Systems/ActionSystem")
	combat_system = root.get_node_or_null("Main/Systems/CombatSystem")
	merchant_system = root.get_node_or_null("Main/Systems/MerchantSystem")
	save_system = root.get_node_or_null("Main/Systems/SpatialSaveSystem")
	time_system = root.get_node_or_null("Main/Systems/TimeSystem")
	if [controller, npc_system, action_system, combat_system, merchant_system, save_system, time_system].has(null):
		_fail("A5-P8 fresh Main dependencies unavailable")
		return
	npc_node = _get_npc_node(npc_system, NPC_ID)
	if npc_node == null:
		_fail("fresh Main formal NPC body unavailable")
		return
	var combined_load: Dictionary = save_system.load_formal_spatial_checkpoint(CHECKPOINT_PATH)
	if not bool(combined_load.get("ok", false)):
		_fail("combined spatial checkpoint load failed: %s" % JSON.stringify(combined_load))
		return
	var restored_combat: Dictionary = combat_system.create_formal_spatial_checkpoint()
	var restored_market: Dictionary = merchant_system.get_market_snapshot()
	var restored_escape: Dictionary = combat_system.get_escape_intervention_state(NPC_ID)
	if (
		int(restored_combat.get("enemy_count", 0)) != 8
		or int(restored_combat.get("wave_number", 0)) != 1
		or str(restored_market.get("wagon_state", "")) != "arriving"
		or str(restored_market.get("route_mode", "")) != "formal_rear_trade_default"
		or not bool(restored_escape.get("escaping", false))
		or npc_node.global_position.distance_to(saved_npc_position) > 0.8
		or npc_node.global_position == Vector3.ZERO
	):
		_fail("one or more spatial authorities were not restored: %s / %s / %s" % [JSON.stringify(restored_combat), JSON.stringify(restored_market), JSON.stringify(restored_escape)])
		return
	var npc_result: Dictionary = combined_load.get("npc_result", {})
	if (
		int(npc_result.get("duplicate_location_or_action_events", -1)) != 0
		or not (npc_result.get("fallback_npc_ids", []) as Array).is_empty()
	):
		_fail("restore created duplicate facts or used unsafe position fallback: %s" % JSON.stringify(npc_result))
		return

	print("T0129C A5-P8 formal spatial save verification passed")
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node3D:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath(""))) as Node3D


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
