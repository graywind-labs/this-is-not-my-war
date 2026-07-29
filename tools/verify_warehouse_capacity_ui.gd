extends SceneTree


const LIMITED_CAPACITIES_LEVEL_1 := {
	"grain": 120,
	"meal": 120,
	"wine": 60,
	"wood": 120,
	"stone": 120,
	"iron": 120
}
const LIMITED_CAPACITIES_LEVEL_2 := {
	"grain": 180,
	"meal": 180,
	"wine": 90,
	"wood": 180,
	"stone": 180,
	"iron": 180
}


func _init() -> void:
	root.size = Vector2i(1280, 720)
	DisplayServer.window_set_size(root.size)
	var main_scene := load("res://scenes/main/Main.tscn") as PackedScene
	if main_scene == null:
		_fail("Failed to load Main.tscn")
		return
	var main := main_scene.instantiate()
	root.add_child(main)
	await process_frame
	await process_frame
	await process_frame

	var resource_system := root.get_node_or_null("Main/Systems/ResourceSystem")
	var building_system := root.get_node_or_null("Main/Systems/BuildingSystem")
	var building_panel := root.get_node_or_null("Main/UI/BuildingPanel")
	var hud := root.get_node_or_null("Main/UI/HUD")
	if (
		resource_system == null
		or building_system == null
		or building_panel == null
		or hud == null
	):
		_fail("Warehouse capacity verification nodes not found")
		return

	if not _verify_capacities(resource_system, LIMITED_CAPACITIES_LEVEL_1):
		return
	if int(resource_system.get_resource_capacity("money")) != -1:
		_fail("Money must remain outside warehouse capacity")
		return

	var grain_before := int(resource_system.get_resource("grain"))
	var grain_remaining := int(resource_system.get_resource_remaining_capacity("grain"))
	if (
		grain_remaining <= 0
		or not bool(resource_system.add_resource("grain", grain_remaining))
		or int(resource_system.get_resource("grain")) != 120
	):
		_fail("A limited resource must be able to fill exactly to its capacity")
		return
	if (
		bool(resource_system.add_resource("grain", 1))
		or int(resource_system.get_resource("grain")) != 120
	):
		_fail("A positive resource addition must be rejected atomically above capacity")
		return
	if bool(resource_system.add_resources({"grain": 1, "money": 2})):
		_fail("A multi-resource addition must reject the whole batch when one item overflows")
		return
	if int(resource_system.get_resource("money")) != 30:
		_fail("Rejected multi-resource addition changed an unlimited resource")
		return
	if not bool(resource_system.add_resource("grain", grain_before - 120)):
		_fail("Failed to restore grain after the authority-capacity check")
		return

	building_panel.show_building("warehouse")
	await process_frame
	await process_frame
	await process_frame
	var capacity_label := building_panel.find_child(
		"WarehouseCapacityLabel",
		true,
		false
	) as Label
	if capacity_label == null or not capacity_label.visible:
		_fail("Warehouse building panel did not show its capacity line")
		return
	for expected_fragment in [
		"储存上限：",
		"粮食 120",
		"餐食 120",
		"酒 60",
		"木材 120",
		"石料 120",
		"铁 120"
	]:
		if not capacity_label.text.contains(expected_fragment):
			_fail("Warehouse capacity line missed %s: %s" % [
				expected_fragment,
				capacity_label.text
			])
			return

	var grain_label := hud.find_child("GrainResourceLabel", true, false) as Label
	var wine_label := hud.find_child("WineResourceLabel", true, false) as Label
	var money_label := hud.find_child("MoneyResourceLabel", true, false) as Label
	if (
		grain_label == null
		or wine_label == null
		or money_label == null
		or grain_label.tooltip_text != "仓库储存上限：120"
		or wine_label.tooltip_text != "仓库储存上限：60"
		or not money_label.tooltip_text.is_empty()
		or grain_label.mouse_filter != Control.MOUSE_FILTER_STOP
	):
		_fail("Top-left resource hover capacity hints are incomplete")
		return

	if not bool(building_system.upgrade_building("warehouse")):
		_fail("Warehouse level-2 upgrade failed to start")
		return
	building_system._on_logical_time_tick(999999.0, 1.0)
	await process_frame
	await process_frame
	await process_frame
	if int(building_system.get_building("warehouse").get("level", 0)) != 2:
		_fail("Warehouse upgrade did not complete")
		return
	if not _verify_capacities(resource_system, LIMITED_CAPACITIES_LEVEL_2):
		return
	if (
		not capacity_label.text.contains("粮食 180")
		or not capacity_label.text.contains("酒 90")
		or grain_label.tooltip_text != "仓库储存上限：180"
		or wine_label.tooltip_text != "仓库储存上限：90"
	):
		_fail("Warehouse panel or HUD hover hints did not refresh after the upgrade")
		return

	print(
		"Warehouse capacity authority and UI verification passed: "
		+ "six limited resources, atomic overflow rejection, level-1/2 panel line, "
		+ "and top-left hover hints."
	)
	quit(0)


func _verify_capacities(resource_system: Node, expected: Dictionary) -> bool:
	var snapshot: Array = resource_system.get_warehouse_capacity_snapshot()
	if snapshot.size() != expected.size():
		_fail("Warehouse capacity snapshot should contain exactly six bulk resources")
		return false
	for raw_resource_id in expected.keys():
		var resource_id := str(raw_resource_id)
		if int(resource_system.get_resource_capacity(resource_id)) != int(expected[resource_id]):
			_fail("Unexpected capacity for %s" % resource_id)
			return false
	return true


func _fail(message: String) -> void:
	push_error(message)
	quit(1)
