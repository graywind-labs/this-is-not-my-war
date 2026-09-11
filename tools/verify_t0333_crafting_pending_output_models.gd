extends SceneTree


const BLACKSMITH_DISPLAY_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt/Interior/PendingOutputDisplay"
const WORKSHOP_DISPLAY_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop/WorkshopArt/Interior/PendingOutputDisplay"


func _init() -> void:
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("T0333 could not load Main.tscn")
		return
	root.add_child(main_scene.instantiate())
	await process_frame
	await physics_frame

	var crafting := root.get_node_or_null("Main/Systems/CraftingSystem")
	var resources := root.get_node_or_null("Main/Systems/ResourceSystem")
	var blacksmith_display := root.get_node_or_null(BLACKSMITH_DISPLAY_PATH)
	var workshop_display := root.get_node_or_null(WORKSHOP_DISPLAY_PATH)
	var blacksmith_art := blacksmith_display.get_node_or_null("../..") if blacksmith_display != null else null
	var workshop_art := workshop_display.get_node_or_null("../..") if workshop_display != null else null
	if [crafting, resources, blacksmith_display, workshop_display, blacksmith_art, workshop_art].has(null):
		_fail("T0333 required systems or formal display nodes are missing")
		return
	var blacksmith_empty_snapshot: Dictionary = blacksmith_display.debug_get_snapshot()
	var workshop_empty_snapshot: Dictionary = workshop_display.debug_get_snapshot()
	if (
		not blacksmith_display.visible
		or not workshop_display.visible
		or not bool(blacksmith_empty_snapshot.get("fixture_visible", false))
		or not bool(workshop_empty_snapshot.get("fixture_visible", false))
		or bool(blacksmith_empty_snapshot.get("item_visible", true))
		or bool(workshop_empty_snapshot.get("item_visible", true))
	):
		_fail("T0333 fixtures must remain visible while finished items start hidden")
		return
	var blacksmith_workstations_before: Dictionary = blacksmith_art.get_art_slice_snapshot().get("workstations", {}).duplicate(true)
	var workshop_workstations_before: Dictionary = workshop_art.get_art_slice_snapshot().get("workstations", {}).duplicate(true)

	var helmet_stock_before := int(resources.get_resource("item_iron_helmet"))
	if not _complete_recipe(crafting, resources, "blacksmith", "craft_iron_helmet"):
		return
	await process_frame
	if int(resources.get_resource("item_iron_helmet")) != helmet_stock_before:
		_fail("T0333 pending helmet leaked into formal inventory")
		return
	if str(crafting.get_latest_pending_output_item_id("blacksmith")) != "item_iron_helmet":
		_fail("T0333 CraftingSystem did not retain the latest blacksmith output identity")
		return
	if not _expect_display(blacksmith_display, "item_iron_helmet", "helmet"):
		return

	if not _complete_recipe(crafting, resources, "workshop", "craft_wall_arrow_tower"):
		return
	await process_frame
	if not _expect_display(workshop_display, "item_wall_arrow_tower", "asset"):
		return
	if not _complete_recipe(crafting, resources, "workshop", "craft_wall_ballista"):
		return
	await process_frame
	if str(crafting.get_latest_pending_output_item_id("workshop")) != "item_wall_ballista":
		_fail("T0333 later ballista did not replace the earlier arrow-tower identity")
		return
	if not _expect_display(workshop_display, "item_wall_ballista", "asset"):
		return
	var workshop_pending: Dictionary = crafting.get_pending_outputs("workshop")
	if int(workshop_pending.get("item_wall_arrow_tower", 0)) != 1 or int(workshop_pending.get("item_wall_ballista", 0)) != 1:
		_fail("T0333 visual replacement altered the pending-output store")
		return

	for building_id in ["blacksmith", "workshop"]:
		var display := blacksmith_display if building_id == "blacksmith" else workshop_display
		for recipe in crafting.get_recipes_for_building(building_id):
			var item_id := str(recipe.get("output_item_id", ""))
			display._rebuild_content(item_id)
			await process_frame
			var coverage_snapshot: Dictionary = display.debug_get_snapshot()
			if int(coverage_snapshot.get("mesh_count", 0)) <= 5 or int(coverage_snapshot.get("collision_object_count", -1)) != 0:
				_fail("T0333 item display coverage failed for %s: %s" % [item_id, JSON.stringify(coverage_snapshot)])
				return
		display._refresh_from_authority()
		await process_frame

	var workshop_collection: Dictionary = crafting.collect_pending_outputs("workshop")
	await process_frame
	var workshop_collected_snapshot: Dictionary = workshop_display.debug_get_snapshot()
	if (
		not bool(workshop_collection.get("ok", false))
		or not workshop_display.visible
		or not bool(workshop_collected_snapshot.get("fixture_visible", false))
		or bool(workshop_collected_snapshot.get("item_visible", true))
		or not str(crafting.get_latest_pending_output_item_id("workshop")).is_empty()
	):
		_fail("T0333 workshop item did not disappear while its permanent fixture remained")
		return
	if not blacksmith_display.visible:
		_fail("T0333 workshop collection incorrectly hid the independent blacksmith display")
		return
	var blacksmith_collection: Dictionary = crafting.collect_pending_outputs("blacksmith")
	await process_frame
	var blacksmith_collected_snapshot: Dictionary = blacksmith_display.debug_get_snapshot()
	if (
		not bool(blacksmith_collection.get("ok", false))
		or not blacksmith_display.visible
		or not bool(blacksmith_collected_snapshot.get("fixture_visible", false))
		or bool(blacksmith_collected_snapshot.get("item_visible", true))
	):
		_fail("T0333 blacksmith item did not disappear while its permanent fixture remained")
		return
	if int(resources.get_resource("item_iron_helmet")) != helmet_stock_before + 1:
		_fail("T0333 collection did not preserve the existing inventory authority")
		return
	if blacksmith_art.get_art_slice_snapshot().get("workstations", {}) != blacksmith_workstations_before:
		_fail("T0333 blacksmith display changed workstation state or position")
		return
	if workshop_art.get_art_slice_snapshot().get("workstations", {}) != workshop_workstations_before:
		_fail("T0333 workshop display changed workstation state or position")
		return

	print("T0333_CRAFTING_PENDING_OUTPUT_MODELS_OK")
	quit(0)


