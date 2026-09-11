extends SceneTree


const MAIN_PATH := "res://scenes/main/Main.tscn"
const BUILDING_IDS := ["blacksmith", "workshop"]


func _init() -> void:
	var packed := load(MAIN_PATH) as PackedScene
	if packed == null:
		_fail("Main.tscn unavailable")
		return
	var main := packed.instantiate()
	root.add_child(main)
	for _step in 4:
		await process_frame
		await physics_frame
	var crafting := root.get_node_or_null("Main/Systems/CraftingSystem")
	var dialog := root.get_node_or_null("Main/UI/CraftingHarvestDialog")
	if crafting == null or dialog == null:
		_fail("Crafting harvest runtime hierarchy is incomplete")
		return
	for building_id in BUILDING_IDS:
		var recipe_ids: Array[String] = crafting.get_recipe_ids_for_building(building_id)
		for recipe_id in recipe_ids:
			var result: Dictionary = crafting.debug_complete_product(building_id, recipe_id)
			if not bool(result.get("ok", false)):
				_fail("Could not prepare pending output: %s" % JSON.stringify(result))
				return
		dialog.debug_open_for_building(building_id)
		await process_frame
		var snapshot: Dictionary = dialog.debug_get_snapshot()
		var entries: Array = snapshot.get("entries", [])
		var icons: Array = snapshot.get("icon_nodes", [])
		if entries.size() != icons.size() or icons.size() != recipe_ids.size():
			_fail("Pending icon projection count drifted: %s" % JSON.stringify(snapshot))
			return
		for index in icons.size():
			var expected_name := str((entries[index] as Dictionary).get("name", "")).strip_edges()
			var tooltip := str((icons[index] as Dictionary).get("tooltip", "")).strip_edges()
			if expected_name.is_empty() or tooltip != expected_name or tooltip.begins_with("item_"):
				_fail("Pending icon did not expose its formal name: %s" % JSON.stringify(icons[index]))
				return
		dialog.debug_close_without_collecting()
	print("T0339 crafting harvest icon tooltips verified")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
