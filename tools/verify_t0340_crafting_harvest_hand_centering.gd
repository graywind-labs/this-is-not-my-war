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
	var presenter := root.get_node_or_null("Main/UI/CraftingTargetAlerts")
	if crafting == null or presenter == null:
		_fail("Crafting harvest world presenter is unavailable")
		return
	for building_id in BUILDING_IDS:
		var recipe_ids: Array[String] = crafting.get_recipe_ids_for_building(building_id)
		if recipe_ids.is_empty():
			_fail("Manufacturing building has no formal recipe: %s" % building_id)
			return
		var result: Dictionary = crafting.debug_complete_product(building_id, recipe_ids[0])
		if not bool(result.get("ok", false)):
			_fail("Could not prepare pending output: %s" % JSON.stringify(result))
			return
		await process_frame
		var snapshot: Dictionary = presenter.debug_get_harvest_snapshot(building_id)
		if bool(snapshot.get("has_count_badge", true)):
			_fail("Removed count badge still exists: %s" % JSON.stringify(snapshot))
			return
		if int(snapshot.get("icon_alignment", -1)) != HORIZONTAL_ALIGNMENT_CENTER or int(snapshot.get("vertical_icon_alignment", -1)) != VERTICAL_ALIGNMENT_CENTER:
			_fail("Harvest hand is not centered on both axes: %s" % JSON.stringify(snapshot))
			return
		if not bool(snapshot.get("expand_icon", false)) or int(snapshot.get("icon_max_width", 0)) != 28:
			_fail("Harvest hand sizing contract drifted: %s" % JSON.stringify(snapshot))
			return
	print("T0340 crafting harvest hand centering verified")
	quit(0)


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
