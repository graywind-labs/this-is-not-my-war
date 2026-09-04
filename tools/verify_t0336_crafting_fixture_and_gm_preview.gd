extends SceneTree


const BLACKSMITH_DISPLAY_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Blacksmith/BlacksmithArt/Interior/PendingOutputDisplay"
const WORKSHOP_DISPLAY_PATH := "Main/WorldRoot/FormalStationLayout/BuildingRoots/Workshop/WorkshopArt/Interior/PendingOutputDisplay"

var _failures: Array[String] = []


func _init() -> void:
	var packed := load("res://scenes/main/Main.tscn") as PackedScene
	check(packed != null, "Main.tscn could not be loaded")
	if packed == null:
		finish()
		return
	root.add_child(packed.instantiate())
	for _frame in 6:
		await process_frame
		await physics_frame

	var crafting := root.get_node_or_null("Main/Systems/CraftingSystem")
	var gm_panel := root.get_node_or_null("Main/UI/GMPanel")
	var blacksmith_display := root.get_node_or_null(BLACKSMITH_DISPLAY_PATH)
	var workshop_display := root.get_node_or_null(WORKSHOP_DISPLAY_PATH)
	check(crafting != null and gm_panel != null and blacksmith_display != null and workshop_display != null, "T0336 dependencies are missing")
	if not _failures.is_empty():
		finish()
		return

	var blacksmith_select := gm_panel.find_child("BlacksmithCompletedProductSelect", true, false) as OptionButton
	var workshop_select := gm_panel.find_child("WorkshopCompletedProductSelect", true, false) as OptionButton
	var blacksmith_button := gm_panel.find_child("BlacksmithCompleteProductButton", true, false) as Button
	var workshop_button := gm_panel.find_child("WorkshopCompleteProductButton", true, false) as Button
	check(blacksmith_select != null and workshop_select != null and blacksmith_button != null and workshop_button != null, "GM completed-product controls are missing")
	if not _failures.is_empty():
		finish()
		return

	var blacksmith_recipe_ids: Array[String] = crafting.get_recipe_ids_for_building("blacksmith")
	var workshop_recipe_ids: Array[String] = crafting.get_recipe_ids_for_building("workshop")
	check(_selected_ids(blacksmith_select) == blacksmith_recipe_ids, "Blacksmith GM selector does not match its formal recipe catalog")
	check(_selected_ids(workshop_select) == workshop_recipe_ids, "Workshop GM selector does not match its formal recipe catalog")
	check(blacksmith_recipe_ids.size() == 6 and workshop_recipe_ids.size() == 4, "Expected 6 blacksmith and 4 workshop products")

	for building_id in ["blacksmith", "workshop"]:
		var display := blacksmith_display if building_id == "blacksmith" else workshop_display
		var preview_button := blacksmith_button if building_id == "blacksmith" else workshop_button
		var empty_snapshot: Dictionary = display.debug_get_snapshot()
		check(bool(empty_snapshot.get("visible", false)), "%s fixture display is not permanently visible" % building_id)
		check(bool(empty_snapshot.get("fixture_visible", false)), "%s fixture is missing" % building_id)
		check(not bool(empty_snapshot.get("item_visible", true)), "%s starts with an unexpected item" % building_id)
		check(int(empty_snapshot.get("fixture_mesh_count", 0)) == 5, "%s fixture geometry changed unexpectedly" % building_id)

		var building_recipe_ids: Array[String] = crafting.get_recipe_ids_for_building(building_id)
		for recipe_index in building_recipe_ids.size():
			var recipe_id := building_recipe_ids[recipe_index]
			var recipe: Dictionary = crafting.get_recipe(recipe_id)
			var item_id := str(recipe.get("output_item_id", ""))
			var result: Dictionary = {}
			if recipe_index == 0:
				preview_button.pressed.emit()
				result = {"ok": int(crafting.get_pending_outputs(building_id).get(item_id, 0)) > 0}
			else:
				result = crafting.debug_complete_product(building_id, recipe_id)
			await process_frame
			var snapshot: Dictionary = display.debug_get_snapshot()
			check(bool(result.get("ok", false)), "GM completion failed for %s" % recipe_id)
			check(str(snapshot.get("displayed_item_id", "")) == item_id, "Latest display mismatch for %s" % recipe_id)
			check(bool(snapshot.get("fixture_visible", false)) and bool(snapshot.get("item_visible", false)), "Fixture/item visibility mismatch for %s" % recipe_id)
			check(int(snapshot.get("item_mesh_count", 0)) > 0, "No finished-item mesh for %s" % recipe_id)
			check(int(snapshot.get("collision_object_count", -1)) == 0, "Finished-item preview has collision for %s" % recipe_id)
			check(
				float(snapshot.get("item_bottom_y", -999.0)) + 0.0001 >= float(snapshot.get("fixture_top_y", 0.0)),
				"Finished item intersects fixture for %s: %s" % [recipe_id, JSON.stringify(snapshot)]
			)

		var collected: Dictionary = crafting.collect_pending_outputs(building_id)
		await process_frame
		var collected_snapshot: Dictionary = display.debug_get_snapshot()
		check(bool(collected.get("ok", false)), "Could not collect %s preview outputs" % building_id)
		check(bool(collected_snapshot.get("fixture_visible", false)), "%s fixture disappeared after collection" % building_id)
		check(not bool(collected_snapshot.get("item_visible", true)), "%s item remained after collection" % building_id)

	finish()


func _selected_ids(select: OptionButton) -> Array[String]:
	var result: Array[String] = []
	for index in select.get_item_count():
		result.append(str(select.get_item_metadata(index)))
	return result


func check(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func finish() -> void:
	if _failures.is_empty():
		print("T0336_CRAFTING_FIXTURE_AND_GM_PREVIEW PASS")
		quit(0)
		return
	for failure in _failures:
		push_error(failure)
	print("T0336_CRAFTING_FIXTURE_AND_GM_PREVIEW FAIL count=%d" % _failures.size())
	quit(1)
