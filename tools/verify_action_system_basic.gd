extends SceneTree


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		push_error("Failed to load Main.tscn")
		quit(1)
		return

	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	if action_system == null or npc_system == null or building_system == null or resource_system == null or memory_system == null:
		push_error("Required systems not found")
		quit(1)
		return

	var npc_id := "veteran_deputy_01"
	_set_debug_move_speed(npc_id, 80.0)

	npc_system.update_npc_state(npc_id, {"satiety": 40, "fatigue": 70})
	var grain_before: int = resource_system.get_resource("grain")
	if not action_system.debug_assign_eat(npc_id):
		push_error("Failed to assign eat action")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, npc_id, "completed_eat"):
		push_error("Eat action did not complete")
		quit(1)
		return
	var after_grain_eat: Dictionary = npc_system.get_npc_state(npc_id)
	if int(after_grain_eat.get("satiety", 0)) != 65 or resource_system.get_resource("grain") != grain_before - 1:
		push_error("Grain eating result mismatch")
		quit(1)
		return

	resource_system.add_resource("meal", 1)
	npc_system.update_npc_state(npc_id, {"satiety": 40, "last_action_result": ""})
	if not action_system.debug_assign_eat(npc_id):
		push_error("Failed to assign meal eat action")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, npc_id, "completed_eat"):
		push_error("Meal eat action did not complete")
		quit(1)
		return
	var after_meal_eat: Dictionary = npc_system.get_npc_state(npc_id)
	if int(after_meal_eat.get("satiety", 0)) != 85 or resource_system.get_resource("meal") != 0:
		push_error("Meal eating result mismatch")
		quit(1)
		return

	npc_system.update_npc_state(npc_id, {"fatigue": 70, "last_action_result": ""})
	if not action_system.debug_assign_sleep(npc_id):
		push_error("Failed to assign sleep action")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, npc_id, "completed_sleep"):
		push_error("Sleep action did not complete")
		quit(1)
		return
	var after_sleep: Dictionary = npc_system.get_npc_state(npc_id)
	if int(after_sleep.get("fatigue", 0)) != 35:
		push_error("Sleep fatigue result mismatch")
		quit(1)
		return

	var worker_id := "gardener_01"
	_set_debug_move_speed(worker_id, 80.0)
	var grain_before_work: int = resource_system.get_resource("grain")
	npc_system.update_npc_state(worker_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(worker_id, "garden"):
		push_error("Failed to assign garden work")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, worker_id, "completed_work_garden"):
		push_error("Garden work did not complete")
		quit(1)
		return
	var after_work: Dictionary = npc_system.get_npc_state(worker_id)
	if resource_system.get_resource("grain") != grain_before_work + 2:
		push_error("Garden work resource output mismatch")
		quit(1)
		return
	if int(after_work.get("satiety", 0)) != 76 or int(after_work.get("fatigue", 0)) != 28:
		push_error("Garden work state delta mismatch")
		quit(1)
		return

	var cook_id := "cook_01"
	_set_debug_move_speed(cook_id, 80.0)
	var grain_before_tavern: int = resource_system.get_resource("grain")
	var wine_before: int = resource_system.get_resource("wine")
	npc_system.update_npc_state(cook_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(cook_id, "tavern"):
		push_error("Failed to assign tavern work")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, cook_id, "completed_work_tavern"):
		push_error("Tavern work did not complete")
		quit(1)
		return
	if resource_system.get_resource("grain") != grain_before_tavern - 1 or resource_system.get_resource("wine") != wine_before + 1:
		push_error("Tavern work resource result mismatch")
		quit(1)
		return

	var blacksmith_id := "blacksmith_01"
	_set_debug_move_speed(blacksmith_id, 80.0)
	var iron_before: int = resource_system.get_resource("iron")
	var wood_before_blacksmith: int = resource_system.get_resource("wood")
	var weapons_before: int = resource_system.get_resource("weapons")
	var armor_before: int = resource_system.get_resource("armor")
	npc_system.update_npc_state(blacksmith_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(blacksmith_id, "blacksmith"):
		push_error("Failed to assign blacksmith work")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, blacksmith_id, "completed_work_blacksmith"):
		push_error("Blacksmith work did not complete")
		quit(1)
		return
	if resource_system.get_resource("iron") != iron_before - 1 or resource_system.get_resource("wood") != wood_before_blacksmith - 1:
		push_error("Blacksmith input resource mismatch")
		quit(1)
		return
	if resource_system.get_resource("weapons") != weapons_before + 1 or resource_system.get_resource("armor") != armor_before + 1:
		push_error("Blacksmith output resource mismatch")
		quit(1)
		return

	var engineer_id := "engineer_01"
	_set_debug_move_speed(engineer_id, 80.0)
	var wood_before_workshop: int = resource_system.get_resource("wood")
	var devices_before: int = resource_system.get_resource("defense_devices")
	npc_system.update_npc_state(engineer_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(engineer_id, "workshop"):
		push_error("Failed to assign workshop work")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, engineer_id, "completed_work_workshop"):
		push_error("Workshop work did not complete")
		quit(1)
		return
	if resource_system.get_resource("wood") != wood_before_workshop - 2 or resource_system.get_resource("defense_devices") != devices_before + 1:
		push_error("Workshop resource result mismatch")
		quit(1)
		return

	var wall_before: Dictionary = building_system.get_building("wall")
	var wall_max_hp := int(wall_before.get("max_hp", 0))
	building_system.debug_damage_building("wall", 30)
	var stone_before_wall: int = resource_system.get_resource("stone")
	npc_system.update_npc_state(engineer_id, {"satiety": 80, "fatigue": 20, "last_action_result": ""})
	if not action_system.debug_assign_work(engineer_id, "wall"):
		push_error("Failed to assign wall repair work")
		quit(1)
		return
	if not await _wait_until_action_result(npc_system, engineer_id, "completed_work_repair_wall"):
		push_error("Wall repair work did not complete")
		quit(1)
		return
	var wall_after: Dictionary = building_system.get_building("wall")
	if resource_system.get_resource("stone") != stone_before_wall - 1:
		push_error("Wall repair did not spend stone")
		quit(1)
		return
	if int(wall_after.get("hp", 0)) != wall_max_hp - 10:
		push_error("Wall repair HP result mismatch")
		quit(1)
		return

	if memory_system.get_event_count() < 8:
		push_error("Action events were not written to structured event log")
		quit(1)
		return

	print("T0305 basic action system verification passed.")
	quit(0)


func _wait_until_action_result(npc_system: Node, npc_id: String, expected_result: String) -> bool:
	for frame in range(600):
		await process_frame
		var state: Dictionary = npc_system.get_npc_state(npc_id)
		if str(state.get("last_action_result", "")) == expected_result:
			return true
	return false


func _set_debug_move_speed(npc_id: String, speed: float) -> void:
	var npc_root := root.get_node_or_null("Main/WorldRoot/Station/NPCs")
	if npc_root == null:
		return

	for npc_node in npc_root.get_children():
		if str(npc_node.get_meta("npc_id", "")) == npc_id and "move_speed" in npc_node:
			npc_node.move_speed = speed
			return