func _complete_recipe(crafting: Node, resources: Node, building_id: String, recipe_id: String) -> bool:
	var selected: Dictionary = crafting.set_target(building_id, recipe_id, true)
	if not bool(selected.get("ok", false)):
		_fail("T0333 could not select %s: %s" % [recipe_id, JSON.stringify(selected)])
		return false
	var recipe: Dictionary = crafting.get_recipe(recipe_id)
	for _stage_index in range((recipe.get("stages", []) as Array).size()):
		var project: Dictionary = crafting.get_project_snapshot(building_id)
		_ensure_cost(resources, project.get("current_stage_cost", {}))
		var result: Dictionary = crafting.complete_stage(building_id, int(project.get("project_revision", -1)), "")
		if not bool(result.get("ok", false)):
			_fail("T0333 stage completion failed: %s" % JSON.stringify(result))
			return false
	return true


func _ensure_cost(resources: Node, raw_cost: Variant) -> void:
	var cost: Dictionary = raw_cost if raw_cost is Dictionary else {}
	for raw_resource_id in cost.keys():
		var resource_id := str(raw_resource_id)
		var missing := int(cost[raw_resource_id]) - int(resources.get_resource(resource_id))
		if missing > 0:
			resources.add_resource(resource_id, missing)


func _expect_display(display: Node, item_id: String, kind: String) -> bool:
	var snapshot: Dictionary = display.debug_get_snapshot()
	if (
		not bool(snapshot.get("visible", false))
		or not bool(snapshot.get("fixture_visible", false))
		or not bool(snapshot.get("item_visible", false))
		or str(snapshot.get("displayed_item_id", "")) != item_id
		or str(snapshot.get("display_kind", "")) != kind
		or int(snapshot.get("mesh_count", 0)) <= 5
		or int(snapshot.get("collision_object_count", -1)) != 0
		or float(snapshot.get("item_bottom_y", 0.0)) + 0.0001 < float(snapshot.get("fixture_top_y", 0.0))
	):
		_fail("T0333 display mismatch for %s: %s" % [item_id, JSON.stringify(snapshot)])
		return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
