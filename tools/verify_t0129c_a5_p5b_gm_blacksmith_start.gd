extends SceneTree


const NPC_ID := "blacksmith_01"
const BUILDING_ID := "blacksmith"
const ACTION_ID := "work_blacksmith"


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await physics_frame

	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var gm_window := root.get_node_or_null("Main/UI/GMPanel/GMWindow") as Control
	var formal_button := gm_window.find_child("FormalBlacksmithWorkButton", true, false) as Button if gm_window != null else null
	var time_system := root.get_node_or_null("Main/Systems/TimeSystem")
	var crafting_system := root.get_node_or_null("Main/Systems/CraftingSystem")
	var npc_system := root.get_node_or_null("Main/Systems/NPCSystem")
	var controller := root.get_node_or_null("Main/Presentation/StationLayoutController")
	if [gm_panel, gm_window, formal_button, time_system, crafting_system, npc_system, controller].has(null):
		_fail("A5-P5b-R runtime dependencies unavailable")
		return
	if not str(crafting_system.get_project_snapshot(BUILDING_ID).get("target_recipe_id", "")).is_empty():
		_fail("Fresh Main unexpectedly already has a blacksmith target")
		return

	var glen := _get_npc_node(npc_system, NPC_ID)
	if glen == null:
		_fail("Glen scene node unavailable")
		return
	glen.set("move_speed", 40.0)
	time_system.set_paused(false)
	gm_window.visible = true
	formal_button.pressed.emit()
	await process_frame

	var project: Dictionary = crafting_system.get_project_snapshot(BUILDING_ID)
	var formal: Dictionary = npc_system.get_formal_workstation_action_snapshot(NPC_ID)
	var spatial: Dictionary = npc_system.debug_get_spatial_migration_snapshot(NPC_ID)
	if str(project.get("target_recipe_id", "")).is_empty():
		_fail("One-click GM start did not auto-select a blacksmith recipe")
		return
	if not bool(formal.get("active", false)):
		_fail("One-click GM start did not create a formal workstation session: %s" % JSON.stringify(formal))
		return
	if gm_window.visible:
		_fail("Successful GM start left the GM window covering the formal scene")
		return
	if not bool(controller.is_runtime_formal_world_enabled()):
		_fail("Successful GM start did not reveal the formal world")
		return
	if not glen.visible or absf(glen.global_position.x) > 80.0 or absf(glen.global_position.z) > 100.0:
		_fail("Glen was not visibly staged in the formal world: %s" % JSON.stringify(spatial))
		return
	if not await _wait_for_action(npc_system, ACTION_ID):
		_fail("One-click GM start did not reach active blacksmith work: %s" % JSON.stringify(npc_system.debug_get_spatial_migration_snapshot(NPC_ID)))
		return

	print("T0129C A5-P5b-R one-click GM blacksmith start passed")
	quit(0)


func _get_npc_node(npc_system: Node, npc_id: String) -> Node:
	var node_paths: Dictionary = npc_system.get("_npc_nodes")
	return npc_system.get_node_or_null(node_paths.get(npc_id, NodePath("")))


func _wait_for_action(npc_system: Node, action_id: String, max_frames: int = 700) -> bool:
	for _frame in range(max_frames):
		if str(npc_system.get_npc_state(NPC_ID).get("current_action", "")) == action_id:
			return true
		time_system_resume(npc_system)
		await physics_frame
		await process_frame
	return false


func time_system_resume(npc_system: Node) -> void:
	var time_system := npc_system.get_node_or_null("../TimeSystem")
	if time_system != null and time_system.has_method("set_paused"):
		time_system.set_paused(false)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
