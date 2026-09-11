extends SceneTree


const NPC_ID := "veteran_deputy_01"
const NORMAL_BUILDING_ID := "dining_hall"
const SPATIAL_BUILDING_ID := "blacksmith"


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	if [npc_system, time_system, memory_system, gm_panel].has(null):
		_fail("Required systems not found")
		return
	_set_move_speed(npc_system, 40.0)

	# A new GM move during pause must be rejected without creating ghost state.
	time_system.set_paused(true)
	var before_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	var before_position: Variant = npc_system.get_npc_world_position(NPC_ID)
	var before_event_count: int = memory_system.get_npc_daily_events(NPC_ID).size()
	if npc_system.debug_move_npc_to_building(NPC_ID, NORMAL_BUILDING_ID):
		_fail("Paused debug movement reported success")
		return
	var rejected_state: Dictionary = npc_system.get_npc_state(NPC_ID)
	if not _expect(str(rejected_state.get("current_action", "")) == str(before_state.get("current_action", "")), "Paused rejection changed current_action"):
		return
	if not _expect(str(rejected_state.get("movement_target", "")) == str(before_state.get("movement_target", "")), "Paused rejection created movement_target"):
		return
	if not _expect(npc_system.get_npc_world_position(NPC_ID) == before_position, "Paused rejection changed world position"):
		return
	if not _expect(memory_system.get_npc_daily_events(NPC_ID).size() == before_event_count, "Paused rejection wrote movement events"):
		return

	gm_panel._run_move_npc(NPC_ID, NORMAL_BUILDING_ID)
	if not _expect("游戏当前暂停" in str(gm_panel._result_text.text), "GM panel did not explain paused movement rejection"):
		return
	if not _expect(str(npc_system.get_npc_state(NPC_ID).get("movement_target", "")).is_empty(), "GM paused rejection created ghost movement"):
		return

	# Resuming and retrying must complete a normal-building movement and event commit.
	time_system.set_paused(false)
	if not npc_system.debug_move_npc_to_building(NPC_ID, NORMAL_BUILDING_ID):
		_fail("Normal-building movement did not start after resume")
		return
	if not await _wait_for_location(npc_system, NORMAL_BUILDING_ID):
		_fail("Normal-building movement did not arrive after resume")
		return
	if not _expect(memory_system.get_location_people_present(NORMAL_BUILDING_ID).has(NPC_ID), "Normal-building people_present was not committed"):
		return
	if not _expect(_has_location_event(memory_system, "location_entered", NORMAL_BUILDING_ID), "Normal-building entry event was not recorded"):
		return

	# Pausing an already-running route still freezes and resumes, preserving pause semantics.
	if not npc_system.debug_move_npc_to_building(NPC_ID, "dormitory"):
		_fail("Could not start pause-in-flight scenario")
		return
	await process_frame
	time_system.set_paused(true)
	var frozen_position: Variant = npc_system.get_npc_world_position(NPC_ID)
	for _frame in range(20):
		await process_frame
	if not _expect(npc_system.get_npc_world_position(NPC_ID) == frozen_position, "Existing movement advanced while paused"):
		return
	if not _expect(str(npc_system.get_npc_state(NPC_ID).get("movement_target", "")) == "dormitory", "Pause cancelled an existing movement"):
		return
	time_system.set_paused(false)
	if not await _wait_for_location(npc_system, "dormitory"):
		_fail("Existing movement did not resume")
		return

	# The T0127 route follows the same GM pause contract and still commits after resume.
	time_system.set_paused(true)
	if npc_system.debug_move_npc_to_building(NPC_ID, SPATIAL_BUILDING_ID):
		_fail("Paused spatial movement reported success")
		return
	var spatial_rejected: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if not _expect(str(spatial_rejected.get("route_kind", "")).is_empty(), "Paused spatial rejection created a route"):
		return
	time_system.set_paused(false)
	if not npc_system.debug_move_npc_to_building(NPC_ID, SPATIAL_BUILDING_ID):
		_fail("Spatial movement did not start after resume")
		return
	if not await _wait_for_location(npc_system, SPATIAL_BUILDING_ID):
		_fail("Spatial movement did not cross the blacksmith door")
		return
	if not await _wait_for_movement_end(npc_system):
		_fail("Spatial movement did not reach the blacksmith interior target")
		return
	if not _expect(memory_system.get_location_people_present(SPATIAL_BUILDING_ID).has(NPC_ID), "Blacksmith people_present was not committed"):
		return
	if not _expect(_has_location_event(memory_system, "location_entered", SPATIAL_BUILDING_ID), "Blacksmith entry event was not recorded"):
		return

	print("T0127A paused GM movement verification passed.")
	quit(0)


func _wait_for_location(npc_system: Node, location_id: String) -> bool:
	for _frame in range(600):
		await process_frame
		if str(npc_system.get_npc_state(NPC_ID).get("current_location", "")) == location_id:
			return true
	return false


func _wait_for_movement_end(npc_system: Node) -> bool:
	for _frame in range(600):
		await process_frame
		if str(npc_system.get_npc_state(NPC_ID).get("movement_target", "")).is_empty():
			return true
	return false


func _has_location_event(memory_system: Node, event_type: String, location_id: String) -> bool:
	for raw_event in memory_system.get_npc_daily_events(NPC_ID):
		if not raw_event is Dictionary:
			continue
		var event: Dictionary = raw_event
		if str(event.get("type", "")) == event_type and str(event.get("location_id", "")) == location_id:
			return true
	return false


func _set_move_speed(npc_system: Node, speed: float) -> void:
	var npc_path: NodePath = npc_system._npc_nodes.get(NPC_ID, NodePath())
	var npc_node := npc_system.get_node_or_null(npc_path)
	if npc_node != null and "move_speed" in npc_node:
		npc_node.move_speed = speed


func _expect(condition: bool, message: String) -> bool:
	if condition:
		return true
	_fail(message)
	return false


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
