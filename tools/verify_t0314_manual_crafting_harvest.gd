extends SceneTree


func _init() -> void:
	root.size = Vector2i(1280, 720)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	root.add_child(main_scene.instantiate())
	await process_frame
	await physics_frame

	var crafting := root.get_node_or_null("Main/Systems/CraftingSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	var action_system := root.get_node_or_null("Main/Systems/ActionSystem")
	var memory_system := root.get_node_or_null("Main/Systems/MemorySystem")
	var feedback_presenter := root.get_node_or_null("Main/UI/WorldFeedbackPresenter")
	var harvest_presenter := root.get_node_or_null("Main/UI/CraftingTargetAlerts")
	var harvest_dialog := root.get_node_or_null("Main/UI/CraftingHarvestDialog")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	if [crafting, resources, action_system, memory_system, feedback_presenter, harvest_presenter, harvest_dialog, building_panel].has(null):
		_fail("T0314 required systems or UI nodes are missing")
		return

	var helmet_stock_before := int(resources.get_resource("item_iron_helmet"))
	var sword_stock_before := int(resources.get_resource("item_sword_shield"))
	if not _complete_recipe(crafting, resources, "blacksmith", "craft_iron_helmet", 2):
		return
	if int(resources.get_resource("item_iron_helmet")) != helmet_stock_before:
		_fail("Uncollected helmets leaked into formal inventory")
		return
	if int(crafting.get_pending_outputs("blacksmith").get("item_iron_helmet", 0)) != 2:
		_fail("Two identical products were not retained as two pending units")
		return

	if not _complete_recipe(crafting, resources, "blacksmith", "craft_sword_shield", 1):
		return
	var pending_blacksmith: Dictionary = crafting.get_pending_outputs("blacksmith")
	if int(pending_blacksmith.get("item_iron_helmet", 0)) != 2 or int(pending_blacksmith.get("item_sword_shield", 0)) != 1:
		_fail("Target switching lost old pending output or failed to retain a second type")
		return
	var active_project: Dictionary = crafting.get_project_snapshot("blacksmith")
	if str(active_project.get("target_recipe_id", "")) != "craft_sword_shield" or int(active_project.get("completed_stages", -1)) != 0:
		_fail("Product completion interrupted the selected repeating production target")
		return

	await process_frame
	var button_snapshot: Dictionary = harvest_presenter.debug_get_harvest_snapshot("blacksmith")
	if int(button_snapshot.get("pending_total", 0)) != 3 or bool(button_snapshot.get("has_count_badge", true)):
		_fail("World harvest button did not preserve pending state after removing its count badge")
		return
	if str(button_snapshot.get("icon_path", "")) != "res://assets/ui/status_icons/harvest_hand.svg":
		_fail("World harvest button did not use the project hand icon")
		return

	harvest_dialog.debug_open_for_building("blacksmith")
	var dialog_snapshot: Dictionary = harvest_dialog.debug_get_snapshot()
	if not bool(dialog_snapshot.get("visible", false)) or int(dialog_snapshot.get("rendered_icon_count", 0)) != 3:
		_fail("Harvest dialog did not render one icon per pending item")
		return
	if bool(dialog_snapshot.get("shows_item_names", true)) or bool(dialog_snapshot.get("shows_quantity_badges", true)):
		_fail("Harvest dialog still renders item names or quantity badges")
		return
	for raw_icon_node in dialog_snapshot.get("icon_nodes", []):
		var icon_node: Dictionary = raw_icon_node if raw_icon_node is Dictionary else {}
		if not str(icon_node.get("text", "")).is_empty() or str(icon_node.get("tooltip", "")).is_empty() or not bool(icon_node.get("has_icon", false)) or not bool(icon_node.get("flat", false)):
			_fail("Harvest item projection is not a borderless icon with tooltip-only naming")
			return
	for entry in dialog_snapshot.get("entries", []):
		if str(entry.get("icon_path", "")).is_empty() or str(entry.get("name", "")).is_empty():
			_fail("Harvest icon projection lost its icon or hover-tooltip name")
			return
	if not _complete_recipe(crafting, resources, "blacksmith", "craft_sword_shield", 1):
		return
	dialog_snapshot = harvest_dialog.debug_get_snapshot()
	if int(dialog_snapshot.get("rendered_icon_count", 0)) != 4:
		_fail("An item completed while the dialog was open did not refresh as one more icon")
		return
	harvest_dialog.debug_close_without_collecting()
	if crafting.get_pending_output_total("blacksmith") != 4:
		_fail("Closing the harvest dialog collected or discarded pending output")
		return

	building_panel.show_building("blacksmith")
	await process_frame
	var panel_snapshot: Dictionary = building_panel.debug_get_crafting_panel_snapshot()
	if bool(panel_snapshot.get("harvest_disabled", true)) or not str(panel_snapshot.get("pending_text", "")).contains("4 件"):
		_fail("Building panel did not expose the same pending-harvest entry")
		return

	var project_before_collect: Dictionary = crafting.get_project_snapshot("blacksmith")
	harvest_dialog.debug_open_for_building("blacksmith")
	var collection: Dictionary = harvest_dialog.debug_collect_all()
	if not bool(collection.get("ok", false)) or crafting.get_pending_output_total("blacksmith") != 0:
		_fail("Collect all did not atomically clear the blacksmith pending snapshot")
		return
	if int(resources.get_resource("item_iron_helmet")) != helmet_stock_before + 2 or int(resources.get_resource("item_sword_shield")) != sword_stock_before + 2:
		_fail("Collect all did not transfer every exact item into formal inventory")
		return
	var project_after_collect: Dictionary = crafting.get_project_snapshot("blacksmith")
	if str(project_after_collect.get("target_recipe_id", "")) != str(project_before_collect.get("target_recipe_id", "")) or int(project_after_collect.get("project_revision", -1)) != int(project_before_collect.get("project_revision", -2)):
		_fail("Collection altered the selected production target or revision")
		return

	if not _verify_action_event_and_feedback(crafting, resources, action_system, memory_system, feedback_presenter):
		return

	print("T0314 manual crafting harvest verification passed.")
	quit(0)


func _complete_recipe(crafting: Node, resources: Node, building_id: String, recipe_id: String, count: int) -> bool:
	var selected: Dictionary = crafting.set_target(building_id, recipe_id, true)
	if not bool(selected.get("ok", false)):
		return _fail("Could not select %s: %s" % [recipe_id, JSON.stringify(selected)])
	for _item_index in range(count):
		var recipe: Dictionary = crafting.get_recipe(recipe_id)
		for _stage_index in range((recipe.get("stages", []) as Array).size()):
			var project: Dictionary = crafting.get_project_snapshot(building_id)
			_ensure_cost(resources, project.get("current_stage_cost", {}))
			var result: Dictionary = crafting.complete_stage(building_id, int(project.get("project_revision", -1)), "")
			if not bool(result.get("ok", false)):
				return _fail("Stage completion failed: %s" % JSON.stringify(result))
	return true


func _verify_action_event_and_feedback(crafting: Node, resources: Node, action_system: Node, memory_system: Node, presenter: Node) -> bool:
	var building_id := "workshop"
	var recipe_id := "craft_bow"
	var selected: Dictionary = crafting.set_target(building_id, recipe_id, true)
	if not bool(selected.get("ok", false)):
		return _fail("Could not select workshop action-event fixture")
	var recipe: Dictionary = crafting.get_recipe(recipe_id)
	for _stage_index in range((recipe.get("stages", []) as Array).size() - 1):
		var project: Dictionary = crafting.get_project_snapshot(building_id)
		_ensure_cost(resources, project.get("current_stage_cost", {}))
		var result: Dictionary = crafting.complete_stage(building_id, int(project.get("project_revision", -1)), "")
		if not bool(result.get("ok", false)):
			return _fail("Could not prepare the final workshop stage")

	presenter.debug_advance_feedback(2.1)
	var final_project: Dictionary = crafting.get_project_snapshot(building_id)
	_ensure_cost(resources, final_project.get("current_stage_cost", {}))
	var bow_stock_before := int(resources.get_resource("item_bow"))
	var bow_pending_before := int(crafting.get_pending_outputs(building_id).get("item_bow", 0))
	var action: Dictionary = action_system.get_action("work_workshop")
	action_system._complete_work("engineer_01", {
		"action": action,
		"building_id": building_id,
		"workstation_id": "",
		"crafting_project_revision": int(final_project.get("project_revision", -1)),
		"crafting_recipe_id": recipe_id,
		"crafting_target_item_id": "item_bow",
		"duration_seconds": float(action.get("duration_seconds", 3600.0)),
		"state_deltas": {},
		"applied_state_deltas": {}
	})
	if int(resources.get_resource("item_bow")) != bow_stock_before or int(crafting.get_pending_outputs(building_id).get("item_bow", 0)) != bow_pending_before + 1:
		return _fail("Action completion bypassed workshop pending output")

	var work_event := _find_last_work_completed(memory_system.get_npc_daily_events("engineer_01"))
	var payload: Dictionary = work_event.get("payload", {}) if work_event.get("payload", {}) is Dictionary else {}
	if not (payload.get("output_resources", {}) as Dictionary).is_empty() or int((payload.get("pending_output_resources", {}) as Dictionary).get("item_bow", 0)) != 1:
		return _fail("Manufacturing memory event did not distinguish formal and pending output")
	if not str(work_event.get("summary", "")).contains("待收取"):
		return _fail("Manufacturing memory summary implied warehouse output instead of pending output")
	var feedback_groups: Array = presenter.debug_get_snapshot()
	if feedback_groups.size() != 1 or not _has_feedback_entry(feedback_groups[0], "弓（待收取）", "gain", 1, true):
		return _fail("Final manufacturing feedback did not show the pending item icon and status")
	return true


func _ensure_cost(resources: Node, raw_cost: Variant) -> void:
	var cost: Dictionary = raw_cost if raw_cost is Dictionary else {}
	for raw_resource_id in cost.keys():
		var resource_id := str(raw_resource_id)
		var missing := int(cost[raw_resource_id]) - int(resources.get_resource(resource_id))
		if missing > 0:
			resources.add_resource(resource_id, missing)


func _find_last_work_completed(events: Array) -> Dictionary:
	for index in range(events.size() - 1, -1, -1):
		var event: Dictionary = events[index] if events[index] is Dictionary else {}
		if str(event.get("type", "")) == "work_completed":
			return event
	return {}


func _has_feedback_entry(group: Dictionary, display_name: String, color_role: String, amount: int, require_icon: bool) -> bool:
	for raw_entry in group.get("entries", []):
		var entry: Dictionary = raw_entry if raw_entry is Dictionary else {}
		if str(entry.get("display_name", "")) != display_name or str(entry.get("color_role", "")) != color_role or int(entry.get("amount", 0)) != amount:
			continue
		return not require_icon or not str(entry.get("icon_path", "")).is_empty()
	return false


func _fail(message: String) -> bool:
	push_error(message)
	quit(1)
	return false
