extends SceneTree

const HEALTHY_COLOR := Color("#71865a")
const DANGER_COLOR := Color("#a7433b")


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Main.tscn failed to load.")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	for _index in range(6):
		await process_frame

	var combat_system := root.get_node_or_null("Main/Systems/CombatSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var device_system := root.get_node_or_null("Main/Systems/DefenseDeviceSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var layout_controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	var device_presenter := root.get_node_or_null("Main/WorldRoot/Station/DefenseDevices")
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if [combat_system, building_system, npc_system, device_system, resource_system, layout_controller, device_presenter, npc_root].has(null):
		_fail("T0280 required runtime nodes are missing.")
		return

	var npc := _find_npc_view(npc_root)
	if npc == null or not npc.has_method("debug_get_overhead_ui_snapshot"):
		_fail("No NPC world view exposes the T0280 overhead snapshot.")
		return
	var npc_id := str(npc.get_meta("npc_id", ""))
	var peaceful_npc: Dictionary = npc.debug_get_overhead_ui_snapshot()
	if not _verify_npc_label_contract(peaceful_npc):
		return
	if bool((peaceful_npc.get("health_bar", {}) as Dictionary).get("local_visible", true)):
		_fail("NPC health bar must be hidden outside combat.")
		return
	if not _verify_friendly_overhead_heights(peaceful_npc):
		return

	var peaceful_buildings: Dictionary = layout_controller.debug_get_strategic_building_health_bar_snapshot()
	if not _verify_strategic_building_set(peaceful_buildings, false):
		return

	resource_system.add_resource("item_wall_ballista", 1)
	_set_building_level(building_system, "wall", 1)
	var deploy_result: Dictionary = device_system.deploy_device("wall_ballista", "wall_slot_01")
	if not bool(deploy_result.get("ok", false)):
		_fail("Could not deploy a defense device for T0280 verification: %s" % deploy_result)
		return
	var deployment_id := str(deploy_result.get("deployment_id", ""))
	await process_frame
	await process_frame
	var device_view: Node = device_presenter.get_view_for_deployment(deployment_id)
	if device_view == null:
		_fail("Deployed defense device world view is missing.")
		return
	var peaceful_device: Dictionary = device_view.get_debug_snapshot().get("overhead_ui", {})
	if str(peaceful_device.get("name_text", "")) != "弩床":
		_fail("Defense device overhead must contain its name only: %s" % peaceful_device)
		return
	var peaceful_device_text := str(peaceful_device.get("name_text", ""))
	if peaceful_device_text.contains("HP") or peaceful_device_text.contains("射程"):
		_fail("Defense device overhead leaked textual HP or range.")
		return
	if bool((peaceful_device.get("health_bar", {}) as Dictionary).get("local_visible", true)):
		_fail("Defense device health bar must be hidden outside combat.")
		return

	var spawn_result: Dictionary = combat_system.debug_spawn_wave(1, true)
	if not bool(spawn_result.get("ok", false)):
		_fail("Could not spawn enemies for T0280 wartime verification: %s" % spawn_result)
		return
	for _index in range(4):
		await process_frame

	var wartime_npc: Dictionary = npc.debug_get_overhead_ui_snapshot()
	if not _verify_healthy_bar(wartime_npc.get("health_bar", {}), "NPC"):
		return
	if not _verify_strategic_building_set(layout_controller.debug_get_strategic_building_health_bar_snapshot(), true):
		return
	var wartime_device: Dictionary = device_view.get_debug_snapshot().get("overhead_ui", {})
	if not _verify_healthy_bar(wartime_device.get("health_bar", {}), "defense device"):
		return

	var npc_state: Dictionary = npc_system.get_npc_state(npc_id)
	var npc_hp := int(npc_state.get("hp", 1))
	var npc_max_hp := maxi(1, int(npc_state.get("max_hp", npc_hp)))
	npc_system.apply_damage_to_npc(npc_id, maxi(1, npc_hp - maxi(1, int(floor(npc_max_hp * 0.2)))))
	var warehouse: Dictionary = building_system.get_building("warehouse")
	var warehouse_hp := int(warehouse.get("hp", 1))
	var warehouse_max_hp := maxi(1, int(warehouse.get("max_hp", warehouse_hp)))
	building_system.apply_damage_to_building("warehouse", maxi(1, warehouse_hp - maxi(1, int(floor(warehouse_max_hp * 0.2)))))
	var deployment: Dictionary = device_system.get_deployment(deployment_id)
	var device_hp := int(deployment.get("hp", 1))
	var device_max_hp := maxi(1, int(deployment.get("max_hp", device_hp)))
	device_system.apply_damage_to_device(deployment_id, maxi(1, device_hp - maxi(1, int(floor(device_max_hp * 0.2)))))
	for _index in range(3):
		await process_frame

	if not _verify_danger_bar((npc.debug_get_overhead_ui_snapshot().get("health_bar", {})), "NPC"):
		return
	var damaged_buildings: Dictionary = layout_controller.debug_get_strategic_building_health_bar_snapshot()
	if not _verify_danger_bar((damaged_buildings.get("warehouse", {})), "warehouse"):
		return
	device_view = device_presenter.get_view_for_deployment(deployment_id)
	var damaged_device: Dictionary = device_view.get_debug_snapshot().get("overhead_ui", {})
	if not _verify_danger_bar(damaged_device.get("health_bar", {}), "defense device"):
		return

	combat_system.debug_clear_enemies()
	for _index in range(4):
		await process_frame
	if bool(((npc.debug_get_overhead_ui_snapshot().get("health_bar", {})) as Dictionary).get("local_visible", true)):
		_fail("NPC health bar did not hide after enemies were cleared.")
		return
	if not _verify_strategic_building_set(layout_controller.debug_get_strategic_building_health_bar_snapshot(), false):
		return
	device_view = device_presenter.get_view_for_deployment(deployment_id)
	var cleared_device: Dictionary = device_view.get_debug_snapshot().get("overhead_ui", {})
	if bool((cleared_device.get("health_bar", {}) as Dictionary).get("local_visible", true)):
		_fail("Defense device health bar did not hide after enemies were cleared.")
		return

	var llm_bridge := root.get_node_or_null("Main/Systems/LLMBridge")
	if llm_bridge != null and llm_bridge.has_method("_shutdown_async_requests"):
		llm_bridge._shutdown_async_requests()
		await process_frame
	print("T0280 world combat health bars verification passed.")
	quit(0)


func _find_npc_view(npc_root: Node) -> Node:
	for child in npc_root.get_children():
		if child.has_method("debug_get_overhead_ui_snapshot"):
			return child
	return null


func _verify_npc_label_contract(snapshot: Dictionary) -> bool:
	var action_text := str(snapshot.get("action_text", ""))
	if action_text.contains("HP"):
		return _fail("NPC action label still contains textual HP: %s" % action_text)
	var name_position: Vector3 = snapshot.get("name_position", Vector3.ZERO)
	var action_position: Vector3 = snapshot.get("action_position", Vector3.ZERO)
	if action_position.x <= name_position.x or not is_equal_approx(action_position.y, name_position.y):
		return _fail("NPC action label is not positioned to the right of its name.")
	if float(snapshot.get("action_pixel_size", 1.0)) >= float(snapshot.get("name_pixel_size", 0.0)):
		return _fail("NPC action label must use a smaller font than its name.")
	var action_color: Color = snapshot.get("action_color", Color.WHITE)
	if action_color.r > 0.7 or action_color.g > 0.7 or action_color.b > 0.7:
		return _fail("NPC action label is not using the subdued gray color.")
	return true


func _verify_friendly_overhead_heights(snapshot: Dictionary) -> bool:
	var name_y := float((snapshot.get("name_position", Vector3.ZERO) as Vector3).y)
	var bar_y := float(((snapshot.get("health_bar", {}) as Dictionary).get("position", Vector3.ZERO) as Vector3).y)
	var activity_y := float((snapshot.get("llm_activity_marker_position", Vector3.ZERO) as Vector3).y)
	var proactive_y := float((snapshot.get("proactive_marker_position", Vector3.ZERO) as Vector3).y)
	var dialogue_y := float((snapshot.get("dialogue_bubble_position", Vector3.ZERO) as Vector3).y)
	var escape_y := float((snapshot.get("escape_marker_position", Vector3.ZERO) as Vector3).y)
	var emotion_y := float((snapshot.get("emotion_bubble_position", Vector3.ZERO) as Vector3).y)
	if bar_y < name_y + 0.5:
		return _fail("Friendly health bar is still too close to the name: %s" % snapshot)
	if minf(activity_y, proactive_y) < bar_y + 0.3:
		return _fail("Friendly thinking/proactive markers are not above the health-bar lane: %s" % snapshot)
	if minf(dialogue_y, escape_y) < activity_y + 0.15:
		return _fail("Friendly dialogue/escape markers are not in the raised status lane: %s" % snapshot)
	if emotion_y < dialogue_y + 0.5:
		return _fail("Dialogue emoji did not stay above the raised NPC dialogue bubble: %s" % snapshot)
	return true


func _verify_strategic_building_set(snapshot: Dictionary, expected_visible: bool) -> bool:
	var expected_ids := ["warehouse", "front_gate", "main_hall"]
	var actual_ids := snapshot.keys()
	actual_ids.sort()
	var sorted_expected := expected_ids.duplicate()
	sorted_expected.sort()
	if actual_ids != sorted_expected:
		return _fail("Strategic building health bar whitelist mismatch: %s" % actual_ids)
	for building_id in expected_ids:
		var bar: Dictionary = snapshot.get(building_id, {})
		if bool(bar.get("local_visible", not expected_visible)) != expected_visible:
			return _fail("%s health bar visibility mismatch: %s" % [building_id, bar])
		if expected_visible and not _verify_healthy_bar(bar, building_id):
			return false
	return true


func _verify_healthy_bar(raw: Variant, owner_name: String) -> bool:
	var bar: Dictionary = raw if raw is Dictionary else {}
	if not bool(bar.get("local_visible", false)) or bool(bar.get("danger", true)):
		return _fail("%s healthy wartime bar state mismatch: %s" % [owner_name, bar])
	if not (bar.get("color", Color.TRANSPARENT) as Color).is_equal_approx(HEALTHY_COLOR):
		return _fail("%s healthy wartime bar color mismatch: %s" % [owner_name, bar])
	return true


func _verify_danger_bar(raw: Variant, owner_name: String) -> bool:
	var bar: Dictionary = raw if raw is Dictionary else {}
	if not bool(bar.get("local_visible", false)) or not bool(bar.get("danger", false)):
		return _fail("%s danger wartime bar state mismatch: %s" % [owner_name, bar])
	if float(bar.get("ratio", 1.0)) >= 0.30:
		return _fail("%s danger wartime bar did not normalize below 30%%: %s" % [owner_name, bar])
	if not (bar.get("color", Color.TRANSPARENT) as Color).is_equal_approx(DANGER_COLOR):
		return _fail("%s danger wartime bar color mismatch: %s" % [owner_name, bar])
	return true


func _set_building_level(building_system: Node, building_id: String, level: int) -> void:
	var buildings: Dictionary = building_system.get("_buildings")
	var building: Dictionary = buildings.get(building_id, {})
	building["level"] = level
	building["hp"] = maxi(1, int(building.get("max_hp", 1)))
	buildings[building_id] = building
	building_system.set("_buildings", buildings)


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
